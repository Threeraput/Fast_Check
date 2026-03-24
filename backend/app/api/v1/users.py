# backend/app/api/v1/users.py

from fastapi import APIRouter, Depends, HTTPException, status, Path, UploadFile, File
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timezone
from uuid import UUID
import uuid

from app.database import get_db
from app.schemas.user_schema import UserResponse, TokenData, UserUpdate
from app.models.user import User
from app.services.db_service import get_user_by_id
from app.core.security import decode_access_token
from app.services.profile_service import save_user_avatar, delete_user_avatar

# OAuth2
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    # logic เดิม + รองรับ token_data เป็น dict/Pydantic
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    token_data = decode_access_token(token)
    if token_data is None:
        raise credentials_exception

    # รองรับทั้ง dict และ object (บางเคสอยู่ใน key 'sub')
    if isinstance(token_data, dict):
        uid = token_data.get("user_id") or token_data.get("sub")
    else:
        uid = getattr(token_data, "user_id", None) or getattr(token_data, "sub", None)

    if not uid:
        raise credentials_exception

    # แปลงเป็น UUID ถ้าเป็นสตริง
    try:
        user_id = UUID(str(uid))
    except Exception:
        raise credentials_exception

    user = get_user_by_id(db, user_id=user_id)
    if user is None:
        raise credentials_exception
    return user


async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Inactive user")
    return current_user


async def get_current_admin_user(current_user: User = Depends(get_current_active_user)) -> User:
    if "admin" not in [role.name for role in current_user.roles]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions. Admin required.",
        )
    return current_user


router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserResponse)
async def read_users_me(current_user: User = Depends(get_current_active_user)):
    _ = current_user.roles
    user_roles = [role.name for role in current_user.roles]
    return UserResponse(
        user_id=current_user.user_id,
        username=current_user.username,
        first_name=current_user.first_name,
        last_name=current_user.last_name,
        email=current_user.email,
        is_active=current_user.is_active,
        created_at=current_user.created_at,
        updated_at=current_user.updated_at,
        last_login_at=current_user.last_login_at,
        roles=user_roles,
        avatar_url=current_user.avatar_url,  # ✅ เพิ่ม
    )


@router.get("/{user_id}", response_model=UserResponse)
async def read_user_by_id(
    user_id: uuid.UUID = Path(..., description="The UUID of the user to retrieve"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    user = get_user_by_id(db, user_id=user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    _ = user.roles
    user_roles = [role.name for role in user.roles]
    return UserResponse(
        user_id=user.user_id,
        username=user.username,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        is_active=user.is_active,
        created_at=user.created_at,
        updated_at=user.updated_at,
        last_login_at=user.last_login_at,
        roles=user_roles,
        avatar_url=user.avatar_url,  # ✅ เพิ่ม
    )


@router.get("/", response_model=List[UserResponse])
async def read_all_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    users = db.query(User).all()
    response_users = []
    for user in users:
        _ = user.roles
        user_roles = [role.name for role in user.roles]
        response_users.append(
            UserResponse(
                user_id=user.user_id,
                username=user.username,
                first_name=user.first_name,
                last_name=user.last_name,
                email=user.email,
                is_active=user.is_active,
                created_at=user.created_at,
                updated_at=user.updated_at,
                last_login_at=user.last_login_at,
                roles=user_roles,
                avatar_url=user.avatar_url,  # ✅ เพิ่ม
            )
        )
    return response_users


@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_update: UserUpdate,
    user_id: uuid.UUID = Path(..., description="The UUID of the user to update"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    # อนุญาต: เจ้าของ หรือ admin
    if str(current_user.user_id) != str(user_id) and "admin" not in [r.name for r in current_user.roles]:
        raise HTTPException(status_code=403, detail="Not authorized to update this user's profile")

    db_user = get_user_by_id(db, user_id=user_id)
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    # ❌ บล็อกการแก้ email (คง logic เดิม + เพิ่ม guard)
    if hasattr(user_update, "email") and user_update.email is not None:
        raise HTTPException(status_code=400, detail="Email cannot be updated")

    # อัปเดตตามฟิลด์ที่อนุญาต (จาก UserUpdate)
    if user_update.username is not None:
        db_user.username = user_update.username
    if user_update.first_name is not None:
        db_user.first_name = user_update.first_name
    if user_update.last_name is not None:
        db_user.last_name = user_update.last_name
    if user_update.student_id is not None:
        db_user.student_id = user_update.student_id
    if user_update.teacher_id is not None:
        db_user.teacher_id = user_update.teacher_id
    if hasattr(user_update, "is_active") and user_update.is_active is not None:
        db_user.is_active = user_update.is_active

    db_user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(db_user)

    return UserResponse(
        user_id=db_user.user_id,
        username=db_user.username,
        first_name=db_user.first_name,
        last_name=db_user.last_name,
        email=db_user.email,
        is_active=db_user.is_active,
        created_at=db_user.created_at,
        updated_at=db_user.updated_at,
        last_login_at=db_user.last_login_at,
        roles=[r.name for r in db_user.roles],
        avatar_url=db_user.avatar_url,  # ✅ เพิ่ม
    )


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: uuid.UUID = Path(..., description="The UUID of the user to delete"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    db_user = get_user_by_id(db, user_id=user_id)
    if not db_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if str(db_user.user_id) == str(current_user.user_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete your own user account via this endpoint.",
        )

    db.delete(db_user)
    db.commit()
    # 204 No Content → ไม่ต้อง return body
    return


@router.post("/me/avatar", response_model=UserResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    content = await file.read()
    user = save_user_avatar(db, current_user, content)
    return UserResponse(
        user_id=user.user_id,
        username=user.username,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        is_active=user.is_active,
        created_at=user.created_at,
        updated_at=user.updated_at,
        last_login_at=user.last_login_at,
        roles=[r.name for r in user.roles],
        avatar_url=user.avatar_url,
    )


@router.delete("/me/avatar", response_model=UserResponse)
async def remove_avatar(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    user = delete_user_avatar(db, current_user)
    return UserResponse(
        user_id=user.user_id,
        username=user.username,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        is_active=user.is_active,
        created_at=user.created_at,
        updated_at=user.updated_at,
        last_login_at=user.last_login_at,
        roles=[r.name for r in user.roles],
        avatar_url=user.avatar_url,
    )
