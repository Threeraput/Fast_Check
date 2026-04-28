# backend/app/api/v1/attendance_report_detail.py
from datetime import datetime
import io
import csv
import openpyxl  
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session, joinedload
from app.database import get_db
from app.models.attendance_report_detail import AttendanceReportDetail
from app.schemas.attendance_report_detail_schema import AttendanceReportDetailResponse
from app.core.deps import get_current_user, role_required
from app.models.user import User

# อย่าลืม Import Model ที่ต้องใช้ ถ้าอันไหนมีอยู่แล้วด้านบนก็ไม่ต้องใส่ซ้ำนะครับ
from app.models.attendance_report import AttendanceReport
from app.models.attendance_session import AttendanceSession

router = APIRouter(prefix="/attendance/reports/details", tags=["Attendance Details"])


# ---------------------------------------------------------
# นักเรียนดูรายงานรายวันของตัวเอง
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

    # แมปค่า path รูปภาพจาก DB เข้าสู่ field url ใน Schema (ทั้ง 2 รูป)
    for r in results:
        r.face_image_url = r.face_image_path
        r.reverify_image_url = r.reverify_image_path

    return results


# ---------------------------------------------------------
# ครูดูรายงานรายวันของคลาส (ดูภาพรวมราย Session ของทั้งห้อง)
# ---------------------------------------------------------
@router.get(
    "/class/{class_id}",
    response_model=list[AttendanceReportDetailResponse],
    dependencies=[Depends(role_required(["teacher", "admin"]))],  # เพิ่ม admin เผื่อไว้
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
# ครูดูรายงานรายวัน "เจาะจงรายบุคคล" (ดูย้อนหลังรายคน)
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

# ---------------------------------------------------------
# ส่งออกรายงานการเข้าเรียนรายวัน (Detailed Excel Export)
# ---------------------------------------------------------
@router.get(
    "/class/{class_id}/export/detailed",
    # dependencies=[Depends(role_required(["teacher", "admin"]))], # เปิดคอมเมนต์เมื่อใช้จริง
)
def export_class_detailed_report(class_id: UUID, db: Session = Depends(get_db)):
    """ดาวน์โหลดไฟล์ Excel รายงานการเข้าเรียนแบบรายวันของทั้งคลาส"""
    
    # 1️.ดึงข้อมูลโดยการ Join 4 ตารางเข้าด้วยกัน
    results = (
        db.query(
            AttendanceSession.start_time,
            AttendanceSession.end_time,
            User.student_id.label("student_code"),
            User.first_name,
            User.last_name,
            AttendanceReportDetail.check_in_time,
            AttendanceReportDetail.status,
            AttendanceReportDetail.is_reverified,
            AttendanceReportDetail.reverify_time,
        )
        .join(AttendanceReportDetail, AttendanceSession.session_id == AttendanceReportDetail.session_id)
        .join(AttendanceReport, AttendanceReportDetail.report_id == AttendanceReport.report_id)
        .join(User, AttendanceReport.student_id == User.user_id)
        .filter(AttendanceReport.class_id == class_id)
        .order_by(AttendanceSession.start_time.asc(), User.student_id.asc()) 
        .all()
    )

    if not results:
        raise HTTPException(status_code=404, detail="ไม่มีข้อมูลสำหรับการส่งออก")

    # 2.เตรียมตัวช่วยแปลภาษาและฟอร์แมตวันที่
    def translate_status(status_str: str) -> str:
        s = status_str.lower()
        if s == "present": return "เข้าเรียน"
        if s == "late": return "สาย"
        if s == "absent": return "ขาดเรียน"
        if s in ["left_early", "leftearly"]: return "กลับก่อน"
        return status_str

    def format_dt(dt: datetime, fmt: str = "%d/%m/%Y %H:%M:%S") -> str:
        if not dt:
            return "-"
        return dt.strftime(fmt)

    # สร้างไฟล์ Excel แท้ๆ แบบไร้ภาษาเอเลี่ยน
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "รายงานรายวัน"

    # เขียนหัวตาราง
    headers = ["วันที่เรียน", "รหัสนักศึกษา", "ชื่อ-นามสกุล", "เวลาเริ่มคาบ", "เวลาสิ้นสุดคาบ", "เวลาที่เช็คชื่อ", "สถานะ", "สุ่มตรวจซ้ำ", "เวลาตรวจซ้ำ"]
    ws.append(headers)

    # 3. วนลูปข้อมูลใส่ตาราง Excel
    for r in results:
        # แปลงข้อมูลเวลาให้เป็นแบบเต็ม (Full Datetime)
        date_str = format_dt(r.start_time, "%d/%m/%Y")
        start_time_full = format_dt(r.start_time, "%d/%m/%Y %H:%M:%S")
        end_time_full = format_dt(r.end_time, "%d/%m/%Y %H:%M:%S")
        
        check_in_full = format_dt(r.check_in_time, "%d/%m/%Y %H:%M:%S")
        reverify_full = format_dt(r.reverify_time, "%d/%m/%Y %H:%M:%S")
        
        full_name = f"{r.first_name or ''} {r.last_name or ''}".strip()
        reverified_text = "ใช่" if r.is_reverified else "-"

        # 4. ใส่ข้อมูลลงไปทีละบรรทัดตามลำดับ Headers
        ws.append([
            date_str,
            r.student_code or "-",
            full_name or "ไม่ระบุชื่อ",
            start_time_full,    # เวลาเริ่มคาบแบบเต็ม
            end_time_full,      # เวลาสิ้นสุดคาบแบบเต็ม
            check_in_full,      # เวลาที่นักเรียนกดเช็คชื่อ
            translate_status(r.status),
            reverified_text,
            reverify_full
        ])

    # 5.บันทึกไฟล์ Excel ลงในหน่วยความจำ
    output = io.BytesIO()
    wb.save(output) # ต้องสั่ง save ข้อมูลลง output ก่อน
    output.seek(0)  # และต้องรีเซ็ตเคอร์เซอร์กลับไปจุดเริ่มต้นเพื่อให้อ่านไฟล์ได้
    
    # 6.ส่งไฟล์กลับไปให้หน้าบ้านโหลด
    return Response(
        content=output.getvalue(),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f"attachment; filename=detailed_report_{class_id}.xlsx"
        }
    )