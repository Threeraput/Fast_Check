# backend/app/services/scheduler_tasks.py
import logging
import uuid
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.attendance import Attendance
from app.models.attendance_enums import AttendanceStatus
from app.services.session_finalizer_service import handle_finalize_session
from firebase_admin import messaging
from app.models.user import User

logger = logging.getLogger(__name__)


def finalize_attendance_job(session_id: uuid.UUID):
    """
    Job สำหรับปิด Session และเช็คบิลคนหนีเรียน
    """
    print(f"⏳ [Scheduler] เริ่มการเช็คบิลอัตโนมัติสำหรับ Session: {session_id}")

    db: Session = SessionLocal()
    try:
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
            if record.last_verified_at is None:
                record.status = AttendanceStatus.LEFT_EARLY

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
            logger.info("⚠️ [FCM] ไม่มีนักเรียนให้ส่ง Push (หรือยังไม่มีใครอัปเดต fcm_token)")
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
        logger.info(
            f"✅ [FCM] ยิงสำเร็จ {response.success_count} เครื่อง, ล้มเหลว {response.failure_count} เครื่อง"
        )

    except Exception as e:
        logger.error(f"❌ [FCM] เกิดข้อผิดพลาดในการยิง: {str(e)}")
    finally:
        db.close()
