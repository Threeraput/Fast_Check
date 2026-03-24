from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.attendance_report_detail import AttendanceReportDetail
from app.schemas.attendance_report_detail_schema import AttendanceReportDetailResponse
from app.core.deps import get_current_user, role_required
from app.models.user import User

router = APIRouter(prefix="/attendance/reports/details", tags=["Attendance Details"])


# 🧑‍🎓 นักเรียนดูรายงานรายวันของตัวเอง
@router.get("/my", response_model=list[AttendanceReportDetailResponse])
def get_my_daily_reports(
    db: Session = Depends(get_db), me: User = Depends(get_current_user)
):
    """ให้นักเรียนดูรายงานรายวันของตัวเอง"""
    # ✅ ตรวจสอบ role แบบยืดหยุ่น (รองรับ Role object)
    role_value = getattr(me, "role", None)
    roles_value = getattr(me, "roles", None)

    is_student = False

    # กรณี role เป็น string เดียว
    if isinstance(role_value, str) and role_value.lower() == "student":
        is_student = True
    # กรณี roles เป็น list ของ string หรือ Role object
    elif isinstance(roles_value, list):
        for r in roles_value:
            # ดึงชื่อ role จาก attribute ที่มีอยู่จริง
            role_name = None
            if isinstance(r, str):
                role_name = r
            elif hasattr(r, "name"):
                role_name = r.name
            elif hasattr(r, "role_name"):
                role_name = r.role_name
            elif hasattr(r, "role"):
                role_name = r.role

            if role_name and role_name.lower() == "student":
                is_student = True
                break

    if not is_student:
        raise HTTPException(status_code=403, detail="Only students can view this")

    # ✅ Query รายละเอียดรายวัน
    results = (
        db.query(AttendanceReportDetail)
        .join(AttendanceReportDetail.report)
        .filter(AttendanceReportDetail.report.has(student_id=me.user_id))
        .order_by(AttendanceReportDetail.check_in_time.desc())
        .all()
    )

    if not results:
        raise HTTPException(status_code=404, detail="No daily reports found")

    return results


# 👩‍🏫 ครูดูรายงานรายวันของคลาส
@router.get(
    "/class/{class_id}",
    response_model=list[AttendanceReportDetailResponse],
    dependencies=[Depends(role_required(["teacher"]))],
)
def get_class_daily_reports(class_id: str, db: Session = Depends(get_db)):
    """ให้ครูดูรายงานรายวันของคลาส"""
    results = (
        db.query(AttendanceReportDetail)
        .join(AttendanceReportDetail.report)
        .filter(AttendanceReportDetail.report.has(class_id=class_id))
        .order_by(AttendanceReportDetail.check_in_time.desc())
        .all()
    )

    if not results:
        raise HTTPException(
            status_code=404, detail="No daily reports found for this class"
        )

    return results
