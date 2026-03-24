# backend/app/core/security.py
from datetime import datetime, timedelta, timezone
from typing import Optional
import uuid # เพิ่ม import นี้
from passlib.context import CryptContext
from jose import JWTError, jwt
from app.core.config import settings
from app.schemas.user_schema import TokenData # TokenData ย้ายมาที่ user_schema

# สำหรับ hashing รหัสผ่าน
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# สำหรับ JWT
SECRET_KEY = settings.SECRET_KEY # ดึงมาจาก config
ALGORITHM = settings.ALGORITHM # ดึงมาจาก config

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """ตรวจสอบว่ารหัสผ่านที่ใส่มาตรงกับรหัสผ่านที่ถูก hash ไว้หรือไม่"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Hash รหัสผ่านที่ใส่มา"""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """สร้าง JWT Access Token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload  
    except JWTError:
        return None