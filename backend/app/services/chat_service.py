from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.chat_message import ChatMessage
from app.models.class_model import Class as ClassModel
from app.models.user import User
from app.models.association import class_students


def _roles_from_user(user: User) -> set[str]:
    if hasattr(user, "roles_list") and isinstance(user.roles_list, list):
        return {str(r).lower() for r in user.roles_list}
    return {str(r.name).lower() for r in getattr(user, "roles", []) if hasattr(r, "name")}


def _is_teacher(user: User) -> bool:
    return "teacher" in _roles_from_user(user)


def _is_student(user: User) -> bool:
    return "student" in _roles_from_user(user)


def _user_in_class(db: Session, class_id, user_id) -> bool:
    return (
        db.query(class_students)
        .filter(
            and_(
                class_students.c.class_id == class_id,
                class_students.c.student_id == user_id,
            )
        )
        .first()
        is not None
    )


def _validate_chat_participants(db: Session, class_id, sender: User, receiver_id):
    classroom = db.get(ClassModel, class_id)
    if classroom is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found.")

    receiver = db.get(User, receiver_id)
    if receiver is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Receiver not found.")

    sender_is_teacher = _is_teacher(sender)
    sender_is_student = _is_student(sender)
    receiver_is_teacher = _is_teacher(receiver)
    receiver_is_student = _is_student(receiver)

    if sender_is_teacher:
        if classroom.teacher_id != sender.user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not the teacher of this classroom.",
            )
        if not receiver_is_student:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Teachers can only message students.",
            )
        if not _user_in_class(db, class_id, receiver.user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Receiver is not a student in this classroom.",
            )

    elif sender_is_student:
        if not _user_in_class(db, class_id, sender.user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not enrolled in this classroom.",
            )
        if not receiver_is_teacher:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Students can only message the class teacher.",
            )
        if receiver.user_id != classroom.teacher_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Receiver is not the teacher of this classroom.",
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only students and teachers may use the chat feature.",
        )

    return classroom, receiver


def create_chat_message(db: Session, class_id, sender: User, receiver_id, content: str) -> ChatMessage:
    classroom, receiver = _validate_chat_participants(db, class_id, sender, receiver_id)
    
    # ดึงชื่อวิชา และชื่อของผู้ส่ง/ผู้รับ ออกมาบันทึกแทนรหัส UUID บูดๆ
    # (โน้ต: ปรับเปลี่ยนตัวแปรด้านหลัง เช่น .username หรือ .name ให้ตรงกับ Model ตารางของคุณนะครับ)
    class_name = getattr(classroom, "class_name", getattr(classroom, "name", class_id))
    sender_name = getattr(sender, "username", getattr(sender, "name", sender.user_id))
    receiver_name = getattr(receiver, "username", getattr(receiver, "name", receiver_id))

    message = ChatMessage(
        class_id=class_name,        # เก็บเป็นชื่อวิชาแล้ว!
        sender_id=sender_name,      # เก็บเป็นชื่อผู้ส่งแล้ว!
        receiver_id=receiver_name,  # เก็บเป็นชื่อผู้รับแล้ว!
        content=content.strip(),
    )
    db.add(message)
    db.commit()
    db.refresh(message)  # เอาการอ้างอิงถึง ["sender"] ออกเพื่อไม่ให้ Error
    return message


def get_chat_conversation(db: Session, class_id, current_user: User, other_user_id):
    classroom = db.get(ClassModel, class_id)
    if classroom is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Classroom not found.")

    other = db.get(User, other_user_id)
    if other is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Other user not found.")

    current_is_teacher = _is_teacher(current_user)
    current_is_student = _is_student(current_user)
    other_is_teacher = _is_teacher(other)
    other_is_student = _is_student(other)

    if current_is_teacher:
        if classroom.teacher_id != current_user.user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not the teacher of this classroom.")
        if not other_is_student or not _user_in_class(db, class_id, other_user_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Conversation is only allowed with a student in this classroom.")
    elif current_is_student:
        if not _user_in_class(db, class_id, current_user.user_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not enrolled in this classroom.")
        if not other_is_teacher or other_user_id != classroom.teacher_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Students may only chat with the class teacher.")
    else:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only students and teachers may access conversations.")

    # ดึงชื่อมาแปลงเพื่อใช้ดึงข้อมูลใน DB เนื่องจากตอนนี้ในเบสเป็นข้อความชื่อธรรมดาแล้ว
    class_name = getattr(classroom, "class_name", getattr(classroom, "name", class_id))
    current_user_name = getattr(current_user, "username", getattr(current_user, "name", current_user.user_id))
    other_user_name = getattr(other, "username", getattr(other, "name", other_user_id))

    # นำ .options(selectinload(...)) ออกแล้ว เพื่อแก้ไขบั๊ก AttributeError
    messages = db.query(ChatMessage).filter(
        ChatMessage.class_id == class_name,
        or_(
            and_(
                ChatMessage.sender_id == current_user_name,
                ChatMessage.receiver_id == other_user_name,
            ),
            and_(
                ChatMessage.sender_id == other_user_name,
                ChatMessage.receiver_id == current_user_name,
            ),
        ),
    ).order_by(ChatMessage.created_at.asc()).all()

    return messages