"""add announcements and attendance reports

Revision ID: 2764efb111ad
Revises: 3816869da5a7
Create Date: 2025-11-05 06:17:39.915251

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import uuid


# revision identifiers, used by Alembic.
revision: str = '2764efb111ad'
down_revision: Union[str, Sequence[str], None] = '3816869da5a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade():
    # ✅ ใช้ UUID ให้ตรงกับ classes, users
    announcements_table = op.create_table(
        'announcements',
        sa.Column(
            'announcement_id',
            sa.dialects.postgresql.UUID(as_uuid=True),
            primary_key=True,
            default=uuid.uuid4,
        ),
        sa.Column(
            'class_id',
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey('classes.class_id', ondelete='CASCADE'),
            nullable=False,
        ),
        sa.Column(
            'teacher_id',
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey('users.user_id', ondelete='SET NULL'),
            nullable=True,
        ),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('body', sa.Text, nullable=True),
        sa.Column('pinned', sa.Boolean, nullable=False, server_default='false'),
        sa.Column('visible', sa.Boolean, nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime, nullable=True),
        sa.Column('expires_at', sa.DateTime, nullable=True),
    )
    print("✅ Created table: announcements")

    # ✅ สร้าง attendance_reports table
    op.create_table(
        'attendance_reports',
        sa.Column(
            'report_id',
            sa.dialects.postgresql.UUID(as_uuid=True),
            primary_key=True,
            default=uuid.uuid4,
        ),
        sa.Column(
            'class_id',
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey('classes.class_id', ondelete='CASCADE'),
            nullable=False,
        ),
        sa.Column(
            'student_id',
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey('users.user_id', ondelete='CASCADE'),
            nullable=False,
        ),
        sa.Column('total_sessions', sa.Integer, nullable=False, server_default='0'),
        sa.Column('attended_sessions', sa.Integer, nullable=False, server_default='0'),
        sa.Column('absent_sessions', sa.Integer, nullable=False, server_default='0'),
        sa.Column('reverified_sessions', sa.Integer, nullable=False, server_default='0'),
        sa.Column('attendance_rate', sa.Float, nullable=False, server_default='0'),
        sa.Column('generated_at', sa.DateTime, server_default=sa.text('CURRENT_TIMESTAMP')),
    )
    print("✅ Created table: attendance_reports")


def downgrade():
    op.drop_table('attendance_reports')
    op.drop_table('announcements')