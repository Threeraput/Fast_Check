# backend/app/models/class_model.py
import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from app.database import Base
from app.models.association import class_students # ต้อง import ตารางเชื่อมความสัมพันธ์
from app.models.classwork_assignment import ClassworkAssignment

class Class(Base):
    __tablename__ = "classes"

    class_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), unique=False, index=True, nullable=False)
    code = Column(String(10), unique=True, nullable=False)
    description = Column(String(255), nullable=True)
    teacher_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False) # อาจารย์ผู้สอน (User ID)
    start_time = Column(DateTime, nullable=True)
    end_time = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # Relationships
    attendance_sessions = relationship("AttendanceSession", back_populates="classroom", cascade="all, delete-orphan")
    teacher = relationship("User", back_populates="teaching_classes", foreign_keys=[teacher_id])
    students = relationship("User", secondary=class_students, back_populates="enrolled_classes")
    attendances = relationship("Attendance", back_populates="class_rel", cascade="all, delete-orphan")
    teacher_location_logs = relationship("TeacherLocation", back_populates="classroom", cascade="all, delete-orphan")
    student_location_logs = relationship("StudentLocation", back_populates="classroom", cascade="all, delete-orphan")
    # เพิ่ม Relationship สำหรับ Classwork
    assignments = relationship("ClassworkAssignment", back_populates="classroom", cascade="all, delete-orphan")
    announcements = relationship("Announcement", back_populates="klass", cascade="all, delete-orphan")
    def __repr__(self):
        return f"<Class(name='{self.name}')>"

# เพิ่ม relationship ใน User model ที่เกี่ยวข้องกับ Class (ถ้ายังไม่มี)
# ต้องนำเข้าในไฟล์ user.py ด้วย
# จาก app/models/user.py
# class User(Base):
#     # ...
#     teaching_classes = relationship("Class", back_populates="teacher", foreign_keys='Class.teacher_id')
#     enrolled_classes = relationship("Class", secondary=class_students, back_populates="students")