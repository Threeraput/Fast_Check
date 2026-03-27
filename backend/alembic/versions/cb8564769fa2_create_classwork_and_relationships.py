"""create_classwork_and_relationships

Revision ID: cb8564769fa2
Revises: 9a6a104ecb57
Create Date: 2025-11-04 01:15:27.042872
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'cb8564769fa2'
down_revision: Union[str, Sequence[str], None] = '9a6a104ecb57'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# ชื่อ enum/type/index/tables ที่ใช้ซ้ำ
ENUM_NAME = "submissionlateness"
TABLE_NAME = "classwork"
IDX_CLASS_STUDENT = "ix_classwork_class_student"


def _create_uuid_extension_if_needed():
    # เผื่อเครื่อง/DB ยังไม่ได้ลง uuid-ossp
    op.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')


def _create_enum_if_needed():
    # สร้าง ENUM เฉพาะเมื่อยังไม่มี
    op.execute(f"""
    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM pg_type t
            WHERE t.typname = '{ENUM_NAME}'
        ) THEN
            CREATE TYPE {ENUM_NAME} AS ENUM ('On_Time', 'Late', 'Not_Submitted');
        END IF;
    END
    $$;
    """)


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    _create_uuid_extension_if_needed()
    _create_enum_if_needed()

    # ถ้ายังไม่มีตาราง classwork ค่อยสร้าง
    if TABLE_NAME not in insp.get_table_names():
        op.create_table(
            TABLE_NAME,

            # --- คอลัมน์หลัก ---
            sa.Column(
                'assignment_id',
                postgresql.UUID(as_uuid=True),
                primary_key=True,
                server_default=sa.text('uuid_generate_v4()')
            ),
            sa.Column(
                'class_id',
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey('classes.class_id', ondelete='CASCADE'),
                nullable=False
            ),
            sa.Column(
                'teacher_id',
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey('users.user_id', ondelete='CASCADE'),
                nullable=False
            ),
            sa.Column(
                'student_id',
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey('users.user_id', ondelete='CASCADE'),
                nullable=False
            ),

            sa.Column('title', sa.String(255), nullable=False),
            sa.Column('max_score', sa.Integer(), nullable=False, server_default=sa.text('100')),
            sa.Column('due_date', sa.DateTime(timezone=True), nullable=False),

            # --- Submission Data ---
            sa.Column('content_url', sa.String(512), nullable=True),
            sa.Column('submitted_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('graded', sa.Boolean(), nullable=False, server_default=sa.text('false')),
            sa.Column('score', sa.Integer(), nullable=True),

            # --- สถานะ (ใช้ ENUM ที่เพิ่งสร้าง) ---
            sa.Column('submission_status', sa.dialects.postgresql.ENUM(
                'On_Time', 'Late', 'Not_Submitted',
                name=ENUM_NAME, create_type=False
            ), nullable=False, server_default='Not_Submitted'),

            # --- Constraints ---
            sa.UniqueConstraint('class_id', 'student_id', 'title', name='uq_classwork_submission'),
        )

    # สร้าง index ถ้ายังไม่มี
    existing_indexes = [ix['name'] for ix in insp.get_indexes(TABLE_NAME)] if TABLE_NAME in insp.get_table_names() else []
    if IDX_CLASS_STUDENT not in existing_indexes and TABLE_NAME in insp.get_table_names():
        op.create_index(IDX_CLASS_STUDENT, TABLE_NAME, ['class_id', 'student_id'])


def downgrade() -> None:
    # ลบ index ถ้ามี
    op.execute(f'DROP INDEX IF EXISTS {IDX_CLASS_STUDENT};')

    # ลบตาราง ถ้ามี (CASCADE เผื่อ FK อ้างอิง)
    op.execute(f'DROP TABLE IF EXISTS {TABLE_NAME} CASCADE;')

    # ลบ ENUM ถ้ามี (และไม่มีตารางอื่นใช้อยู่แล้วใน DB นี้)
    op.execute(f"""
    DO $$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM pg_type t WHERE t.typname = '{ENUM_NAME}'
        ) THEN
            DROP TYPE {ENUM_NAME};
        END IF;
    END
    $$;
    """)
