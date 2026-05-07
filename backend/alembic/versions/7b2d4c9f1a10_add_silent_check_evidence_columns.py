"""add silent check evidence columns to student_locations

Revision ID: 7b2d4c9f1a10
Revises: ff54f6ed0632
Create Date: 2026-05-07 23:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "7b2d4c9f1a10"
down_revision: Union[str, Sequence[str], None] = "ff54f6ed0632"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "student_locations",
        sa.Column("session_id", sa.UUID(), nullable=True),
    )
    op.add_column(
        "student_locations",
        sa.Column("server_received_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "student_locations",
        sa.Column("anchor_lat", sa.Numeric(9, 6), nullable=True),
    )
    op.add_column(
        "student_locations",
        sa.Column("anchor_lon", sa.Numeric(9, 6), nullable=True),
    )
    op.add_column(
        "student_locations",
        sa.Column("distance_m", sa.Numeric(10, 3), nullable=True),
    )
    op.add_column(
        "student_locations",
        sa.Column("radius_m", sa.Numeric(10, 3), nullable=True),
    )
    op.add_column(
        "student_locations",
        sa.Column("verification_result", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "student_locations",
        sa.Column("verification_reason", sa.String(length=255), nullable=True),
    )

    op.create_foreign_key(
        "fk_student_locations_session_id",
        "student_locations",
        "attendance_sessions",
        ["session_id"],
        ["session_id"],
        ondelete="SET NULL",
    )

    op.create_index(
        "ix_student_locations_student_session_timestamp",
        "student_locations",
        ["student_id", "session_id", "timestamp"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_student_locations_student_session_timestamp", table_name="student_locations")
    op.drop_constraint("fk_student_locations_session_id", "student_locations", type_="foreignkey")

    op.drop_column("student_locations", "verification_reason")
    op.drop_column("student_locations", "verification_result")
    op.drop_column("student_locations", "radius_m")
    op.drop_column("student_locations", "distance_m")
    op.drop_column("student_locations", "anchor_lon")
    op.drop_column("student_locations", "anchor_lat")
    op.drop_column("student_locations", "server_received_at")
    op.drop_column("student_locations", "session_id")
