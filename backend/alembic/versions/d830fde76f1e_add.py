"""add

Revision ID: d830fde76f1e
Revises: 1d7adc60a2f3
Create Date: 2025-11-07 08:32:42.647442

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy import inspect
from sqlalchemy import text

# revision identifiers, used by Alembic.
revision: str = 'd830fde76f1e'
down_revision: Union[str, Sequence[str], None] = '1d7adc60a2f3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _insp(bind=None):
    return inspect(bind or op.get_bind())

def _table_exists(table: str, bind=None) -> bool:
    return _insp(bind).has_table(table)

def _column_exists(table: str, column: str, bind=None) -> bool:
    insp = _insp(bind)
    if not insp.has_table(table):
        return False
    return column in [c["name"] for c in insp.get_columns(table)]

def _index_exists(table: str, index_name: str) -> bool:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        # best-effort สำหรับ non-PG
        return False
    res = bind.execute(
        text("""SELECT 1 FROM pg_indexes WHERE tablename=:t AND indexname=:i"""),
        {"t": table, "i": index_name},
    ).fetchone()
    return bool(res)

def _fk_exists(table: str, fk_name: str) -> bool:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        return False
    res = bind.execute(
        text("""
        SELECT 1
        FROM information_schema.table_constraints
        WHERE table_name = :t
          AND constraint_type = 'FOREIGN KEY'
          AND constraint_name = :n
        """),
        {"t": table, "n": fk_name},
    ).fetchone()
    return bool(res)

def upgrade():
    bind = op.get_bind()

    # --- Announcements: index/FK เช็คก่อนสร้าง ---
    if _table_exists("announcements", bind):
        # indexes
        ix_class = "ix_announcements_class_id"
        ix_teacher = "ix_announcements_teacher_id"
        if not _index_exists("announcements", ix_class):
            op.create_index(op.f(ix_class), "announcements", ["class_id"], unique=False)
        if not _index_exists("announcements", ix_teacher):
            op.create_index(op.f(ix_teacher), "announcements", ["teacher_id"], unique=False)

        # FKs (ใช้ชื่อที่ alembic สร้างอัตโนมัติได้ อาจเป็น None; ใส่ชื่อคงที่ชัดเจนแทน)
        fk_teacher = "announcements_teacher_id_users_user_id_fkey"
        fk_class = "announcements_class_id_classes_class_id_fkey"

        # ลอง drop ของเดิมถ้ามีชื่อเดิมจาก auto-gen รอบก่อน (เงียบถ้าไม่มี)
        try:
            op.drop_constraint(op.f("announcements_class_id_fkey"), "announcements", type_="foreignkey")
        except Exception:
            pass
        try:
            op.drop_constraint(op.f("announcements_teacher_id_fkey"), "announcements", type_="foreignkey")
        except Exception:
            pass

        if not _fk_exists("announcements", fk_teacher):
            op.create_foreign_key(
                fk_teacher, "announcements", "users",
                ["teacher_id"], ["user_id"]
            )
        if not _fk_exists("announcements", fk_class):
            op.create_foreign_key(
                fk_class, "announcements", "classes",
                ["class_id"], ["class_id"]
            )

    # --- attendance_reports: คอลัมน์นับ session เพิ่มแบบมี default ชั่วคราวแล้วลบออก ---
    if _table_exists("attendance_reports", bind):
        cols = [
            ("unverified_sessions", sa.Integer(), "0"),
            ("left_early_no_reverify_sessions", sa.Integer(), "0"),
            ("left_early_real_sessions", sa.Integer(), "0"),
        ]
        for name, typ, default in cols:
            if not _column_exists("attendance_reports", name, bind):
                op.add_column(
                    "attendance_reports",
                    sa.Column(name, typ, nullable=False, server_default=default),
                )
                op.alter_column("attendance_reports", name, server_default=None)

    # --- attendance_sessions: flags/closed_at ---
    if _table_exists("attendance_sessions", bind):
        if not _column_exists("attendance_sessions", "is_active", bind):
            op.add_column(
                "attendance_sessions",
                sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
            )
            op.alter_column("attendance_sessions", "is_active", server_default=None)
        if not _column_exists("attendance_sessions", "closed_at", bind):
            op.add_column(
                "attendance_sessions",
                sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
            )

    # --- attendances: reverify/override fields ---
    if _table_exists("attendances", bind):
        if not _column_exists("attendances", "is_manual_override", bind):
            op.add_column(
                "attendances",
                sa.Column("is_manual_override", sa.Boolean(), nullable=False, server_default=sa.text("false")),
            )
            op.alter_column("attendances", "is_manual_override", server_default=None)

        if not _column_exists("attendances", "is_reverify_required", bind):
            op.add_column(
                "attendances",
                sa.Column("is_reverify_required", sa.Boolean(), nullable=False, server_default=sa.text("false")),
            )
            op.alter_column("attendances", "is_reverify_required", server_default=None)

        if not _column_exists("attendances", "reverify_requested_at", bind):
            op.add_column(
                "attendances",
                sa.Column("reverify_requested_at", sa.DateTime(timezone=True), nullable=True),
            )

        if not _column_exists("attendances", "reverify_deadline_at", bind):
            op.add_column(
                "attendances",
                sa.Column("reverify_deadline_at", sa.DateTime(timezone=True), nullable=True),
            )

        if not _column_exists("attendances", "left_early_reason", bind):
            op.add_column(
                "attendances",
                sa.Column("left_early_reason", sa.String(length=32), nullable=True),
            )

def downgrade():
    # --- attendance_reports ---
    op.drop_column("attendance_reports", "left_early_real_sessions")
    op.drop_column("attendance_reports", "left_early_no_reverify_sessions")
    op.drop_column("attendance_reports", "unverified_sessions")

    # --- attendance_report_details ---
    # สร้าง enum เก่า reportstatus กลับมา
    reportstatus = sa.Enum("Present", "Late", "Absent", "LeftEarly", name="reportstatus")
    bind = op.get_bind()
    try:
        reportstatus.create(bind, checkfirst=True)
    except Exception:
        pass

    # เพิ่มคอลัมน์เก่า (ชั่วคราว) แล้ว map ค่ากลับ
    op.add_column(
        "attendance_report_details",
        sa.Column("status_old", reportstatus, nullable=False, server_default="Absent"),
    )
    # map 'Left_Early' -> 'LeftEarly', ค่าอื่นที่ไม่รู้จัก fallback เป็น 'Present'
    op.execute(
        """
        UPDATE attendance_report_details
        SET status_old =
            CASE status::text
                WHEN 'Left_Early' THEN 'LeftEarly'::reportstatus
                WHEN 'Present' THEN 'Present'::reportstatus
                WHEN 'Late' THEN 'Late'::reportstatus
                WHEN 'Absent' THEN 'Absent'::reportstatus
                ELSE 'Present'::reportstatus
            END
        """
    )
    # ลบคอลัมน์ status ใหม่ แล้วเปลี่ยนชื่อ status_old -> status
    op.drop_column("attendance_report_details", "status")
    op.alter_column("attendance_report_details", "status_old", new_column_name="status")
    # ลบเหตุผลย่อย
    op.drop_column("attendance_report_details", "left_early_reason")
    # (ไม่ลบ enum attendancestatus เพราะยังใช้งานในตาราง attendances)

    # --- attendance_sessions ---
    op.drop_column("attendance_sessions", "closed_at")
    op.drop_column("attendance_sessions", "is_active")

    # --- attendances ---
    op.drop_column("attendances", "left_early_reason")
    op.drop_column("attendances", "reverify_deadline_at")
    op.drop_column("attendances", "reverify_requested_at")
    op.drop_column("attendances", "is_reverify_required")
    op.drop_column("attendances", "is_manual_override")

    # ตั้ง check_in_time กลับไปไม่ให้เป็น NULL (และอาจใส่ default now() ถ้าต้องการ)
    try:
        op.alter_column(
            "attendances",
            "check_in_time",
            existing_type=sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        )
    except Exception:
        pass
