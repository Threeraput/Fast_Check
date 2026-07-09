from __future__ import annotations

import base64
import hashlib
from functools import lru_cache
from typing import Optional

from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy.types import TypeDecorator, Text

from app.core.config import settings


_PREFIX = "enc:v1:"


def _build_fernet_key(raw_secret: str) -> bytes:
    digest = hashlib.sha256(raw_secret.encode("utf-8")).digest()
    return base64.urlsafe_b64encode(digest)


@lru_cache(maxsize=1)
def _get_fernet() -> Fernet:
    base_secret = (
        settings.CONTENT_ENCRYPTION_KEY
        if getattr(settings, "CONTENT_ENCRYPTION_KEY", None)
        else settings.SECRET_KEY
    )
    return Fernet(_build_fernet_key(base_secret))


def encrypt_text(value: str) -> str:
    if value.startswith(_PREFIX):
        return value
    token = _get_fernet().encrypt(value.encode("utf-8")).decode("utf-8")
    return f"{_PREFIX}{token}"


def decrypt_text(value: str) -> str:
    if not value.startswith(_PREFIX):
        return value
    token = value[len(_PREFIX):]
    try:
        return _get_fernet().decrypt(token.encode("utf-8")).decode("utf-8")
    except InvalidToken:
        # Keep value readable for safety if key changed unexpectedly.
        return value


class EncryptedText(TypeDecorator):
    """Transparent text encryption at rest using Fernet."""

    impl = Text
    cache_ok = True

    def process_bind_param(self, value: Optional[str], dialect):  # noqa: ANN001
        if value is None:
            return None
        if not isinstance(value, str):
            value = str(value)
        return encrypt_text(value)

    def process_result_value(self, value: Optional[str], dialect):  # noqa: ANN001
        if value is None:
            return None
        return decrypt_text(value)
