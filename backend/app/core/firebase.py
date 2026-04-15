# backend/app/core/firebase.py
import firebase_admin
from firebase_admin import credentials


def init_firebase():
    """
    ฟังก์ชันสำหรับเปิดใช้งาน Firebase Admin SDK
    """
    # เช็คก่อนว่าเคยเปิดไว้หรือยัง (ป้องกัน Error ตอน FastAPI รีโหลดตัวเอง)
    if not firebase_admin._apps:
        try:
            # ชี้ path ไปที่ไฟล์ JSON firebase
            cred = credentials.Certificate("firebase-adminsdk.json")
            firebase_admin.initialize_app(cred)
            print("🔥 Firebase Admin SDK initialized successfully.")
        except Exception as e:
            print(f"❌ Failed to initialize Firebase: {e}")
