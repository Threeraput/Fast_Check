import uuid
from typing import List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Path
from sqlalchemy.orm import Session
from app.database import get_db
from app.core.deps import get_current_active_user
from app.schemas.chat_schema import ChatMessageCreate, ChatMessageResponse
from app.services.chat_service import create_chat_message, get_chat_conversation
from app.models.chat_message import ChatMessage
from app.models.user import User

router = APIRouter(prefix="/chat", tags=["Chat"])


@router.post(
    "/class/{class_id}/messages",
    response_model=ChatMessageResponse,
    status_code=status.HTTP_201_CREATED,
)
def send_chat_message(
    payload: ChatMessageCreate,
    class_id: UUID = Path(..., description="UUID of the classroom"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    message = create_chat_message(db, class_id, current_user, payload.receiver_id, payload.content)
    return message


@router.get(
    "/class/{class_id}/conversation/{other_user_id}",
    response_model=List[ChatMessageResponse],
)
def get_chat_conversation_api(
    class_id: UUID = Path(..., description="UUID of the classroom"),
    other_user_id: UUID = Path(..., description="UUID of the other participant"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    messages = get_chat_conversation(db, class_id, current_user, other_user_id)
    return messages
