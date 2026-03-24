# backend/app/schemas/class_schema.py
from typing import List, Optional
from uuid import UUID
from datetime import datetime

from pydantic import BaseModel, Field
from pydantic.config import ConfigDict  # Pydantic v2

from app.schemas.user_schema import UserPublic


# -----------------
# Request Schemas
# -----------------
class ClassroomCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str = Field(..., max_length=100)
    description: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None


class ClassroomJoin(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str = Field(..., max_length=10, description="The unique code to join the classroom")


class ClassroomUpdate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None


# -----------------
# Response Schemas
# -----------------
class ClassroomResponseBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    class_id: UUID
    name: str
    code: Optional[str] = None
    teacher_id: UUID
    created_at: Optional[datetime] = None
    description: Optional[str] = None


class ClassroomResponse(ClassroomResponseBase):
    model_config = ConfigDict(from_attributes=True)

    teacher: Optional[UserPublic] = None
    students: List[UserPublic] = Field(default_factory=list)


class ClassMembersResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    class_id: UUID
    name: str
    code: Optional[str] = None
    teacher: UserPublic
    students: List[UserPublic] = Field(default_factory=list)
