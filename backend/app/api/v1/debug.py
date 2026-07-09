from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from typing import Optional
from app.database import get_db

router = APIRouter(prefix="/debug", tags=["Debug"])


@router.get("/silent-check")
def debug_silent_check(student_id: str, session_id: Optional[str] = None, db=Depends(get_db)):
    """Return attendance, fcm_token, session and student_locations for diagnosis."""
    try:
        res = {}

        # attendances
        att_q = text(
            "SELECT session_id, check_in_time, status, last_verified_at FROM attendances WHERE student_id = :student_id ORDER BY check_in_time DESC LIMIT 20"
        )
        atts = db.execute(att_q, {"student_id": student_id}).fetchall()
        res["attendances"] = [dict(r) for r in atts]

        if session_id is None and res["attendances"]:
            session_id = res["attendances"][0].get("session_id")

        # user token
        user_q = text("SELECT user_id, fcm_token, last__at FROM users WHERE user_id = :student_id")
        u = db.execute(user_q, {"student_id": student_id}).first()
        res["user"] = dict(u) if u else None

        # session
        if session_id:
            sess_q = text(
                "SELECT session_id, class_id, end_time, silent_check_scheduled_at FROM attendance_sessions WHERE session_id = :session_id"
            )
            s = db.execute(sess_q, {"session_id": session_id}).first()
            res["session"] = dict(s) if s else None

            loc_q = text(
                "SELECT id, session_id, student_id, is_silent_check, timestamp, server_received_at, verification_result, distance_m, radius_m FROM student_locations WHERE student_id = :student_id AND session_id = :session_id ORDER BY server_received_at DESC NULLS LAST, timestamp DESC LIMIT 100"
            )
            locs = db.execute(loc_q, {"student_id": student_id, "session_id": session_id}).fetchall()
            res["student_locations"] = [dict(r) for r in locs]
        else:
            res["session"] = None
            res["student_locations"] = []

        return res
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
