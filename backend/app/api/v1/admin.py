from fastapi import APIRouter, Depends, HTTPException, status, Path, Query
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
import uuid
from datetime import datetime, timezone
import string
import random

from app.database import get_db
from app.schemas.user_schema import UserResponse
from app.schemas.admin_schema import (
    AdminUsersPage,
    SystemSummaryReport,
    AdminClassesPage,
    AdminClassSummary,
    AdminCreateClass,  #  เพิ่ม schema สำหรับสร้างคลาส
)
from app.models.user import User
from app.models.role import Role
from app.models.class_model import Class as ClassModel
from app.models.attendance import Attendance
from app.models.association import user_roles
#  association table สำหรับนับนักเรียนในคลาส
from app.models.association import class_students
from app.services import class_service
from app.services.db_service import approve_teacher
from app.core.deps import get_current_admin_user

router = APIRouter(prefix="/admin", tags=["Admin"])



#  helper: สร้าง code ที่ไม่ซ้ำ
def _generate_unique_class_code(db: Session, length: int = 6) -> str:
    chars = string.ascii_uppercase + string.digits
    tries = 0
    while True:
        code = "".join(random.choices(chars, k=length))
        exists = (
            db.query(ClassModel)
            .filter(func.lower(ClassModel.code) == code.lower())
            .first()
        )
        if not exists:
            return code
        tries += 1
        if tries > 20:
            # กันไว้กรณีชนเยอะ เพิ่มความยาว
            length += 1
            tries = 0

@router.get("/status", response_model=dict)
async def get_admin_status(current_user: User = Depends(get_current_admin_user)):
    return {"message": f"Admin endpoint is working! Welcome, {current_user.username}."}

