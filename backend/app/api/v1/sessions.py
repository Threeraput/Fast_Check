# backend/app/api/v1/sessions.py
import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.schemas.session_schema import SessionOpenRequest, SessionResponse
from app.core.deps import get_current_user
from app.services.attendance_session_service import (
    create_attendance_session,
    get_active_sessions as service_get_active_sessions,  
)

router = APIRouter(prefix="/sessions", tags=["Attendance Sessions"])

# ------------------------------------
# 1) POST /sessions/open (Teacher เท่านั้น)
# ------------------------------------
@router.post("/open", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def open_attendance_session(
    session_data: SessionOpenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if "teacher" not in [r.name for r in current_user.roles]:
        raise HTTPException(status_code=403, detail="Only teachers can open a check-in session.")
    new_session = create_attendance_session(db=db, teacher_id=current_user.user_id, session_data=session_data)
    return new_session
# ------------------------------------
# 2) GET /sessions/active (ดู Session ที่ยังไม่หมดอายุ)
# ------------------------------------
@router.get("/active", response_model=List[SessionResponse])
async def list_active_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # ดึง sessions ที่ยัง active จาก service
    sessions = service_get_active_sessions(db)

    # (ถ้าต้องการกรองเฉพาะคลาสที่นักเรียนลงทะเบียน ค่อยเพิ่ม logic ที่นี่)

    #  แปลงเป็น Pydantic list
    items: List[SessionResponse] = []
    for s in sessions:
        try:
            items.append(SessionResponse.model_validate(s, from_attributes=True))
        except Exception:
            items.append(SessionResponse.from_orm(s))
    return items
