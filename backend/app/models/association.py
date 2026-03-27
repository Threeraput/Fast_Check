# backend/app/models/association.py
# เพิ่ม Integer เข้าไปใน list ของที่ถูก import
from sqlalchemy import DateTime, Table, Column, ForeignKey, Integer, func
from sqlalchemy.dialects.postgresql import UUID  # สำหรับ UUID ใน ForeignKey
from app.database import Base

# Many-to-Many: User <-> Role
user_roles = Table(
    "user_roles",
    Base.metadata,
    Column(
        "user_id", UUID(as_uuid=True), ForeignKey("users.user_id"), primary_key=True
    ),
    Column("role_id", Integer, ForeignKey("roles.id"), primary_key=True),
)

# Many-to-Many: Role <-> Permission
role_permissions = Table(
    "role_permissions",
    Base.metadata,
    Column("role_id", Integer, ForeignKey("roles.id"), primary_key=True),
    Column("permission_id", Integer, ForeignKey("permissions.id"), primary_key=True),
)

# Many-to-Many: Class <-> Student (User)
class_students = Table(
    "class_students",
    Base.metadata,
    Column(
        "class_id", UUID(as_uuid=True), ForeignKey("classes.class_id"), primary_key=True
    ),
    Column(
        "student_id", UUID(as_uuid=True), ForeignKey("users.user_id"), primary_key=True
    ),
    Column("joined_at", DateTime(timezone=True), server_default=func.now()),
)
