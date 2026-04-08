# backend/app/services/classwork_service.py
import uuid
from sqlalchemy.orm import Session
from sqlalchemy import select

# นำเข้า Model ของเรา
from app.models.classwork_assignment import AssignmentComment

def create_comment(db: Session, assignment_id: uuid.UUID, user_id: uuid.UUID, content: str) -> AssignmentComment:
    """
    สร้างคอมเมนต์ใหม่ในงาน (Assignment)
    """
    new_comment = AssignmentComment(
        assignment_id=assignment_id,
        user_id=user_id,
        content=content
    )
    
    db.add(new_comment)
    db.commit()
    db.refresh(new_comment)
    
    return new_comment

def get_comments_by_assignment(db: Session, assignment_id: uuid.UUID):
    """
    ดึงคอมเมนต์ทั้งหมดของงานชิ้นนั้น
    - เรียงลำดับจากเก่าไปใหม่ (asc) เพื่อให้แสดงผลเหมือนแชทปกติ
    """
    stmt = (
        select(AssignmentComment)
        .where(AssignmentComment.assignment_id == assignment_id)
        .order_by(AssignmentComment.created_at.asc())
    )
    
    comments = db.scalars(stmt).all()
    return comments