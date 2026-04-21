import io
import logging
import os
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from app.models.attendance import Attendance
from app.models.attendance_enums import AttendanceStatus
from app.models.attendance_session import AttendanceSession
from app.schemas.attendance_schema import AttendanceResponse
from app.services.face_recognition_service import get_face_embedding, compare_faces
from app.services.location_service import (
    PROXIMITY_THRESHOLD,
    is_within_proximity,
    log_student_location,
)

logger = logging.getLogger(__name__)

#  กำหนดที่เก็บรูปภาพแยกโฟลเดอร์ให้ชัดเจน
CHECKIN_IMAGE_DIR = "uploads/attendance/checkin"
REVERIFY_IMAGE_DIR = "uploads/attendance/reverify"

os.makedirs(CHECKIN_IMAGE_DIR, exist_ok=True)
os.makedirs(REVERIFY_IMAGE_DIR, exist_ok=True)


# ---------------------------
# Helpers
# ---------------------------
def _today_range_utc() -> tuple[datetime, datetime]:
    """ช่วงเวลาเริ่ม-จบของ 'วันนี้' (UTC) สำหรับกันเช็คชื่อซ้ำ"""
    now = datetime.now(timezone.utc)
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=1)
    return start, end


def _ensure_aware_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def decide_status_by_hard_times(
    start: datetime,
    late_cutoff: datetime,
    end: datetime,
    now: datetime | None = None,
) -> AttendanceStatus:
    now = _ensure_aware_utc(now or datetime.now(timezone.utc))
    s = _ensure_aware_utc(start)
    l = _ensure_aware_utc(late_cutoff)
    e = _ensure_aware_utc(end)

    if now > e:
        return AttendanceStatus.ABSENT
    if now < s:
        return AttendanceStatus.PRESENT
    if now >= s and now < l:
        return AttendanceStatus.PRESENT
    if now >= s and now < l:
        return AttendanceStatus.PRESENT
    if now >= l and now < e:
        return AttendanceStatus.LATE

    return AttendanceStatus.ABSENT


# ---------------------------
# Main
# ---------------------------
def record_check_in(
    db: Session,
    session_id: uuid.UUID,
    student_id: uuid.UUID,
    image_bytes: bytes,
    student_lat: float,
    student_lon: float,
) -> AttendanceResponse:
    session = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.session_id == session_id)
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="Attendance session not found.")

    now = datetime.now(timezone.utc)
    if now > _ensure_aware_utc(session.end_time):
        raise HTTPException(
            status_code=400, detail="Check-in window for this session has closed."
        )

    t_lat = float(session.anchor_lat)
    t_lon = float(session.anchor_lon)
    session_radius = getattr(session, "radius_meters", None)
    radius = float(session_radius) if session_radius is not None else None

    if not is_within_proximity(
        student_lat, student_lon, t_lat, t_lon, threshold=radius
    ):
        raise HTTPException(
            status_code=403,
            detail="Location check failed. You are too far from the classroom teacher.",
        )

    if not image_bytes:
        raise HTTPException(status_code=400, detail="Image is required for check-in.")

    # --- Face Verification Logic ---
    try:
        embedding = get_face_embedding(io.BytesIO(image_bytes))
        is_face_verified = compare_faces(db, student_id, embedding)
    except HTTPException:
        raise
    except Exception:
        is_face_verified = False

    already = (
        db.query(Attendance)
        .filter(
            Attendance.session_id == session_id,
            Attendance.student_id == student_id,
        )
        .first()
    )
    if already:
        raise HTTPException(
            status_code=409, detail="Attendance already recorded for this session."
        )

    status_to_record = AttendanceStatus.UNVERIFIED_FACE
    if is_face_verified:
        status_to_record = decide_status_by_hard_times(
            session.start_time, session.late_cutoff_time, session.end_time, now=now
        )

    #  1. บันทึกรูปภาพลงโฟลเดอร์ Checkin
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_name = f"checkin_{student_id}_{session_id}_{timestamp}.jpg"
    file_path = os.path.join(CHECKIN_IMAGE_DIR, file_name)
    relative_path = f"uploads/attendance/checkin/{file_name}"

    try:
        with open(file_path, "wb") as f:
            f.write(image_bytes)
    except Exception as e:
        logger.error(f"Failed to save check-in image: {e}")

    #  2. สร้าง Record และเก็บ path ใน face_image_path (ช่องที่ 1)
    new_attendance = Attendance(
        class_id=session.class_id,
        session_id=session.session_id,
        student_id=student_id,
        status=status_to_record,
        check_in_lat=student_lat,
        check_in_lon=student_lon,
        face_image_path=relative_path,
        check_in_time=now,
        last_verified_at=now,
    )

    try:
        db.add(new_attendance)
        db.commit()
        db.refresh(new_attendance)
    except Exception as e:
        db.rollback()
        if os.path.exists(file_path):
            os.remove(file_path)
        logger.exception(
            "Commit failed in record_check_in | session_id=%s student_id=%s status=%s",
            session_id,
            student_id,
            getattr(status_to_record, "value", status_to_record),
        )
        raise

    try:
        return AttendanceResponse.model_validate(new_attendance, from_attributes=True)
    except Exception:
        # Fallback สำหรับ Pydantic v1
        return AttendanceResponse.from_orm(new_attendance)


