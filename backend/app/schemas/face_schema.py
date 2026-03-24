# backend/app/schemas/face_schema.py
from pydantic import BaseModel
from fastapi import UploadFile, File
from typing import List, Optional
from uuid import UUID
from datetime import datetime

class FaceSampleCreate(BaseModel):
    user_id: UUID

class FaceSampleResponse(BaseModel):
    sample_id: UUID
    user_id: UUID
    image_url: str
    created_at: datetime
        
    class Config:
        from_attributes = True