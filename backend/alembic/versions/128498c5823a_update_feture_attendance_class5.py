"""create attendance_sessions and backfill session_id

Revision ID: 128498c5823a
Revises: addef2024a70
Create Date: 2025-10-09 20:07:38.330626
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql as pg
import uuid

# revision identifiers, used by Alembic.
revision: str = "128498c5823a"
down_revision: Union[str, Sequence[str], None] = "addef2024a70"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1) สร้างตาราง attendance_sessions
    op.create_table(
        "attendance_sessions",
        sa.Column("session_id", pg.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("class_id", pg.UUID(as_uuid=True), sa.ForeignKey("classes.class_id", ondelete="CASCADE"), nullable=False),
        sa.Column("teacher_id", pg.UUID(as_uuid=True), sa.ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("anchor_lat", sa.Numeric(9, 6), nullable=False),
        sa.Column("anchor_lon", sa.Numeric(9, 6), nullable=False),
        sa.Column("start_time", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("end_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )

    # (ทางเลือก) index ที่ใช้บ่อย
    op.create_index("ix_attendance_sessions_class_id", "attendance_sessions", ["class_id"])
    op.create_index("ix_attendance_sessions_teacher_id", "attendance_sessions", ["teacher_id"])
    op.create_index("ix_attendance_sessions_active", "attendance_sessions", ["is_active"])

    # 2) เพิ่มคอลัมน์ session_id ใน attendances (ยังไม่บังคับ NOT NULL)
    op.add_column(
        "attendances",
        sa.Column("session_id", pg.UUID(as_uuid=True), nullable=True),
    )

    # 3) backfill: สร้าง session ต่อ class_id ที่มี attendance เดิมอยู่ แล้วโยง attendances เก่าเข้าไป
    conn = op.get_bind()

    # เอา class_id และ teacher_id ที่มี attendance เดิม
    result = conn.execute(
        sa.text(
            """
            SELECT DISTINCT a.class_id, c.teacher_id
            FROM attendances a
            JOIN classes c ON c.class_id = a.class_id
            """
        )
    ).fetchall()

    # สำหรับแต่ละ class_id ให้สร้าง 1 session (inactive, anchor 0,0) แล้วโยง attendances เก่าทั้งหมดของคลาสนั้นเข้าไป
    for row in result:
        class_id, teacher_id = row[0], row[1]
        session_id = str(uuid.uuid4())

        conn.execute(
            sa.text(
                """
                INSERT INTO attendance_sessions
                    (session_id, class_id, teacher_id, anchor_lat, anchor_lon, start_time, end_time, is_active, created_at)
                VALUES
                    (:sid, :cid, :tid, 0, 0, now(), now(), false, now())
                """
            ),
            {"sid": session_id, "cid": str(class_id), "tid": str(teacher_id)},
        )

        conn.execute(
            sa.text(
                """
                UPDATE attendances
                SET session_id = :sid
                WHERE class_id = :cid AND session_id IS NULL
                """
            ),
            {"sid": session_id, "cid": str(class_id)},
        )

    # 4) ตอนนี้ทุก attendance ควรมี session_id แล้ว → สร้าง FK และบังคับ NOT NULL
    op.create_foreign_key(
        "fk_attendances_session_id",
        "attendances",
        "attendance_sessions",
        ["session_id"],
        ["session_id"],
        ondelete="CASCADE",
    )

    op.alter_column(
        "attendances",
        "session_id",
        existing_type=pg.UUID(as_uuid=True),
        nullable=False,
    )

    # (ทางเลือก) สร้าง index บน attendances.session_id
    op.create_index("ix_attendances_session_id", "attendances", ["session_id"])


def downgrade() -> None:
    # ย้อนกลับ: เอา FK/Index ออกก่อน
    op.drop_index("ix_attendances_session_id", table_name="attendances")
    op.drop_constraint("fk_attendances_session_id", "attendances", type_="foreignkey")

    # ลบคอลัมน์ session_id
    op.drop_column("attendances", "session_id")

    # ลบ index ของ attendance_sessions
    op.drop_index("ix_attendance_sessions_active", table_name="attendance_sessions")
    op.drop_index("ix_attendance_sessions_teacher_id", table_name="attendance_sessions")
    op.drop_index("ix_attendance_sessions_class_id", table_name="attendance_sessions")

    # ลบตาราง attendance_sessions
    op.drop_table("attendance_sessions")
