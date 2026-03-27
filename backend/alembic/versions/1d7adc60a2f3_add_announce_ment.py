"""add_announce_ment

Revision ID: 1d7adc60a2f3
Revises: f44a086c4fd7
Create Date: 2025-11-07 08:20:11.819474
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "1d7adc60a2f3"
down_revision: Union[str, Sequence[str], None] = "f44a086c4fd7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema safely for existing data."""

    # --- Announcements ---
    op.alter_column(
        "announcements", "teacher_id",
        existing_type=sa.UUID(),
        nullable=False
    )
    op.alter_column(
        "announcements", "created_at",
        existing_type=postgresql.TIMESTAMP(),
        nullable=False,
        existing_server_default=sa.text("CURRENT_TIMESTAMP"),
    )
    op.alter_column(
        "announcements", "updated_at",
        existing_type=postgresql.TIMESTAMP(),
        nullable=False,
    )

    op.create_index(op.f("ix_announcements_class_id"), "announcements", ["class_id"], unique=False)
    op.create_index(op.f("ix_announcements_teacher_id"), "announcements", ["teacher_id"], unique=False)

    op.drop_constraint(op.f("announcements_class_id_fkey"), "announcements", type_="foreignkey")
    op.drop_constraint(op.f("announcements_teacher_id_fkey"), "announcements", type_="foreignkey")

    op.create_foreign_key(None, "announcements", "users", ["teacher_id"], ["user_id"])
    op.create_foreign_key(None, "announcements", "classes", ["class_id"], ["class_id"])

    # --- Attendance Reports ---
    op.add_column(
        "attendance_reports",
        sa.Column("unverified_sessions", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "attendance_reports",
        sa.Column("left_early_no_reverify_sessions", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "attendance_reports",
        sa.Column("left_early_real_sessions", sa.Integer(), nullable=False, server_default="0"),
    )

    # เคลียร์ default (optional)
    op.alter_column("attendance_reports", "unverified_sessions", server_default=None)
    op.alter_column("attendance_reports", "left_early_no_reverify_sessions", server_default=None)
    op.alter_column("attendance_reports", "left_early_real_sessions", server_default=None)

    op.alter_column(
        "attendance_reports", "class_id",
        existing_type=sa.UUID(),
        nullable=False
    )
    op.alter_column(
        "attendance_reports", "student_id",
        existing_type=sa.UUID(),
        nullable=False
    )

    # --- Attendance Sessions ---
    op.add_column(
        "attendance_sessions",
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
    )
    op.add_column(
        "attendance_sessions",
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.alter_column("attendance_sessions", "is_active", server_default=None)

    # --- Attendances ---
    op.add_column(
        "attendances",
        sa.Column("is_manual_override", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column(
        "attendances",
        sa.Column("is_reverify_required", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column(
        "attendances",
        sa.Column("reverify_requested_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "attendances",
        sa.Column("reverify_deadline_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "attendances",
        sa.Column("left_early_reason", sa.String(length=32), nullable=True),
    )

    # ล้าง default (optional)
    op.alter_column("attendances", "is_manual_override", server_default=None)
    op.alter_column("attendances", "is_reverify_required", server_default=None)


def downgrade() -> None:
    """Downgrade schema."""
    # --- Attendances ---
    op.drop_column("attendances", "left_early_reason")
    op.drop_column("attendances", "reverify_deadline_at")
    op.drop_column("attendances", "reverify_requested_at")
    op.drop_column("attendances", "is_reverify_required")
    op.drop_column("attendances", "is_manual_override")

    # --- Attendance Sessions ---
    op.drop_column("attendance_sessions", "closed_at")
    op.drop_column("attendance_sessions", "is_active")

    # --- Attendance Reports ---
    op.alter_column("attendance_reports", "student_id", existing_type=sa.UUID(), nullable=True)
    op.alter_column("attendance_reports", "class_id", existing_type=sa.UUID(), nullable=True)
    op.drop_column("attendance_reports", "left_early_real_sessions")
    op.drop_column("attendance_reports", "left_early_no_reverify_sessions")
    op.drop_column("attendance_reports", "unverified_sessions")

    # --- Announcements ---
    op.drop_constraint(None, "announcements", type_="foreignkey")
    op.drop_constraint(None, "announcements", type_="foreignkey")
    op.create_foreign_key(
        op.f("announcements_teacher_id_fkey"),
        "announcements", "users", ["teacher_id"], ["user_id"], ondelete="SET NULL",
    )
    op.create_foreign_key(
        op.f("announcements_class_id_fkey"),
        "announcements", "classes", ["class_id"], ["class_id"], ondelete="CASCADE",
    )
    op.drop_index(op.f("ix_announcements_teacher_id"), table_name="announcements")
    op.drop_index(op.f("ix_announcements_class_id"), table_name="announcements")
    op.alter_column(
        "announcements", "updated_at",
        existing_type=postgresql.TIMESTAMP(),
        nullable=True,
    )
    op.alter_column(
        "announcements", "created_at",
        existing_type=postgresql.TIMESTAMP(),
        nullable=True,
        existing_server_default=sa.text("CURRENT_TIMESTAMP"),
    )
    op.alter_column(
        "announcements", "teacher_id",
        existing_type=sa.UUID(),
        nullable=True,
    )
