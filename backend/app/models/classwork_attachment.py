import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class ClassworkAttachment(Base):
    """ไฟล์แนบของ assignment สำหรับครูแนบโจทย์/เอกสารประกอบ"""

    __tablename__ = "classwork_attachments"

    attachment_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    assignment_id = Column(
        UUID(as_uuid=True),
        ForeignKey("classwork_assignments.assignment_id", ondelete="CASCADE"),
        nullable=False,
    )
    uploaded_by = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    file_name = Column(String(255), nullable=False)
    storage_path = Column(String(512), nullable=False)
    mime_type = Column(String(128), nullable=False)
    size_bytes = Column(Integer, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    assignment = relationship("ClassworkAssignment", back_populates="attachments")

    __table_args__ = (
        Index("ix_cw_attachments_assignment", "assignment_id"),
    )
