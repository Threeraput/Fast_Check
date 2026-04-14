# backend/app/core/scheduler.py
from apscheduler.schedulers.background import BackgroundScheduler

# สร้าง instance ของ Scheduler แบบทำงานเบื้องหลัง
# เพื่อไม่ให้ไปบล็อกการทำงานหลักของ FastAPI
scheduler = BackgroundScheduler()


def start_scheduler():
    if not scheduler.running:
        scheduler.start()
        print("✅ APScheduler started successfully")


def shutdown_scheduler():
    if scheduler.running:
        scheduler.shutdown()
        print("🛑 APScheduler shut down")
