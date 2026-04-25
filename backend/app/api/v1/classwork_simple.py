# app/api/v1/classwork_simple.py
import io

import openpyxl
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, Response, UploadFile, File, HTTPException, status, Body, Path
from app.schemas.classwork_new_schema import CommentCreate, CommentResponse
from app.services import classwork_service
from sqlalchemy.orm import Session
from datetime import datetime

from app.database import get_db
from app.core.deps import get_current_user, role_required
from app.models.user import User
from app.schemas.classwork_new_schema import (
    AssignmentCreate,
    AssignmentResponse,
    SubmissionResponse,
    AssignmentWithMySubmission,
    GradeSubmission,
)
from app.models.classwork_enums import SubmissionLateness
from app.services.simple_classwork_service import (
    create_assignment,
    submit_pdf,
    list_assignments_for_student,
    list_submissions_for_teacher,
    grade_submission,
    _ensure_teacher_of_class,
)
from app.models.classwork_assignment import ClassworkAssignment
from app.models.classwork_submission import ClassworkSubmission
# นำเข้าตารางเชื่อม Many-to-Many
from app.models.association import class_students



router = APIRouter(prefix="/classwork-simple", tags=["Classwork (Simple)"])


# -----------------------------
# ครู: สร้างงานระดับคลาส
# -----------------------------
@router.post(
    "/assignments",
    response_model=AssignmentResponse,
    dependencies=[Depends(role_required(["teacher"]))],
    status_code=status.HTTP_201_CREATED,
)
def create_assignment_route(
    payload: AssignmentCreate,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    asg = create_assignment(
        db,
        teacher_id=me.user_id,
        class_id=payload.class_id,
        title=payload.title,
        max_score=payload.max_score,
        due_date=payload.due_date,
    )
    return asg


# -----------------------------
# นักเรียน: รายการงานในคลาส + สถานะของฉัน
# -----------------------------
# app/api/v1/classwork_simple.py


@router.get(
    "/student/{class_id}/assignments",
    response_model=List[AssignmentWithMySubmission],
    dependencies=[Depends(role_required(["student"]))],  # เฉพาะนักเรียน
)
def list_my_assignments_route(
    class_id: UUID,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    rows = list_assignments_for_student(db, class_id=class_id, student_id=me.user_id)

    resp: List[AssignmentWithMySubmission] = []
    for asg, sub in rows:
        computed = SubmissionLateness.NOT_SUBMITTED
        mymini = None
        if sub:
            computed = sub.submission_status
            mymini = {
                "content_url": sub.content_url,
                "submitted_at": sub.submitted_at,
                "submission_status": sub.submission_status,
                "graded": sub.graded,
                "score": sub.score,
            }
        resp.append(
            AssignmentWithMySubmission(
                assignment_id=asg.assignment_id,
                class_id=asg.class_id,
                teacher_id=asg.teacher_id,
                title=asg.title,
                max_score=asg.max_score,
                due_date=asg.due_date,
                computed_status=computed,
                my_submission=mymini,
            )
        )
    return resp


# -----------------------------
# นักเรียน: ส่งไฟล์ PDF
# -----------------------------
@router.post(
    "/assignments/{assignment_id}/submit",
    response_model=SubmissionResponse,
    dependencies=[Depends(role_required(["student"]))],
)
async def submit_assignment_pdf_route(
    assignment_id: UUID,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    if file.content_type not in {"application/pdf"}:
        raise HTTPException(400, "Only PDF is allowed")
    sub = await submit_pdf(
        db, assignment_id=assignment_id, student_id=me.user_id, file=file
    )
    return sub


# -----------------------------
# ครู: ดูการส่งทั้งหมดของงานหนึ่ง
# -----------------------------
@router.get(
    "/assignments/{assignment_id}/submissions",
    response_model=List[SubmissionResponse],
    dependencies=[Depends(role_required(["teacher"]))],
)
def list_submissions_for_teacher_route(
    assignment_id: UUID,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    items = list_submissions_for_teacher(
        db, assignment_id=assignment_id, teacher_id=me.user_id
    )
    return items


# -----------------------------
# ครู: ให้คะแนน
# -----------------------------
@router.post(
    "/assignments/{assignment_id}/grade",
    response_model=SubmissionResponse,
    dependencies=[Depends(role_required(["teacher"]))],
)
def grade_submission_route(
    assignment_id: UUID,
    payload: GradeSubmission,  # { student_id, score }
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    sub = grade_submission(
        db,
        assignment_id=assignment_id,
        student_id=payload.student_id,
        teacher_id=me.user_id,
        score=payload.score,
    )
    return sub


@router.get(
    "/teacher/{class_id}/assignments",
    response_model=List[AssignmentResponse],
    dependencies=[Depends(role_required(["teacher"]))],
)
def list_assignments_for_class_route(
    class_id: UUID,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    # ครูเจ้าของคลาสเท่านั้น
    _ = _ensure_teacher_of_class(db, teacher_id=me.user_id, class_id=class_id)
    # ดึงรายการงาน
    from app.models.classwork_assignment import ClassworkAssignment

    items = (
        db.query(ClassworkAssignment)
        .filter(ClassworkAssignment.class_id == class_id)
        .order_by(ClassworkAssignment.due_date.asc())
        .all()
    )
    return items


# -----------------------------
# ครู: ดูงานที่นักเรียนคนหนึ่งส่งในคลาส (รวมทุกงาน)
# -----------------------------
@router.get(
    "/teacher/{class_id}/student/{student_id}/submissions",
    response_model=List[AssignmentWithMySubmission],
    dependencies=[Depends(role_required(["teacher"]))],
)
def get_student_submissions_for_class_route(
    class_id: UUID,
    student_id: UUID,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    # ตรวจสอบว่าครูเป็นครูของคลาส
    _ = _ensure_teacher_of_class(db, teacher_id=me.user_id, class_id=class_id)
    
    # ดึงรายการงานทั้งหมดในคลาส
    from app.models.classwork_assignment import ClassworkAssignment
    from app.models.classwork_submission import ClassworkSubmission
    
    assignments = (
        db.query(ClassworkAssignment)
        .filter(ClassworkAssignment.class_id == class_id)
        .order_by(ClassworkAssignment.due_date.asc())
        .all()
    )
    
    resp: List[AssignmentWithMySubmission] = []
    for asg in assignments:
        # ดึงการส่งงานของนักเรียนคนนี้ (ถ้ามี)
        sub = (
            db.query(ClassworkSubmission)
            .filter(
                ClassworkSubmission.assignment_id == asg.assignment_id,
                ClassworkSubmission.student_id == student_id,
            )
            .first()
        )
        
        computed = SubmissionLateness.NOT_SUBMITTED
        mymini = None
        if sub:
            computed = sub.submission_status
            mymini = {
                "content_url": sub.content_url,
                "submitted_at": sub.submitted_at,
                "submission_status": sub.submission_status,
                "graded": sub.graded,
                "score": sub.score,
            }
        
        resp.append(
            AssignmentWithMySubmission(
                assignment_id=asg.assignment_id,
                class_id=asg.class_id,
                teacher_id=asg.teacher_id,
                title=asg.title,
                max_score=asg.max_score,
                due_date=asg.due_date,
                computed_status=computed,
                my_submission=mymini,
            )
        )
    
    return resp


# -----------------------------
# คอมเมนต์: สร้างคอมเมนต์ใหม่ (ทั้งครูและนักเรียน)
# -----------------------------
@router.post(
    "/assignments/{assignment_id}/comments",
    response_model=CommentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_assignment_comment(
    assignment_id: UUID = Path(..., description="UUID ของงานที่ต้องการคอมเมนต์"),
    comment_in: CommentCreate = Body(...),
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),  # ไม่บังคับ Role เพราะทั้งครูและเด็กก็คอมเมนต์ได้
):
    new_comment = classwork_service.create_comment(
        db=db,
        assignment_id=assignment_id,
        user_id=me.user_id,
        content=comment_in.content,
    )
    return new_comment


# -----------------------------
# คอมเมนต์: ดึงคอมเมนต์ทั้งหมดของงานชิ้นนั้น
# -----------------------------
@router.get(
    "/assignments/{assignment_id}/comments", response_model=List[CommentResponse]
)
async def get_assignment_comments(
    assignment_id: UUID = Path(..., description="UUID ของงานที่ต้องการดูคอมเมนต์"),
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    comments = classwork_service.get_comments_by_assignment(
        db=db, assignment_id=assignment_id
    )
    return comments

@router.get("/assignments/{assignment_id}/export")
def export_assignment_report(assignment_id: UUID, db: Session = Depends(get_db)):
    # 1️.ดึงข้อมูล Assignment เพื่อเอาหัวข้อและคะแนนเต็ม
    assignment = db.query(ClassworkAssignment).filter(ClassworkAssignment.assignment_id == assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="ไม่พบข้อมูลงานที่ระบุ")

    # 2.ดึงรายชื่อนักเรียนในคลาส และ Join กับข้อมูลการส่งงาน (Left Join)
    # หมายเหตุ: ผมสมมติว่าคุณมีตารางเชื่อมระหว่าง User กับ Class ชื่อ ClassMember หรือคล้ายๆ กัน
    # ในที่นี้ผมจะ Query จาก User ที่มีความเกี่ยวข้องกับ class_id ของงานนี้
    results = (
        db.query(
            User.student_id.label("student_code"),
            User.first_name,
            User.last_name,
            ClassworkSubmission.submitted_at,
            ClassworkSubmission.submission_status,
            ClassworkSubmission.score,
            ClassworkSubmission.graded
        )
        .select_from(User)
        # เปลี่ยนจาก class_students.c.user_id เป็น class_students.c.student_id
        .join(class_students, User.user_id == class_students.c.student_id) 
        .filter(class_students.c.class_id == assignment.class_id)
        .outerjoin(ClassworkSubmission, 
            (ClassworkSubmission.assignment_id == assignment_id) & 
            (ClassworkSubmission.student_id == User.user_id)
        )
        .order_by(User.student_id.asc())
        .all()
    )

    # 3️.สร้างไฟล์ Excel
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "รายงานการส่งงาน"

    # เขียนข้อมูลหัวเรื่องงานไว้ที่แถวบนสุด
    ws.append([f"งาน: {assignment.title}", f"คะแนนเต็ม: {assignment.max_score}"])
    ws.append([f"กำหนดส่ง: {assignment.due_date.strftime('%d/%m/%Y %H:%M')}"])
    ws.append([]) # เว้นบรรทัด

    # เขียนหัวตาราง
    headers = ["รหัสนักศึกษา", "ชื่อ-นามสกุล", "วันที่ส่ง", "สถานะ", "สถานะการตรวจ", "คะแนน"]
    ws.append(headers)

    # 4️.วนลูปใส่ข้อมูลนักเรียน
    for r in results:
        full_name = f"{r.first_name or ''} {r.last_name or ''}".strip()
        submit_date = r.submitted_at.strftime("%d/%m/%Y %H:%M") if r.submitted_at else "ยังไม่ส่ง"
        
        # แปลงสถานะ SubmissionStatus (Enum) เป็นภาษาไทย
        status_th = "ยังไม่ส่ง"
        if r.submission_status:
            status_map = {"on_time": "ตรงเวลา", "late": "ล่าช้า"}
            status_th = status_map.get(r.submission_status.value, r.submission_status.value)

        grading_status = "ตรวจแล้ว" if r.graded else "รอตรวจ"
        score_display = r.score if r.graded else "-"

        ws.append([
            r.student_code or "-",
            full_name or "ไม่ระบุชื่อ",
            submit_date,
            status_th,
            grading_status,
            score_display
        ])

    # 5️.ส่งไฟล์กลับ
    output = io.BytesIO()
    wb.save(output)
    output.seek(0)

    filename = f"report_{assignment.title.replace(' ', '_')}.xlsx"
    return Response(
        content=output.getvalue(),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
