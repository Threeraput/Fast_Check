"""add_announcement_and_attendance_reports

Revision ID: 1a35f96aa3a2
Revises: 8952f81ab52c
Create Date: 2025-11-05 02:35:53.643486
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
import uuid

# revision identifiers, used by Alembic.
revision: str = '1a35f96aa3a2'
down_revision: Union[str, Sequence[str], None] = '8952f81ab52c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    # ✅ สร้างตาราง attendance_reports ถ้ายังไม่มี
    if "attendance_reports" not in tables:
        op.create_table(
            "attendance_reports",
            sa.Column(
                "report_id",
                sa.String(36),  # ใช้ String 36 เพื่อให้รองรับ SQLite/PG ได้ทั้งคู่
                primary_key=True,
                default=lambda: str(uuid.uuid4()),
            ),
            sa.Column(
                "class_id",
                sa.String(36),
                sa.ForeignKey("classes.class_id"),
                nullable=False,
            ),
            sa.Column(
                "student_id",
                sa.String(36),
                sa.ForeignKey("users.user_id"),
                nullable=False,
            ),
            sa.Column("total_sessions", sa.Integer, nullable=False, server_default="0"),
            sa.Column("attended_sessions", sa.Integer, nullable=False, server_default="0"),
            sa.Column("absent_sessions", sa.Integer, nullable=False, server_default="0"),
            sa.Column("reverified_sessions", sa.Integer, nullable=False, server_default="0"),
            sa.Column("attendance_rate", sa.Float, nullable=False, server_default="0"),
            sa.Column("generated_at", sa.DateTime, nullable=True),
        )
        print("✅ created attendance_reports table")

    # ✅ ป้องกันตาราง announcements หาย (บาง revision เคยลบไป)
    if "announcements" not in tables:
        op.create_table(
            "announcements",
            sa.Column(
                "announcement_id",
                sa.String(36),
                primary_key=True,
                default=lambda: str(uuid.uuid4()),
            ),
            sa.Column(
                "class_id",
                sa.String(36),
                sa.ForeignKey("classes.class_id"),
                nullable=False,
            ),
            sa.Column(
                "teacher_id",
                sa.String(36),
                sa.ForeignKey("users.user_id"),
                nullable=True,
            ),
            sa.Column("title", sa.String(255), nullable=False),
            sa.Column("body", sa.Text, nullable=True),
            sa.Column("pinned", sa.Boolean, server_default="0"),
            sa.Column("visible", sa.Boolean, server_default="1"),
            sa.Column(
                "created_at",
                sa.DateTime,
                nullable=False,
                server_default=sa.text("(DATETIME('now'))")
                if conn.dialect.name == "sqlite"
                else sa.text("CURRENT_TIMESTAMP"),
            ),
            sa.Column("updated_at", sa.DateTime, nullable=True),
            sa.Column("expires_at", sa.DateTime, nullable=True),
        )
        print("✅ recreated announcements table")


def downgrade():
    op.drop_table("attendance_reports")
    # ⚠️ ไม่ลบ announcements เพราะอาจมีข้อมูลอยู่แล้ว
