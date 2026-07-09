"""encrypt content fields in chat and submissions

Revision ID: f2c9d4a1b8e7
Revises: c6a1a9f7d2b4
Create Date: 2026-06-19 00:00:00.000000

"""
from __future__ import annotations

import base64
import hashlib
import os
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from cryptography.fernet import Fernet


# revision identifiers, used by Alembic.
revision: str = "f2c9d4a1b8e7"
down_revision: Union[str, Sequence[str], None] = "c6a1a9f7d2b4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_PREFIX = "enc:v1:"


def _fernet() -> Fernet:
    secret = os.getenv("CONTENT_ENCRYPTION_KEY") or os.getenv("SECRET_KEY")
    if not secret:
        raise RuntimeError("SECRET_KEY or CONTENT_ENCRYPTION_KEY is required for encryption migration")
    digest = hashlib.sha256(secret.encode("utf-8")).digest()
    key = base64.urlsafe_b64encode(digest)
    return Fernet(key)


def _encrypt_text(value: str, f: Fernet) -> str:
    if value.startswith(_PREFIX):
        return value
    token = f.encrypt(value.encode("utf-8")).decode("utf-8")
    return f"{_PREFIX}{token}"


def upgrade() -> None:
    """Upgrade schema."""
    bind = op.get_bind()
    f = _fernet()

    chat_rows = bind.execute(
        sa.text(
            """
            SELECT message_id, content
            FROM chat_messages
            WHERE content IS NOT NULL
            """
        )
    ).fetchall()
    for row in chat_rows:
        content = row[1]
        if not isinstance(content, str) or content.startswith(_PREFIX):
            continue
        bind.execute(
            sa.text("UPDATE chat_messages SET content = :content WHERE message_id = :id"),
            {"content": _encrypt_text(content, f), "id": row[0]},
        )

    sub_rows = bind.execute(
        sa.text(
            """
            SELECT submission_id, submission_text
            FROM classwork_submissions
            WHERE submission_text IS NOT NULL
            """
        )
    ).fetchall()
    for row in sub_rows:
        text_val = row[1]
        if not isinstance(text_val, str) or text_val.startswith(_PREFIX):
            continue
        bind.execute(
            sa.text(
                "UPDATE classwork_submissions SET submission_text = :text WHERE submission_id = :id"
            ),
            {"text": _encrypt_text(text_val, f), "id": row[0]},
        )


def downgrade() -> None:
    """Downgrade schema."""
    # Data decryption rollback is intentionally not performed.
    pass
