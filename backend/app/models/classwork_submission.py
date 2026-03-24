import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Integer, Boolean, ForeignKey, UniqueConstraint, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base
from sqlalchemy import Enum as SAEnum
from app.models.classwork_enums import SubmissionLateness  # ใช้ enum เดิมของคุณ

class ClassworkSubmission(Base):
    """
    การส่งงานของนักเรียนต่อ assignment หนึ่ง (1 แถวต่อ 1 นักเรียน)
    """
    __tablename__ = "classwork_submissions"

    submission_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    assignment_id = Column(
        UUID(as_uuid=True),
        ForeignKey("classwork_assignments.assignment_id", ondelete="CASCADE"),
        nullable=False,
    )
    student_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    content_url = Column(String(512), nullable=True)   # เช่น workpdf/<uuid>.pdf
    submitted_at = Column(DateTime(timezone=True), nullable=True)

    submission_status = Column(
        SAEnum(SubmissionLateness, name="submissionlateness", values_callable=lambda x: [e.value for e in x], create_type=False),
        nullable=False,
        default=SubmissionLateness.NOT_SUBMITTED.value,
    )
    graded = Column(Boolean, nullable=False, default=False)
    score = Column(Integer, nullable=True)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    # relationships
    assignment = relationship("ClassworkAssignment", back_populates="submissions")
    student = relationship("User", foreign_keys=[student_id], back_populates="class_submissions")

    __table_args__ = (
        # ห้ามมีแถวซ้ำสำหรับ (assignment_id, student_id)
        UniqueConstraint("assignment_id", "student_id", name="uq_cw_submission_assign_student"),
        Index("ix_cw_submissions_assign_student", "assignment_id", "student_id"),
    )
