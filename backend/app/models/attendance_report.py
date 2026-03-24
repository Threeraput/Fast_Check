from sqlalchemy import Column, Integer, Float, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base
import uuid
from datetime import datetime


class AttendanceReport(Base):
    __tablename__ = "attendance_reports"

    report_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.class_id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)

    total_sessions = Column(Integer, nullable=False, default=0)
    attended_sessions = Column(Integer, nullable=False, default=0)
    late_sessions = Column(Integer, nullable=False, default=0)
    absent_sessions = Column(Integer, nullable=False, default=0)
    left_early_sessions = Column(Integer, nullable=False, default=0)
    reverified_sessions = Column(Integer, nullable=False, default=0)
    attendance_rate = Column(Float, nullable=False, default=0.0)

    generated_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    student = relationship("User", backref="attendance_reports")
    classroom = relationship("Class", backref="attendance_reports")
