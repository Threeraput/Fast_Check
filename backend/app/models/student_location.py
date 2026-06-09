# backend/app/models/student_location.py
import uuid
from sqlalchemy import Column, ForeignKey, DateTime, Numeric, func, Boolean, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship   
from app.database import Base

class StudentLocation(Base):
    """
    Model สำหรับบันทึกตำแหน่งผู้เรียนเป็นระยะระหว่างคาบเรียน (Continuous Tracking)
    """
    __tablename__ = "student_locations"

    stdl_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.class_id", ondelete="CASCADE"), nullable=False)
    session_id = Column(
        UUID(as_uuid=True),
        ForeignKey("attendance_sessions.session_id", ondelete="SET NULL"),
        nullable=True,
    )

    latitude = Column(Numeric(9, 6), nullable=False)
    longitude = Column(Numeric(9, 6), nullable=False)
    timestamp = Column(DateTime(timezone=True), default=func.now())
    server_received_at = Column(DateTime(timezone=True), nullable=True)
    is_silent_check = Column(
        Boolean, default=False, server_default="false", nullable=False
    )
    anchor_lat = Column(Numeric(9, 6), nullable=True)
    anchor_lon = Column(Numeric(9, 6), nullable=True)
    distance_m = Column(Numeric(10, 3), nullable=True)
    radius_m = Column(Numeric(10, 3), nullable=True)
    verification_result = Column(String(32), nullable=True)
    verification_reason = Column(String(255), nullable=True)

    #  เพิ่ม Relationship ตรงนี้ให้ตรงกับ User.student_locations
    student = relationship("User", back_populates="student_locations")

    #  เพิ่ม Relationship กับ Class ด้วย (optional แต่แนะนำให้มี)
    classroom = relationship("Class", back_populates="student_location_logs")

    def __repr__(self):
        return (
            f"<StudentLocation(student='{self.student_id}', class='{self.class_id}', "
            f"coords={self.latitude},{self.longitude}, result='{self.verification_result}', "
            f"time='{self.timestamp.strftime('%H:%M:%S')}')>"
        )
