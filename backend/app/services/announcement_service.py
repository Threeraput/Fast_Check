# app/services/announcement_service.py
from typing import List, Optional
from uuid import UUID
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from app.models.announcement import Announcement, AnnouncementComment
from app.models.announcement_attachment import AnnouncementAttachment
from app.models.class_model import Class as ClassModel
from fastapi import HTTPException, UploadFile, status
from app.services.simple_classwork_service import _ensure_teacher_of_class
from app.utils.announcement_storage import save_announcement_file, delete_announcement_file

def get_announcement(db: Session, announcement_id: UUID) -> Optional[Announcement]:
    return db.query(Announcement).filter(Announcement.announcement_id == announcement_id).first()

def create_announcement(
    db: Session,
    *,
    teacher_id: UUID,
    class_id: UUID,
    title: str,
    body: Optional[str],
    pinned: bool = False,
    visible: bool = True,
    expires_at: Optional[datetime] = None,
) -> Announcement:
    # ครูเจ้าของคลาสเท่านั้น
    _ = _ensure_teacher_of_class(db, teacher_id=teacher_id, class_id=class_id)

    ann = Announcement(
        class_id=class_id,
        teacher_id=teacher_id,
        title=title,
        body=body,
        pinned=pinned or False,
        visible=visible if visible is not None else True,
        expires_at=expires_at,
    )
    db.add(ann)
    db.commit()
    db.refresh(ann)
    return ann

async def create_announcement_attachment(
    db: Session,
    *,
    announcement_id: UUID,
    uploaded_by: UUID,
    file: UploadFile,
) -> AnnouncementAttachment:
    """อัปโหลดและผูกไฟล์แนบเข้ากับประกาศ"""
    ann = db.query(Announcement).filter(Announcement.announcement_id == announcement_id).first()
    if not ann:
        raise HTTPException(status_code=404, detail="Announcement not found")
    
    # ตรวจสอบว่าเป็นเจ้าของประกาศ (ครู)
    _ = _ensure_teacher_of_class(db, teacher_id=uploaded_by, class_id=ann.class_id)

    storage_path, mime_type, size_bytes = await save_announcement_file(file)

    attachment = AnnouncementAttachment(
        announcement_id=announcement_id,
        uploaded_by=uploaded_by,
        file_name=file.filename or "attachment",
        storage_path=storage_path,
        mime_type=mime_type,
        size_bytes=size_bytes,
    )

    db.add(attachment)
    db.commit()
    db.refresh(attachment)
    return attachment

def list_announcements_for_class(
    db: Session,
    *,
    class_id: UUID,
    include_hidden: bool = False,
) -> List[Announcement]:
    q = db.query(Announcement).filter(Announcement.class_id == class_id)
    if not include_hidden:
        q = q.filter(Announcement.visible == True)  # noqa: E712
    
    # เรียง: ปักหมุดก่อน แล้วค่อยล่าสุด
    q = q.order_by(Announcement.pinned.desc(), Announcement.created_at.desc())
    return q.all()

def update_announcement(
    db: Session,
    *,
    teacher_id: UUID,
    announcement_id: UUID,
    title: Optional[str] = None,
    body: Optional[str] = None,
    pinned: Optional[bool] = None,
    visible: Optional[bool] = None,
    expires_at: Optional[datetime] = None,
) -> Announcement:
    ann = db.query(Announcement).filter(Announcement.announcement_id == announcement_id).first()
    if not ann:
        raise ValueError("Announcement not found")
    # เฉพาะครูเจ้าของคลาส
    _ = _ensure_teacher_of_class(db, teacher_id=teacher_id, class_id=ann.class_id)

    if title is not None:
        ann.title = title
    if body is not None:
        ann.body = body
    if pinned is not None:
        ann.pinned = pinned
    if visible is not None:
        ann.visible = visible
    if expires_at is not None:
        ann.expires_at = expires_at

    db.add(ann)
    db.commit()
    db.refresh(ann)
    return ann

def delete_announcement(
    db: Session,
    *,
    teacher_id: UUID,
    announcement_id: UUID,
) -> None:
    ann = db.query(Announcement).filter(Announcement.announcement_id == announcement_id).first()
    if not ann:
        return
    _ = _ensure_teacher_of_class(db, teacher_id=teacher_id, class_id=ann.class_id)
    db.delete(ann)
    db.commit()

def delete_announcement_attachment(
    db: Session,
    *,
    teacher_id: UUID,
    attachment_id: UUID,
) -> None:
    """ลบไฟล์แนบของประกาศ"""
    att = db.query(AnnouncementAttachment).filter(AnnouncementAttachment.attachment_id == attachment_id).first()
    if not att:
        return
    
    # ตรวจสอบว่าเป็นเจ้าของประกาศ (ครู)
    ann = att.announcement
    _ = _ensure_teacher_of_class(db, teacher_id=teacher_id, class_id=ann.class_id)

    # ลบไฟล์ใน storage
    delete_announcement_file(att.storage_path)

    db.delete(att)
    db.commit()

# ==========================================
# ระบบคอมเมนต์ประกาศ (Announcement Comments)
# ==========================================

def create_announcement_comment(
    db: Session, 
    announcement_id: UUID, 
    user_id: UUID, 
    content: str
) -> AnnouncementComment:
    """
    สร้างคอมเมนต์ใหม่ในประกาศ
    """
    new_comment = AnnouncementComment(
        announcement_id=announcement_id,
        user_id=user_id,
        content=content
    )
    db.add(new_comment)
    db.commit()
    db.refresh(new_comment)
    return new_comment

def get_announcement_comments(
    db: Session, 
    announcement_id: UUID
) -> List[AnnouncementComment]:
    """
    ดึงคอมเมนต์ทั้งหมดของประกาศนั้น (เรียงจากเก่าไปใหม่)
    """
    return (
        db.query(AnnouncementComment)
        .filter(AnnouncementComment.announcement_id == announcement_id)
        .order_by(AnnouncementComment.created_at.asc())
        .all()
    )