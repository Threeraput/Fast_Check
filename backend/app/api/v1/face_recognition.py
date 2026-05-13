# backend/app/api/v1/face_recognition.py
import imghdr
import logging
import uuid
import shutil
import os
import io
from io import BytesIO
from typing import Optional
from PIL import UnidentifiedImageError
from PIL import Image as PilImage
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Path
from fastapi.concurrency import run_in_threadpool
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.models.user_face_sample import UserFaceSample
from app.schemas.face_schema import FaceSampleResponse 
from app.services.face_recognition_service import get_face_embedding, create_face_sample, compare_faces
from app.core.deps import get_current_user
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError

router = APIRouter(prefix="/face-recognition", tags=["Face Recognition"])

logger = logging.getLogger(__name__)

UPLOAD_DIR = "./uploads"
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload-face", response_model=FaceSampleResponse)
async def upload_face_for_user(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    if not (file.content_type and file.content_type.startswith("image/")):
        raise HTTPException(status_code=400, detail="Invalid file type. Only images are allowed.")
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Empty file.")
    old_sample = db.query(UserFaceSample).filter(UserFaceSample.user_id == current_user.user_id).first()
    old_image_path = None
    if old_sample and old_sample.image_url:
        old_image_path = os.path.join(os.getcwd(), old_sample.image_url.strip('/'))
    try:
        embedding = get_face_embedding(BytesIO(content))
    except ValueError as e:
        msg = str(e).lower()
        if "no_face" in msg: raise HTTPException(status_code=400, detail="No face detected.")
        if "multi_face" in msg: raise HTTPException(status_code=400, detail="Please upload an image with exactly one face.")
        raise HTTPException(status_code=500, detail=f"Face embedding failed: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Face embedding failed: {e}")
    file_extension = os.path.splitext(file.filename or "")[1] or ".jpg"
    filename = f"{current_user.user_id}_{uuid.uuid4().hex}{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, filename)
    image_url = f"/uploads/{filename}"
    try:
        with open(file_path, "wb") as buffer:
            buffer.write(content)
        face_sample = create_face_sample(db, current_user.user_id, image_url, embedding)
        if old_image_path and os.path.exists(old_image_path):
            try: os.remove(old_image_path)
            except Exception: pass
        return face_sample
    except HTTPException:
        if os.path.exists(file_path):
            try: os.remove(file_path)
            except Exception: pass
        raise
    except Exception as e:
        db.rollback()
        if os.path.exists(file_path):
            try: os.remove(file_path)
            except Exception: pass
        raise HTTPException(status_code=500, detail=f"Upload failed: {e}")

@router.post("/verify-face", status_code=status.HTTP_200_OK)
async def verify_face(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    file_bytes = await file.read()
    if not file_bytes: raise HTTPException(status_code=400, detail="Empty file.")
    if not (file.content_type and file.content_type.startswith("image/")):
        raise HTTPException(status_code=400, detail="Invalid file type. Only images are allowed.")
    if imghdr.what(None, h=file_bytes) is None:
        raise HTTPException(status_code=400, detail="Uploaded file is not a valid image.")
    try:
        with PilImage.open(BytesIO(file_bytes)) as im: im.verify()
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="Corrupted or unsupported image.")
    try:
        new_embedding = await run_in_threadpool(get_face_embedding, BytesIO(file_bytes))
    except ValueError as e:
        msg = str(e).lower()
        if "no_face" in msg: raise HTTPException(status_code=400, detail="No face detected.")
        if "multi_face" in msg: raise HTTPException(status_code=400, detail="Please upload an image with exactly one face.")
        logger.exception("Embedding error")
        raise HTTPException(status_code=500, detail="Face embedding failed.")
    except Exception:
        logger.exception("Embedding error")
        raise HTTPException(status_code=500, detail="Face embedding failed.")
    if new_embedding is None: raise HTTPException(status_code=400, detail="No face detected.")
    try:
        is_match, distance = compare_faces(db, current_user.user_id, new_embedding)
    except Exception:
        logger.exception("Comparison error")
        raise HTTPException(status_code=500, detail="Face comparison failed.")
    if not is_match:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Face verification failed. distance={distance:.4f}, tolerance=0.6"
        )
    return {
        "message": "Face verified successfully.",
        "matched": True,
        "distance": round(distance, 4),
        "tolerance": 0.6,
    }

@router.delete("/delete-face-sample/{sample_id}", status_code=status.HTTP_200_OK)
async def delete_face_sample(
    sample_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    is_admin_or_teacher = any(role.name in ["admin", "teacher"] for role in current_user.roles)
    if not is_admin_or_teacher:
        raise HTTPException(status_code=403, detail="นักเรียนไม่สามารถลบใบหน้าได้")
    sample_to_delete = db.query(UserFaceSample).filter(UserFaceSample.sample_id == sample_id).first()
    if not sample_to_delete: raise HTTPException(status_code=404, detail="Face sample not found.")
    file_path_on_disk = os.path.join(os.getcwd(), sample_to_delete.image_url.strip('/'))
    if os.path.exists(file_path_on_disk): os.remove(file_path_on_disk)
    db.delete(sample_to_delete)
    db.commit()
    return JSONResponse(status_code=200, content={"message": "Face sample deleted successfully."})

@router.get("/check-face/{user_id}")
async def check_face_registered(
    user_id: str = Path(..., description="User ID ของนักเรียน"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if "student" in [r.name for r in current_user.roles]:
        if str(current_user.user_id) != user_id:
            raise HTTPException(status_code=403, detail="Forbidden")
    face_record = db.query(UserFaceSample).filter(UserFaceSample.user_id == user_id).first()
    return {"user_id": user_id, "has_face": face_record is not None}

@router.get("/me", response_model=Optional[FaceSampleResponse])
async def get_my_face_sample(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """ดึงข้อมูลใบหน้าของตัวเอง (สำหรับหน้า Profile)"""
    return db.query(UserFaceSample).filter(UserFaceSample.user_id == current_user.user_id).first()
