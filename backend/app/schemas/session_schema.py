# backend/app/schemas/session_schema.py
from pydantic import BaseModel, Field, conint, validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime

class LocationData(BaseModel):
    """Base model for Lat/Lon"""
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)

class SessionOpenRequest(BaseModel):
    class_id: UUID
    latitude: float
    longitude: float
    radius_meters: conint(ge=10, le=2000) = Field(..., description="รัศมีเมตร")
    start_time: Optional[datetime] = None
    late_cutoff_time: Optional[datetime] = None   
    end_time: Optional[datetime] = None

    @validator("late_cutoff_time")
    def _validate_order1(cls, v, values):
        s = values.get("start_time")
        if s and v < s:
            raise ValueError("late_cutoff_time must be >= start_time")
        return v

    @validator("end_time")
    def _validate_order2(cls, v, values):
        l = values.get("late_cutoff_time")
        if l and v < l:
            raise ValueError("end_time must be >= late_cutoff_time")
        return v

class SessionResponse(BaseModel):
    session_id: UUID
    class_id: UUID
    teacher_id: UUID
    start_time: datetime
    late_cutoff_time: datetime
    end_time: datetime
    radius_meters: int
    anchor_lat: float
    anchor_lon: float
    reverify_enabled: bool = False
    
    class Config:
        from_attributes = True