# ---------------------------
# Re-verification
# ---------------------------
def handle_reverification(
    db: Session,
    session_id: uuid.UUID,
    student_id: uuid.UUID,
    image_bytes: bytes,
    student_lat: float,
    student_lon: float,
) -> Attendance:
    session = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.session_id == session_id)
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="Attendance session not found.")
    if session.anchor_lat is None or session.anchor_lon is None:
        raise HTTPException(
            status_code=400,
            detail="Re-verification unavailable: teacher anchor location is not set.",
        )

    end_aware = _ensure_aware_utc(session.end_time)
    if end_aware and datetime.now(timezone.utc) > end_aware:
        raise HTTPException(
            status_code=400,
            detail="Re-verification window has closed for this session.",
        )

    attendance = (
        db.query(Attendance)
        .filter(
            Attendance.session_id == session_id, Attendance.student_id == student_id
        )
        .order_by(Attendance.check_in_time.desc())
        .first()
    )
    if not attendance:
        raise HTTPException(
            status_code=404, detail="No attendance record found for this session."
        )

    # ตรวจตำแหน่ง
    anchor_lat = float(session.anchor_lat)
    anchor_lon = float(session.anchor_lon)
    radius = float(getattr(session, "radius_meters", None) or PROXIMITY_THRESHOLD)
    if not is_within_proximity(
        student_lat, student_lon, anchor_lat, anchor_lon, threshold=radius
    ):
        raise HTTPException(
            status_code=403, detail="Location check failed during re-verification."
        )

    # ตรวจหน้า
    if not image_bytes:
        raise HTTPException(
            status_code=400, detail="Image is required for re-verification."
        )

    try:
        new_embedding = get_face_embedding(io.BytesIO(image_bytes))
        result = compare_faces(db, student_id, new_embedding)
        matched = bool(result[0]) if isinstance(result, tuple) else bool(result)
    except Exception:
        matched = False

    #  1. บันทึกรูปภาพลงโฟลเดอร์ Reverify
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_name = f"reverify_{student_id}_{session_id}_{timestamp}.jpg"
    file_path = os.path.join(REVERIFY_IMAGE_DIR, file_name)
    relative_path = f"uploads/attendance/reverify/{file_name}"

    try:
        with open(file_path, "wb") as f:
            f.write(image_bytes)
    except Exception as e:
        logger.error(f"Failed to save reverify image: {e}")

    #  2. อัปเดตสถานะและเก็บ path ลงช่อง reverify_image_path (ช่องที่ 2)
    attendance.is_reverified = True
    attendance.reverify_image_path = relative_path
    attendance.reverify_time = datetime.now(timezone.utc)

    # ปรับสถานะถ้าไม่ตรงกัน (เป็น LeftEarly)
    if isinstance(attendance.status, str):
        try:
            attendance.status = AttendanceStatus(attendance.status)
        except Exception:
            pass

    if not matched:
        attendance.status = AttendanceStatus.LEFT_EARLY

    try:
        db.commit()
        db.refresh(attendance)
        return attendance
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"re-verify commit failed: {e}",
        )


