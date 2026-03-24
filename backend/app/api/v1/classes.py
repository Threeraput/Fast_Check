import uuid
from typing import List, Iterable, Set, Optional, Dict, Any

from fastapi import APIRouter, Depends, HTTPException, status, Path, Response
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.class_schema import (
    ClassMembersResponse,
    ClassroomCreate,
    ClassroomResponse,
    ClassroomJoin,
    ClassroomUpdate,
)
from app.schemas.user_schema import UserPublic
from app.models.user import User
from app.core.deps import get_current_active_user, get_current_user
from app.services import class_service
from app.models.class_model import Class as ClassModel
from app.models.association import class_students

router = APIRouter(prefix="/classes", tags=["Classes"])


# ---------------------------
# Helpers
# ---------------------------
def _safe_list(xs: Iterable) -> list:
    return list(xs or [])


def _role_names(user_obj) -> List[str]:
    try:
        return [r.name for r in _safe_list(getattr(user_obj, "roles", []))]
    except Exception:
        return []


def _has_any_role(user: User, targets: Set[str]) -> bool:
    return bool({r.name for r in _safe_list(getattr(user, "roles", []))} & targets)


def _user_payload(u) -> Optional[Dict[str, Any]]:
    if not u:
        return None
    return {
        "user_id": getattr(u, "user_id", None),
        "username": getattr(u, "username", None),
        "email": getattr(u, "email", None),
        # เติมเท่าที่ schema UserPublic รองรับ
        "full_name": getattr(u, "full_name", None),
        "is_active": getattr(u, "is_active", None),
        "created_at": getattr(u, "created_at", None),
        "updated_at": getattr(u, "updated_at", None),
        # roles -> เป็น list[str]
        "roles": _role_names(u),
    }


def _serialize_classroom(obj) -> ClassroomResponse:
    """
    แปลง ORM -> Pydantic โดย 'ประกอบ payload' เอง (เลี่ยงปัญหา roles เป็น ORM object)
    """
    payload = {
        "class_id": getattr(obj, "class_id", None),
        "name": getattr(obj, "name", None),
        "code": getattr(obj, "code", None),
        "teacher_id": getattr(obj, "teacher_id", None),
        "created_at": getattr(obj, "created_at", None),
        "teacher": _user_payload(getattr(obj, "teacher", None)),
        "students": [_user_payload(s) for s in _safe_list(getattr(obj, "students", []))],
    }
    return ClassroomResponse.model_validate(payload)


def _serialize_classroom_list(objs) -> List[ClassroomResponse]:
    return [_serialize_classroom(o) for o in _safe_list(objs)]


# ------------------------------------
# 1. POST /classes - สร้างห้องเรียนใหม่ (Teacher/Admin)
# ------------------------------------
@router.post("/", response_model=ClassroomResponse, status_code=status.HTTP_201_CREATED)
async def create_classroom(
    class_create: ClassroomCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _has_any_role(current_user, {"teacher", "admin"}):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only teachers or admins can create a classroom.",
        )

    new_class = class_service.create_classroom(
        db=db,
        name=class_create.name,
        teacher_id=current_user.user_id,
        start_time=class_create.start_time,
        end_time=class_create.end_time,
    )
    return _serialize_classroom(new_class)


# ------------------------------------
# 2. GET /classes/taught - ดูห้องเรียนที่สอน (Teacher/Admin)
# ------------------------------------
@router.get("/taught", response_model=List[ClassroomResponse])
async def get_taught_classes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _has_any_role(current_user, {"teacher", "admin"}):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You are not authorized as a teacher/admin.",
        )
    classes = class_service.get_taught_classes(db, current_user.user_id)
    return _serialize_classroom_list(classes)


# ------------------------------------
# 3. POST /classes/join - นักเรียนเข้าร่วมห้องเรียน (Student Only)
# ------------------------------------
@router.post("/join", status_code=status.HTTP_200_OK)
async def join_classroom(
    join_data: ClassroomJoin,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _has_any_role(current_user, {"student"}):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only students can join a classroom.",
        )

    code = (join_data.code or "").strip()
    class_service.assign_student_to_class(
        db=db,
        student_id=current_user.user_id,
        code=code,
    )
    return {"message": "Successfully joined the classroom."}


