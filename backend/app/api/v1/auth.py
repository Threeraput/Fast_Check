# backend/app/api/v1/auth.py
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import datetime, timezone, timedelta
import uuid
from typing import Optional
from app.core.config import settings
from app.database import get_db
from app.schemas.user_schema import (
    UserCreate,
    UserResponse,
    Token,
)
from app.schemas.otp_schema import (
    OTPRequest,
    OTPVerification,
    PasswordResetRequest
)
from app.models.user import User
from app.models.role import Role # <-- เพิ่มการ import Role Model
from app.models.association import user_roles # <-- แก้ไขการ import ให้ใช้ user_roles (Table object)
from app.services.db_service import get_user_by_email, get_user_by_username ,  create_user , assign_role_to_user
from app.core.security import get_password_hash, verify_password, create_access_token
# นำเข้า Service ใหม่สำหรับ OTP และ Email
from app.services.otp_service import create_otp, verify_otp, get_user_by_email_or_username_for_otp
from app.services.email_service import send_email

router = APIRouter(prefix="/auth", tags=["Authentication"])

logger = logging.getLogger(__name__)

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register_user(user_create: UserCreate, db: Session = Depends(get_db)):
    db_user_by_username = get_user_by_username(db, username=user_create.username)
    if db_user_by_username:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already registered")

    if user_create.email:
        db_user_by_email = get_user_by_email(db, email=user_create.email)
        if db_user_by_email:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    hashed_password = get_password_hash(user_create.password)

    # --- Logic is_approved ตาม role ---
    is_approved_status = True
    if user_create.role == "teacher":
        is_approved_status = False

    #  user_data สำหรับ User ไม่ใส่ role
    user_data = {
        "username": user_create.username,
        "password_hash": hashed_password,
        "first_name": user_create.first_name,
        "last_name": user_create.last_name,
        "email": user_create.email,
        "student_id": user_create.student_id,
        "teacher_id": user_create.teacher_id,
        "is_active": False,
        "is_approved": is_approved_status,
        "role": user_create.role
    }

    try:
        # สร้าง user (generate student_id/teacher_id จะทำงานใน create_user)
        new_user = create_user(db, user_data)

        # assign role แยกออกมา
        assign_role_to_user(db, new_user, user_create.role)
        db.commit()
        db.refresh(new_user)

        # สร้าง OTP + ส่งอีเมล
        otp_record = create_otp(db, new_user.user_id)
        otp_sent = await send_email(
            recipients=[new_user.email],
            subject="ยืนยันอีเมลสำหรับบัญชีของคุณ",
            body=f"รหัส OTP ของคุณคือ: {otp_record.otp_code}\nรหัสนี้จะหมดอายุภายใน {settings.OTP_EXPIRE_MINUTES} นาที"
        )
        if not otp_sent:
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send OTP email. Please try again or contact support."
            )

        return UserResponse(
            user_id=new_user.user_id,
            username=new_user.username,
            first_name=new_user.first_name,
            last_name=new_user.last_name,
            email=new_user.email,
            is_active=new_user.is_active,
            is_approved=new_user.is_approved,
            created_at=new_user.created_at,
            updated_at=new_user.updated_at,
            last_login_at=new_user.last_login_at,
            roles=[user_create.role]
        )

    except Exception as e:
        db.rollback()
        logger.error(f"Failed to register user due to unexpected error: {e}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="An unexpected error occurred during registration. Please try again.")


@router.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    user = get_user_by_email(db, email=form_data.username)
    if not user:
        user = get_user_by_username(db, username=form_data.username)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or username",
                headers={"WWW-Authenticate": "Bearer"},
            )

    if not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account not activated. Please verify your email with OTP."
        )

    # --- ปรับปรุง: เพิ่มการตรวจสอบ is_approved สำหรับ Teacher ---
    if "teacher" in [role.name for role in user.roles] and not user.is_approved:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teacher account is pending approval by an administrator."
        )
    # ----------------------------------------------------

    user_roles = [role.name for role in user.roles]

    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"user_id": str(user.user_id), "roles": user_roles},
        expires_delta=access_token_expires
    )

    user.last_login_at = datetime.now(timezone.utc)
    db.add(user)
    db.commit()
    db.refresh(user)

    user_response_data = UserResponse(
        user_id=user.user_id,
        username=user.username,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        is_active=user.is_active,
        is_approved=user.is_approved, # <--- ส่งค่า is_approved กลับไปด้วย
        created_at=user.created_at,
        updated_at=user.updated_at,
        last_login_at=user.last_login_at,
        roles = user_roles
    )

    return Token(access_token=access_token, token_type="bearer", user=user_response_data)

# --- Endpoint ใหม่สำหรับ OTP และ Password Reset ---
# (โค้ดส่วนนี้ถูกต้องแล้ว ไม่ต้องแก้ไข)
@router.post("/request-otp", status_code=status.HTTP_200_OK)
async def request_otp_for_action(otp_request: OTPRequest, db: Session = Depends(get_db)):
    """
    ขอ OTP สำหรับการยืนยันตัวตน (เช่น การ Activate บัญชี หรือรีเซ็ตรหัสผ่าน)
    """
    user = get_user_by_email_or_username_for_otp(db, email_or_username=otp_request.email)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    otp_record = create_otp(db, user.user_id)
    otp_sent = await send_email(
        recipients=[user.email],
        subject="รหัส OTP ของคุณ",
        body=f"รหัส OTP ของคุณคือ: {otp_record.otp_code}\nรหัสนี้จะหมดอายุภายใน {settings.OTP_EXPIRE_MINUTES} นาที"
    )
    if not otp_sent:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to send OTP email.")

    return {"message": "OTP sent successfully to your email."}

@router.post("/verify-otp", status_code=status.HTTP_200_OK)
async def verify_otp_and_activate_account(otp_verification: OTPVerification, db: Session = Depends(get_db)):
    """
    ตรวจสอบ OTP และ Activate บัญชีผู้ใช้
    """
    user = get_user_by_email_or_username_for_otp(db, email_or_username=otp_verification.email)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    is_valid_otp = verify_otp(db, user.user_id, otp_verification.otp_code)
    if not is_valid_otp:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP.")

    if user.is_active:
        return {"message": "Account is already active."}

    user.is_active = True
    user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)

    return {"message": "Account activated successfully."}

@router.post("/reset-password", status_code=status.HTTP_200_OK)
async def reset_password_with_otp(reset_request: PasswordResetRequest, db: Session = Depends(get_db)):
    """
    รีเซ็ตรหัสผ่านของผู้ใช้หลังจากยืนยัน OTP แล้ว
    """
    user = get_user_by_email_or_username_for_otp(db, email_or_username=reset_request.email)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    is_valid_otp = verify_otp(db, user.user_id, reset_request.otp_code)
    if not is_valid_otp:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP.")

    if not reset_request.new_password:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="New password cannot be empty.")

    user.password_hash = get_password_hash(reset_request.new_password)
    user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)

    return {"message": "Password has been reset successfully."}