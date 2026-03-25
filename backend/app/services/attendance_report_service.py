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
    """
    สร้าง/อัปเดตรายงานรายคน (Upsert) โดยคำนึงถึงวันเข้าเรียน (joined_at)
    และนับเฉพาะ session ที่จบแล้วเท่านั้น
    """
    now = datetime.now(timezone.utc)

    # 1. ดึงข้อมูลนักเรียนพร้อมวันเข้าคลาส (joined_at)
    student_data = db.execute(
        select(class_students.c.student_id, class_students.c.joined_at).where(
            class_students.c.class_id == class_id
        )
    ).all()

    if not student_data:
        return {"message": f"❌ No students found in class {class_id}"}

    # 2. ดึง sessions ทั้งหมดที่ 'จบลงแล้ว' (end_time <= now)
    # เพื่อไม่ให้นับคาบในอนาคตมาหักคะแนนเด็ก
    all_past_sessions = (
        db.query(AttendanceSession)
        .filter(
            AttendanceSession.class_id == class_id, AttendanceSession.end_time <= now
        )
        .order_by(AttendanceSession.start_time.asc())
        .all()
    )

    for student_id, joined_at in student_data:
        # กรองเฉพาะ session ที่เริ่มหลังจากนักเรียนเข้าคลาสแล้วเท่านั้น
        effective_sessions = [
            s
            for s in all_past_sessions
            if joined_at is None or s.start_time >= joined_at
        ]

        total_effective = len(effective_sessions)
        attended = late = absent = left_early = reverified = 0

        # 3. ใช้ระบบ Upsert: หา report เดิม ถ้าไม่มีค่อยสร้างใหม่
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
            db.flush()  # เพื่อให้ได้ report_id

        # ลบรายละเอียดรายวันเก่า (Detail) เพื่อสร้างใหม่ให้เป็นปัจจุบันที่สุด
        db.query(AttendanceReportDetail).filter(
            AttendanceReportDetail.report_id == report.report_id
        ).delete()

        # 4. คำนวณสถิติจาก Effective Sessions เท่านั้น
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

            if not record:
                absent += 1
            else:
                check_in_time = record.check_in_time
                is_reverified = record.is_reverified

                # Logic การตัดสินสถานะ
                if not record.is_reverified:
                    status = "LeftEarly"
                    left_early += 1
                else:
                    status = record.status or "Present"
                    if status == "Present":
                        attended += 1
                    elif status == "Late":
                        late += 1
                    elif status == "Absent":
                        absent += 1

                if record.is_reverified:
                    reverified += 1

            # บันทึกรายละเอียดราย session (Detail)
            db.add(
                AttendanceReportDetail(
                    report_id=report.report_id,
                    session_id=session.session_id,
                    status=status,
                    check_in_time=check_in_time,
                    is_reverified=is_reverified,
                )
            )

        # 5. อัปเดตตัวเลขสรุปใน Report
        report.total_sessions = total_effective
        report.attended_sessions = attended
        report.late_sessions = late
        report.absent_sessions = absent
        report.left_early_sessions = left_early
        report.reverified_sessions = reverified
        report.generated_at = now

        # คำนวณ % การเข้าเรียน (เฉพาะคาบที่เขาควรเข้าจริง)
        if total_effective > 0:
            rate = ((attended + late) / total_effective) * 100
            report.attendance_rate = round(rate, 2)
        else:
            report.attendance_rate = 0.0

    db.commit()
    return {"message": f"✅ Updated reports for {len(student_data)} students."}
