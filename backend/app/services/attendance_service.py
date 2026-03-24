import io
import logging
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from app.models.attendance import Attendance
from app.models.attendance_enums import AttendanceStatus
from app.models.class_model import Class as ClassModel
from app.models.attendance_session import AttendanceSession
from app.schemas.attendance_schema import AttendanceResponse
from app.services.face_recognition_service import get_face_embedding, compare_faces
from app.services.location_service import (
    PROXIMITY_THRESHOLD,
    is_within_proximity,
    get_latest_teacher_location,
)

logger = logging.getLogger(__name__)


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
    if (now >= s and now < l):
        return AttendanceStatus.PRESENT
    if (now >= l and now < e):
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
        raise HTTPException(status_code=400, detail="Check-in window for this session has closed.")

    t_lat = float(session.anchor_lat)
    t_lon = float(session.anchor_lon)
    session_radius = getattr(session, "radius_meters", None)
    radius = float(session_radius) if session_radius is not None else None

    if not is_within_proximity(student_lat, student_lon, t_lat, t_lon, threshold=radius):
        raise HTTPException(status_code=403, detail="Location check failed. You are too far from the classroom teacher.")

    if not image_bytes:
        raise HTTPException(status_code=400, detail="Image is required for check-in.")
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
        raise HTTPException(status_code=409, detail="Attendance already recorded for this session.")

    status_to_record = AttendanceStatus.UNVERIFIED_FACE
    if is_face_verified:
        status_to_record = decide_status_by_hard_times(
            session.start_time, session.late_cutoff_time, session.end_time, now=now
        )

    new_attendance = Attendance(
        class_id=session.class_id,
        session_id=session.session_id,
        student_id=student_id,
        status=status_to_record,
        check_in_lat=student_lat,
        check_in_lon=student_lon,
    )
    try:
        db.add(new_attendance)
        db.commit()
        db.refresh(new_attendance)
    except Exception as e:
        db.rollback()
        logger.exception(
            "Commit failed in record_check_in | session_id=%s student_id=%s status=%s",
            session_id, student_id, getattr(status_to_record, "value", status_to_record)
        )
        raise

    try:
        return AttendanceResponse.model_validate(new_attendance, from_attributes=True)
    except Exception:
        return AttendanceResponse.from_orm(new_attendance)


# ✅ UPDATED: handle_reverification
def handle_reverification(
    db: Session,
    session_id: uuid.UUID,
    student_id: uuid.UUID,
    image_bytes: bytes,
    student_lat: float,
    student_lon: float,
) -> Attendance:
    # 1) หา session
    session = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.session_id == session_id)
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="Attendance session not found.")
    if session.anchor_lat is None or session.anchor_lon is None:
        raise HTTPException(status_code=400, detail="Re-verification unavailable: teacher anchor location is not set.")

    # 2) หมดเวลาหรือยัง
    end_aware = _ensure_aware_utc(session.end_time)
    if end_aware and datetime.now(timezone.utc) > end_aware:
        raise HTTPException(status_code=400, detail="Re-verification window has closed for this session.")

    # 3) ดึง attendance ล่าสุดของนักเรียน
    attendance = (
        db.query(Attendance)
        .filter(Attendance.session_id == session_id, Attendance.student_id == student_id)
        .order_by(Attendance.check_in_time.desc())
        .first()
    )
    if not attendance:
        raise HTTPException(status_code=404, detail="No attendance record found for this session.")

    # 4) ตรวจตำแหน่ง
    anchor_lat = float(session.anchor_lat); anchor_lon = float(session.anchor_lon)
    radius = float(getattr(session, "radius_meters", None) or PROXIMITY_THRESHOLD)
    if not is_within_proximity(student_lat, student_lon, anchor_lat, anchor_lon, threshold=radius):
        raise HTTPException(status_code=403, detail="Location check failed during re-verification.")

    # 5) ตรวจหน้า (ใช้ผล matched แบบเดียวกับ check-in)
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Image is required for re-verification.")
    try:
        new_embedding = get_face_embedding(io.BytesIO(image_bytes))
        result = compare_faces(db, student_id, new_embedding)
        matched = bool(result[0]) if isinstance(result, tuple) else bool(result)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Face service error in re-verify | session_id=%s student_id=%s", session_id, student_id)
        matched = False

    # 6) อัปเดตสถานะอย่างระวัง (ไม่แตะ enum DB)
    attendance.is_reverified = True
    # ถ้าค่าเดิมใน attendance.status เป็น string ให้แปลงกลับเป็น enum object ก่อนเสมอ
    if isinstance(attendance.status, str):
        try:
            attendance.status = AttendanceStatus(attendance.status)
        except Exception:
            # กันกรณีพิเศษ: ถ้าเจอสตริงที่ map ไม่ได้ ก็ไม่เปลี่ยนสถานะ (ปล่อยค่าเดิมไป)
            logger.warning("Status string on record not in Enum mapping: %r", attendance.status)

    if not matched:
        # ไม่ผ่านหน้า ให้เปลี่ยนเป็น LEFT_EARLY ด้วย enum object เท่านั้น
        attendance.status = AttendanceStatus.LEFT_EARLY

    # (ถ้าผ่านหน้า matched=True) → "อย่า" เซ็ตเป็น PRESENT เอง
    # ให้คงสถานะเดิมที่เช็คอินไว้ (ซึ่งเคยบันทึกผ่าน DB มาแล้ว)

    # 7) commit
    try:
        logger.debug("Reverify before commit | status=%r (type=%s) is_reverified=%s",
                     getattr(attendance.status, "value", attendance.status), type(attendance.status), attendance.is_reverified)
        db.commit()
        db.refresh(attendance)
        logger.info("✅ Re-verify committed | session=%s user=%s status=%s",
                    session_id, student_id, getattr(attendance.status, "value", attendance.status))
        return attendance
    except SQLAlchemyError as e:
        db.rollback()
        logger.exception("DB commit failed in handle_reverification | session=%s user=%s", session_id, student_id)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                            detail=f"re-verify commit failed: {getattr(e, 'orig', e)}")
    except Exception as e:
        db.rollback()
        logger.exception("Unexpected error in handle_reverification | session=%s user=%s", session_id, student_id)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                            detail=f"unexpected error: {e}")


def manual_override_attendance(
    db: Session,
    attendance_id: uuid.UUID,
    new_status: AttendanceStatus,
    recorded_by_user_id: uuid.UUID
) -> AttendanceResponse:
    attendance = db.query(Attendance).filter(Attendance.attendance_id == attendance_id).first()

    if not attendance:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attendance record not found.")

    attendance.status = new_status
    attendance.is_manual_override = True
    attendance.recorded_by_user_id = recorded_by_user_id

    try:
        db.commit()
        db.refresh(attendance)
        return AttendanceResponse.from_orm(attendance)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to save manual override: {e}")


def identify_user(image_bytes: bytes) -> Tuple[Optional[uuid.UUID], Optional[float]]:
    """
    รู้จำว่ารูปนี้คือผู้ใช้คนไหนในระบบ + คะแนนความเหมือน
    """
    raise NotImplementedError("identify_user must be implemented to return (user_id, score)")
