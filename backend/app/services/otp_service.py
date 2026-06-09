# app/services/otp_service.py
from sqlalchemy.orm import Session
import uuid
import random
import string
from datetime import datetime, timezone, timedelta
from typing import Optional

from app.models.otp import OTP
from app.models.user import User # Assuming User model is accessible
from app.core.config import settings

# ฟังก์ชันสำหรับดึงผู้ใช้
def get_user_by_email_or_username_for_otp(db: Session, email_or_username: str) -> Optional[User]:
    # คล้ายกับ get_user_by_email หรือ get_user_by_username ใน db_service
    # แต่รวมกันเพื่อใช้ในการค้นหาผู้ใช้สำหรับ OTP
    user = db.query(User).filter(User.email == email_or_username).first()
    if not user:
        user = db.query(User).filter(User.username == email_or_username).first()
    return user

def generate_otp_code() -> str:
    # สร้าง OTP แบบ 6 หลัก
    return str(random.randint(100000, 999999))

from fastapi import HTTPException, status

# ฟังก์ชันสำหรับดึงผู้ใช้
# ...

def create_otp(db: Session, user_id: uuid.UUID) -> OTP:
    now = datetime.now(timezone.utc)
    
    # 1. ตรวจสอบ Cooldown (Rate Limit): ห้ามขอใหม่ภายใน 60 วินาที
    last_otp = (
        db.query(OTP)
        .filter(OTP.user_id == user_id)
        .order_by(OTP.created_at.desc())
        .first()
    )
    
    if last_otp:
        # ตรวจสอบส่วนต่างเวลา (Time Diff)
        last_created = last_otp.created_at
        if last_created.tzinfo is None:
            last_created = last_created.replace(tzinfo=timezone.utc)
            
        diff = (now - last_created).total_seconds()
        if diff < 60:
            seconds_left = int(60 - diff)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"กรุณารออีก {seconds_left} วินาทีจึงจะสามารถขอรหัส OTP ใหม่ได้"
            )

    # 2. ลบ OTP เก่าที่ยังไม่หมดอายุของ user คนนี้ก่อน (ถ้ามี)
    db.query(OTP).filter(
        OTP.user_id == user_id, 
        OTP.is_used == False, 
        OTP.expires_at > now
    ).delete()
    db.commit()

    # 3. สร้างรหัสใหม่
    otp_code = generate_otp_code()
    otp_record = OTP(user_id=user_id, otp_code=otp_code)
    otp_record.created_at = now # บันทึกเวลาที่สร้างจริง

    db.add(otp_record)
    db.commit()
    db.refresh(otp_record)
    return otp_record

def verify_otp(db: Session, user_id: uuid.UUID, otp_code: str) -> bool:
    otp_record = db.query(OTP).filter(
        OTP.user_id == user_id,
        OTP.otp_code == otp_code,
        OTP.is_used == False # ยังไม่ได้ใช้
    ).order_by(OTP.created_at.desc()).first() # เอา OTP ล่าสุด

    if not otp_record:
        return False

    if otp_record.is_expired():
        otp_record.is_used = True # ทำเครื่องหมายว่าหมดอายุแล้ว
        db.add(otp_record)
        db.commit()
        return False

    otp_record.is_used = True # ทำเครื่องหมายว่าใช้แล้ว
    db.add(otp_record)
    db.commit()
    return True