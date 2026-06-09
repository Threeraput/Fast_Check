from __future__ import annotations

import uuid
from pathlib import Path
from typing import Final

from fastapi import HTTPException, UploadFile

# backend/app/utils/announcement_storage.py -> parents[2] == backend/
_BACKEND_ROOT: Final[Path] = Path(__file__).resolve().parents[2]
_UPLOAD_DIR: Final[Path] = _BACKEND_ROOT / "uploads" / "announcements" / "attachments"
_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_MIME: Final[set[str]] = {
    "application/pdf",
    "image/png",
    "image/jpeg",
    "image/webp",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-excel",
    "text/plain",
}
MAX_SIZE_BYTES: Final[int] = 30 * 1024 * 1024


def _sanitize_filename(name: str) -> str:
    base = Path(name).name
    return base.replace("/", "_").replace("\\", "_")


async def save_announcement_file(file: UploadFile) -> tuple[str, str, int]:
    mime = (file.content_type or "").strip().lower()
    if mime not in ALLOWED_MIME:
        raise HTTPException(status_code=400, detail="File type is not allowed")

    original_name = _sanitize_filename(file.filename or "attachment")
    ext = Path(original_name).suffix.lower()
    if not ext:
        ext = ".bin"

    filename = f"{uuid.uuid4()}{ext}"
    dest_path = _UPLOAD_DIR / filename

    size = 0
    try:
        with dest_path.open("wb") as out:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                if size > MAX_SIZE_BYTES:
                    dest_path.unlink(missing_ok=True)
                    raise HTTPException(status_code=413, detail="Attachment is too large")
                out.write(chunk)
    finally:
        await file.close()

    # ใช้ path ที่สอดคล้องกับ StaticFiles('/uploads', directory='uploads')
    relative_path = f"uploads/announcements/attachments/{filename}"
    return relative_path, mime, size


def delete_announcement_file(storage_path: str) -> None:
    if not storage_path:
        return

    rel = storage_path.replace("\\", "/").lstrip("/")
    root = _BACKEND_ROOT.resolve()
    target = (root / rel).resolve()

    # ป้องกัน path traversal ก่อนลบไฟล์
    if root not in target.parents and target != root:
        return

    if target.exists() and target.is_file():
        target.unlink(missing_ok=True)
