# app/services/simple_classwork_service.py
from __future__ import annotations
from typing import Optional, List
from uuid import UUID
from datetime import datetime, timezone
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_, func, or_
import sqlalchemy as sa

from app.models.classwork_assignment import ClassworkAssignment
from app.models.classwork_submission import ClassworkSubmission
from app.models.classwork_enums import SubmissionLateness
from app.models.class_model import Class
from app.models.user import User
from app.models.association import class_students
from app.utils.pdf_storage import save_pdf  # คุณทำไว้แล้ว
from fastapi import HTTPException as ApiException

# ---------- Helper ----------
def _ensure_teacher_of_class(db: Session, teacher_id: UUID, class_id: UUID):
    cls = db.query(Class).filter(
        Class.class_id == class_id,
        Class.teacher_id == teacher_id
    ).first()
    if not cls:
        raise ApiException(403, "Only the class teacher can perform this action.")
    return cls

def _ensure_student_in_class(db: Session, student_id: UUID, class_id: UUID):
    exists = db.query(class_students).filter(
        class_students.c.class_id == class_id,
        class_students.c.student_id == student_id
    ).first()
    if not exists:
        raise ApiException(403, "Student is not enrolled in this class.")

# ---------- Core ----------
def create_assignment(
    db: Session,
    *,
    teacher_id: UUID,
    class_id: UUID,
    title: str,
    max_score: int,
    due_date: datetime,
) -> ClassworkAssignment:
    _ensure_teacher_of_class(db, teacher_id, class_id)

    obj = ClassworkAssignment(
        class_id=class_id,
        teacher_id=teacher_id,
        title=title,
        max_score=max_score,
        due_date=due_date,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj

async def submit_pdf(
    db: Session,
    *,
    assignment_id: UUID,
    student_id: UUID,
    file,  # UploadFile
) -> ClassworkSubmission:
    asg = db.query(ClassworkAssignment).filter(
        ClassworkAssignment.assignment_id == assignment_id
    ).first()
    if not asg:
        raise ApiException(404, "Assignment not found")

    # ต้องเป็นนักเรียนในคลาสนั้น
    _ensure_student_in_class(db, student_id, asg.class_id)

    # บันทึกไฟล์ PDF
    stored_path = await save_pdf(file)  # คืนเช่น "workpdf/<uuid>.pdf"

    # หา/สร้าง submission (1 คน ต่อ 1 assignment เท่านั้น - unique)
    sub = db.query(ClassworkSubmission).filter(
        ClassworkSubmission.assignment_id == assignment_id,
        ClassworkSubmission.student_id == student_id,
    ).first()

    now = datetime.now(timezone.utc)
    status = SubmissionLateness.NOT_SUBMITTED
    if now <= asg.due_date:
        status = SubmissionLateness.ON_TIME
    else:
        status = SubmissionLateness.LATE

    if sub:
        sub.content_url = stored_path
        sub.submitted_at = now
        sub.submission_status = status
        sub.updated_at = now
    else:
        sub = ClassworkSubmission(
            assignment_id=assignment_id,
            student_id=student_id,
            content_url=stored_path,
            submitted_at=now,
            submission_status=status,
            graded=False,
            score=None,
            created_at=now,
            updated_at=now,
        )
        db.add(sub)

    db.commit()
    db.refresh(sub)
    return sub

def list_assignments_for_student(
    db: Session, *, class_id: UUID, student_id: UUID
) -> List[tuple[ClassworkAssignment, Optional[ClassworkSubmission]]]:
    # ต้องเป็นนักเรียนในคลาส
    _ensure_student_in_class(db, student_id, class_id)

    # left join assignment กับ submission ของ "ฉัน"
    q = (
        db.query(ClassworkAssignment, ClassworkSubmission)
        .outerjoin(
            ClassworkSubmission,
            and_(
                ClassworkSubmission.assignment_id == ClassworkAssignment.assignment_id,
                ClassworkSubmission.student_id == student_id,
            ),
        )
        .filter(ClassworkAssignment.class_id == class_id)
        .order_by(ClassworkAssignment.due_date.asc())
    )
    return q.all()

def list_submissions_for_teacher(
    db: Session, *, assignment_id: UUID, teacher_id: UUID
) -> List[ClassworkSubmission]:
    # ยืนยันว่าเป็นครูเจ้าของงาน
    asg = db.query(ClassworkAssignment).filter(
        ClassworkAssignment.assignment_id == assignment_id
    ).first()
    if not asg:
        raise ApiException(404, "Assignment not found")
    _ensure_teacher_of_class(db, teacher_id, asg.class_id)

    subs = (
        db.query(ClassworkSubmission)
        .filter(ClassworkSubmission.assignment_id == assignment_id)
        .order_by(ClassworkSubmission.submitted_at.desc().nullslast())
        .all()
    )
    return subs

def grade_submission(
    db: Session, *, assignment_id: UUID, student_id: UUID, teacher_id: UUID, score: int
) -> ClassworkSubmission:
    # ตรวจว่าเป็นครูเจ้าของงาน
    asg = db.query(ClassworkAssignment).filter(
        ClassworkAssignment.assignment_id == assignment_id
    ).first()
    if not asg:
        raise ApiException(404, "Assignment not found")
    _ensure_teacher_of_class(db, teacher_id, asg.class_id)

    sub = db.query(ClassworkSubmission).filter(
        ClassworkSubmission.assignment_id == assignment_id,
        ClassworkSubmission.student_id == student_id,
    ).first()
    if not sub:
        raise ApiException(404, "Submission not found")

    if score < 0 or score > asg.max_score:
        raise ApiException(400, f"Score must be between 0 and {asg.max_score}")

    sub.score = score
    sub.graded = True
    sub.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(sub)
    return sub

def list_assignments_for_teacher_view(
    db,
    *,
    class_id: UUID,
    teacher_id: UUID,
    target_student_id: Optional[UUID] = None,
) -> List[tuple[ClassworkAssignment, Optional[ClassworkSubmission]]]:
    # ต้องเป็นครูเจ้าของคลาส
    cls = db.query(Class).filter(
        Class.class_id == class_id,
        Class.teacher_id == teacher_id
    ).first()
    if not cls:
        # ใช้ ApiException หรือ HTTPException ตามที่คุณตั้งไว้
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="Only the class teacher can view this class.")

    q = db.query(ClassworkAssignment, ClassworkSubmission).filter(
        ClassworkAssignment.class_id == class_id
    )

    if target_student_id:
        # left join เฉพาะ submission ของนักเรียนเป้าหมาย
        q = q.outerjoin(
            ClassworkSubmission,
            and_(
                ClassworkSubmission.assignment_id == ClassworkAssignment.assignment_id,
                ClassworkSubmission.student_id == target_student_id,
            ),
        )
    else:
        # ไม่มีนักเรียนเป้าหมาย -> left join เงื่อนไขเป็น False เพื่อให้ได้ None เสมอ
        q = q.outerjoin(
            ClassworkSubmission,
            and_(
                ClassworkSubmission.assignment_id == ClassworkAssignment.assignment_id,
                sa.text("FALSE")
            ),
        )

    q = q.order_by(ClassworkAssignment.due_date.asc())
    return q.all()