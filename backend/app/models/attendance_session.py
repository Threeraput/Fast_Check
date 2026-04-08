# backend/app/models/attendance_session.py
import uuid
from sqlalchemy import Boolean, Column, ForeignKey, DateTime, Integer, func, Numeric, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base

class AttendanceSession(Base):
    """
    Model สำหรับบันทึกแต่ละครั้งที่อาจารย์สั่งเปิดการเช็คชื่อ (กล่องประกาศ)
    """
    __tablename__ = "attendance_sessions"

    session_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.class_id", ondelete="CASCADE"), nullable=False)
    teacher_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    
    # เวลาเต็ม (DateTime) ที่ใช้ในการตัดสินใจเช็คชื่อจริง
    start_time = Column(DateTime(timezone=True), default=func.now() , nullable=False)
    late_cutoff_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=False) 
    radius_meters = Column(Integer, nullable=False)
    reverify_enabled = Column(Boolean, nullable=False, server_default="false") 
    # Anchor Point สำหรับ Geofencing ณ เวลาประกาศ
    anchor_lat = Column(Numeric(9, 6), nullable=False)
    anchor_lon = Column(Numeric(9, 6), nullable=False)
    
    # คอนสเตรนต์ให้ลำดับเวลา valid
    __table_args__ = (
        CheckConstraint("start_time <= late_cutoff_time", name="ck_session_start_late"),
        CheckConstraint("late_cutoff_time <= end_time", name="ck_session_late_end"),
    )

    # Relationships
    classroom = relationship("Class", back_populates="attendance_sessions")
    teacher = relationship("User", back_populates="attendance_sessions") 
    attendances = relationship("Attendance", back_populates="attendance_session", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<AttendanceSession(class='{self.class_id}', start='{self.start_time.strftime('%Y-%m-%d %H:%M')}')>"
    
    