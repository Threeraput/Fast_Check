# backend/app/api/v1/sessions.py
from datetime import datetime, timedelta, timezone
import random
import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.attendance_session import AttendanceSession # เพิ่มบรรทัดนี้
from app.schemas.session_schema import SessionOpenRequest, SessionResponse
from app.core.deps import get_current_user
from app.services.attendance_session_service import (
    create_attendance_session,
    get_active_sessions as service_get_active_sessions,
)
from app.core.scheduler import scheduler
from app.services.scheduler_tasks import (
    close_checkin_job,
    finalize_attendance_job,
    trigger_silent_check_job,
)

NETWORK_GRACE_SECONDS = 30
SHORT_SESSION_MAX_MINUTES = 10
SHORT_SESSION_RANDOM_MIN_MINUTES = 1
SHORT_SESSION_RANDOM_MAX_MINUTES = 2
LONG_SESSION_RANDOM_MIN_MINUTES = 15
LONG_SESSION_RANDOM_MAX_MINUTES = 30

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
    # จองคิวงานอัตโนมัติ: สุ่ม silent check หลัง end_time
    # ------------------------------------------------------------
    start_time = new_session.start_time
    end_time = new_session.end_time
    session_duration_seconds = max((end_time - start_time).total_seconds(), 0.0)
    session_duration_minutes = session_duration_seconds / 60.0

    if session_duration_seconds <= 0:
        random_offset_minutes = LONG_SESSION_RANDOM_MIN_MINUTES
        print(
            f"[⌛SCHEDULER] Invalid session duration for {new_session.session_id}. "
            f"🔙Fallback offset={random_offset_minutes} minutes after end_time."
        )
    elif session_duration_minutes <= SHORT_SESSION_MAX_MINUTES:
        random_offset_minutes = random.randint(
            SHORT_SESSION_RANDOM_MIN_MINUTES,
            SHORT_SESSION_RANDOM_MAX_MINUTES,
        )
    else:
        random_offset_minutes = random.randint(
            LONG_SESSION_RANDOM_MIN_MINUTES,
            LONG_SESSION_RANDOM_MAX_MINUTES,
        )

    check_time = end_time + timedelta(minutes=random_offset_minutes)
    finalize_time = check_time + timedelta(seconds=NETWORK_GRACE_SECONDS)

    scheduler.add_job(
        close_checkin_job,
        trigger="date",
        run_date=end_time,
        args=[new_session.session_id],
        id=f"close_checkin_{new_session.session_id}",
        replace_existing=True,
    )

    scheduler.add_job(
        trigger_silent_check_job,
        trigger="date",
        run_date=check_time,
        args=[new_session.session_id],
        id=f"silent_push_{new_session.session_id}",
        replace_existing=True,
    )

    scheduler.add_job(
        finalize_attendance_job,
        trigger="date",
        run_date=finalize_time,
        args=[new_session.session_id],
        id=f"finalize_{new_session.session_id}",
        replace_existing=True,
    )

    new_session.silent_check_scheduled_at = check_time
    db.commit()
    db.refresh(new_session)

    print("\n" + "=" * 72)
    print("[⌛SILENT CHECK SCHEDULED]")
    print(f"Session ID              : {new_session.session_id}")
    print(f"Start Time (UTC)        : {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"End Time (UTC)          : {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Session Duration        : {session_duration_minutes:.2f} minutes")
    print(f"Random Offset After End : {random_offset_minutes} minutes")
    print(f"Silent Check Time (UTC) : {check_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(
        f"Finalize Time (UTC)     : {finalize_time.strftime('%Y-%m-%d %H:%M:%S')} "
        f"(includes {NETWORK_GRACE_SECONDS}s network grace)"
    )
    print("=" * 72 + "\n")

    return new_session


# ------------------------------------
# 2) GET /sessions/active (ดู Session ที่ยังไม่หมดอายุ)
# ------------------------------------
@router.get("/active", response_model=List[SessionResponse])
async def list_active_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)

    # เช็คว่าเป็นอาจารย์หรือแอดมินไหม
    is_privileged = any(r.name in ["admin", "teacher"] for r in current_user.roles)

    if is_privileged:
        # ครูเห็น: 
        # 1. อันที่กำลังเปิดอยู่ (end_time >= now)
        # 2. อันที่จบไปแล้ว แต่เพิ่งทำ Silent Check ไปไม่เกิน 10 นาที
        sessions = (
            db.query(AttendanceSession)
            .filter(
                (AttendanceSession.end_time >= now) | 
                (
                    (AttendanceSession.silent_check_scheduled_at.isnot(None)) & 
                    (AttendanceSession.silent_check_scheduled_at >= now - timedelta(minutes=10))
                )
            )
            .order_by(AttendanceSession.start_time.desc())
            .all()
        )
    else:
        # นักเรียนเห็น: เฉพาะอันที่กำลังเปิดอยู่เท่านั้น
        sessions = (
            db.query(AttendanceSession)
            .filter(AttendanceSession.start_time <= now, AttendanceSession.end_time >= now)
            .order_by(AttendanceSession.start_time.desc())
            .all()
        )

    #  แปลงเป็น Pydantic list
    items: List[SessionResponse] = []
    for s in sessions:
        try:
            items.append(SessionResponse.model_validate(s, from_attributes=True))
        except Exception:
            items.append(SessionResponse.from_orm(s))
    return items
