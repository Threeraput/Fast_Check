from sqlalchemy import Column, DateTime, Boolean, ForeignKey, Enum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base
from datetime import datetime
import uuid

class AttendanceReportDetail(Base):
    __tablename__ = "attendance_report_details"

    detail_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    report_id = Column(UUID(as_uuid=True), ForeignKey("attendance_reports.report_id", ondelete="CASCADE"), nullable=False)
    session_id = Column(UUID(as_uuid=True), ForeignKey("attendance_sessions.session_id", ondelete="CASCADE"), nullable=False)

    check_in_time = Column(DateTime(timezone=True), nullable=True)
    status = Column(Enum("Present", "Late", "Absent", "LeftEarly", name="reportstatus"), nullable=False)
    is_reverified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    report = relationship("AttendanceReport", backref="details")
