# backend/app/services/scheduler_tasks.py
import logging
import uuid
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.attendance import Attendance
from app.models.attendance_session import AttendanceSession
from app.models.attendance_enums import AttendanceStatus
from app.models.student_location import StudentLocation
from app.services.session_finalizer_service import handle_finalize_session
from app.services.attendance_report_service import generate_reports_for_class
from firebase_admin import messaging
from app.models.user import User

logger = logging.getLogger(__name__)

NETWORK_GRACE_SECONDS = 30


def _ensure_aware_utc(dt):
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _is_pending_silent_check(record: Attendance) -> bool:
    if record.last_verified_at is None:
        return True
    check_in_time = _ensure_aware_utc(record.check_in_time)
    last_verified_at = _ensure_aware_utc(record.last_verified_at)
    return check_in_time is not None and last_verified_at == check_in_time


def _latest_silent_evidence(db: Session, session_id: uuid.UUID, student_id: uuid.UUID):
    return (
        db.query(StudentLocation)
        .filter(
            StudentLocation.session_id == session_id,
            StudentLocation.student_id == student_id,
            StudentLocation.is_silent_check.is_(True),
        )
        .order_by(
            StudentLocation.server_received_at.desc().nullslast(),
            StudentLocation.timestamp.desc(),
        )
        .first()
    )


def close_checkin_job(session_id: uuid.UUID):
    """ปิดรับเช็คชื่อเมื่อถึง end_time โดยยังไม่ตัด LeftEarly ใน job นี้"""
    print(f"🔒 [Scheduler] ปิดรับเช็คชื่อสำหรับ Session: {session_id}")
    db: Session = SessionLocal()
    try:
        session = (
            db.query(AttendanceSession)
            .filter(AttendanceSession.session_id == session_id)
            .first()
        )
        if not session:
            print(f"⚠️ [Scheduler] ไม่พบ Session สำหรับปิดเช็คชื่อ: {session_id}")
            return

        if session.is_active:
            session.is_active = False
            db.commit()
            print(f"✅ [Scheduler] ปิดเช็คชื่อแล้ว: {session_id}")
        else:
            print(f"ℹ️ [Scheduler] Session ถูกปิดเช็คชื่ออยู่แล้ว: {session_id}")
    except Exception as e:
        db.rollback()
        print(f"❌ [Scheduler] ปิดเช็คชื่อไม่สำเร็จ: {str(e)}")
    finally:
        db.close()


def _derive_late_grace_window(record: Attendance, session: AttendanceSession) -> timedelta:
    _ = record
    _ = session
    return timedelta(seconds=NETWORK_GRACE_SECONDS)


def _should_spare_late_student(
    record: Attendance,
    session: AttendanceSession,
    silent_check_at: datetime | None,
) -> bool:
    if silent_check_at is None:
        return True

    check_in_time = _ensure_aware_utc(record.check_in_time)
    if check_in_time is None:
        return False

    if check_in_time >= silent_check_at:
        return True

    grace_deadline = check_in_time + _derive_late_grace_window(record, session)
    return silent_check_at <= grace_deadline


