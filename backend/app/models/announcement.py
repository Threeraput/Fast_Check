# app/models/announcement.py
import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Boolean, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.dialects.sqlite import BLOB as SQLITE_UUID
from sqlalchemy.orm import relationship
from app.database import Base

# รองรับได้ทั้ง Postgres/SQLite: ถ้าใช้ Postgres แนะนำ PG_UUID, ถ้า SQLite ก็เก็บเป็น TEXT/Blob
UUIDCol = PG_UUID(as_uuid=True) if hasattr(PG_UUID, "python_type") else String(36)

class Announcement(Base):
    __tablename__ = "announcements"

    announcement_id = Column(UUIDCol, primary_key=True, default=uuid.uuid4)
    class_id       = Column(UUIDCol, ForeignKey("classes.class_id"), index=True, nullable=False)
    teacher_id     = Column(UUIDCol, ForeignKey("users.user_id"), index=True, nullable=False)

    title          = Column(String(255), nullable=False)
    body           = Column(Text, nullable=True)  # เนื้อหาประกาศ
    pinned         = Column(Boolean, default=False, nullable=False)  # ปักหมุด
    visible        = Column(Boolean, default=True,  nullable=False)  # ปิด/เปิดการมองเห็น

    created_at     = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at     = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    expires_at     = Column(DateTime, nullable=True)  # ถ้าต้องการหมดอายุ

    # ความสัมพันธ์ที่ใช้อยู่แล้ว
    klass          = relationship("Class", back_populates="announcements")
    teacher        = relationship("User", foreign_keys=[teacher_id])
