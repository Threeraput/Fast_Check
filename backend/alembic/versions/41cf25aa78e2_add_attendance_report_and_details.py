"""add attendance report and details

Revision ID: 41cf25aa78e2
Revises: 2764efb111ad
Create Date: 2025-11-05 17:32:50.834803

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import uuid


# revision identifiers, used by Alembic.
revision: str = '41cf25aa78e2'
down_revision: Union[str, Sequence[str], None] = '2764efb111ad'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.create_table(
        "attendance_reports",
        sa.Column("report_id", sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column("class_id", sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey("classes.class_id", ondelete="CASCADE")),
        sa.Column("student_id", sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey("users.user_id", ondelete="CASCADE")),
        sa.Column("total_sessions", sa.Integer, nullable=False, server_default="0"),
        sa.Column("attended_sessions", sa.Integer, nullable=False, server_default="0"),
        sa.Column("late_sessions", sa.Integer, nullable=False, server_default="0"),
        sa.Column("absent_sessions", sa.Integer, nullable=False, server_default="0"),
        sa.Column("left_early_sessions", sa.Integer, nullable=False, server_default="0"),
        sa.Column("reverified_sessions", sa.Integer, nullable=False, server_default="0"),
        sa.Column("attendance_rate", sa.Float, nullable=False, server_default="0"),
        sa.Column("generated_at", sa.DateTime, nullable=True),
    )

    op.create_table(
        "attendance_report_details",
        sa.Column("detail_id", sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
        sa.Column("report_id", sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey("attendance_reports.report_id", ondelete="CASCADE")),
        sa.Column("session_id", sa.dialects.postgresql.UUID(as_uuid=True), sa.ForeignKey("attendance_sessions.session_id", ondelete="CASCADE")),
        sa.Column("check_in_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", sa.Enum("Present", "Late", "Absent", "LeftEarly", name="reportstatus"), nullable=False),
        sa.Column("is_reverified", sa.Boolean, nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade():
    op.drop_table("attendance_report_details")
    op.drop_table("attendance_reports")