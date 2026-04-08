# backend/app/schemas/attendance_schema.py
from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from fastapi import Form
from app.models.attendance_enums import AttendanceStatus # นำเข้า Enum

# -----------------
# Request Schemas
# -----------------

class LocationData(BaseModel):
    """ใช้สำหรับรับ Lat/Lon ทั่วไป (เช่น อัปเดตตำแหน่งครู)"""
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)

class AttendanceCheckIn(BaseModel):
    session_id: UUID
    latitude: float
    longitude: float

    @classmethod
    def as_form(
        cls,
        session_id: UUID = Form(...),
        latitude: float = Form(...),
        longitude: float = Form(...),
    ):
        return cls(session_id=session_id, latitude=latitude, longitude=longitude)

class TeacherLocationUpdate(LocationData):
    """ใช้สำหรับรับตำแหน่งล่าสุดของอาจารย์"""
    class_id: UUID # ระบุว่าตำแหน่งนี้เกี่ยวข้องกับคลาสไหน (ถ้ามี)

class StudentLocationLogCreate(LocationData):
    """ใช้สำหรับบันทึก Log ตำแหน่งของนักเรียนระหว่างคาบ"""
    class_id: UUID
    
# -----------------
# Response Schemas
# -----------------
class AttendanceResponse(BaseModel):
    """Response สำหรับการบันทึกการเข้าเรียนสำเร็จ"""
    attendance_id: UUID
    class_id: UUID
    student_id: UUID
    check_in_time: datetime
    status: AttendanceStatus
    is_reverified: bool
    
    class Config:
        from_attributes = True

class TeacherLocationResponse(BaseModel):
    """Response สำหรับข้อมูลตำแหน่งของอาจารย์"""
    tl_id: UUID
    teacher_id: UUID
    class_id: UUID
    latitude: float
    longitude: float
    timestamp: datetime
    
    class Config:
        from_attributes = True


class AttendanceManualOverride(BaseModel):
    """ใช้สำหรับ Teacher/Admin ในการแก้ไขสถานะการเข้าเรียน"""
    status: AttendanceStatus 
    # สถานะใหม่ที่ต้องการตั้งค่า (เช่น PRESENT, ABSENT, LATE, MANUAL_OVERRIDE)
    
    # เพิ่ม is_manual_override ใน Schema
    is_manual_override: bool = True 
    

class ReverifyRequest(BaseModel):
    session_id: UUID
    latitude: float
    longitude: float

    @classmethod
    def as_form(
        cls,
        session_id: UUID = Form(...),
        latitude: float = Form(...),
        longitude: float = Form(...),
    ):
        return cls(session_id=session_id, latitude=latitude, longitude=longitude)