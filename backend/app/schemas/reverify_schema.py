# backend/app/schemas/reverify_schema.py
from pydantic import BaseModel
from uuid import UUID

class ToggleReverifyRequest(BaseModel):
    session_id: UUID
    enabled: bool  # True = เปิด, False = ปิด

class ToggleReverifyResponse(BaseModel):
    ok: bool
    reverify_enabled: bool
