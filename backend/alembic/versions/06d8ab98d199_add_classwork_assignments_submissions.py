"""add classwork assignments & submissions

Revision ID: 06d8ab98d199
Revises: d7cbf76ef205
Create Date: 2025-11-04 03:31:40.020361
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "06d8ab98d199"
down_revision: Union[str, Sequence[str], None] = "d7cbf76ef205"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # ใช้ uuid-ossp ถ้าจะ default เป็น uuid_generate_v4()
    op.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')

    # ENUM แบบกันซ้ำ (idempotent)
    op.execute(
        """
        DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type t WHERE t.typname = 'submissionlateness') THEN
            CREATE TYPE submissionlateness AS ENUM ('On_Time','Late','Not_Submitted');
          END IF;
        END $$;
        """
    )

    # ====== 1) ตารางงานระดับคลาส ======
    op.create_table(
        "classwork_assignments",
        sa.Column(
            "assignment_id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            nullable=False,
            server_default=sa.text("uuid_generate_v4()"),
        ),
        sa.Column(
            "class_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("classes.class_id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "teacher_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.user_id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("max_score", sa.Integer(), nullable=False, server_default=sa.text("100")),
        sa.Column("due_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.UniqueConstraint("class_id", "title", name="uq_cw_assign_class_title"),
    )
    op.create_index("ix_cw_assignments_class", "classwork_assignments", ["class_id"], unique=False)

    # เตรียม enum object แบบไม่สร้างซ้ำ ใช้ในตาราง submissions
    submission_lateness_enum = postgresql.ENUM(
        "On_Time", "Late", "Not_Submitted",
        name="submissionlateness",
        create_type=False,
    )

    # ====== 2) ตารางส่งงานของนักเรียน ======
    op.create_table(
        "classwork_submissions",
        sa.Column(
            "submission_id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            nullable=False,
            server_default=sa.text("uuid_generate_v4()"),
        ),
        sa.Column(
            "assignment_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("classwork_assignments.assignment_id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "student_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.user_id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("content_url", sa.String(length=512), nullable=True),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "submission_status",
            submission_lateness_enum,
            nullable=False,
            server_default="Not_Submitted",
        ),
        sa.Column("graded", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("score", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.UniqueConstraint("assignment_id", "student_id", name="uq_cw_submission_assign_student"),
    )
    op.create_index(
        "ix_cw_submissions_assign_student",
        "classwork_submissions",
        ["assignment_id", "student_id"],
        unique=False,
    )
    op.create_index(
        "ix_cw_submissions_student",
        "classwork_submissions",
        ["student_id"],
        unique=False,
    )
    op.create_index(
        "ix_cw_submissions_assignment",
        "classwork_submissions",
        ["assignment_id"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    # drop submissions ก่อน (เพราะ FK ชี้ไป assignments)
    op.drop_index("ix_cw_submissions_assignment", table_name="classwork_submissions")
    op.drop_index("ix_cw_submissions_student", table_name="classwork_submissions")
    op.drop_index("ix_cw_submissions_assign_student", table_name="classwork_submissions")
    op.drop_constraint("uq_cw_submission_assign_student", "classwork_submissions", type_="unique")
    op.drop_table("classwork_submissions")

    # ค่อย drop assignments
    op.drop_index("ix_cw_assignments_class", table_name="classwork_assignments")
    op.drop_constraint("uq_cw_assign_class_title", "classwork_assignments", type_="unique")
    op.drop_table("classwork_assignments")

    # ไม่ drop ENUM เพื่อเลี่ยงกระทบตารางอื่น
