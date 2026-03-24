from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.core.deps import get_current_user, role_required
from app.models.user import User
from app.models.attendance_report import AttendanceReport
from app.schemas.attendance_report_schema import AttendanceReportResponse
from app.services.attendance_report_service import generate_reports_for_class

router = APIRouter(prefix="/attendance/reports", tags=["Attendance Reports"])

def _to_schema(r: AttendanceReport) -> AttendanceReportResponse:
    return AttendanceReportResponse.model_validate({
        "report_id": r.report_id,
        "class_id": r.class_id,  # ตอนนี้ schema รับ None ได้แล้ว
        "student_id": r.student_id,
        "total_sessions": r.total_sessions or 0,
        "attended_sessions": r.attended_sessions or 0,
        "late_sessions": r.late_sessions or 0,
        "absent_sessions": r.absent_sessions or 0,
        "left_early_sessions": r.left_early_sessions or 0,
        "reverified_sessions": r.reverified_sessions or 0,
        "attendance_rate": float(r.attendance_rate or 0.0),
        "generated_at": r.generated_at,
        "class_name": getattr(getattr(r, "classroom", None), "name", None),
    })

# ---------- นักเรียน ----------
@router.get("/my-report", response_model=list[AttendanceReportResponse])
def get_my_report(db: Session = Depends(get_db), me: User = Depends(get_current_user)):
    if not any(getattr(r, "name", None) == "student" for r in getattr(me, "roles", [])):
        raise HTTPException(status_code=403, detail="Only students can view their own report")

    rows = (
        db.query(AttendanceReport)
          .options(joinedload(AttendanceReport.classroom))
          .filter(
              AttendanceReport.student_id == me.user_id,
              AttendanceReport.class_id.isnot(None)  # กันแถวเสีย
          )
          .all()
    )
    if not rows:
        raise HTTPException(status_code=404, detail="No reports found for this user")
    return [_to_schema(r) for r in rows]

# ---------- ครู ----------
@router.post(
    "/class/{class_id}/generate",
    response_model=dict,
    dependencies=[Depends(role_required(["teacher"]))],
)
def generate_class_reports(class_id: UUID, db: Session = Depends(get_db)):
    return generate_reports_for_class(db, str(class_id))

@router.get(
    "/class/{class_id}",
    response_model=list[AttendanceReportResponse],
    dependencies=[Depends(role_required(["teacher"]))],
)
def get_class_reports(class_id: UUID, db: Session = Depends(get_db)):
    rows = (
        db.query(AttendanceReport)
          .options(joinedload(AttendanceReport.classroom))
          .filter(
              AttendanceReport.class_id == class_id,
              AttendanceReport.class_id.isnot(None)
          )
          .all()
    )
    return [_to_schema(r) for r in rows]

@router.get(
    "/class/{class_id}/summary",
    response_model=dict,
    dependencies=[Depends(role_required(["teacher"]))],
)
def get_class_summary(class_id: UUID, db: Session = Depends(get_db)):
    rows = (
        db.query(AttendanceReport)
          .filter(AttendanceReport.class_id == class_id)
          .all()
    )
    if not rows:
        raise HTTPException(status_code=404, detail="No reports found for this class")

    rates = [float(r.attendance_rate or 0.0) for r in rows]
    avg_rate = (sum(rates) / len(rows)) if rows else 0.0
    total_absent = sum(int(r.absent_sessions or 0) for r in rows)

    return {
        "class_id": str(class_id),
        "total_students": len(rows),
        "average_attendance_rate": round(avg_rate, 2),
        "total_absent_records": total_absent,
    }

@router.get(
    "/student/{student_id}",
    response_model=list[AttendanceReportResponse],
    dependencies=[Depends(role_required(["teacher"]))],
)
def get_student_report(student_id: UUID, db: Session = Depends(get_db)):
    rows = (
        db.query(AttendanceReport)
          .options(joinedload(AttendanceReport.classroom))
          .filter(
              AttendanceReport.student_id == student_id,
              AttendanceReport.class_id.isnot(None)
          )
          .all()
    )
    if not rows:
        raise HTTPException(status_code=404, detail="No report found for this student")
    return [_to_schema(r) for r in rows]
