# backend/app/models/user.py
import uuid
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship # <-- ตรวจสอบว่ามีบรรทัดนี้
from datetime import datetime, timezone
from app.database import Base
from app.models.association import user_roles, class_students # ตรวจสอบว่า import class_students ด้วย
from app.models.attendance_session import AttendanceSession
from pydantic import BaseModel
from typing import Optional

class User(Base):
    __tablename__ = "users"

    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(80), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(60), nullable=True) 
    last_name = Column(String(60), nullable=True) 
    email = Column(String(120), unique=True, index=True, nullable=False)
    student_id = Column(String(20), unique=True, index=True, nullable=True)
    teacher_id = Column(String(20), unique=True, index=True, nullable=True)
    is_active = Column(Boolean, default=True , nullable=False) # ใช้ default=True เพื่อให้เป็น True โดยค่าเริ่มต้น
    is_approved = Column(Boolean, default=True , nullable=False) # ใช้ default=True เพื่อให้เป็น True โดยค่าเริ่มต้น
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    last_login_at = Column(DateTime, nullable=True)
    avatar_url = Column(String(255), nullable=True)
    # Relationships
    # User -> Roles (Many-to-Many)
    roles = relationship("Role", secondary=user_roles, back_populates="users")
    location_updates = relationship("TeacherLocation", back_populates="teacher", cascade="all, delete-orphan")
    student_locations = relationship("StudentLocation", back_populates="student", cascade="all, delete-orphan")
    # User -> Face Samples (One-to-Many)
    face_samples = relationship("UserFaceSample", back_populates="user", cascade="all, delete-orphan")
    # User -> Attendances (One-to-Many, นักเรียนเป็นคนถูกบันทึก)
    # Attendance Relationships
    # ความสัมพันธ์ของนักเรียน (ผู้เข้าเรียน)
    attendances = relationship(
        "Attendance", 
        foreign_keys="[Attendance.student_id]", 
        back_populates="student", 
        cascade="all, delete-orphan"
    )
    # User -> Recorded Attendances (One-to-Many, อาจารย์/ผู้ดูแลเป็นคนบันทึก)
    recorded_attendances = relationship(
        "Attendance", 
        foreign_keys="[Attendance.recorded_by_user_id]", # <-- ชี้ไปที่คอลัมน์ใน Attendance
        back_populates="recorder", 
        cascade="all, delete-orphan"
    )
    # User -> Classes (One-to-Many, อาจารย์เป็นเจ้าของ Class)
    teaching_classes = relationship("Class", back_populates="teacher", foreign_keys='Class.teacher_id')
    enrolled_classes = relationship("Class", secondary=class_students, back_populates="students")
   
    
    # User -> OTPs (One-to-Many)
    otps = relationship("OTP", back_populates="user", cascade="all, delete-orphan")
    
    enrolled_classes = relationship("Class", secondary=class_students, back_populates="students")
    # เพิ่มความสัมพันธ์สำหรับการเป็นผู้สอน/ผู้ประกาศ
    attendance_sessions = relationship("AttendanceSession", back_populates="teacher", cascade="all, delete-orphan")
    # ความสัมพันธ์สำหรับการส่งงาน (Student)
    class_assignments = relationship("ClassworkAssignment", back_populates="teacher", cascade="all, delete-orphan")
    class_submissions = relationship("ClassworkSubmission", back_populates="student", cascade="all, delete-orphan")
   
    def __repr__(self):
        return f"<User(username='{self.username}', email='{self.email}')>"
    
