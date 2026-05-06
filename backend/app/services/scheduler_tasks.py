# backend/app/services/scheduler_tasks.py
import logging
import uuid
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.attendance import Attendance
from app.models.attendance_session import AttendanceSession
from app.models.attendance_enums import AttendanceStatus
from app.services.session_finalizer_service import handle_finalize_session
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
    Job สำหรับปิด Session และเช็คบิลคนหนีเรียน
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

        silent_check_at = _ensure_aware_utc(session.silent_check_scheduled_at)

        # 1. ปรับสถานะคนที่ไม่รอดจากการสุ่มตรวจ
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
            if not _is_pending_silent_check(record):
                print(
                    f"✅ [STILL HERE] นักเรียน {record.student_id} ผ่านการสุ่มตรวจ (เวลาอัปเดตแล้ว)"
                )
                continue

            if silent_check_at is None:
                print(
                    f"⚠️ [SKIP SILENT CHECK] Session {session_id} ไม่มีเวลาสุ่มตรวจ จึงไม่ปรับสถานะนักเรียน {record.student_id}"
                )
                continue

            # กฎข้อ 1: มาตรงเวลา แต่ไม่ผ่านสุ่มตรวจ = หนีเรียน
            if record.status == AttendanceStatus.PRESENT:
                print(
                    f"🚨 [LEFT_EARLY] นักเรียน {record.student_id} มาตรงเวลาแต่หายตัวไประหว่างคาบ (หนีเรียน)"
                )
                record.status = AttendanceStatus.LEFT_EARLY

            # กฎข้อ 2: มาสาย จะรอดเฉพาะกรณีเข้าหลังรอบสุ่ม หรือรอบสุ่มเกิดเร็วเกินไปหลังเช็คชื่อ
            elif record.status == AttendanceStatus.LATE:
                if _should_spare_late_student(record, session, silent_check_at):
                    print(
                        f"⚠️ [LATE_SPARED] นักเรียน {record.student_id} เช็คชื่อสายใกล้รอบสุ่มหรือหลังรอบสุ่ม (ให้คงสถานะสายไว้)"
                    )
                else:
                    print(
                        f"🚨 [LEFT_EARLY_LATE] นักเรียน {record.student_id} เช็คชื่อสายก่อนรอบสุ่ม แต่ไม่ผ่านการยืนยันภายหลัง"
                    )
                    record.status = AttendanceStatus.LEFT_EARLY
            else:
                print(
                    f"ℹ️ [SKIP STATUS] นักเรียน {record.student_id} มีสถานะ {record.status} จึงไม่เข้ากฎสุ่มตรวจ"
                )

        db.flush()

        # 2. เรียกใช้ Service เดิมของคุณเพื่อปิด Session และเติมคนขาด (ABSENT)
        handle_finalize_session(db, session_id)

        db.commit()
        print(f"✅ [Scheduler] ปิด Session และเช็คบิลเรียบร้อยแล้ว")

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
