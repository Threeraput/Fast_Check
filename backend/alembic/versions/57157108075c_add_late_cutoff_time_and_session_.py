"""add late_cutoff_time and session relations

Revision ID: 57157108075c
Revises: ecbdfbea09a3
Create Date: 2025-10-15 20:08:28.529355

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '57157108075c'
down_revision: Union[str, Sequence[str], None] = 'ecbdfbea09a3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.add_column(
        'attendance_sessions',
        sa.Column('late_cutoff_time', sa.DateTime(timezone=True), nullable=True)
    )
    # เติมค่าให้ทุกแถว: ใช้ end_time หรือ start_time + 10 นาทีเป็นค่าเริ่มต้น
    op.execute("""
        UPDATE attendance_sessions
        SET late_cutoff_time = COALESCE(
            start_time + INTERVAL '10 minutes',
            end_time
        )
        WHERE late_cutoff_time IS NULL;
    """)
    # จากนั้นค่อยบังคับ NOT NULL
    op.alter_column('attendance_sessions', 'late_cutoff_time', nullable=False)

def downgrade():
    op.drop_column("attendance_sessions", "late_cutoff_time")