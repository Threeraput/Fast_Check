from typing import List, Optional
from datetime import datetime
import uuid
from pydantic import BaseModel
from app.schemas.user_schema import UserResponse

class AdminClassSummary(BaseModel):
    class_id: uuid.UUID
    name: str
    code: Optional[str] = None
    student_count: int
    created_at: datetime
    teacher: Optional[UserResponse] = None

    class Config:
        from_attributes = True

class AdminClassesPage(BaseModel):
    total: int
    limit: int
    offset: int
    items: List[AdminClassSummary] = []

# ✅ ใช้ตอนสร้างคลาสใหม่
class AdminCreateClass(BaseModel):
    name: str
    teacher_id: uuid.UUID
    code: Optional[str] = None
    description: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None

class AdminUsersPage(BaseModel):
    total: int
    limit: int
    offset: int
    items: List[UserResponse] = []

class SystemSummaryReport(BaseModel):
    total_users: int
    total_admins: int
    total_teachers: int
    total_students: int
    total_classes: int
    total_attendances: int
    total_attendances_in_range: int
    range_start: Optional[datetime] = None
    range_end: Optional[datetime] = None