@router.post("/users/{user_id}/approve-teacher", response_model=UserResponse)
async def approve_user_as_teacher(
    user_id: uuid.UUID = Path(..., description="The UUID of the teacher user to approve"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    approved_user = approve_teacher(db, user_id)
    if not approved_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found or is not a teacher."
        )
    user_roles = [role.name for role in approved_user.roles]
    return UserResponse(
        user_id=approved_user.user_id,
        username=approved_user.username,
        first_name=approved_user.first_name,
        last_name=approved_user.last_name,
        email=approved_user.email,
        is_active=approved_user.is_active,
        is_approved=getattr(approved_user, "is_approved", None),
        created_at=approved_user.created_at,
        updated_at=approved_user.updated_at,
        last_login_at=approved_user.last_login_at,
        roles=user_roles,
        # ส่ง avatar_url ออกไปเพื่อให้ Frontend แสดงรูปจริงได้
        avatar_url=getattr(approved_user, "avatar_url", None),
    )

@router.get("/pending-teachers", response_model=List[UserResponse])
async def get_pending_teachers(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    pending_teachers = db.query(User).filter(User.is_approved == False).all()
    response_list: List[UserResponse] = []
    for user in pending_teachers:
        user_roles = [role.name for role in user.roles]
        response_list.append(
            UserResponse(
                user_id=user.user_id,
                username=user.username,
                first_name=user.first_name,
                last_name=user.last_name,
                email=user.email,
                is_active=user.is_active,
                is_approved=getattr(user, "is_approved", None),
                created_at=user.created_at,
                updated_at=user.updated_at,
                last_login_at=user.last_login_at,
                roles=user_roles,
                # ส่ง avatar_url ออกด้วย
                avatar_url=getattr(user, "avatar_url", None),
            )
        )
    return response_list

# ===========================
# Admin - List all users (with search, role filter, pagination)
# ===========================
@router.get("/users", response_model=AdminUsersPage)
async def admin_list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
    q: Optional[str] = Query(None, description="search by username/email/first/last name"),
    role: Optional[str] = Query(None, description="filter by role: admin|teacher|student"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    # 🚨 1. ดักเงื่อนไขแรกสุดเลย: เอาเฉพาะคนที่ "ยังไม่โดนลบ" (deleted_at เป็น None)
    query = db.query(User).filter(User.deleted_at.is_(None))

    if q:
        like = f"%{q.strip()}%"
        query = query.filter(or_(
            User.username.ilike(like),
            User.email.ilike(like),
            User.first_name.ilike(like),
            User.last_name.ilike(like),
        ))

    if role:
        rl = role.strip().lower()
        query = query.join(User.roles).filter(func.lower(Role.name) == rl)

    total = query.count()
    rows = (
        query
        .order_by(User.created_at.desc())
        .limit(limit)
        .offset(offset)
        .all()
    )

    items: List[UserResponse] = []
    for u in rows:
        items.append(
            UserResponse(
                user_id=u.user_id,
                username=u.username,
                first_name=u.first_name,
                last_name=u.last_name,
                email=u.email,
                is_active=u.is_active,
                is_approved=getattr(u, "is_approved", None),
                created_at=u.created_at,
                updated_at=u.updated_at,
                last_login_at=u.last_login_at,
                roles=[r.name for r in u.roles],
                avatar_url=getattr(u, "avatar_url", None),
                # 🚨 2. ส่งค่า deleted_at กลับไปให้หน้าบ้านด้วย 
                # (เผื่อในอนาคต Flutter อยากเอาไปเช็คอะไรเพิ่ม)
                deleted_at=getattr(u, "deleted_at", None),
            )
        )

    return AdminUsersPage(total=total, limit=limit, offset=offset, items=items)

# ===========================
# Admin - List users in TRASH (Soft Deleted)
# ===========================
@router.get("/users/trash", response_model=AdminUsersPage)
async def admin_list_trash_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
    q: Optional[str] = Query(None, description="search by username/email/first/last name"),
    role: Optional[str] = Query(None, description="filter by role: admin|teacher|student"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    # 🚨 1. หัวใจหลัก: ดึงเฉพาะคนที่ถูกลบแล้ว (deleted_at ไม่ใช่ None)
    query = db.query(User).filter(User.deleted_at.isnot(None))

    if q:
        like = f"%{q.strip()}%"
        query = query.filter(or_(
            User.username.ilike(like),
            User.email.ilike(like),
            User.first_name.ilike(like),
            User.last_name.ilike(like),
        ))

    if role:
        rl = role.strip().lower()
        query = query.join(User.roles).filter(func.lower(Role.name) == rl)

    total = query.count()
    rows = (
        query
        # 🚨 2. เปลี่ยนมาเรียงตาม "วันที่โดนลบ" (ล่าสุดอยู่บนสุด) จะสมเหตุสมผลกว่า
        .order_by(User.deleted_at.desc()) 
        .limit(limit)
        .offset(offset)
        .all()
    )

    items: List[UserResponse] = []
    for u in rows:
        items.append(
            UserResponse(
                user_id=u.user_id,
                username=u.username,
                first_name=u.first_name,
                last_name=u.last_name,
                email=u.email,
                is_active=u.is_active,
                is_approved=getattr(u, "is_approved", None),
                created_at=u.created_at,
                updated_at=u.updated_at,
                last_login_at=u.last_login_at,
                roles=[r.name for r in u.roles],
                avatar_url=getattr(u, "avatar_url", None),
                # ส่งค่า deleted_at กลับไปด้วย เพื่อให้หน้าแอปเอาไปโชว์ว่า "ลบไปเมื่อไหร่"
                deleted_at=u.deleted_at, 
            )
        )

    return AdminUsersPage(total=total, limit=limit, offset=offset, items=items)

# ===========================
# Admin - Soft Delete user (ย้ายลงถังขยะ)
# ===========================
@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_user(
    user_id: uuid.UUID = Path(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    u = db.get(User, user_id)
    
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
        
    # เช็คก่อนว่าคนนี้อยู่ในถังขยะอยู่แล้วหรือเปล่า จะได้ไม่ปั๊มเวลาซ้ำ
    if getattr(u, "deleted_at", None) is not None:
        raise HTTPException(status_code=400, detail="User นี้ถูกลบไปแล้ว")

    # 🚨 ยกเลิกการใช้ db.delete(u) แล้วเปลี่ยนมาประทับเวลาแทน
    u.deleted_at = datetime.now(timezone.utc)
    
    # 💡 ออปชันเสริม: จะปรับ is_active เป็น False ด้วยก็ได้ เพื่อความชัวร์ในหลายๆ ระบบ
    # u.is_active = False 

    db.add(u)
    db.commit()
    return None

# ===========================
# Admin - Restore user from TRASH
# ===========================
@router.patch("/users/{user_id}/restore", response_model=UserResponse)
async def admin_restore_user(
    user_id: uuid.UUID = Path(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    u = db.get(User, user_id)
    
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
        
    # 🚨 เช็คก่อนว่า User คนนี้อยู่ในถังขยะจริงๆ ไหม (ถ้าไม่ได้โดนลบ ก็ไม่รู้จะกู้คืนทำไม)
    if getattr(u, "deleted_at", None) is None:
        raise HTTPException(status_code=400, detail="User นี้ไม่ได้อยู่ในถังขยะและยังใช้งานได้ตามปกติ")

    # 🌟 พระเอกของงานนี้: เช็ดตรายางวันที่โดนลบทิ้งไปซะ!
    u.deleted_at = None
    
    # 💡 ออปชันเสริม: ถ้าตอนคุณทำ Soft Delete มีการตั้ง u.is_active = False ไปด้วย 
    # ตอนกู้คืนก็อย่าลืมปลุกให้เขากลับมา Active ด้วยนะครับ
    u.is_active = True 

    db.add(u)
    db.commit()
    
    # ดึงข้อมูลล่าสุดหลังจากอัปเดต เพื่อส่งกลับไปให้หน้าบ้านอัปเดต UI
    db.refresh(u) 
    
    # (ถ้ามีตัวแปร avatar_url อย่าลืมดึงมาใส่ด้วยแบบนี้ครับ)
    # เราสามารถใช้ from_orm หรือส่งเป็น dict ได้ขึ้นอยู่กับโครงสร้างที่คุณใช้ประจำ
    return UserResponse(
        user_id=u.user_id,
        username=u.username,
        first_name=u.first_name,
        last_name=u.last_name,
        email=u.email,
        is_active=u.is_active,
        is_approved=getattr(u, "is_approved", None),
        created_at=u.created_at,
        updated_at=u.updated_at,
        last_login_at=u.last_login_at,
        roles=[r.name for r in u.roles],
        avatar_url=getattr(u, "avatar_url", None),
        deleted_at=u.deleted_at, # ตอนนี้จะเป็น None แล้ว
    )

# ===========================
# Admin - System summary report
# ===========================
@router.get("/reports/summary", response_model=SystemSummaryReport)
async def admin_system_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
    start: Optional[datetime] = Query(None, description="ISO datetime start for attendance range"),
    end: Optional[datetime] = Query(None, description="ISO datetime end for attendance range"),
):
    total_users = db.query(func.count(User.user_id)).scalar() or 0
    total_admins = (
        db.query(func.count(User.user_id))
        .join(User.roles)
        .filter(func.lower(Role.name) == "admin")
        .scalar() or 0
    )
    total_teachers = (
        db.query(func.count(User.user_id))
        .join(User.roles)
        .filter(func.lower(Role.name) == "teacher")
        .scalar() or 0
    )
    total_students = (
        db.query(func.count(User.user_id))
        .join(User.roles)
        .filter(func.lower(Role.name) == "student")
        .scalar() or 0
    )

    total_classes = db.query(func.count(ClassModel.class_id)).scalar() or 0
    total_attendances = db.query(func.count(Attendance.attendance_id)).scalar() or 0

    q_att = db.query(func.count(Attendance.attendance_id))
    if start:
        q_att = q_att.filter(Attendance.timestamp >= start)
    if end:
        q_att = q_att.filter(Attendance.timestamp <= end)
    total_attendances_in_range = q_att.scalar() or 0

    return SystemSummaryReport(
        total_users=total_users,
        total_admins=total_admins,
        total_teachers=total_teachers,
        total_students=total_students,
        total_classes=total_classes,
        total_attendances=total_attendances,
        total_attendances_in_range=total_attendances_in_range,
        range_start=start,
        range_end=end,
    )

# ===========================
# Admin - List all classes (search + pagination)
# ===========================
@router.get("/classes", response_model=AdminClassesPage)
async def admin_list_classes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
    q: Optional[str] = Query(None, description="search by class name/code"),
    is_archived: Optional[bool] = Query(None, description="Filter by archived status"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    base = db.query(ClassModel)
    if is_archived is not None:
        base = base.filter(ClassModel.is_archived == is_archived)
    if q:
        like = f"%{q.strip()}%"
        filters = [ClassModel.name.ilike(like)]
        # ถ้ามีฟิลด์ code ให้ค้นหาด้วย
        if hasattr(ClassModel, "code"):
            filters.append(getattr(ClassModel, "code").ilike(like))
        base = base.filter(or_(*filters))

    total = base.count()
    rows = (
        base.order_by(getattr(ClassModel, "created_at", ClassModel.name).desc())
        .limit(limit)
        .offset(offset)
        .all()
    )

    # นับนักเรียนต่อคลาสด้วย association table
    class_ids = [r.class_id for r in rows]
    counts_map = {cid: 0 for cid in class_ids}
    if class_ids:
        count_rows = (
            db.query(class_students.c.class_id, func.count(class_students.c.student_id))
            .filter(class_students.c.class_id.in_(class_ids))
            .group_by(class_students.c.class_id)
            .all()
        )
        for cid, cnt in count_rows:
            counts_map[cid] = int(cnt)

    items: List[AdminClassSummary] = []
    for c in rows:
        teacher = db.query(User).filter(User.user_id == getattr(c, "teacher_id", None)).first()
        items.append(
            AdminClassSummary(
                class_id=c.class_id,
                name=c.name,
                code=getattr(c, "code", None),
                student_count=counts_map.get(c.class_id, 0),
                created_at=getattr(c, "created_at", datetime.utcnow()),
                is_archived=getattr(c, "is_archived", False),
                teacher=UserResponse(
                    user_id=teacher.user_id,
                    username=teacher.username,
                    first_name=teacher.first_name,
                    last_name=teacher.last_name,
                    email=teacher.email,
                    is_active=teacher.is_active,
                    is_approved=getattr(teacher, "is_approved", None),
                    created_at=teacher.created_at,
                    updated_at=teacher.updated_at,
                    last_login_at=teacher.last_login_at,
                    roles=[r.name for r in teacher.roles],
                    avatar_url=getattr(teacher, "avatar_url", None),  # ส่ง avatar_url
                ) if teacher else None,
            )
        )

    return AdminClassesPage(
        total=total,
        limit=limit,
        offset=offset,
        items=items,
    )

# ===========================
# Admin - Archive class
# ===========================
@router.delete("/classes/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_archive_class(
    class_id: uuid.UUID = Path(..., description="UUID of the classroom to archive"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    class_service.delete_classroom(
        db=db,
        class_id=class_id,
        user_id=current_user.user_id,
        is_admin=True,
    )
    return None

# ===========================
# Admin - Create class (แก้ 500 จาก code = NULL)
# ===========================
@router.post("/classes", response_model=AdminClassSummary, status_code=status.HTTP_201_CREATED)
def admin_create_class(
    payload: AdminCreateClass,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_admin_user),
):
    # ตรวจสอบครู
    teacher = db.query(User).filter(User.user_id == payload.teacher_id).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")

    role_names = {r.name.lower() for r in teacher.roles}
    if "teacher" not in role_names and "admin" not in role_names:
        raise HTTPException(status_code=400, detail="The provided user is not a teacher/admin")

    # เตรียม code: ใช้จาก payload หรือ gen ใหม่
    code: str
    if payload.code and payload.code.strip():
        code = payload.code.strip().upper()
        exists = (
            db.query(ClassModel)
            .filter(func.lower(ClassModel.code) == code.lower())
            .first()
        )
        if exists:
            raise HTTPException(status_code=409, detail="Class code already exists")
    else:
        code = _generate_unique_class_code(db)

    now = datetime.utcnow()

    # สร้างคลาสใหม่ — ใส่ code ให้ไม่ NULL และไม่ซ้ำ
    new_class = ClassModel(
        name=payload.name.strip(),
        code=code,
        description=payload.description,
        teacher_id=payload.teacher_id,
        start_time=payload.start_time,
        end_time=payload.end_time,
        created_at=now,
        updated_at=now,
    )

    db.add(new_class)
    db.commit()
    db.refresh(new_class)

    return AdminClassSummary(
        class_id=new_class.class_id,
        name=new_class.name,
        code=new_class.code,
        student_count=0,
        created_at=new_class.created_at or now,
        teacher=UserResponse(
            user_id=teacher.user_id,
            username=teacher.username,
            first_name=teacher.first_name,
            last_name=teacher.last_name,
            email=teacher.email,
            is_active=teacher.is_active,
            is_approved=getattr(teacher, "is_approved", None),
            created_at=teacher.created_at,
            updated_at=teacher.updated_at,
            last_login_at=teacher.last_login_at,
            roles=[r.name for r in teacher.roles],
            avatar_url=getattr(teacher, "avatar_url", None),
        ),
    )