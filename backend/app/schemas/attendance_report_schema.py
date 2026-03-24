from typing import Optional, List
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field
from pydantic.config import ConfigDict

class AttendanceReportDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    session_id: UUID
    check_in_time: Optional[datetime] = None
    status: str
    is_reverified: bool

class AttendanceReportCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    class_id: UUID
    student_id: UUID

class AttendanceReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    report_id: UUID
    # NOTE: ชั่วคราวให้ Optional เพื่อกันล้ม ถ้าทำความสะอาด DB แล้วค่อยเปลี่ยนกลับเป็น UUID
    class_id: Optional[UUID] = None
    student_id: UUID

    total_sessions: int
    attended_sessions: int
    late_sessions: int
    absent_sessions: int
    left_early_sessions: int
    reverified_sessions: int
    attendance_rate: float

    generated_at: datetime
    class_name: Optional[str] = None
    details: List[AttendanceReportDetailResponse] = Field(default_factory=list)
