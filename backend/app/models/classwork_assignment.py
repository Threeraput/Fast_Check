import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Integer, ForeignKey, UniqueConstraint, Index, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base

class ClassworkAssignment(Base):
    """
    งานระดับคลาส (ยังไม่ผูกนักเรียน)
    """
    __tablename__ = "classwork_assignments"

    assignment_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.class_id", ondelete="CASCADE"), nullable=False)
    teacher_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)

    title = Column(String(255), nullable=False)
    max_score = Column(Integer, nullable=False, default=100)
    due_date = Column(DateTime(timezone=True), nullable=False)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    # relationships
    submissions = relationship(
        "ClassworkSubmission",
        back_populates="assignment",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    classroom = relationship("Class", back_populates="assignments")
    teacher = relationship("User", foreign_keys=[teacher_id], back_populates="class_assignments")

    # 👉 สิ่งที่ต้องเติมเพิ่มเข้าไป:
    comments = relationship(
        "AssignmentComment",
        back_populates="assignment",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    __table_args__ = (
        # กันชื่องานซ้ำในคลาสเดียวกัน (ถ้าคุณอยากให้ซ้ำได้ ให้ลบบรรทัดนี้)
        UniqueConstraint("class_id", "title", name="uq_cw_assign_class_title"),
        Index("ix_cw_assignments_class", "class_id"),
    )

# ----------------------------------------------------
# ตารางสำหรับเก็บคอมเมนต์ในแต่ละงาน (Assignment Comments)
# ----------------------------------------------------
class AssignmentComment(Base):
    __tablename__ = "assignment_comments"

    comment_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # ผูกกับงานชิ้นไหน? (ถ้างานถูกลบ คอมเมนต์จะโดนลบตาม CASCADE)
    assignment_id = Column(UUID(as_uuid=True), ForeignKey("classwork_assignments.assignment_id", ondelete="CASCADE"), nullable=False)
    # ใครเป็นคนพิมพ์คอมเมนต์? (ครู หรือ นักเรียน)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    
    # เนื้อหาคอมเมนต์
    content = Column(Text, nullable=False)

    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    # relationships
    assignment = relationship("ClassworkAssignment", back_populates="comments")
    # ผูกกับ User เพื่อให้ตอนดึงข้อมูล เราจะได้รู้ชื่อและรูปโปรไฟล์ของคนพิมพ์คอมเมนต์ด้วย
    user = relationship("User", lazy="joined")