"""add silent_check_scheduled_at to attendance_sessions

Revision ID: c3f1f47d9d42
Revises: 6bff2a573b82
Create Date: 2026-04-30 09:55:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "c3f1f47d9d42"
down_revision: Union[str, Sequence[str], None] = "6bff2a573b82"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "attendance_sessions",
        sa.Column("silent_check_scheduled_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("attendance_sessions", "silent_check_scheduled_at")
