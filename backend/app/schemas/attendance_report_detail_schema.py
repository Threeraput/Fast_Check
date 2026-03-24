from pydantic import BaseModel
from datetime import datetime
from uuid import UUID

class AttendanceReportDetailResponse(BaseModel):
    detail_id: UUID
    report_id: UUID
    session_id: UUID
    check_in_time: datetime | None
    status: str
    is_reverified: bool
    created_at: datetime | None

    class Config:
        orm_mode = True