def finalize_attendance_job(session_id: uuid.UUID):
    """
    Job สำหรับตัดสินผลหลัง silent-check และสรุป attendance ตอนท้าย
    """
    print(f"⏳ [Scheduler] เริ่มการเช็คบิลอัตโนมัติสำหรับ Session: {session_id}")

    db: Session = SessionLocal()
    try:
        session = (
            db.query(AttendanceSession)
            .filter(AttendanceSession.session_id == session_id)
            .first()
        )
        if not session:
            print(f"⚠️ [Scheduler] ไม่พบ Session: {session_id}")
            return

        # 1. ตัดสินผลจากหลักฐาน silent-check ล่าสุด
        records = (
            db.query(Attendance)
            .filter(
                Attendance.session_id == session_id,
                Attendance.status.in_(
                    [AttendanceStatus.PRESENT, AttendanceStatus.LATE]
                ),
            )
            .all()
        )

        for record in records:
            evidence = _latest_silent_evidence(db, session_id, record.student_id)
            if evidence is None:
                print(
                    f"🚨 [LEFT_EARLY_NO_LOG] นักเรียน {record.student_id} ไม่มีหลักฐาน silent-check ภายในหน้าต่างที่กำหนด"
                )
                record.status = AttendanceStatus.LEFT_EARLY
                continue

            result = (evidence.verification_result or "").lower()

            if result == "in_range":
                print(
                    f"✅ [STILL_HERE] นักเรียน {record.student_id} ผ่าน silent-check "
                    f"(distance={evidence.distance_m}, radius={evidence.radius_m})"
                )
            elif result == "out_of_range":
                print(
                    f"🚨 [LEFT_EARLY_OUT_OF_RANGE] นักเรียน {record.student_id} นอกระยะ "
                    f"(distance={evidence.distance_m}, radius={evidence.radius_m})"
                )
                record.status = AttendanceStatus.LEFT_EARLY
            else:
                print(
                    f"🚨 [LEFT_EARLY_UNVERIFIED] นักเรียน {record.student_id} มี evidence result='{result or 'unknown'}' "
                    f"จึงตัดเป็น LeftEarly"
                )
                record.status = AttendanceStatus.LEFT_EARLY

        db.flush()

        # 2. ปิด Session และเติมคนขาด (ABSENT)
        handle_finalize_session(db, session_id)

        db.commit()
        print(f"✅ [Scheduler] ปิด Session และเช็คบิลเรียบร้อยแล้ว")

        # 3. Auto-generate attendance report
        try:
            class_id = str(session.class_id)
            generate_reports_for_class(db, class_id)
            print(f"✅ [Scheduler] สร้างรายงานอัตโนมัติสำเร็จสำหรับ class {class_id}")
        except Exception as report_err:
            print(f"⚠️ [Scheduler] สร้างรายงานอัตโนมัติไม่สำเร็จ: {report_err}")

    except Exception as e:
        db.rollback()
        print(f"❌ [Scheduler] เกิดข้อผิดพลาด: {str(e)}")
    finally:
        db.close()


def trigger_silent_check_job(session_id: uuid.UUID):
    """
    Job สำหรับยิง Silent Push ไปหาคนที่เช็คชื่อแล้ว (PRESENT/LATE) เพื่อขอพิกัดยืนยัน
    """
    print(f"🔔 [FCM] กำลังยิง Silent Push ตรวจพิกัดสำหรับ Session: {session_id}")

    db: Session = SessionLocal()
    try:
        # ดึง fcm_token ของนักเรียนที่เช็คชื่อเข้าคลาสแล้ว
        records = (
            db.query(User.fcm_token)
            .join(Attendance, Attendance.student_id == User.user_id)
            .filter(
                Attendance.session_id == session_id,
                Attendance.status.in_(
                    [AttendanceStatus.PRESENT, AttendanceStatus.LATE]
                ),
                User.fcm_token.isnot(None),  # เอาเฉพาะคนที่มี Token
            )
            .all()
        )

        tokens = [r[0] for r in records if r[0]]

        if not tokens:
            print("⚠️ [FCM] ไม่มีนักเรียนให้ส่ง Push (หรือยังไม่มีใครอัปเดต fcm_token)")
            return

        # สร้าง Data Message (ไม่ส่งเสียงร้อง แต่แอปจะทำงานเบื้องหลัง)
        message = messaging.MulticastMessage(
            data={
                "type": "SILENT_CHECK",
                "session_id": str(session_id),
                "action": "request_location",
            },
            tokens=tokens,
        )

        # สั่งยิงผ่าน Firebase
        response = messaging.send_each_for_multicast(message)
        print(
            f"✅ [FCM] ยิงสำเร็จ {response.success_count} เครื่อง, ล้มเหลว {response.failure_count} เครื่อง"
        )

    except Exception as e:
        print(f"❌ [FCM] เกิดข้อผิดพลาดในการยิง: {str(e)}")
    finally:
        db.close()
