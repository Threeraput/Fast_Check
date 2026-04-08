from sqlalchemy.orm import Session, joinedload
from app.models.attendance import Attendance
from app.models.attendance_report_detail import AttendanceReportDetail


def generate_report_details_for_class(db: Session, class_id, report_map: dict):
    """
    สร้างข้อมูลรายวัน (ราย session) สำหรับทุกนักเรียนใน class นั้น
    report_map: { student_id(str): report_id(UUID) }
    """
    # ใช้ joinedload ดึงข้อมูล session มารวมด้วยเพื่อเอาเวลาเริ่มคาบ (session_start) แบบไม่ให้เกิด N+1 Query
    attendances = (
        db.query(Attendance)
        .options(joinedload(Attendance.attendance_session))
        .filter(Attendance.class_id == class_id)
        .all()
    )
    details = []

    for att in attendances:
        report_id = report_map.get(str(att.student_id))
        if not report_id:
            continue

        # ดึงเวลาเริ่มคาบจาก relationship (ถ้ามี)
        session_start = (
            att.attendance_session.start_time if att.attendance_session else None
        )

        details.append(
            AttendanceReportDetail(
                report_id=report_id,
                session_id=att.session_id,
                status=att.status,
                is_reverified=att.is_reverified,
                #  ข้อมูลชุดที่ 1: การเช็คชื่อปกติ
                check_in_time=att.check_in_time,
                face_image_path=att.face_image_path,
                #  ข้อมูลชุดที่ 2: การสุ่มตรวจ (Re-verify)
                reverify_time=att.reverify_time,
                reverify_image_path=att.reverify_image_path,
                #  ข้อมูลคาบเรียน
                session_start=session_start,
            )
        )

    if details:
        db.bulk_save_objects(details)
        db.commit()

    return len(details)
