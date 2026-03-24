# backend/app/core/config.py
import os
from dotenv import load_dotenv
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

load_dotenv() # โหลด environment variables จาก .env

class Settings(BaseSettings):
    # Core Database Setting
    DATABASE_URL: str

    # JWT Authentication Settings
    SECRET_KEY: str
    ALGORITHM: str = "HS256" # ค่าเริ่มต้นถ้าไม่ระบุใน .env
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30 # ค่าเริ่มต้นถ้าไม่ระบุใน .env

    # S3/Cloud Storage Settings (Optional)
    AWS_ACCESS_KEY_ID: Optional[str] = None
    AWS_SECRET_ACCESS_KEY: Optional[str] = None
    AWS_REGION: str = "us-east-1"
    S3_BUCKET_NAME: str = "your-default-bucket-name"

     # Email settings
    MAIL_USERNAME: str
    MAIL_PASSWORD: str
    MAIL_FROM: str
    MAIL_PORT: int
    MAIL_SERVER: str
    MAIL_STARTTLS: bool 
    MAIL_SSL_TLS: bool  
    MAIL_USE_CREDENTIALS: bool

    # For OTP generation
    OTP_LENGTH: int = 6 # เช่น 6 หลัก
    OTP_EXPIRE_MINUTES: int = 5 # OTP หมดอายุใน 5 นาที

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()