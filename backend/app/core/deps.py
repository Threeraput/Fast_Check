from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from typing import List
import uuid

# Import from your project's files
from app.database import get_db
from app.core.security import decode_access_token # ใช้เพื่อถอดรหัส token
from app.models.user import User
from app.models.role import Role
from app.models.association import user_roles # Import association table
from app.schemas.user_schema import TokenData # Pydantic schema สำหรับ token payload

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    """
    Dependency เพื่อดึงข้อมูลผู้ใช้จาก Access Token
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # ใช้ TokenData เพื่อตรวจสอบ payload จาก JWT โดยตรง
    payload = decode_access_token(token)
    if not payload:
        raise credentials_exception
    
    try:
        token_data = TokenData(**payload)
        user_id = token_data.user_id
    except (ValueError, KeyError, AttributeError):
        raise credentials_exception

    # ดึงข้อมูล User จากฐานข้อมูล
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise credentials_exception
    
    # แนบ role names เข้าไปใน user object โดยตรงเพื่อความสะดวก
    user.roles_list = token_data.roles
    
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    """
    Dependency เพื่อยืนยันว่าผู้ใช้ปัจจุบัน Active อยู่
    """
    if not current_user.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Inactive user")
    return current_user

async def get_current_admin_user(current_user: User = Depends(get_current_active_user)) -> User:
    """
    Dependency เพื่อยืนยันว่าผู้ใช้ปัจจุบันเป็น Admin
    """
    if "admin" not in current_user.roles_list:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions. Admin required."
        )
    return current_user

def role_required(required_roles: list[str]):
    """
    สร้าง Dependency ที่ตรวจสอบว่าผู้ใช้มี Role ที่จำเป็นหรือไม่
    """
    def decorator(current_user: User = Depends(get_current_active_user)):
        if not any(role_name in current_user.roles_list for role_name in required_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to perform this action"
            )
        return current_user
    return decorator