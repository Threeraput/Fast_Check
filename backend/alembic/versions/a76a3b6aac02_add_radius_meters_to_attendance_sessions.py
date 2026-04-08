"""add radius_meters to attendance_sessions

Revision ID: a76a3b6aac02
Revises: 57157108075c
Create Date: 2025-10-29 17:46:31.540014

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a76a3b6aac02'
down_revision: Union[str, Sequence[str], None] = '57157108075c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
