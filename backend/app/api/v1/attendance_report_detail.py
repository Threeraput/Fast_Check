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
from app.core.deps import get_current_user, get_roles_from_token, role_required
from app.models.user import User

# อย่าลืม Import Model ที่ต้องใช้ ถ้าอันไหนมีอยู่แล้วด้านบนก็ไม่ต้องใส่ซ้ำนะครับ
from app.models.attendance_report import AttendanceReport
from app.models.attendance_session import AttendanceSession
from app.models.association import class_students # นำเข้าตารางสมาชิกคลาส
from app.models.student_location import StudentLocation # นำเข้าตารางพิกัด
from sqlalchemy import func # เพิ่ม func สำหรับ subquery

router = APIRouter(prefix="/attendance/reports/details", tags=["Attendance Details"])


# ---------------------------------------------------------
# นักเรียนดูรายงานรายวันของตัวเอง
# ---------------------------------------------------------
@router.get("/my", response_model=list[AttendanceReportDetailResponse])
def get_my_daily_reports(
    class_id: UUID = None, # 👈 เพิ่ม class_id เป็นตัวเลือก
    db: Session = Depends(get_db), 
    me: User = Depends(get_current_user), 
    token_roles: list = Depends(get_roles_from_token)
):
    """ให้นักเรียนดูรายงานรายวันของตัวเอง"""
    
    if "student" not in token_roles:
        raise HTTPException(status_code=403, detail="Only students can view this")

    query = db.query(AttendanceReportDetail).join(AttendanceReportDetail.report)
    
    # กรอง student_id เสมอ
    filters = [AttendanceReportDetail.report.has(student_id=me.user_id)]
    
    # 👈 ถ้าส่ง class_id มาให้กรองเพิ่ม
    if class_id:
        filters.append(AttendanceReportDetail.report.has(class_id=class_id))

    results = (
        query.filter(*filters)
        .order_by(AttendanceReportDetail.created_at.desc())
        .all()
    )

    if not results:
        return [] # คืนค่าลิสต์ว่างแทนที่จะ Error เพื่อให้ UI ทำงานต่อได้

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
    dependencies=[Depends(role_required(["teacher", "admin"]))],
)
def get_class_daily_reports(
    class_id: UUID, db: Session = Depends(get_db)
):
    """ให้ครู/แอดมินดูรายงานรายวันของคลาส"""
    results = (
        db.query(AttendanceReportDetail)
        .options(joinedload(AttendanceReportDetail.report))
        .filter(AttendanceReportDetail.report.has(class_id=class_id))
        .order_by(AttendanceReportDetail.created_at.desc())
        .all()
    )

    if not results:
        return []

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
def get_student_daily_reports(
    student_id: UUID, 
    class_id: UUID = None, # 👈 เพิ่ม class_id เป็นตัวเลือก
    db: Session = Depends(get_db)
):
    """ให้อาจารย์ดูประวัติการเช็คชื่อราย session ของนักเรียนคนใดคนหนึ่ง"""

    query = db.query(AttendanceReportDetail).join(AttendanceReportDetail.report)
    
    filters = [AttendanceReportDetail.report.has(student_id=student_id)]
    
    # 👈 กรองคลาสเรียนด้วย ถ้าส่งมา
    if class_id:
        filters.append(AttendanceReportDetail.report.has(class_id=class_id))

    results = (
        query.filter(*filters)
        .order_by(AttendanceReportDetail.created_at.desc())
        .all()
    )

    if not results:
        return []

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
    
    # 1️. ดึงข้อมูลพิกัด Silent Check อันล่าสุดของแต่ละคนในแต่ละ Session
    # เพื่อเอามา Join กับตาราง Attendance
    silent_check_sub = (
        db.query(
            StudentLocation.student_id,
            StudentLocation.session_id,
            func.max(StudentLocation.timestamp).label("latest_ts")
        )
        .filter(StudentLocation.is_silent_check == True)
        .group_by(StudentLocation.student_id, StudentLocation.session_id)
        .subquery()
    )

    # 2. Query ข้อมูลหลัก
    results = (
        db.query(
            AttendanceSession.session_id,
            AttendanceSession.start_time,
            AttendanceSession.end_time,
            User.user_id,
            User.student_id.label("student_code"),
            User.first_name,
            User.last_name,
            AttendanceReportDetail.check_in_time,
            AttendanceReportDetail.status,
            StudentLocation.timestamp.label("silent_check_at"),
            StudentLocation.is_silent_check,
            StudentLocation.distance_m
        )
        .join(AttendanceReportDetail, AttendanceSession.session_id == AttendanceReportDetail.session_id)
        .join(AttendanceReport, AttendanceReportDetail.report_id == AttendanceReport.report_id)
        .join(User, AttendanceReport.student_id == User.user_id)
        .join(class_students, (class_students.c.student_id == User.user_id) & (class_students.c.class_id == class_id))
        # Left Join กับข้อมูลพิกัด (ดึงพิกัดที่ timestamp ตรงกับ subquery ล่าสุด)
        .outerjoin(silent_check_sub, 
            (silent_check_sub.c.student_id == User.user_id) & 
            (silent_check_sub.c.session_id == AttendanceSession.session_id)
        )
        .outerjoin(StudentLocation,
            (StudentLocation.student_id == silent_check_sub.c.student_id) &
            (StudentLocation.session_id == silent_check_sub.c.session_id) &
            (StudentLocation.timestamp == silent_check_sub.c.latest_ts)
        )
        .filter(AttendanceReport.class_id == class_id)
        .order_by(AttendanceSession.start_time.asc(), User.student_id.asc()) 
        .all()
    )

    if not results:
        raise HTTPException(status_code=404, detail="ไม่มีข้อมูลสำหรับการส่งออก")

    # 3.เตรียมตัวช่วยแปลภาษาและฟอร์แมตวันที่
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

    # สร้างไฟล์ Excel
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "รายงานรายวัน"

    # เขียนหัวตารางใหม่ (เพิ่ม ระยะทาง)
    headers = [
        "วันที่เรียน", 
        "รหัสนักศึกษา", 
        "ชื่อ-นามสกุล", 
        "เวลาเริ่มคาบ", 
        "เวลาสิ้นสุดคาบ", 
        "เวลาที่เช็คชื่อ", 
        "สถานะ", 
        "สุ่มตรวจซ้ำ (Silent Check)", 
        "เวลาตรวจซ้ำ",
        "ระยะห่าง (เมตร)"
    ]
    ws.append(headers)

    # 4. วนลูปข้อมูลใส่ตาราง Excel
    for r in results:
        date_str = format_dt(r.start_time, "%d/%m/%Y")
        start_time_full = format_dt(r.start_time, "%d/%m/%Y %H:%M:%S")
        end_time_full = format_dt(r.end_time, "%d/%m/%Y %H:%M:%S")
        check_in_full = format_dt(r.check_in_time, "%d/%m/%Y %H:%M:%S")
        
        # ใช้ข้อมูลจาก StudentLocation แทน Re-verify เดิม
        silent_check_at_full = format_dt(r.silent_check_at, "%d/%m/%Y %H:%M:%S")
        silent_check_status = "ใช่" if r.is_silent_check else "-"
        distance_val = round(float(r.distance_m), 2) if r.distance_m is not None else "-"
        
        full_name = f"{r.first_name or ''} {r.last_name or ''}".strip()

        ws.append([
            date_str,
            r.student_code or "-",
            full_name or "ไม่ระบุชื่อ",
            start_time_full,
            end_time_full,
            check_in_full,
            translate_status(r.status),
            silent_check_status,
            silent_check_at_full,
            distance_val
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