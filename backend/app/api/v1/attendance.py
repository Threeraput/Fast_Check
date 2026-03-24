# backend/app/api/v1/attendance.py
import uuid
import logging
import io
from uuid import UUID
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Response, Path, Body, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy.exc import SQLAlchemyError

from app.database import get_db
from app.models.user import User
from app.models.attendance import Attendance
from app.models.attendance_session import AttendanceSession
from app.models.user_face_sample import UserFaceSample  # ✅ เช็คว่าผู้ใช้มี sample หรือยัง

from app.schemas.attendance_schema import (
    AttendanceCheckIn,
    AttendanceResponse,
    TeacherLocationUpdate,
    StudentLocationLogCreate,
    AttendanceManualOverride,
    ReverifyRequest,
)
from app.schemas.session_schema import SessionResponse
from app.schemas.reverify_schema import ToggleReverifyRequest, ToggleReverifyResponse
from app.core.deps import get_current_user, role_required
from app.services.attendance_service import record_check_in, handle_reverification, manual_override_attendance
from app.services.location_service import update_teacher_location_log, log_student_location
from app.services.face_recognition_service import get_face_embedding, compare_faces
from datetime import datetime, timezone

# ---------- NEW: ช่วยจัด EXIF orientation เพื่อลด false reject ----------
from PIL import Image, ImageOps

def _normalize_image_bytes(raw: bytes) -> bytes:
    """แก้ EXIF orientation + บังคับ RGB -> bytes (JPEG)"""
    try:
        im = Image.open(io.BytesIO(raw))
        im = ImageOps.exif_transpose(im)  # เคารพ EXIF orientation
        if im.mode != "RGB":
            im = im.convert("RGB")
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=92)
        return buf.getvalue()
    except Exception:
        # ถ้าจัดการไม่ได้ ให้ใช้ raw เดิม
        return raw

REVERIFY_MIN_SIMILARITY = 0.25

router = APIRouter(prefix="/attendance", tags=["Attendance"])
logger = logging.getLogger(__name__)


def _has_role(user: User, role_name: str) -> bool:
    try:
        return any(getattr(r, "name", None) == role_name for r in (user.roles or []))
    except Exception:
        return False


