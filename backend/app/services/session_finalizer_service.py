# app/services/session_finalizer_service.py
from datetime import datetime, timezone
from typing import Union
from uuid import UUID

import logging
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.models.attendance_session import AttendanceSession
from app.models.attendance import Attendance
from app.models.user import User
from app.models.association import class_students  # << ใช้ association table แทน ClassroomMember
from app.models.attendance_enums import AttendanceStatus  # ใช้ enum ให้ตรง DB

logger = logging.getLogger(__name__)


def handle_finalize_session(db: Session, session_id: Union[UUID, str]) -> int:
    """
    ปิด session ที่หมดเวลา + เติม 'Absent' ให้นักเรียนที่ยังไม่มี record ใน session นั้น
    คืนค่า: จำนวนเรคคอร์ดที่ถูกสร้างขึ้น (จำนวน absent ที่เติม)
    """
    # 1) หา session
    session = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.session_id == session_id)
        .first()
    )
    if not session:
        raise ValueError("Session not found")

    # 2) ถ้าปิดไปแล้ว ข้ามได้
    if not session.is_active:
        logger.info(f"Session {session_id} already finalized")
        return 0

    # 3) ปิด session
    session.is_active = False
    session.closed_at = datetime.now(timezone.utc)
    db.add(session)
    db.commit()  # แยก commit เพื่อให้สถานะ session ชัดเจน

    # 4) ดึงเฉพาะ student ของคลาสนี้ จาก association table + กรอง role
    student_ids = db.execute(
        select(User.user_id)
        .select_from(
            class_students.join(
                User, User.user_id == class_students.c.student_id
            )
        )
        .where(
            class_students.c.class_id == session.class_id,
            User.role == "student",
        )
    ).scalars().all()

    created = 0

    # 5) สำหรับนักเรียนแต่ละคน ถ้ายังไม่มี Attendance ใน session นี้ → เติม Absent
    for sid in student_ids:
        exists = (
            db.query(Attendance)
            .filter(
                Attendance.session_id == session.session_id,
                Attendance.student_id == sid,
            )
            .first()
        )
        if exists:
            continue

        db.add(
            Attendance(
                session_id=session.session_id,
                class_id=session.class_id,
                student_id=sid,
                # ใช้ค่าที่ตรงกับ enum ใน DB (เช่น "Absent")
                status=AttendanceStatus.ABSENT.value,
                # ไม่ต้องตั้ง check_in_time (ปล่อยให้เป็น NULL/ไม่กำหนด)
                is_reverified=False,
            )
        )
        created += 1

    db.commit()
    logger.info(f"Finalized {session.session_id}: added {created} absent records.")

    return created
