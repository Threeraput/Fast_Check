# backend/app/schemas/user_schema.py
from __future__ import annotations

from typing import Optional, List
from datetime import datetime
from uuid import UUID
from app.models import User
from pydantic import BaseModel, EmailStr, Field
from pydantic.config import ConfigDict  # Pydantic v2


# ---------------------------
# Public user (สำหรับฝั่ง client/UI)
# ---------------------------
class UserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    username: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    is_active: Optional[bool] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    student_id: Optional[str] = None
    teacher_id: Optional[str] = None
    avatar_url: Optional[str] = None
    # เก็บ role เป็นชื่อ string
    roles: List[str] = Field(default_factory=list)
    avatar_url: Optional[str] = None


# ---------------------------
# หลักสำหรับการจัดการ User
# ---------------------------
class UserBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    username: str = Field(..., min_length=3, max_length=80)
    first_name: str = Field(..., min_length=1, max_length=60)
    last_name: str = Field(..., min_length=1, max_length=60)
    email: EmailStr = Field(..., max_length=120)


class UserCreate(UserBase):
    password: str = Field(..., min_length=6)
    student_id: Optional[str] = Field(None, max_length=20)
    teacher_id: Optional[str] = Field(None, max_length=20)
    role: str = Field(..., pattern=r"^(student|teacher|admin)$")


class UserLogin(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    username: Optional[str] = Field(None, max_length=80)
    first_name: Optional[str] = Field(None, max_length=60)
    last_name: Optional[str] = Field(None, max_length=60)
    student_id: Optional[str] = Field(None, max_length=20)
    teacher_id: Optional[str] = Field(None, max_length=20)
    is_active: Optional[bool] = None


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    is_active: bool
    is_approved: Optional[bool] = None
    created_at: datetime
    updated_at: datetime
    last_login_at: Optional[datetime] = None
    roles: List[str] = Field(default_factory=list)  # หลีกเลี่ยง mutable default
    avatar_url: Optional[str] = None
    student_id: Optional[str] = Field(None, max_length=20)
    teacher_id: Optional[str] = Field(None, max_length=20)


# ---------------------------
# Token / Authentication
# ---------------------------
class Token(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    access_token: str
    token_type: str = "bearer"
    user: UserResponse  # แนบข้อมูล user ใน token response


class TokenData(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    roles: List[str] = Field(default_factory=list)
