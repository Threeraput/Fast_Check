# backend/app/utils/pdf_storage.py
from __future__ import annotations
import os
import uuid
from pathlib import Path
from typing import Final

from fastapi import UploadFile, HTTPException

# โฟลเดอร์เก็บไฟล์: <repo-root>/workpdf
# (__file__) = backend/app/utils/pdf_storage.py  → parents[2] = backend/
_REPO_ROOT: Final[Path] = Path(__file__).resolve().parents[2]
_UPLOAD_DIR: Final[Path] = _REPO_ROOT / "workpdf"
_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_MIME: Final[set[str]] = {"application/pdf"}
MAX_SIZE_BYTES: Final[int] = 25 * 1024 * 1024  # 25 MB

async def save_pdf(file: UploadFile) -> str:
    """
    บันทึกไฟล์ PDF ลงโฟลเดอร์ workpdf แล้วคืน path แบบ relative เช่น "workpdf/<uuid>.pdf"
    - ตรวจ MIME type = application/pdf
    - จำกัดขนาดไฟล์ ~25MB (ปรับได้)
    """
    if file.content_type not in ALLOWED_MIME:
        raise HTTPException(status_code=400, detail="Only PDF is allowed")

    # ตั้งชื่อไฟล์เป็น UUID เพื่อกันชน/ชื่อประหลาด
    filename = f"{uuid.uuid4()}.pdf"
    dest_path = _UPLOAD_DIR / filename

    # อ่านเป็นชิ้น ๆ เพื่อกันกินแรม และตรวจขนาดรวม
    size = 0
    try:
        with dest_path.open("wb") as out:
            while True:
                chunk = await file.read(1024 * 1024)  # 1MB/ครั้ง
                if not chunk:
                    break
                size += len(chunk)
                if size > MAX_SIZE_BYTES:
                    try:
                        dest_path.unlink(missing_ok=True)
                    except Exception:
                        pass
                    raise HTTPException(status_code=413, detail="PDF is too large")
                out.write(chunk)
    finally:
        await file.close()

    # คืนเป็น path relative เพื่อเก็บลง DB
    return f"workpdf/{filename}"
