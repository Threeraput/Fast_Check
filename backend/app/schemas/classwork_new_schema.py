# backend/app/schemas/classwork_new_schema.py
from __future__ import annotations
from pydantic import BaseModel, Field, conint
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from app.models.classwork_enums import SubmissionLateness  # ใช้ enum เดิม: On_Time, Late, Not_Submitted

# -------------------------------------------------------------------
# Assignment (งานระดับคลาส)
# -------------------------------------------------------------------

class AssignmentCreate(BaseModel):
    """ครูสร้างงานระดับคลาส"""
    class_id: UUID
    title: str = Field(..., max_length=255)
    max_score: conint(ge=1) = 100
    due_date: datetime   # รองรับ timezone-aware

class AssignmentUpdate(BaseModel):
    """แก้ไขเมทาดาทา (ทางเลือก)"""
    title: Optional[str] = Field(None, max_length=255)
    max_score: Optional[conint(ge=1)] = None
    due_date: Optional[datetime] = None

class AssignmentResponse(BaseModel):
    """ข้อมูลงานระดับคลาส (อ่านอย่างเดียว)"""
    assignment_id: UUID
    class_id: UUID
    teacher_id: UUID
    title: str
    max_score: int
    due_date: datetime
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# -------------------------------------------------------------------
# Submission (การส่งของนักเรียน)
# -------------------------------------------------------------------

class SubmissionBase(BaseModel):
    assignment_id: UUID
    student_id: UUID

class SubmissionCreateOrUpdate(BaseModel):
    """
    สำหรับ endpoint ที่รับ metadata เพิ่ม (ถ้าต้องการ)
    ปกติการอัปโหลด PDF ใช้ form-data แยก ไม่ได้ผ่าน schema นี้
    """
    # เผื่ออนาคตถ้าจะให้ส่งลิงก์ไฟล์แทนการอัปโหลด
    content_url: Optional[str] = None

class GradeSubmission(BaseModel):
    """ครูให้คะแนนการส่งของนักเรียนคนหนึ่ง"""
    student_id: UUID
    score: conint(ge=0)  # ฝั่ง service ควรตรวจ <= max_score

class SubmissionResponse(BaseModel):
    """ข้อมูลการส่งของนักเรียน (อ่านอย่างเดียว)"""
    submission_id: UUID
    assignment_id: UUID
    student_id: UUID
    content_url: Optional[str] = None
    submitted_at: Optional[datetime] = None
    submission_status: SubmissionLateness   # On_Time / Late / Not_Submitted
    graded: bool
    score: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# -------------------------------------------------------------------
# View รวม/ผสมเพื่อหน้าจอ (สะดวกใช้ใน API)
# -------------------------------------------------------------------

class MySubmissionMini(BaseModel):
    """ย่อ: สำหรับแสดงงานของฉันต่อ assignment หนึ่ง"""
    content_url: Optional[str] = None
    submitted_at: Optional[datetime] = None
    submission_status: SubmissionLateness
    graded: bool
    score: Optional[int] = None

    class Config:
        from_attributes = True

class AssignmentWithMySubmission(BaseModel):
    """นักเรียนดึงรายการงานในคลาส + สถานะของตัวเอง (ถ้ามี)"""
    assignment_id: UUID
    class_id: UUID
    teacher_id: UUID
    title: str
    max_score: int
    due_date: datetime

    # สถานะคำนวณของฉัน ณ ตอนเรียก (ถ้ายังไม่เคยส่ง = Not_Submitted)
    computed_status: SubmissionLateness
    my_submission: Optional[MySubmissionMini] = None

    class Config:
        from_attributes = True

class SubmissionRowForTeacher(BaseModel):
    """ครูดูภาพรวมการส่งของทั้งคลาส สำหรับ assignment หนึ่ง"""
    student_id: UUID
    student_name: Optional[str] = None
    content_url: Optional[str] = None
    submitted_at: Optional[datetime] = None
    submission_status: SubmissionLateness
    graded: bool
    score: Optional[int] = None

class AssignmentStats(BaseModel):
    """สถิติรวม (ทางเลือก)"""
    total_students: int
    on_time: int
    late: int
    not_submitted: int

class AssignmentWithClassOverview(BaseModel):
    """
    ครูดู assignment + ภาพรวมทั้งคลาส
    ใช้ใน GET /assignments/{assignment_id}/submissions
    """
    assignment: AssignmentResponse
    stats: AssignmentStats
    submissions: List[SubmissionRowForTeacher]
