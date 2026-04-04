from typing import Optional
from pydantic import BaseModel, field_validator
from datetime import datetime
from uuid import UUID


class AttendanceReportDetailResponse(BaseModel):
    detail_id: UUID
    report_id: UUID
    session_id: UUID
    check_in_time: Optional[datetime] = None
    status: str
    is_reverified: bool
    created_at: Optional[datetime] = None
    face_image_url: Optional[str] = None
    reverify_image_url: Optional[str] = None
    reverify_time: Optional[datetime] = None
    session_start: Optional[datetime] = None

    @field_validator("face_image_url", "reverify_image_url", mode="before")
    @classmethod
    def assemble_image_url(cls, v):
        #  ต่อ URL ให้สมบูรณ์เพื่อให้แอปโหลดรูปขึ้น (เปลี่ยน IP เป็นของคุณ)
        if v and isinstance(v, str) and not v.startswith("http"):
            base_url = "http://10.51.151.125:8000"
            return f"{base_url}/{v}"
        return v

    class Config:
        orm_mode = True
