# backend/app/models/user_face_sample.py
import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, LargeBinary  , UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from app.database import Base

class UserFaceSample(Base):
    __tablename__ = "user_face_samples"

    sample_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    image_url = Column(String(255), nullable=True) # ถ้าเก็บเป็น URL
    # หรือถ้าเก็บ binary data ใน DB โดยตรง (ไม่แนะนำสำหรับไฟล์ขนาดใหญ่)
    face_embedding = Column(LargeBinary, nullable=True) # For storing face recognition embeddings
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    # Relationships
    user = relationship("User", back_populates="face_samples")

    def __repr__(self):
        return f"<UserFaceSample(user_id='{self.user_id}', sample_id='{self.sample_id}')>"
    
    
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_user_face_sample_user"),
    )