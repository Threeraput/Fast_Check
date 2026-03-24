# backend/app/services/face_recognition_service.py
import face_recognition
import numpy as np
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.user_face_sample import UserFaceSample
from app.schemas.face_schema import FaceSampleResponse
from uuid import UUID


# ฟังก์ชันสำหรับประมวลผลรูปภาพและดึง face embedding
def get_face_embedding(image_path: str) -> bytes:
    try:
        # โหลดไฟล์รูปภาพจาก path
        image = face_recognition.load_image_file(image_path)

        # ตรวจจับตำแหน่งใบหน้า
        face_locations = face_recognition.face_locations(image)
        if len(face_locations) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No face detected in the image."
            )
        if len(face_locations) > 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="More than one face detected in the image."
            )

        # ดึง face embedding
        face_encodings = face_recognition.face_encodings(image, face_locations)
        if not face_encodings:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not get face encoding."
            )

        # แปลง embedding เป็น bytes เพื่อเก็บในฐานข้อมูล
        embedding_bytes = face_encodings[0].tobytes()
        return embedding_bytes

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process image: {e}"
        )


# ฟังก์ชันสำหรับบันทึก face sample ลงฐานข้อมูล
def create_face_sample(db: Session, user_id: UUID, image_url: str, embedding: bytes) -> FaceSampleResponse:
    new_sample = UserFaceSample(
        user_id=user_id,
        image_url=image_url,
        face_embedding=embedding
    )
    db.add(new_sample)
    db.commit()
    db.refresh(new_sample)

    return FaceSampleResponse.from_orm(new_sample)


# ฟังก์ชันสำหรับเปรียบเทียบใบหน้า
def compare_faces(db: Session, user_id: UUID, new_embedding: bytes, tolerance: float = 0.45):
    stored_embeddings = db.query(UserFaceSample.face_embedding).filter(
        UserFaceSample.user_id == user_id
    ).all()

    if not stored_embeddings:
        return False, None  # หรือ raise HTTPException(404, "No face samples found")

    # แปลง stored embeddings จาก bytes -> numpy
    stored_embeddings = [
        np.frombuffer(e[0], dtype=np.float64) for e in stored_embeddings
    ]
    new_embedding_np = np.frombuffer(new_embedding, dtype=np.float64)

    # เช็คขนาดตรงกัน
    if any(se.shape != new_embedding_np.shape for se in stored_embeddings):
        raise ValueError("Embedding shape mismatch")

    # คำนวณ distance และ match
    distances = face_recognition.face_distance(stored_embeddings, new_embedding_np)
    best_distance = float(np.min(distances))
    is_match =best_distance <= tolerance
 
    return is_match, best_distance