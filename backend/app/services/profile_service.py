# backend/app/services/profile_service.py
import uuid
import imghdr
from pathlib import Path
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.user import User

# กำหนดโฟลเดอร์เก็บรูป "media/profile_upload" ในไฟล์นี้เลย
MEDIA_ROOT = Path("media")
PROFILE_UPLOAD_DIR = MEDIA_ROOT / "profile_upload"
PROFILE_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)  # สร้างโฟลเดอร์ถ้าไม่มี

ALLOWED_TYPES = {"jpeg", "png"}
MAX_SIZE = 10 * 1024 * 1024  # 3MB

def _ext_from_kind(kind: str) -> str:
    return ".jpg" if kind == "jpeg" else ".png"

def _absolute_path_from_url(url: str) -> Path:
    # แปลง '/media/profile_upload/xxx.png' -> 'media/profile_upload/xxx.png'
    return Path(url.replace("/media/", "media/"))

def save_user_avatar(db: Session, user: User, content: bytes) -> User:
    if len(content) > MAX_SIZE:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="File too large (max 3MB)")

    kind = imghdr.what(None, h=content)
    if kind not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Only JPEG/PNG allowed")

    ext = _ext_from_kind(kind)
    filename = f"{user.user_id}_{uuid.uuid4().hex}{ext}"
    dest = PROFILE_UPLOAD_DIR / filename

    # ลบไฟล์เก่าถ้ามี
    if user.avatar_url:
        try:
            old = _absolute_path_from_url(user.avatar_url)
            if old.is_file():
                old.unlink(missing_ok=True)
        except Exception:
            pass

    dest.write_bytes(content)

    # ตั้ง URL แบบเสิร์ฟผ่าน /media/...
    user.avatar_url = f"/media/profile_upload/{filename}"
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

def delete_user_avatar(db: Session, user: User) -> User:
    if user.avatar_url:
        try:
            old = _absolute_path_from_url(user.avatar_url)
            if old.is_file():
                old.unlink(missing_ok=True)
        except Exception:
            pass
        user.avatar_url = None
        db.add(user)
        db.commit()
        db.refresh(user)
    return user
