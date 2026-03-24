# backend/app/services/class_service.py
import uuid
from sqlalchemy.orm import Session
from sqlalchemy import select, and_
from fastapi import HTTPException, status
from typing import List, Optional
import random
import string
from sqlalchemy.exc import IntegrityError

from app.models.class_model import Class as ClassModel
from app.schemas.class_schema import ClassroomUpdate 
from app.models.user import User
from app.models.role import Role
from app.models.association import class_students # Table object สำหรับนักเรียน

# --- Imports ที่ต้องมีในไฟล์นี้ ---
import uuid
import secrets
from typing import List, Optional

from fastapi import HTTPException, status
from sqlalchemy import select, and_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

# สมมติว่าโมเดล/ตารางเหล่านี้ถูก import แล้ว
# from app.models.classroom import ClassModel, class_students
# from app.models.user import User
# from app.schemas.class_schema import ClassroomUpdate

# -----------------------------
# Helper: สร้างโค้ดเข้าคลาสแบบสุ่ม/ไม่ซ้ำ
# -----------------------------
_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # ตัดตัวที่สับสน เช่น I, O, 0, 1

def _gen_code(n: int = 6) -> str:
    return "".join(secrets.choice(_ALPHABET) for _ in range(n))

def generate_unique_code(db: Session, max_retries: int = 5, length: int = 6) -> str:
    """
    สร้างโค้ดความยาว length ที่ไม่ซ้ำใน DB
    1) สุ่มโค้ดด้วย secrets → ปลอดภัยกว่า random
    2) เช็คซ้ำชั้นแอพก่อน
    3) เผื่อชน UNIQUE ที่ DB ชั้น commit จะ retry ให้อีกชั้นใน create_classroom()
    """
    for _ in range(max_retries):
        code = _gen_code(length)
        exists = db.execute(
            select(ClassModel.class_id).where(ClassModel.code == code)
        ).first()
        if not exists:
            return code
    # ถ้ายังชน ให้คืนโค้ดยาวขึ้นเล็กน้อย เพื่อลดโอกาสชนบนชั้น DB
    return _gen_code(length + 1)

# -----------------------------
# Business Logic
# -----------------------------
def check_class_teacher(db: Session, class_id: uuid.UUID, user_id: uuid.UUID) -> ClassModel:
    """
    ตรวจสิทธิ์ว่าผู้ใช้เป็นอาจารย์เจ้าของคลาส
    """
    classroom: Optional[ClassModel] = db.execute(
        select(ClassModel).where(ClassModel.class_id == class_id)
    ).scalar_one_or_none()

    if not classroom:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found.")

    if classroom.teacher_id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the class teacher can perform this action.")
    return classroom


def create_classroom(db: Session, name: str, teacher_id: uuid.UUID, start_time=None, end_time=None) -> ClassModel:
    """
    สร้างห้องเรียนใหม่ (generate code อัตโนมัติ) พร้อมจัดการเคส UNIQUE ชน
    - ถ้า code ชน UNIQUE → retry อัตโนมัติ
    - ถ้า name ชน (แล้วแต่ constraint ของคุณ) → แจ้ง 400
    """
    for attempt in range(3):  # ลองซัก 3 ครั้งกรณี code ชนบน DB
        unique_code = generate_unique_code(db)

        new_class = ClassModel(
            name=name,
            code=unique_code,
            teacher_id=teacher_id,
            start_time=start_time,
            end_time=end_time
        )

        try:
            db.add(new_class)
            db.commit()
            db.refresh(new_class)
            return new_class
        except IntegrityError as e:
            db.rollback()
            msg = str(getattr(e, "orig", e)).lower()

            # เดาชื่อ constraint/คอลัมน์จากข้อความ error (ขึ้นกับ RDBMS/ชื่อ constraint ของคุณ)
            if "code" in msg:
                # code ชน → loop แล้วลองใหม่
                continue

            if "name" in msg:
                # ชื่อคลาสชน (ทั้งระบบ หรือชนนิยาม unique อื่น ๆ)
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Classroom name already exists.")

            # ไม่ทราบสาเหตุ → โยนต่อเป็น 500
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to create classroom.")

    # ถ้า retry แล้วยังชน code
    raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to generate unique join code. Please try again.")


def get_taught_classes(db: Session, teacher_id: uuid.UUID) -> List[ClassModel]:
    """
    ดึงรายการห้องเรียนที่อาจารย์คนนี้สอนทั้งหมด
    - Eager-load ความสัมพันธ์เพื่อลด N+1 (teacher, teacher.roles, students, students.roles)
    """
    stmt = (
        select(ClassModel)
        .where(ClassModel.teacher_id == teacher_id)
        .options(
            selectinload(ClassModel.teacher).selectinload(ClassModel.teacher.property.mapper.class_.roles),  # type: ignore
            selectinload(ClassModel.students),  # ถ้า students เป็น relationship ไป User
        )
    )
    # หมายเหตุ:
    # บรรทัด selectinload(...) อาจต้องแก้ให้ตรงกับโมเดลจริง:
    #   selectinload(ClassModel.teacher).selectinload(User.roles)
    #   selectinload(ClassModel.students).selectinload(User.roles)
    # ขึ้นอยู่กับการประกาศ relationship ในโมเดลของคุณ
    classes = db.scalars(stmt).all()
    return classes


