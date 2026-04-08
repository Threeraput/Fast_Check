from sqlalchemy import Column, String, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
import uuid
from datetime import datetime, timedelta, timezone
from sqlalchemy.dialects import postgresql # <-- เพิ่มการ import นี้

# หากคุณมี Base ที่ app.database.base (ถ้า Base อยู่ใน app.database.base)
from app.database import Base # ตรวจสอบให้แน่ใจว่า Base ถูกนำเข้าอย่างถูกต้อง
from app.core.config import settings # ตรวจสอบให้แน่ใจว่า Settings ถูกนำเข้าอย่างถูกต้อง

# OTP Model สำหรับจัดการ OTP (One-Time Password)
class OTP(Base):
    __tablename__ = "otps" # กำหนดชื่อตารางในฐานข้อมูล

    # แก้ไขการกำหนด Column สำหรับ otp_id
    otp_id = Column(postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # แก้ไขการกำหนด Column สำหรับ user_id
    user_id = Column(postgresql.UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    
    otp_code = Column(String(6), nullable=False) # รหัส OTP
    expires_at = Column(DateTime(timezone=True), nullable=False) # เวลาหมดอายุ
    is_used = Column(Boolean, default=False) # สถานะว่า OTP ถูกใช้ไปแล้วหรือยัง
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    # ย้าย relationship เข้ามาในคลาส OTP
    user = relationship("User", back_populates="otps")

    # ย้าย __init__ เข้ามาในคลาส OTP และแก้ไข indentation
    def __init__(self, user_id: uuid.UUID, otp_code: str):
        self.user_id = user_id
        self.otp_code = otp_code
        self.expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

    # ย้าย is_expired เข้ามาในคลาส OTP และแก้ไข indentation
    def is_expired(self) -> bool:
        return datetime.now(timezone.utc) > self.expires_at

    # ย้าย __repr__ เข้ามาในคลาส OTP และแก้ไข indentation
    def __repr__(self):
        return f"<OTP(otp_id={self.otp_id}, user_id={self.user_id}, otp_code={self.otp_code[:3]}...{self.otp_code[-3:]}, expires_at={self.expires_at})>"