def manual_override_attendance(
    db: Session,
    attendance_id: uuid.UUID,
    new_status: AttendanceStatus,
    recorded_by_user_id: uuid.UUID,
) -> AttendanceResponse:
    attendance = (
        db.query(Attendance).filter(Attendance.attendance_id == attendance_id).first()
    )

    if not attendance:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Attendance record not found."
        )

    attendance.status = new_status
    attendance.is_manual_override = True
    attendance.recorded_by_user_id = recorded_by_user_id

    try:
        db.commit()
        db.refresh(attendance)
        # รองรับทั้ง Pydantic V1 และ V2
        try:
            return AttendanceResponse.model_validate(attendance, from_attributes=True)
        except AttributeError:
            return AttendanceResponse.from_orm(attendance)
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save manual override: {e}",
        )


def identify_user(image_bytes: bytes) -> Tuple[Optional[uuid.UUID], Optional[float]]:
    raise NotImplementedError("identify_user must be implemented")


def handle_silent_location_update(
    db: Session,
    session_id: uuid.UUID,
    student_id: uuid.UUID,
    student_lat: float,
    student_lon: float,
) -> dict:
    """
    ฟังก์ชันลับสำหรับรับพิกัดเบื้องหลังจากระบบสุ่มตรวจ
    หน้าที่: บันทึกประวัติพิกัดลง Log -> เช็คระยะ -> ถ้าอยู่ในระยะให้อัปเดตเวลา
    """
    # 1. หา Session
    session = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.session_id == session_id)
        .first()
    )
    if not session:
        return {"status": "ignored", "reason": "Session not found"}

    # 2. หาข้อมูลการเข้าเรียนของนักเรียนคนนี้
    attendance = (
        db.query(Attendance)
        .filter(
            Attendance.session_id == session_id, Attendance.student_id == student_id
        )
        .first()
    )
    if not attendance:
        return {"status": "ignored", "reason": "No attendance record"}

    valid_statuses = [
        AttendanceStatus.PRESENT,
        AttendanceStatus.PRESENT.value,
        AttendanceStatus.LATE,
        AttendanceStatus.LATE.value,
    ]
    if attendance.status not in valid_statuses:
        return {
            "status": "ignored",
            "reason": f"Student status is {attendance.status}, ignoring check",
        }

    # ---------------------------------------------------------
    # บันทึกพิกัดเก็บไว้เป็นหลักฐาน (Log)
    # ไม่ว่าจะอยู่ในระยะหรือนอกระยะ เราก็จะเก็บหมดเพื่อกางแผนที่ดูได้
    # ---------------------------------------------------------
    try:
        log_student_location(
            db=db,
            student_id=student_id,
            class_id=session.class_id,
            latitude=student_lat,
            longitude=student_lon,
            is_silent_check=True,
        )
    except Exception as e:
        # ถ้าบันทึก Log พัง (เช่น DB มีปัญหาชั่วคราว) ให้แค่ปริ้นท์ Error แต่ปล่อยให้ระบบเช็คระยะทำงานต่อ
        logger.error(f"Silent Check-in: Failed to log location for {student_id}: {e}")

    # 3. ตรวจสอบระยะทาง
    t_lat = float(session.anchor_lat)
    t_lon = float(session.anchor_lon)
    radius = float(getattr(session, "radius_meters", PROXIMITY_THRESHOLD))

    if is_within_proximity(student_lat, student_lon, t_lat, t_lon, threshold=radius):
        # 4. ถ้าอยู่ในระยะ ให้อัปเดตเวลาล่าสุด
        attendance.last_verified_at = datetime.now(timezone.utc)
        print(
            f"📍 [SILENT CHECK SUCCESS] นักเรียน {student_id} ยืนยันพิกัดสำเร็จ! (แอปแอบส่งพิกัดมาให้แล้ว)"
        )
        try:
            db.commit()
            return {"status": "success", "message": "Location verified silently"}
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to update silent location for {student_id}: {e}")
            raise HTTPException(
                status_code=500, detail="Database error during silent update"
            )
    else:
        return {"status": "ignored", "reason": "Student is out of range"}