def assign_student_to_class(db: Session, student_id: uuid.UUID, code: str):
    """
    นักเรียนเข้าร่วมห้องเรียนด้วยรหัสเข้าร่วม
    - 404 ถ้า code ไม่ถูกต้อง
    - 409 ถ้าเข้าร่วมแล้ว
    """
    code = (code or "").strip()

    classroom: Optional[ClassModel] = db.execute(
        select(ClassModel).where(ClassModel.code == code)
    ).scalar_one_or_none()

    if not classroom:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid classroom code.")

    # ตรวจซ้ำว่าลงทะเบียนแล้วหรือยัง
    already = db.execute(
        select(class_students)
        .where(
            and_(
                class_students.c.student_id == student_id,
                class_students.c.class_id == classroom.class_id,
            )
        )
    ).first()

    if already:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="You have already joined this classroom.")

    try:
        db.execute(
            class_students.insert().values(
                student_id=student_id,
                class_id=classroom.class_id
            )
        )
        db.commit()
    except IntegrityError:
        db.rollback()
        # ถ้าชน UNIQUE ที่ตารางเชื่อม (เช่น unique (student_id, class_id)) ก็ถือว่า join แล้ว
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="You have already joined this classroom.")


def remove_student_from_class(db: Session, student_id: uuid.UUID, class_id: uuid.UUID, current_user_id: uuid.UUID):
    """
    ลบนักเรียนออกจากห้องเรียน (อาจารย์เจ้าของคลาส หรือ นักเรียนคนนั้นเอง เท่านั้น)
    """
    classroom: Optional[ClassModel] = db.execute(
        select(ClassModel).where(ClassModel.class_id == class_id)
    ).scalar_one_or_none()

    if not classroom:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found.")

    is_teacher = classroom.teacher_id == current_user_id
    is_self = student_id == current_user_id

    if not (is_teacher or is_self):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not have permission to remove this student.")

    result = db.execute(
        class_students.delete().where(
            and_(
                class_students.c.student_id == student_id,
                class_students.c.class_id == class_id,
            )
        )
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student is not enrolled in this classroom.")

    db.commit()


def update_classroom(db: Session, class_id: uuid.UUID, user_id: uuid.UUID, update_data: ClassroomUpdate) -> ClassModel:
    """
    อัปเดตรายละเอียดห้องเรียน (เฉพาะอาจารย์เจ้าของคลาส)
    - ตรวจ start_time < end_time ถ้าถูกส่งมา
    - กันชื่อซ้ำ
    """
    classroom = check_class_teacher(db, class_id, user_id)

    data = update_data.model_dump(exclude_none=True)
    if not data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No fields provided for update.")

    # ตรวจสอบเวลา ถ้ามีสองช่องนี้
    start_time = data.get("start_time")
    end_time = data.get("end_time")
    if start_time and end_time and start_time >= end_time:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="start_time must be earlier than end_time.")

    for key, value in data.items():
        setattr(classroom, key, value)

    try:
        db.add(classroom)
        db.commit()
        db.refresh(classroom)
        return classroom
    except IntegrityError as e:
        db.rollback()
        msg = str(getattr(e, "orig", e)).lower()
        if "name" in msg:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Classroom name already exists.")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update classroom.")


def delete_classroom(db: Session, class_id: uuid.UUID, user_id: uuid.UUID, is_admin: bool) -> None:
    """
    ลบห้องเรียน (hard delete)
    - เฉพาะอาจารย์เจ้าของคลาสหรือแอดมินเท่านั้น
    - ลบแถวในตารางเชื่อม class_students ก่อน เพื่อลดโอกาสติด FK
    - ถ้าโครงสร้าง DB มี ON DELETE CASCADE อยู่แล้ว การลบ class_students อาจไม่จำเป็น
    """
    # 1) หา class
    classroom = db.execute(
        select(ClassModel).where(ClassModel.class_id == class_id)
    ).scalar_one_or_none()

    if not classroom:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found.")

    # 2) ตรวจสิทธิ์: admin ผ่าน, teacher ต้องเป็นเจ้าของคลาส
    if not is_admin and classroom.teacher_id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not allowed to delete this classroom.")

    try:
        # 3) ลบความสัมพันธ์ในตารางเชื่อมก่อน (กันกรณีไม่มี ON DELETE CASCADE)
        db.execute(
            class_students.delete().where(class_students.c.class_id == class_id)
        )

        # 4) (ถ้ามีตารางลูกอื่น ๆ เช่น assignments/submissions และยังไม่มี cascade)
        #    คุณสามารถลบด้วยมือที่นี่ก่อน db.delete(classroom) ตามลำดับลึกสุด → ตื้น
        #    ตัวอย่าง (คอมเมนต์ไว้เพราะขึ้นกับโมเดลจริง):
        # for assignment in list(getattr(classroom, "assignments", []) or []):
        #     # ถ้ามี submissions และไม่มี cascade ก็ลบ submissions ก่อน
        #     for sub in list(getattr(assignment, "submissions", []) or []):
        #         db.delete(sub)
        #     db.delete(assignment)

        # 5) ลบตัวคลาส
        db.delete(classroom)
        db.commit()

    except IntegrityError:
        db.rollback()
        # ยังมีระเบียนลูกอื่นที่ผูกอยู่ (เช่น assignments/submissions) และไม่มี CASCADE
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot delete classroom due to related records. Remove related objects or enable ON DELETE CASCADE."
        )
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete classroom."
        )

def get_classroom_with_relations(db: Session, class_id: uuid.UUID):
    """
    ดึงคลาสพร้อมความสัมพันธ์หลัก:
      - teacher, teacher.roles
      - students, students.roles
    """
    stmt = (
        select(ClassModel)
        .where(ClassModel.class_id == class_id)
        .options(
            selectinload(ClassModel.teacher).selectinload(User.roles),
            selectinload(ClassModel.students).selectinload(User.roles),
        )
    )
    return db.scalars(stmt).first()

def get_enrolled_classes(db: Session, student_id: uuid.UUID):
    student = db.query(User).filter(User.user_id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")
    return student.enrolled_classes  # จาก relationship ใน model
