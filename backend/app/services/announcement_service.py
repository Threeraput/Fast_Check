# app/services/announcement_service.py
from typing import List, Optional
from uuid import UUID
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from app.models.announcement import Announcement
from app.models.class_model import Class as ClassModel
from fastapi import HTTPException as ApiException
from app.services.simple_classwork_service import _ensure_teacher_of_class

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
