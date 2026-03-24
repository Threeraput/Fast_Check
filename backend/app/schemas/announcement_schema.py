# app/schemas/announcement_schema.py
from typing import Optional
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field

class AnnouncementCreate(BaseModel):
    class_id: UUID
    title: str = Field(..., max_length=255)
    body: Optional[str] = None
    pinned: Optional[bool] = False
    visible: Optional[bool] = True
    expires_at: Optional[datetime] = None

class AnnouncementUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=255)
    body: Optional[str] = None
    pinned: Optional[bool] = None
    visible: Optional[bool] = None
    expires_at: Optional[datetime] = None

class AnnouncementResponse(BaseModel):
    announcement_id: UUID
    class_id: UUID
    teacher_id: UUID
    title: str
    body: Optional[str]
    pinned: bool
    visible: bool
    created_at: datetime
    updated_at: datetime
    expires_at: Optional[datetime]

    class Config:
        from_attributes = True
