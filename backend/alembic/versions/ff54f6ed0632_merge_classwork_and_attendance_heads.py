"""merge classwork and attendance heads

Revision ID: ff54f6ed0632
Revises: c3f1f47d9d42, 41c3f38533d1
Create Date: 2026-05-06 23:19:14.746501

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ff54f6ed0632'
down_revision: Union[str, Sequence[str], None] = ('c3f1f47d9d42', '41c3f38533d1')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
