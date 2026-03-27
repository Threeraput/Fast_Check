# backend/app/api/v1/attendance_report_detail.py
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from app.database import get_db
from app.models.attendance_report_detail import AttendanceReportDetail
from app.schemas.attendance_report_detail_schema import AttendanceReportDetailResponse
from app.core.deps import get_current_user, role_required
from app.models.user import User

router = APIRouter(prefix="/attendance/reports/details", tags=["Attendance Details"])


# ---------------------------------------------------------
# 1️⃣ นักเรียนดูรายงานรายวันของตัวเอง
# ---------------------------------------------------------
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

    # ปรับปรุงการ Query: ดึงข้อมูลพร้อมกับข้อมูลรูปภาพและเวลาเริ่มคาบที่บันทึกไว้
    results = (
        db.query(AttendanceReportDetail)
        .join(AttendanceReportDetail.report)
        .filter(AttendanceReportDetail.report.has(student_id=me.user_id))
        .order_by(AttendanceReportDetail.created_at.desc())
        .all()
    )

    if not results:
        raise HTTPException(status_code=404, detail="No daily reports found")

    # ✅ แมปค่า path รูปภาพจาก DB เข้าสู่ field url ใน Schema (ทั้ง 2 รูป)
    for r in results:
        r.face_image_url = r.face_image_path
        r.reverify_image_url = r.reverify_image_path

    return results


# ---------------------------------------------------------
# 2️⃣ ครูดูรายงานรายวันของคลาส (ดูภาพรวมราย Session ของทั้งห้อง)
# ---------------------------------------------------------
@router.get(
    "/class/{class_id}",
    response_model=list[AttendanceReportDetailResponse],
    dependencies=[Depends(role_required(["teacher", "admin"]))],  # ✅ เพิ่ม admin เผื่อไว้
)
def get_class_daily_reports(
    class_id: UUID, db: Session = Depends(get_db)
):  #  เปลี่ยน str เป็น UUID
    """ให้ครู/แอดมินดูรายงานรายวันของคลาส"""
    # ใช้ joinedload เพื่อประสิทธิภาพ และดึงข้อมูลรูปภาพ/วันที่มาด้วย
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

    #  แมปค่า path รูปภาพจาก DB เข้าสู่ field url ใน Schema (ทั้ง 2 รูป)
    for r in results:
        r.face_image_url = r.face_image_path
        r.reverify_image_url = r.reverify_image_path

    return results


# ---------------------------------------------------------
# 3️⃣ ครูดูรายงานรายวัน "เจาะจงรายบุคคล" (ดูย้อนหลังรายคน)
# ---------------------------------------------------------
@router.get(
    "/student/{student_id}",
    response_model=list[AttendanceReportDetailResponse],
    dependencies=[Depends(role_required(["teacher", "admin"]))],
)
def get_student_daily_reports(student_id: UUID, db: Session = Depends(get_db)):
    """ให้อาจารย์ดูประวัติการเช็คชื่อราย session ของนักเรียนคนใดคนหนึ่ง"""

    # Query หา AttendanceReportDetail โดยกรองจาก student_id ในตาราง Report
    results = (
        db.query(AttendanceReportDetail)
        .join(AttendanceReportDetail.report)
        .filter(AttendanceReportDetail.report.has(student_id=student_id))
        .order_by(AttendanceReportDetail.created_at.desc())
        .all()
    )

    if not results:
        raise HTTPException(status_code=404, detail="ไม่พบประวัติการเช็คชื่อของนักเรียนคนนี้")

    #  แมป Path รูปภาพ (ทั้งรูปแรกและรูป Re-verify) เข้าสู่ URL ใน Schema
    for r in results:
        r.face_image_url = r.face_image_path
        r.reverify_image_url = r.reverify_image_path

    return results
