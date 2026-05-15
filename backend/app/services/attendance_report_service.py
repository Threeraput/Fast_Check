# app/services/attendance_report_service.py
from sqlalchemy.orm import Session
from sqlalchemy import select
from datetime import datetime, timezone
from app.models.attendance import Attendance
from app.models.attendance_session import AttendanceSession
from app.models.attendance_report import AttendanceReport
from app.models.attendance_report_detail import AttendanceReportDetail
from app.models.association import class_students
from app.models.attendance_enums import AttendanceStatus


def _to_report_status(raw_status: str) -> str:
    """Map attendance status to values accepted by reportstatus enum."""
    mapping = {
        AttendanceStatus.PRESENT.value: "Present",
        AttendanceStatus.LATE.value: "Late",
        AttendanceStatus.ABSENT.value: "Absent",
        AttendanceStatus.LEFT_EARLY.value: "LeftEarly",
        AttendanceStatus.UNVERIFIED_FACE.value: "Absent",
        AttendanceStatus.MANUAL_OVERRIDE.value: "Present",
    }
    return mapping.get(raw_status, "Absent")


def generate_reports_for_class(db: Session, class_id: str):
    now = datetime.now(timezone.utc)

    # 1. ดึงข้อมูลนักเรียนปัจจุบันในคลาสเท่านั้น
    student_data = db.query(
        class_students.c.student_id, 
        class_students.c.joined_at
    ).filter(class_students.c.class_id == class_id).all()

    if not student_data:
        return {"message": f"❌ No students found in class {class_id}"}

    # 2. ดึง sessions ที่เกิดขึ้นแล้ว
    all_past_sessions = (
        db.query(AttendanceSession)
        .filter(
            AttendanceSession.class_id == class_id, 
            AttendanceSession.start_time <= now # เอาคาบที่เริ่มแล้วมาคิดได้เลย ไม่ต้องรอจบ
        )
        .order_by(AttendanceSession.start_time.asc())
        .all()
    )

    for student_id, joined_at in student_data:
        # คำนวณเฉพาะคนนี้
        _calculate_and_save_student_report(db, class_id, student_id, joined_at, all_past_sessions, now)

    db.commit()
    return {"message": f"✅ Updated reports for {len(student_data)} students."}


def sync_student_report_for_session(db: Session, class_id: str, student_id: str):
    """
    ฟังก์ชันสำหรับอัปเดตรายงานของนักเรียนคนเดียว (Real-time Sync)
    เรียกใช้เมื่อนักเรียนเช็คชื่อสำเร็จ
    """
    now = datetime.now(timezone.utc)
    
    # ดึงข้อมูลการเข้าเรียนของนักเรียนคนนี้ในคลาสนี้
    member = db.query(class_students).filter(
        class_students.c.class_id == class_id,
        class_students.c.student_id == student_id
    ).first()
    
    if not member:
        return

    all_past_sessions = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.class_id == class_id, AttendanceSession.start_time <= now)
        .order_by(AttendanceSession.start_time.asc())
        .all()
    )

    _calculate_and_save_student_report(db, class_id, student_id, member.joined_at, all_past_sessions, now)
    db.commit()


def _calculate_and_save_student_report(db, class_id, student_id, joined_at, sessions, now):
    """Logic หลักในการคำนวณรายงานรายบุคคล"""
    effective_sessions = [
        s for s in sessions 
        if joined_at is None or s.start_time >= joined_at
    ]

    total_effective = len(effective_sessions)
    attended = late = absent = left_early = reverified = 0

    report = (
        db.query(AttendanceReport)
        .filter(
            AttendanceReport.class_id == class_id,
            AttendanceReport.student_id == student_id,
        )
        .first()
    )

    if not report:
        report = AttendanceReport(class_id=class_id, student_id=student_id)
        db.add(report)
        db.flush()

    # ลบ Detail เก่าเฉพาะของคนนี้ (เพื่อความถูกต้องแม่นยำ)
    db.query(AttendanceReportDetail).filter(
        AttendanceReportDetail.report_id == report.report_id
    ).delete()

    for session in effective_sessions:
        record = (
            db.query(Attendance)
            .filter(
                Attendance.session_id == session.session_id,
                Attendance.student_id == student_id,
            )
            .first()
        )

        status = AttendanceStatus.ABSENT.value
        check_in_time = None
        is_reverified = False
        current_face_path = None
        current_reverify_time = None
        current_reverify_path = None

        if not record:
            absent += 1
        else:
            check_in_time = record.check_in_time
            is_reverified = record.is_reverified
            current_face_path = record.face_image_path
            current_reverify_time = getattr(record, "reverify_time", None)
            current_reverify_path = getattr(record, "reverify_image_path", None)

            status = record.status.value if hasattr(record.status, "value") else str(record.status)

            if status == AttendanceStatus.PRESENT.value: attended += 1
            elif status == AttendanceStatus.LATE.value: late += 1
            elif status == AttendanceStatus.ABSENT.value: absent += 1
            elif status == AttendanceStatus.LEFT_EARLY.value: left_early += 1

            if record.is_reverified: reverified += 1

        report_status = _to_report_status(status)

        db.add(
            AttendanceReportDetail(
                report_id=report.report_id,
                session_id=session.session_id,
                status=report_status,
                check_in_time=check_in_time,
                is_reverified=is_reverified,
                session_start=session.start_time,
                face_image_path=current_face_path,
                reverify_time=current_reverify_time,
                reverify_image_path=current_reverify_path,
                created_at=now,
            )
        )

    # สรุปยอด
    report.total_sessions = total_effective
    report.attended_sessions = attended
    report.late_sessions = late
    report.absent_sessions = absent
    report.left_early_sessions = left_early
    report.reverified_sessions = reverified
    report.generated_at = now
    if effective_sessions:
        report.last_session_time = effective_sessions[-1].start_time
    
    if total_effective > 0:
        report.attendance_rate = round(((attended + late) / total_effective) * 100, 2)
    else:
        report.attendance_rate = 0.0

    db.commit()
    return {"message": f"✅ Updated report for student {student_id}."}
