# backend/app/services/attendance_session_service.py
import uuid
import logging
from sqlalchemy.orm import Session
from datetime import datetime, timezone, timedelta
from fastapi import HTTPException, status
from typing import List
from app.models.attendance_session import AttendanceSession
from app.schemas.session_schema import SessionOpenRequest
from app.models.class_model import Class as ClassModel
from app.services.location_service import update_teacher_location_log

logger = logging.getLogger(__name__)

# ค่ามาตรฐาน ถ้าไม่ส่งมาก็จะใช้ค่าพวกนี้
DEFAULT_SESSION_MINUTES = 15          # ระยะเวลา session รวม ๆ เช่น เปิด 15 นาที
DEFAULT_LATE_CUTOFF_MINUTES = 10      # ภายใน 10 นาทีแรก = Present, หลังจากนั้นจนหมด session = Late

def _ensure_aware_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

def create_attendance_session(
    db: Session,
    teacher_id: uuid.UUID,
    session_data: SessionOpenRequest
) -> AttendanceSession:
    # 1) ตรวจสอบว่า class มีจริง
    classroom = db.query(ClassModel).filter(ClassModel.class_id == session_data.class_id).first()
    if not classroom:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found.")

    now_utc = datetime.now(timezone.utc)

    # 2) กำหนดค่าเริ่มต้นให้ครบถ้วน (ถ้าไม่ส่งมา)
    start_time = _ensure_aware_utc(session_data.start_time) if session_data.start_time else now_utc

    # late_cutoff_time: ถ้าไม่ส่งมา ใช้ start_time + DEFAULT_LATE_CUTOFF_MINUTES
    late_cutoff_time = (
        _ensure_aware_utc(session_data.late_cutoff_time)
        if getattr(session_data, "late_cutoff_time", None) else
        start_time + timedelta(minutes=DEFAULT_LATE_CUTOFF_MINUTES)
    )

    # end_time: ถ้าไม่ส่งมา ใช้ start_time + DEFAULT_SESSION_MINUTES
    end_time = (
        _ensure_aware_utc(session_data.end_time)
        if session_data.end_time else
        start_time + timedelta(minutes=DEFAULT_SESSION_MINUTES)
    )

    # 3) ตรวจสอบลำดับเวลาให้ถูกต้อง
    # ต้อง: start_time <= late_cutoff_time <= end_time
    if not (start_time <= late_cutoff_time <= end_time):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid time range: must satisfy start_time <= late_cutoff_time <= end_time."
        )

    # 4) บันทึก anchor point ของอาจารย์ (optional แต่คุณใช้อยู่)
    anchor_log = update_teacher_location_log(
        db=db,
        teacher_id=teacher_id,
        class_id=session_data.class_id,
        latitude=session_data.latitude,
        longitude=session_data.longitude,
    )

    # 5) สร้าง Session
    new_session = AttendanceSession(
        class_id=session_data.class_id,
        teacher_id=teacher_id,
        start_time=start_time,
        end_time=end_time,
        late_cutoff_time=late_cutoff_time,  # ← อย่าลืมฟิลด์นี้ในโมเดล/ไมเกรชัน
        radius_meters=int(session_data.radius_meters),
        anchor_lat=anchor_log.latitude,
        anchor_lon=anchor_log.longitude,
    )

    try:
        db.add(new_session)
        db.commit()
        db.refresh(new_session)
    except Exception:
        db.rollback()
        raise

    return new_session


def get_active_sessions(db: Session) -> List[AttendanceSession]:
    """
    ดึงรายการ Sessions ที่กำลังเปิดอยู่และยังไม่หมดอายุ
    """
    current_time = datetime.now(timezone.utc)
    return db.query(AttendanceSession).filter(
        AttendanceSession.end_time > current_time
    ).all()
