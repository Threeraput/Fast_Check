import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, ForeignKey, DateTime, String  # ใช้ String
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base
from app.core.field_encryption import EncryptedText

class ChatMessage(Base):
    __tablename__ = "chat_messages"

    message_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # เปลี่ยนเป็น String ธรรมดา และเอา ForeignKey ออก
    class_id = Column(String, nullable=False, index=True)      # จะเก็บเป็นชื่อวิชาแทน เช่น "Python 101"
    sender_id = Column(String, nullable=False, index=True)     # จะเก็บเป็นชื่อคนส่ง เช่น "Somchai"
    receiver_id = Column(String, nullable=False, index=True)   # จะเก็บเป็นชื่อคนรับ เช่น "Somsri"
    
    content = Column(EncryptedText(), nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # เอา line relationship ด้านล่างออกไปด้วย เพราะไม่ได้ผูก ID สัมพันธ์กันแล้ว