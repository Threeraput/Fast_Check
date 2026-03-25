# backend/app/api/v1/attendance_report_detail.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
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
    # ตรวจสอบสิทธิ์ว่าเป็น student หรือไม่
    roles_list = [
        r.name.lower() if hasattr(r, "name") else str(r).lower()
        for r in getattr(me, "roles", [])
    ]
    if "student" not in roles_list:
        raise HTTPException(status_code=403, detail="Only students can view this")

    #  ปรับปรุงการ Query:
    # 1. ใช้ order_by created_at แทน check_in_time เพราะคนขาดเรียน (Absent) จะไม่มีเวลาเช็คอิน
    # 2. ใช้ .all() เพื่อดึงข้อมูลทั้งหมดมาแสดงในหน้าประวัติ
    results = (
        db.query(AttendanceReportDetail)
        .join(AttendanceReportDetail.report)
        .filter(AttendanceReportDetail.report.has(student_id=me.user_id))
        .order_by(
            AttendanceReportDetail.created_at.desc()
        )  # เรียงตามเวลาที่สร้างเรคคอร์ดล่าสุด
        .all()
    )

    if not results:
        raise HTTPException(status_code=404, detail="No daily reports found")

    return results


# 👩ครูดูรายงานรายวันของคลาส
@router.get(
    "/class/{class_id}",
    response_model=list[AttendanceReportDetailResponse],
    dependencies=[Depends(role_required(["teacher"]))],
)
def get_class_daily_reports(class_id: str, db: Session = Depends(get_db)):
    """ให้ครูดูรายงานรายวันของคลาส"""
    #  ปรับปรุงการ Query:
    # ใช้ joinedload เพื่อลดการ Query ซ้ำซ้อน (N+1 Problem) และเรียงลำดับให้ถูกต้อง
    results = (
        db.query(AttendanceReportDetail)
        .options(joinedload(AttendanceReportDetail.report))
        .filter(AttendanceReportDetail.report.has(class_id=class_id))
        .order_by(AttendanceReportDetail.created_at.desc())
        .all()
    )

    if not results:
        raise HTTPException(
            status_code=404, detail="No daily reports found for this class"
        )

    return results
