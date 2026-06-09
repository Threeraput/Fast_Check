"""add is_accepting_submissions to classwork

Revision ID: 41c3f38533d1
Revises: 2fb5d1142cc5
Create Date: 2026-04-30 17:47:13.551405

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '41c3f38533d1'
down_revision: Union[str, Sequence[str], None] = '2fb5d1142cc5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns("classwork_assignments")}

    if "is_accepting_submissions" not in cols:
        op.add_column(
            "classwork_assignments",
            sa.Column(
                "is_accepting_submissions",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("true"),
            ),
        )


def downgrade() -> None:
    """Downgrade schema."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns("classwork_assignments")}
    if "is_accepting_submissions" in cols:
        op.drop_column("classwork_assignments", "is_accepting_submissions")
