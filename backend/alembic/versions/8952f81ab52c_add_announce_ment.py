"""add_announce_ment

Revision ID: 8952f81ab52c
Revises: 0d6812c37776
Create Date: 2025-11-05 02:34:31.436731

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8952f81ab52c'
down_revision: Union[str, Sequence[str], None] = '0d6812c37776'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.create_table(
        'announcements',
        sa.Column('announcement_id', sa.String(length=36), primary_key=True, nullable=False),
        sa.Column('class_id', sa.String(length=36), sa.ForeignKey('classes.class_id'), nullable=False, index=True),
        sa.Column('teacher_id', sa.String(length=36), sa.ForeignKey('users.user_id'), nullable=False, index=True),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('body', sa.Text(), nullable=True),
        sa.Column('pinned', sa.Boolean(), nullable=False, server_default=sa.text('0')),
        sa.Column('visible', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('expires_at', sa.DateTime(), nullable=True),
    )

def downgrade():
    op.drop_table('announcements')