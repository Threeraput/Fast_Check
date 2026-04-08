"""add submission_status to classwork

Revision ID: 54dfe7895e35
Revises: cb8564769fa2
Create Date: 2025-11-04 01:31:55.025869

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '54dfe7895e35'
down_revision: Union[str, Sequence[str], None] = 'cb8564769fa2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
