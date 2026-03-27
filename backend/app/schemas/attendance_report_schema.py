# backend/app/schemas/attendance_report_schema.py
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict


class AttendanceReportDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    session_id: UUID
    check_in_time: Optional[datetime] = None
    status: str
    is_reverified: bool
    # เพิ่มเพื่อให้ในหน้า Report บอกได้ว่า session นี้เริ่มเรียนเมื่อไหร่
    session_start: Optional[datetime] = None


class AttendanceReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    report_id: UUID
    class_id: Optional[UUID] = None
    student_id: UUID

    # --- ส่วนที่ควรเพิ่ม/ปรับปรุง ---
    student_name: Optional[str] = None  # ส่งชื่อนักเรียนกลับไปด้วยเลย
    student_code: Optional[str] = None  # รหัสนักเรียน (ถ้ามี)

    # total_sessions ในที่นี้จะเป็น "Effective Sessions"
    # หรือจำนวนคาบที่นักเรียนคนนี้ควรเข้าจริงตาม joined_at
    total_sessions: int

    attended_sessions: int
    late_sessions: int
    absent_sessions: int
    left_early_sessions: int
    reverified_sessions: int
    attendance_rate: float  # อัตราส่วนที่คำนวณมาแล้วจาก Service

    generated_at: datetime
    last_session_time: Optional[datetime] = None
    class_name: Optional[str] = None
    details: List[AttendanceReportDetailResponse] = Field(default_factory=list)