# ------------------------------------
# 4. DELETE /classes/{class_id}/students/{student_id} - ลบนักเรียน (Teacher/Student)
# ------------------------------------
@router.delete("/{class_id}/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_student(
    class_id: uuid.UUID = Path(..., description="UUID of the classroom"),
    student_id: uuid.UUID = Path(..., description="UUID of the student to remove"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    class_service.remove_student_from_class(
        db=db,
        student_id=student_id,
        class_id=class_id,
        current_user_id=current_user.user_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ------------------------------------
# 5. PATCH /classes/{class_id} - แก้ไขรายละเอียดห้องเรียน (Teacher/Admin)
# ------------------------------------
@router.patch("/{class_id}", response_model=ClassroomResponse)
async def update_classroom_details(
    class_update: ClassroomUpdate,
    class_id: uuid.UUID = Path(..., description="UUID of the classroom to update"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _has_any_role(current_user, {"teacher", "admin"}):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only teachers or admins can update a classroom.",
        )

    updated_class = class_service.update_classroom(
        db=db,
        class_id=class_id,
        user_id=current_user.user_id,
        update_data=class_update,
    )
    return _serialize_classroom(updated_class)


# ------------------------------------
# 6. DELETE /classes/{class_id} - ลบห้องเรียน (Teacher/Admin)
# ------------------------------------
@router.delete("/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_classroom(
    class_id: uuid.UUID = Path(..., description="UUID of the classroom to delete"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    ลบห้องเรียนทั้งหมด รวมถึง Assignment และ Submissions ที่เกี่ยวข้อง (hard delete).
    ต้องเป็นอาจารย์เจ้าของคลาส หรือ Admin เท่านั้น.
    """
    is_admin = _has_any_role(current_user, {"admin"})

    class_service.delete_classroom(
        db=db,
        class_id=class_id,
        user_id=current_user.user_id,
        is_admin=is_admin,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ------------------------------------
# 7. GET /classes/enrolled - ห้องที่ลงทะเบียน (Student Only)
# ------------------------------------
@router.get("/enrolled", response_model=List[ClassroomResponse])
async def get_enrolled_classes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not _has_any_role(current_user, {"student"}):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only students can view enrolled classes.",
        )
    classes = class_service.get_enrolled_classes(db, current_user.user_id)
    return _serialize_classroom_list(classes)


# ------------------------------------
# 8. GET /classes/{class_id} - รายละเอียดห้อง (Teacher/Admin)
# ------------------------------------
@router.get("/{class_id}", response_model=ClassroomResponse)
async def get_classroom_details(
    class_id: uuid.UUID = Path(..., description="UUID of the classroom"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    ดึงรายละเอียดห้องเรียน (Teacher/Admin เท่านั้น)
    - Admin: เข้าถึงได้ทุกคลาส
    - Teacher: ต้องเป็นเจ้าของคลาส
    """
    is_admin = _has_any_role(current_user, {"admin"})
    if not is_admin:
        class_service.check_class_teacher(db, class_id, current_user.user_id)

    classroom = class_service.get_classroom_with_relations(db, class_id)
    if not classroom:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found.")

    return _serialize_classroom(classroom)


# ------------------------------------
# 9. GET /classes/{class_id}/members - สมาชิกในคลาส (Teacher/Admin/Student member)
# ------------------------------------
@router.get("/{class_id}/members", response_model=ClassMembersResponse)
def get_class_members_for_members(
    class_id: uuid.UUID = Path(..., description="UUID of class"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    # 1) หา class
    cls = db.get(ClassModel, class_id)
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found")

    # 2) ตรวจสิทธิ์
    user_roles = _role_names(current_user)
    is_admin = "admin" in user_roles
    is_teacher_of_class = (current_user.user_id == cls.teacher_id)
    is_student_in_class = (
        db.query(class_students.c.class_id)
        .filter(
            class_students.c.class_id == class_id,
            class_students.c.student_id == current_user.user_id,
        )
        .first()
        is not None
    )
    if not (is_admin or is_teacher_of_class or is_student_in_class):
        raise HTTPException(status_code=403, detail="Forbidden")

    # 3) โหลด teacher และ students
    teacher_obj = db.query(User).filter(User.user_id == cls.teacher_id).first()
    if not teacher_obj:
        raise HTTPException(status_code=404, detail="Teacher not found")

    student_rows = (
        db.query(User)
        .join(class_students, class_students.c.student_id == User.user_id)
        .filter(class_students.c.class_id == class_id)
        .all()
    )

    # 4) ใช้ payload dict -> model_validate (v2 safe)
    teacher_payload = _user_payload(teacher_obj)
    students_payload = [_user_payload(s) for s in student_rows]

    return ClassMembersResponse(
        class_id=cls.class_id,
        name=getattr(cls, "name", str(class_id)),
        code=getattr(cls, "code", None),
        teacher=UserPublic.model_validate(teacher_payload),
        students=[UserPublic.model_validate(p) for p in students_payload],
    )
