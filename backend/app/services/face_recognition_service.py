# backend/app/services/face_recognition_service.py
import face_recognition
import numpy as np
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app.models.user_face_sample import UserFaceSample
from app.schemas.face_schema import FaceSampleResponse
from uuid import UUID
from datetime import datetime, timezone, timedelta 

# ฟังก์ชันสำหรับประมวลผลรูปภาพและดึง face embedding
def get_face_embedding(image_path: str) -> bytes:
    try:
        # โหลดไฟล์รูปภาพจาก path
        image = face_recognition.load_image_file(image_path)

        # ตรวจจับตำแหน่งใบหน้า
        face_locations = face_recognition.face_locations(image)
        if len(face_locations) == 0:
            raise ValueError("no_face: No face detected in the image.")
        if len(face_locations) > 1:
            raise ValueError("multi_face: More than one face detected in the image.")

        # ดึง face embedding
        face_encodings = face_recognition.face_encodings(image, face_locations)
        if not face_encodings:
            raise ValueError("no_face: Could not get face encoding.")

        # แปลง embedding เป็น bytes เพื่อเก็บในฐานข้อมูล
        embedding_bytes = face_encodings[0].tobytes()
        return embedding_bytes

    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(f"Failed to process image: {e}")


# ฟังก์ชันสำหรับบันทึก/อัปเดต face sample พร้อมระบบ Cooldown 30 วัน (ยกเว้นการแก้ไขครั้งแรก)
def create_face_sample(db: Session, user_id: UUID, image_url: str, embedding: bytes) -> FaceSampleResponse:
    now = datetime.now(timezone.utc)
    
    # 1. เช็คว่ามีใบหน้าเดิมอยู่ในระบบไหม
    existing_sample = db.query(UserFaceSample).filter(UserFaceSample.user_id == user_id).first()

    if existing_sample:
        # 2. ตรวจสอบว่าเป็น "การแก้ไขครั้งแรก" หรือไม่
        # ถ้า updated_at ยังเป็น None หรือเท่ากับ created_at (ในกรณีที่บางระบบตั้งให้เท่ากันตอนสร้าง)
        # เราจะอนุญาตให้เขาเปลี่ยนหน้าได้เลย 1 ครั้ง
        
        is_first_update = existing_sample.updated_at is None
        
        if not is_first_update:
            # 3. ถ้าไม่ใช่การแก้ไขครั้งแรก (เคยแก้มาแล้ว) -> เช็ค Cooldown 30 วัน
            last_updated = existing_sample.updated_at
            
            # ป้องกัน error เรื่อง timezone
            if last_updated.tzinfo is None:
                last_updated = last_updated.replace(tzinfo=timezone.utc)

            days_since_update = (now - last_updated).days
            
            if days_since_update < 30:
                days_left = 30 - days_since_update
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"คุณเปลี่ยนใบหน้าไปแล้ว (ติดล็อค 30 วัน) กรุณารออีก {days_left} วันจึงจะสามารถเปลี่ยนได้อีกครั้ง"
                )
            
        # 4. อนุญาตให้อัปเดตใบหน้าใหม่ (ทั้งกรณีการแก้ไขครั้งแรก หรือพ้นกำหนด 30 วันแล้ว)
        existing_sample.image_url = image_url
        existing_sample.face_embedding = embedding
        existing_sample.updated_at = now # บันทึกเวลาที่แก้ไข (จากนี้ไปจะเริ่มติด 30 วัน)
        
        db.commit()
        db.refresh(existing_sample)
        return FaceSampleResponse.from_orm(existing_sample)

    else:
        # 5. ถ้าเป็นการลงทะเบียนครั้งแรก (No face in system) -> สร้างใหม่
        new_sample = UserFaceSample(
            user_id=user_id,
            image_url=image_url,
            face_embedding=embedding,
            created_at=now,
            updated_at=None # ตั้งเป็น None ไว้เพื่อให้ครั้งต่อไป "ยังไม่ติดล็อค 30 วัน"
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