# ------------------------------------
# 1) POST /attendance/check-in
# ------------------------------------
@router.post("/check-in", response_model=AttendanceResponse)
async def check_in(
    class_data: AttendanceCheckIn = Depends(AttendanceCheckIn.as_form),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if "student" not in [role.name for role in current_user.roles]:
        raise HTTPException(status_code=403, detail="Only students can check in.")

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Only images are allowed.")

    raw_bytes = await file.read()
    image_bytes = _normalize_image_bytes(raw_bytes)
    logger.debug("check-in input | session_id=%s user=%s", class_data.session_id, current_user.user_id)

    try:
        attendance_record = record_check_in(
            db=db,
            session_id=class_data.session_id,
            student_id=current_user.user_id,
            image_bytes=image_bytes,
            student_lat=class_data.latitude,
            student_lon=class_data.longitude,
        )
        return attendance_record
    except SQLAlchemyError as e:
        logger.exception("DB error in /check-in")
        raise HTTPException(status_code=500, detail=f"database_error: {getattr(e, 'orig', e)}")
    except Exception as e:
        logger.exception("Unhandled error in /check-in")
        raise HTTPException(status_code=500, detail=f"internal_error: {e}")


# ------------------------------------
# 2) POST /attendance/teacher-location
# ------------------------------------
@router.post("/teacher-location", status_code=200)
async def update_teacher_location(
    location_data: TeacherLocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _has_role(current_user, "teacher"):
        raise HTTPException(status_code=403, detail="Only teachers can update their location.")

    try:
        update_teacher_location_log(
            db=db,
            teacher_id=current_user.user_id,
            class_id=location_data.class_id,
            latitude=location_data.latitude,
            longitude=location_data.longitude,
        )
        return {"message": "Teacher location updated successfully."}
    except SQLAlchemyError as e:
        logger.exception("DB error in /teacher-location")
        raise HTTPException(status_code=500, detail=f"database_error: {getattr(e, 'orig', e)}")


# ------------------------------------
# 3) POST /attendance/student-tracking
# ------------------------------------
@router.post("/student-tracking", status_code=200)
async def track_student_location(
    log_data: StudentLocationLogCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _has_role(current_user, "student"):
        raise HTTPException(status_code=403, detail="Only students can track location.")

    try:
        log_student_location(
            db=db,
            student_id=current_user.user_id,
            class_id=log_data.class_id,
            latitude=log_data.latitude,
            longitude=log_data.longitude,
        )
        return {"message": "Student location logged successfully."}
    except SQLAlchemyError as e:
        logger.exception("DB error in /student-tracking")
        raise HTTPException(status_code=500, detail=f"database_error: {getattr(e, 'orig', e)}")


# ------------------------------------
# 4) POST /attendance/re-verify
# ------------------------------------
@router.post("/re-verify", response_model=AttendanceResponse, status_code=200)
async def re_verify_check_in(
    form: ReverifyRequest = Depends(ReverifyRequest.as_form),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # ✅ ตรวจ role
    if "student" not in [role.name for role in current_user.roles]:
        raise HTTPException(status_code=403, detail="Access denied.")

    # ✅ ตรวจไฟล์รูป
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Only images are allowed.")

    raw_bytes = await file.read()
    image_bytes = _normalize_image_bytes(raw_bytes)
    logger.debug("re-verify input | session_id=%s user=%s", form.session_id, current_user.user_id)

    # ✅ ตรวจว่าผู้ใช้มี Face Sample หรือไม่
    try:
        has_sample = db.query(UserFaceSample).filter(
            UserFaceSample.user_id == current_user.user_id
        ).limit(1).count() > 0
    except Exception as e:
        logger.exception("DB error while checking user's face samples")
        raise HTTPException(status_code=500, detail=f"database_error: {e}")
    if not has_sample:
        raise HTTPException(
            status_code=404,
            detail="No face samples found for this user. Please register your face first."
        )

    # ✅ ใช้ logic เดียวกับ check-in
    try:
        embedding = get_face_embedding(io.BytesIO(image_bytes))
        result = compare_faces(db, current_user.user_id, embedding)
        if isinstance(result, tuple):
            matched = bool(result[0])
            score = result[1]
        else:
            matched = bool(result)
            score = None
    except Exception as e:
        logger.exception("Face service error in /re-verify")
        raise HTTPException(status_code=500, detail=f"Face service error: {e}")

    logger.info("re-verify | user=%s matched=%s score=%s", current_user.user_id, matched, score)

    # ✅ ใช้เงื่อนไขเดียวกับ check-in — ถ้า matched=False ให้ reject
    if not matched:
        raise HTTPException(status_code=403, detail="Face verification failed for this user.")

    # ✅ ถ้าผ่าน ให้เรียก handle_reverification
    try:
        result = handle_reverification(
            db=db,
            session_id=form.session_id,
            student_id=current_user.user_id,
            image_bytes=image_bytes,
            student_lat=form.latitude,
            student_lon=form.longitude,
        )
        try:
            return AttendanceResponse.model_validate(result, from_attributes=True)
        except Exception:
            return AttendanceResponse.from_orm(result)
    except SQLAlchemyError as e:
        logger.exception("DB error in /re-verify")
        raise HTTPException(status_code=500, detail=f"database_error: {getattr(e, 'orig', e)}")
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Unhandled error in /re-verify")
        raise HTTPException(status_code=500, detail=f"internal_error: {e}")


# ------------------------------------
# 5) PATCH /attendance/override/{attendance_id}
# ------------------------------------
@router.patch("/override/{attendance_id}", response_model=AttendanceResponse)
async def override_attendance_status(
    attendance_id: uuid.UUID = Path(..., description="UUID of the attendance record to override"),
    override_data: AttendanceManualOverride = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    roles = {r.name for r in getattr(current_user, "roles", [])}
    is_admin = "admin" in roles
    is_teacher = "teacher" in roles

    if not (is_admin or is_teacher):
        raise HTTPException(status_code=403, detail="Access denied.")

    if is_teacher and not is_admin:
        att = (
            db.query(Attendance)
            .options(joinedload(Attendance.class_rel))
            .filter(Attendance.attendance_id == attendance_id)
            .first()
        )
        if not att:
            raise HTTPException(status_code=404, detail="Attendance not found.")
        if att.class_rel.teacher_id != current_user.user_id:
            raise HTTPException(status_code=403, detail="You can only modify attendance for your own class.")

    try:
        record = manual_override_attendance(
            db=db,
            attendance_id=attendance_id,
            new_status=override_data.status,
            recorded_by_user_id=current_user.user_id,
        )
        try:
            return AttendanceResponse.model_validate(record, from_attributes=True)
        except Exception:
            return AttendanceResponse.from_orm(record)
    except SQLAlchemyError as e:
        logger.exception("DB error in /override")
        raise HTTPException(status_code=500, detail=f"database_error: {getattr(e, 'orig', e)}")


@router.get("/sessions/active", response_model=List[SessionResponse])
def list_active_sessions(db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    qs = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.start_time <= now, AttendanceSession.end_time >= now)
        .order_by(AttendanceSession.start_time.desc())
        .all()
    )
    return qs


@router.post("/re-verify/toggle", response_model=ToggleReverifyResponse)
def toggle_reverify(req: ToggleReverifyRequest, db: Session = Depends(get_db)):
    s = db.query(AttendanceSession).filter_by(session_id=req.session_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Session not found")

    now = datetime.now(timezone.utc)
    if req.enabled and not (s.start_time <= now <= s.end_time):
        raise HTTPException(status_code=400, detail="Session is not active")

    try:
        s.reverify_enabled = req.enabled
        db.commit()
        db.refresh(s)
        return ToggleReverifyResponse(ok=True, reverify_enabled=s.reverify_enabled)
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"database_error: {getattr(e, 'orig', e)}")


@router.get("/my-status")
def my_status(
    session_id: uuid.UUID = Query(..., description="Attendance session id"),
    db: Session = Depends(get_db),
    me=Depends(get_current_user),
):
    att = (
        db.query(Attendance)
        .filter(Attendance.session_id == session_id, Attendance.student_id == me.user_id)
        .first()
    )
    if not att:
        return {"has_checked_in": False}

    return {
        "has_checked_in": True,
        "attendance_id": str(att.attendance_id),
        "status": getattr(att, "status", None),
        "checked_at": getattr(att, "check_in_time", None).isoformat() if getattr(att, "check_in_time", None) else None,
    }


@router.get("/is-reverified/{session_id}")
def get_is_reverified(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    record = (
        db.query(Attendance)
        .filter(Attendance.session_id == session_id, Attendance.student_id == current_user.user_id)
        .first()
    )
    if not record:
        raise HTTPException(status_code=404, detail="Attendance record not found")

    return {"session_id": str(session_id), "is_reverified": record.is_reverified}


@router.post("/session/{session_id}/finalize", dependencies=[Depends(role_required(["teacher"]))])
def finalize_session(session_id: UUID, db: Session = Depends(get_db)):
    from app.services.session_finalizer_service import handle_finalize_session
    handle_finalize_session(db, session_id)
    return {"detail": "Session finalized successfully"}
