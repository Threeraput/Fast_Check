# backend/app/models/teacher_location.py
import uuid
from sqlalchemy import Column, ForeignKey, DateTime, Numeric, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base

class TeacherLocation(Base):
    """
    Model สำหรับเก็บพิกัดล่าสุดของอาจารย์ผู้สอน (Anchor Point)
    """
    __tablename__ = "teacher_locations"

    tl_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    teacher_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.class_id", ondelete="CASCADE"), nullable=False)
    
    latitude = Column(Numeric(9, 6), nullable=False)
    longitude = Column(Numeric(9, 6), nullable=False)
    timestamp = Column(DateTime(timezone=True), default=func.now())
   
    #relationships
    teacher = relationship("User", back_populates="location_updates")
    classroom = relationship("Class", back_populates="teacher_location_logs")
    
    def __repr__(self):
        return (
            f"<TeacherLocation(teacher='{self.teacher_id}', class='{self.class_id}', "
            f"coords={self.latitude},{self.longitude}, time='{self.timestamp.strftime('%H:%M:%S')}')>"
        )