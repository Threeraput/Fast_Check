"""add submission_status to classwork

Revision ID: 68424341f1de
Revises: 54dfe7895e35
Create Date: 2025-11-04 01:34:30.885905

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '68424341f1de'
down_revision: Union[str, Sequence[str], None] = '54dfe7895e35'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
