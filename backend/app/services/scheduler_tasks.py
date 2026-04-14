# backend/app/services/scheduler_tasks.py
import logging
import uuid
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.attendance import Attendance
from app.models.attendance_enums import AttendanceStatus
from app.services.session_finalizer_service import handle_finalize_session

logger = logging.getLogger(__name__)


def finalize_attendance_job(session_id: uuid.UUID):
    """
    Job สำหรับปิด Session และเช็คบิลคนหนีเรียน
    """
    logger.info(f"⏳ [Scheduler] เริ่มการเช็คบิลอัตโนมัติสำหรับ Session: {session_id}")

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
        logger.info(f"✅ [Scheduler] ปิด Session และเช็คบิลเรียบร้อยแล้ว")

    except Exception as e:
        db.rollback()
        logger.error(f"❌ [Scheduler] เกิดข้อผิดพลาด: {str(e)}")
    finally:
        db.close()
