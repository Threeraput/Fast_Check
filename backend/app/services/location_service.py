# backend/app/services/location_service.py
from typing import Tuple
import uuid

from fastapi import HTTPException, status
from geopy.distance import geodesic
from sqlalchemy.orm import Session

from app.models.teacher_location import TeacherLocation
from app.models.student_location import StudentLocation

# ระยะที่ยอมให้ห่างจากครู (เมตร)
PROXIMITY_THRESHOLD: float = 10.0


# -----------------------------
# Utilities & Validators
# -----------------------------
def _validate_coords(lat: float, lon: float) -> None:
    """Validate latitude/longitude to avoid invalid geodesic calls."""
    if lat is None or lon is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Latitude/Longitude are required."
        )
    if not (-90.0 <= float(lat) <= 90.0 and -180.0 <= float(lon) <= 180.0):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid latitude/longitude range."
        )


# -----------------------------
# Distance helpers
# -----------------------------
def calculate_distance(coords1: Tuple[float, float], coords2: Tuple[float, float]) -> float:
    """
    คำนวณระยะทาง (เมตร) ระหว่าง 2 พิกัด (lat, lon).
    """
    try:
        return float(geodesic(coords1, coords2).meters)
    except Exception as e:
        # ส่วนใหญ่เกิดจากค่าพิกัดไม่ถูกต้อง
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Location calculation failed: {e}"
        )


def is_within_proximity(
    student_lat: float,
    student_lon: float,
    teacher_lat: float,
    teacher_lon: float,
    threshold: float | None = None
) -> bool:
    """
    ตรวจว่านักเรียนอยู่ในรัศมีที่กำหนดจากครูหรือไม่
    """
    _validate_coords(student_lat, student_lon)
    _validate_coords(teacher_lat, teacher_lon)
    dist = calculate_distance((student_lat, student_lon), (teacher_lat, teacher_lon))
    limit = float(threshold) if threshold is not None else float(PROXIMITY_THRESHOLD)
    return dist <= limit


# -----------------------------
# DB operations
# -----------------------------
def get_latest_teacher_location(db: Session, teacher_id: uuid.UUID, class_id: uuid.UUID) -> TeacherLocation:
    """
    ดึงตำแหน่ง 'ล่าสุด' ของครูในคลาสที่กำหนด
    * แนะนำให้มีดัชนี (teacher_id, class_id, timestamp DESC) ที่ตาราง teacher_locations
    """
    latest = (
        db.query(TeacherLocation)
        .filter(
            TeacherLocation.teacher_id == teacher_id,
            TeacherLocation.class_id == class_id,
        )
        .order_by(TeacherLocation.timestamp.desc())
        .first()
    )

    if not latest:
        # 404 เหมาะสมกว่า 400 เพราะคือ resource ไม่พบ
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Teacher's location anchor is not available for this class."
        )
    return latest


def log_student_location(db: Session, student_id: uuid.UUID, class_id: uuid.UUID, latitude: float, longitude: float):
    _validate_coords(latitude, longitude)
    new_log = StudentLocation(
        student_id=student_id,
        class_id=class_id,
        latitude=latitude,
        longitude=longitude
    )
    try:
        db.add(new_log)
        db.commit()          
        db.refresh(new_log)
        return new_log
    except Exception:
        db.rollback()        
        raise


def update_teacher_location_log(db: Session, teacher_id: uuid.UUID, class_id: uuid.UUID, latitude: float, longitude: float):
    _validate_coords(latitude, longitude)
    new_log = TeacherLocation(
        teacher_id=teacher_id,
        class_id=class_id,
        latitude=latitude,
        longitude=longitude
    )
    try:
        db.add(new_log)
        db.commit()         
        db.refresh(new_log)
        return new_log
    except Exception:
        db.rollback()
        raise

# -----------------------------
# Convenience helper (optional)
# -----------------------------
def distance_student_to_latest_teacher_anchor(
    db: Session,
    student_lat: float,
    student_lon: float,
    teacher_id: uuid.UUID,
    class_id: uuid.UUID,
) -> float:
    """
    คำนวณระยะจากพิกัดนักเรียน -> พิกัดล่าสุดของครู (เมตร)
    """
    _validate_coords(student_lat, student_lon)
    anchor = get_latest_teacher_location(db, teacher_id, class_id)
    return calculate_distance(
        (student_lat, student_lon),
        (float(anchor.latitude), float(anchor.longitude)),
    )
