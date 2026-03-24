# app/api/v1/classwork_simple.py
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime

from app.database import get_db
from app.core.deps import get_current_user, role_required
from app.models.user import User
from app.schemas.classwork_new_schema import (
    AssignmentCreate, AssignmentResponse,
    SubmissionResponse, AssignmentWithMySubmission, GradeSubmission,
)
from app.models.classwork_enums import SubmissionLateness
from app.services.simple_classwork_service import (
    create_assignment, submit_pdf,
    list_assignments_for_student, list_submissions_for_teacher,
    grade_submission , _ensure_teacher_of_class
)


router = APIRouter(prefix="/classwork-simple", tags=["Classwork (Simple)"])

# -----------------------------
# ครู: สร้างงานระดับคลาส
# -----------------------------
@router.post("/assignments", response_model=AssignmentResponse,
             dependencies=[Depends(role_required(["teacher"]))],
             status_code=status.HTTP_201_CREATED)
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
        resp.append(AssignmentWithMySubmission(
            assignment_id=asg.assignment_id,
            class_id=asg.class_id,
            teacher_id=asg.teacher_id,
            title=asg.title,
            max_score=asg.max_score,
            due_date=asg.due_date,
            computed_status=computed,
            my_submission=mymini,
        ))
    return resp


# -----------------------------
# นักเรียน: ส่งไฟล์ PDF
# -----------------------------
@router.post("/assignments/{assignment_id}/submit", response_model=SubmissionResponse,
             dependencies=[Depends(role_required(["student"]))])
async def submit_assignment_pdf_route(
    assignment_id: UUID,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    if file.content_type not in {"application/pdf"}:
        raise HTTPException(400, "Only PDF is allowed")
    sub = await submit_pdf(db, assignment_id=assignment_id, student_id=me.user_id, file=file)
    return sub

# -----------------------------
# ครู: ดูการส่งทั้งหมดของงานหนึ่ง
# -----------------------------
@router.get("/assignments/{assignment_id}/submissions",
            response_model=List[SubmissionResponse],
            dependencies=[Depends(role_required(["teacher"]))])
def list_submissions_for_teacher_route(
    assignment_id: UUID,
    db: Session = Depends(get_db),
    me: User = Depends(get_current_user),
):
    items = list_submissions_for_teacher(db, assignment_id=assignment_id, teacher_id=me.user_id)
    return items

# -----------------------------
# ครู: ให้คะแนน
# -----------------------------
@router.post("/assignments/{assignment_id}/grade",
             response_model=SubmissionResponse,
             dependencies=[Depends(role_required(["teacher"]))])
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
