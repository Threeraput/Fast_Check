# backend/app/database.py
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.core.config import settings
import logging

# เพิ่มระดับ log ให้ SQLAlchemy เห็นคำสั่ง SQL และการเชื่อมต่อ pool
logging.getLogger("sqlalchemy.engine").setLevel(logging.INFO)
logging.getLogger("sqlalchemy.pool").setLevel(logging.INFO)

if not settings.DATABASE_URL:
    raise ValueError("DATABASE_URL is not set in environment variables.")

SQLALCHEMY_DATABASE_URL = settings.DATABASE_URL

# เปิด echo และ echo_pool เพื่อ debug
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    echo=True,          # ← แสดง SQL ที่ execute
    echo_pool=True,     # ← แสดงเหตุการณ์ connection pool
    pool_pre_ping=True  # ← กัน connection ค้าง/ตาย
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
