# backend/app/models/student_location.py
import uuid
from sqlalchemy import Column, ForeignKey, DateTime, Numeric, func
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
    
    latitude = Column(Numeric(9, 6), nullable=False)
    longitude = Column(Numeric(9, 6), nullable=False)
    timestamp = Column(DateTime(timezone=True), default=func.now())

    #  เพิ่ม Relationship ตรงนี้ให้ตรงกับ User.student_locations
    student = relationship("User", back_populates="student_locations")

    #  เพิ่ม Relationship กับ Class ด้วย (optional แต่แนะนำให้มี)
    classroom = relationship("Class", back_populates="student_location_logs")

    def __repr__(self):
        return (
            f"<StudentLocation(student='{self.student_id}', class='{self.class_id}', "
            f"coords={self.latitude},{self.longitude}, time='{self.timestamp.strftime('%H:%M:%S')}')>"
        )
