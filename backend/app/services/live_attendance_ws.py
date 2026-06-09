import asyncio
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any

from fastapi import WebSocket
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.models.association import class_students
from app.models.attendance import Attendance
from app.models.attendance_session import AttendanceSession
from app.models.class_model import Class


class LiveAttendanceWSManager:
    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, session_key: str, websocket: WebSocket) -> None:
        async with self._lock:
            self._rooms[session_key].add(websocket)

    async def disconnect(self, session_key: str, websocket: WebSocket) -> None:
        async with self._lock:
            clients = self._rooms.get(session_key)
            if not clients:
                return
            clients.discard(websocket)
            if not clients:
                self._rooms.pop(session_key, None)

    async def broadcast(self, session_key: str, payload: dict[str, Any]) -> None:
        async with self._lock:
            clients = list(self._rooms.get(session_key, set()))

        dead: list[WebSocket] = []
        for ws in clients:
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)

        if dead:
            async with self._lock:
                current = self._rooms.get(session_key, set())
                for ws in dead:
                    current.discard(ws)
                if not current and session_key in self._rooms:
                    self._rooms.pop(session_key, None)


live_attendance_ws_manager = LiveAttendanceWSManager()


def _status_text(v: Any) -> str:
    if hasattr(v, "value"):
        return str(v.value)
    if v is None:
        return "Unknown"
    return str(v)


def _student_name(att: Attendance) -> str:
    student = getattr(att, "student", None)
    if not student:
        return "Unknown Student"

    fn = (getattr(student, "first_name", "") or "").strip()
    ln = (getattr(student, "last_name", "") or "").strip()
    full = f"{fn} {ln}".strip()
    if full:
        return full

    username = (getattr(student, "username", "") or "").strip()
    if username:
        return username

    email = (getattr(student, "email", "") or "").strip()
    if email:
        return email

    return "Unknown Student"


def _to_item(att: Attendance) -> dict[str, Any]:
    status = _status_text(att.status)
    check_in_time = att.check_in_time

    return {
        "attendance_id": str(att.attendance_id),
        "student_id": str(att.student_id),
        "student_name": _student_name(att),
        "status": status,
        "check_in_time": check_in_time.isoformat() if check_in_time else None,
        "face_image_path": att.face_image_path,
        "is_manual_override": getattr(att, "is_manual_override", False),
    }


def get_live_session_payload(db: Session, session_id: uuid.UUID | str) -> dict[str, Any] | None:
    if isinstance(session_id, str):
        try:
            session_id = uuid.UUID(session_id)
        except ValueError:
            return None

    session = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.session_id == session_id)
        .first()
    )
    if not session:
        return None

    total_students = (
        db.query(func.count())
        .select_from(class_students)
        .filter(class_students.c.class_id == session.class_id)
        .scalar()
        or 0
    )

    records = (
        db.query(Attendance)
        .options(joinedload(Attendance.student))
        .filter(Attendance.session_id == session_id)
        .order_by(Attendance.check_in_time.desc())
        .all()
    )

    present_count = 0
    late_count = 0
    unverified_count = 0
    for rec in records:
        status = _status_text(rec.status).strip().lower().replace(" ", "_")
        if status == "present":
            present_count += 1
        elif status == "late":
            late_count += 1
        elif status in {"unverified_face", "manual_override"}:
            unverified_count += 1

    checked_in_count = len(records)
    waiting_count = max(int(total_students) - checked_in_count, 0)

    return {
        "session_id": str(session.session_id),
        "class_id": str(session.class_id),
        "class_name": (
            db.query(Class.name)
            .filter(Class.class_id == session.class_id)
            .scalar()
        )
        or "Unknown Class",
        "start_time": session.start_time.isoformat() if session.start_time else None,
        "end_time": session.end_time.isoformat() if session.end_time else None,
        "total_students": int(total_students),
        "checked_in_count": checked_in_count,
        "waiting_count": waiting_count,
        "summary": {
            "present": present_count,
            "late": late_count,
            "unverified": unverified_count,
            "waiting": waiting_count,
        },
        "attendees": [_to_item(r) for r in records],
        "server_time": datetime.now(timezone.utc).isoformat(),
    }
