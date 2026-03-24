# app/api/v1/announcements.py
from typing import List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.deps import get_current_user, role_required
from app.models.user import User
from app.schemas.announcement_schema import (
    AnnouncementCreate,
    AnnouncementUpdate,
    AnnouncementResponse,
)
from app.services.announcement_service import (
    create_announcement,
    list_announcements_for_class,
    update_announcement,
    delete_announcement,
)

router = APIRouter(prefix="/announcements", tags=["Announcements"])


# ครูสร้างประกาศ
@router.post(
    "",
    response_model=AnnouncementResponse,
    dependencies=[Depends(role_required(["teacher"]))],
    status_code=status.HTTP_201_CREATED,
)
def create_announcement_route(
    payload: AnnouncementCreate,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    ann = create_announcement(
        db,
        teacher_id=me.user_id,
        class_id=payload.class_id,
        title=payload.title,
        body=payload.body,
        pinned=payload.pinned or False,
        visible=payload.visible if payload.visible is not None else True,
        expires_at=payload.expires_at,
    )
    return ann


# ทั้งครู/นักเรียน ดูประกาศของคลาส
@router.get("/class/{class_id}", response_model=List[AnnouncementResponse])
def list_class_announcements_route(
    class_id: UUID,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    # ไม่บังคับ role: ทั้งครู/นักเรียนในคลาสจะเรียกได้ (ถ้าต้องการ validate ว่าอยู่ในคลาส ให้เพิ่มตรวจ membership)
    items = list_announcements_for_class(db, class_id=class_id, include_hidden=False)
    return items


# ครูแก้ไข
@router.patch(
    "/{announcement_id}",
    response_model=AnnouncementResponse,
    dependencies=[Depends(role_required(["teacher"]))],
)
def update_announcement_route(
    announcement_id: UUID,
    payload: AnnouncementUpdate,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    try:
        ann = update_announcement(
            db,
            teacher_id=me.user_id,
            announcement_id=announcement_id,
            title=payload.title,
            body=payload.body,
            pinned=payload.pinned,
            visible=payload.visible,
            expires_at=payload.expires_at,
        )
        return ann
    except ValueError:
        raise HTTPException(status_code=404, detail="Announcement not found")


# ครูลบ
@router.delete(
    "/{announcement_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(role_required(["teacher"]))],
)
def delete_announcement_route(
    announcement_id: UUID,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    delete_announcement(db, teacher_id=me.user_id, announcement_id=announcement_id)
    return
