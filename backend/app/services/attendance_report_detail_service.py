from sqlalchemy.orm import Session
from app.models.attendance import Attendance
from app.models.attendance_report_detail import AttendanceReportDetail

def generate_report_details_for_class(db: Session, class_id, report_map: dict):
    """
    สร้างข้อมูลรายวัน (ราย session) สำหรับทุกนักเรียนใน class นั้น
    report_map: { student_id(str): report_id(UUID) }
    """
    attendances = db.query(Attendance).filter(Attendance.class_id == class_id).all()
    details = []

    for att in attendances:
        report_id = report_map.get(str(att.student_id))
        if not report_id:
            continue
        details.append(
            AttendanceReportDetail(
                report_id=report_id,
                session_id=att.session_id,
                check_in_time=att.check_in_time,
                status=att.status,
                is_reverified=att.is_reverified,
            )
        )

    if details:
        db.bulk_save_objects(details)
        db.commit()
    return len(details)
