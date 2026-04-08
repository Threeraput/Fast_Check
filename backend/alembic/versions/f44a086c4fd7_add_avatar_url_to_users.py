"""add avatar_url to users

Revision ID: f44a086c4fd7
Revises: 41cf25aa78e2
Create Date: 2025-11-06 07:03:09.957217
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

# revision identifiers, used by Alembic.
revision: str = "f44a086c4fd7"
down_revision: Union[str, Sequence[str], None] = "41cf25aa78e2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE_NAME = "users"
COLUMN_NAME = "avatar_url"


def _table_exists(bind, table: str) -> bool:
    insp = inspect(bind)
    return insp.has_table(table)


def _column_exists(bind, table: str, column: str) -> bool:
    insp = inspect(bind)
    try:
        cols = [c["name"] for c in insp.get_columns(table)]
    except Exception:
        return False
    return column in cols


def upgrade() -> None:
    bind = op.get_bind()

    # ถ้าไม่มีตาราง users ให้ข้าม เพื่อความปลอดภัยบนสภาพแวดล้อมที่ schema ยังไม่ครบ
    if not _table_exists(bind, TABLE_NAME):
        return

    # เพิ่มคอลัมน์เฉพาะเมื่อยังไม่มี
    if not _column_exists(bind, TABLE_NAME, COLUMN_NAME):
        with op.batch_alter_table(TABLE_NAME) as batch_op:
            batch_op.add_column(sa.Column(COLUMN_NAME, sa.String(length=255), nullable=True))


def downgrade() -> None:
    bind = op.get_bind()

    if not _table_exists(bind, TABLE_NAME):
        return

    if _column_exists(bind, TABLE_NAME, COLUMN_NAME):
        with op.batch_alter_table(TABLE_NAME) as batch_op:
            batch_op.drop_column(COLUMN_NAME)