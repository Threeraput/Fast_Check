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
from app.models.association import class_students
from app.models.attendance_enums import AttendanceStatus

logger = logging.getLogger(__name__)


def handle_finalize_session(db: Session, session_id: Union[UUID, str]) -> int:
    """
    ปิด session ที่หมดเวลา + เติม 'Absent' ให้นักเรียนที่ยังไม่มี record ใน session นั้น
    โดยจะไม่เติมให้นักเรียนที่เพิ่งเข้าคลาสหลังจากที่ session นั้นเริ่มไปแล้ว
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
    db.commit()

    # 4) ดึง student_id พร้อมกับ joined_at เพื่อตรวจสอบสิทธิ์ในการเช็คชื่อ
    # กรองเฉพาะคนที่มีสถานะเป็น student ในคลาสนั้น
    student_data = db.execute(
        select(User.user_id, class_students.c.joined_at)
        .select_from(
            class_students.join(User, User.user_id == class_students.c.student_id)
        )
        .where(class_students.c.class_id == session.class_id)
    ).all()

    created = 0

    # 5) ตรวจสอบนักเรียนแต่ละคน
    for sid, joined_at in student_data:

        # --- [Logic สำหรับนักเรียนใหม่] ---
        # ถ้า Session เริ่มต้นก่อนที่นักเรียนจะเข้าคลาส (joined_at)
        # จะไม่ถือว่าเขาขาดเรียนในคาบนั้น ให้ข้ามไป
        if joined_at and session.start_time < joined_at:
            logger.info(f"Skipping student {sid}: joined class after session start.")
            continue
        # -------------------------------

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

        # บันทึกสถานะ Absent สำหรับคนที่ควรจะเข้าเรียนแต่ไม่ได้เช็คชื่อ
        db.add(
            Attendance(
                session_id=session.session_id,
                class_id=session.class_id,
                student_id=sid,
                status=AttendanceStatus.ABSENT.value,  # ใช้ค่าจาก Enum
                is_reverified=False,
            )
        )
        created += 1

    db.commit()
    logger.info(f"Finalized {session.session_id}: added {created} absent records.")

    return created
