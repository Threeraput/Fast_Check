"""add submission_text to classwork_submissions

Revision ID: c6a1a9f7d2b4
Revises: 5a45b8179022
Create Date: 2026-06-19 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c6a1a9f7d2b4'
down_revision: Union[str, Sequence[str], None] = '5a45b8179022'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c['name'] for c in inspector.get_columns('classwork_submissions')}

    if 'submission_text' not in cols:
        op.add_column(
            'classwork_submissions',
            sa.Column('submission_text', sa.Text(), nullable=True),
        )


def downgrade() -> None:
    """Downgrade schema."""
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c['name'] for c in inspector.get_columns('classwork_submissions')}

    if 'submission_text' in cols:
        op.drop_column('classwork_submissions', 'submission_text')
