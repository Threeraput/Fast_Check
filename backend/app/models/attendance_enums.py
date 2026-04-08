# backend/app/models/attendance_enums.py
from enum import Enum as PyEnum


class AttendanceStatus(str, PyEnum):
    """กำหนดสถานะการเข้าเรียน"""
    PRESENT = "Present"
    LATE = "Late"
    ABSENT = "Absent"
    LEFT_EARLY = "Left_Early"  # ตรวจพบว่าเดินออกจากพื้นที่หลังเช็คอิน
    UNVERIFIED_FACE = "Unverified_Face"  # Face Scan ไม่ผ่าน
    MANUAL_OVERRIDE = "Manual_Override"  # ถูกแก้ไขโดยอาจารย์/แอดมิน
