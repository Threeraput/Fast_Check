from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, constr
from pydantic.config import ConfigDict


class ChatMessageCreate(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    receiver_id: UUID
    content: constr(min_length=1, max_length=1000)


class UserMinimal(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    username: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None

    @property
    def display_name(self) -> str:
        if self.first_name and self.last_name:
            return f"{self.first_name} {self.last_name}"
        return self.username


class ChatMessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    message_id: UUID
    class_id: str        # 👈 แก้ไขจาก UUID เป็น str เพื่อรองรับชื่อวิชา
    sender_id: str       # 👈 แก้ไขจาก UUID เป็น str เพื่อรองรับชื่อผู้ส่ง
    receiver_id: str     # 👈 แก้ไขจาก UUID เป็น str เพื่อรองรับชื่อผู้รับ
    content: str
    created_at: datetime
    sender: Optional[UserMinimal] = None