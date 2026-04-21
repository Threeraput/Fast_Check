# backend/app/api/v1/sessions.py
from datetime import timedelta
import random
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
from app.core.scheduler import scheduler
from app.services.scheduler_tasks import (
    finalize_attendance_job,
    trigger_silent_check_job,
)

router = APIRouter(prefix="/sessions", tags=["Attendance Sessions"])


# ------------------------------------
# 1) POST /sessions/open (Teacher เท่านั้น)
# ------------------------------------
@router.post(
    "/open", response_model=SessionResponse, status_code=status.HTTP_201_CREATED
)
async def open_attendance_session(
    session_data: SessionOpenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if "teacher" not in [r.name for r in current_user.roles]:
        raise HTTPException(
            status_code=403, detail="Only teachers can open a check-in session."
        )

    # 1. สร้าง Session
    new_session = create_attendance_session(
        db=db, teacher_id=current_user.user_id, session_data=session_data
    )

    # ------------------------------------------------------------
    #  ส่วนที่เพิ่ม: จองคิวงานอัตโนมัติ
    # ------------------------------------------------------------

    # จองคิวเช็คบิลเมื่อถึงเวลา end_time
    scheduler.add_job(
        finalize_attendance_job,
        trigger="date",
        run_date=new_session.end_time,
        args=[new_session.session_id],
        id=f"finalize_{new_session.session_id}",
        replace_existing=True,
    )

    # สุ่มเวลาเพื่อส่งสัญญาณตรวจ (Silent Check)
    duration = (new_session.end_time - new_session.late_cutoff_time).total_seconds()

    # 2. เงื่อนไข: ถ้าเวลาระหว่าง late_cutoff_time ถึง end_time มากกว่า 10 วินาที ถึงจะทำการสุ่มตรวจ
    if duration > 10:
        # 3. ลด Buffer เหลือแค่ 10 วินาที (จากเดิม 60)
        offset = random.randint(10, int(duration) - 10)

        # 4. เวลาที่สุ่มได้ = late_cutoff_time + offset
        check_time = new_session.late_cutoff_time + timedelta(seconds=offset)

        # จองคิวงานสุ่มตรวจ (Print Log)
        scheduler.add_job(
            trigger_silent_check_job, 
            trigger="date",
            run_date=check_time,
            args=[new_session.session_id], 
            id=f"silent_push_{new_session.session_id}",
            replace_existing=True,
        )

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
