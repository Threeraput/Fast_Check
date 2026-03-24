from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user_schema import UserUpdate
from datetime import datetime, timezone
from fastapi import HTTPException, status 

# วันนี้เพิ่มไฟล์ตรงนี้ GuyKm
def get_user_by_id(db: Session, user_id: str):
    """
    ดึงข้อมูลผู้ใช้จาก user_id
    """
    user = db.query(User).filter(User.user_id == user_id).first()
    return user


def update_user_profile(db: Session, user_id: str, user_update: UserUpdate):
    """
    อัปเดตข้อมูลโปรไฟล์ของผู้ใช้
    """
    db_user = get_user_by_id(db, user_id)
    if not db_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # อัปเดตฟิลด์ตามข้อมูลที่ได้รับจาก user_update
    if user_update.username is not None:
        db_user.username = user_update.username
    if user_update.first_name is not None:
        db_user.first_name = user_update.first_name
    if user_update.last_name is not None:
        db_user.last_name = user_update.last_name
    if user_update.email is not None:
        db_user.email = user_update.email
    if user_update.student_id is not None:
        db_user.student_id = user_update.student_id
    if user_update.teacher_id is not None:
        db_user.teacher_id = user_update.teacher_id
    if user_update.is_active is not None:
        db_user.is_active = user_update.is_active

    db_user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(db_user)
    return db_user
