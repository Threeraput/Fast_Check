# app/services/attendance_report_service.py
from sqlalchemy.orm import Session
from sqlalchemy import select
from datetime import datetime, timezone
from app.models.attendance import Attendance
from app.models.attendance_session import AttendanceSession
from app.models.attendance_report import AttendanceReport
from app.models.attendance_report_detail import AttendanceReportDetail
from app.models.association import class_students


def generate_reports_for_class(db: Session, class_id: str):
    now = datetime.now(timezone.utc)

    # 1. ดึงข้อมูลนักเรียนพร้อมวันเข้าคลาส
    student_data = db.execute(
        select(class_students.c.student_id, class_students.c.joined_at).where(
            class_students.c.class_id == class_id
        )
    ).all()

    if not student_data:
        return {"message": f"❌ No students found in class {class_id}"}

    # 2. ดึง sessions ที่จบลงแล้ว
    all_past_sessions = (
        db.query(AttendanceSession)
        .filter(
            AttendanceSession.class_id == class_id, AttendanceSession.end_time <= now
        )
        .order_by(AttendanceSession.start_time.asc())
        .all()
    )

    for student_id, joined_at in student_data:
        effective_sessions = [
            s
            for s in all_past_sessions
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

            status = "Absent"
            check_in_time = None
            is_reverified = False
            current_face_path = None  # ✅ เตรียมเก็บ path รูป

            if not record:
                absent += 1
            else:
                check_in_time = record.check_in_time
                is_reverified = record.is_reverified
                current_face_path = (
                    record.face_image_path
                )  # ✅ ดึง path รูปจาก Attendance

                if not record.is_reverified:
                    status = "LeftEarly"
                    left_early += 1
                else:
                    # ดึงค่าจาก Enum หรือ String
                    status = (
                        record.status.value
                        if hasattr(record.status, "value")
                        else str(record.status)
                    )
                    if status == "Present":
                        attended += 1
                    elif status == "Late":
                        late += 1
                    elif status == "Absent":
                        absent += 1

                if record.is_reverified:
                    reverified += 1

            # ✅ บันทึกรายละเอียดพร้อมเวลาเริ่มคาบและรูปถ่าย
            db.add(
                AttendanceReportDetail(
                    report_id=report.report_id,
                    session_id=session.session_id,
                    status=status,
                    check_in_time=check_in_time,
                    is_reverified=is_reverified,
                    session_start=session.start_time,  # ✅ ใส่เวลาเริ่มคาบเรียน
                    face_image_path=current_face_path,  # ✅ ใส่ path รูปถ่าย
                )
            )

        report.total_sessions = total_effective
        report.attended_sessions = attended
        report.late_sessions = late
        report.absent_sessions = absent
        report.left_early_sessions = left_early
        report.reverified_sessions = reverified
        report.generated_at = now

        if total_effective > 0:
            rate = ((attended + late) / total_effective) * 100
            report.attendance_rate = round(rate, 2)
        else:
            report.attendance_rate = 0.0

    db.commit()
    return {"message": f"✅ Updated reports for {len(student_data)} students."}
