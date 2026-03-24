# backend/app/models/__init__.py

# Import all models here so that Base.metadata can discover them.
# This also helps to resolve potential circular import issues.

from .user import User
from .role import Role
from .permission import Permission
from .class_model import Class # ตรวจสอบให้แน่ใจว่ามีไฟล์ class_model.py
from .attendance import Attendance # ตรวจสอบให้แน่ใจว่ามีไฟล์ attendance.py
from .user_face_sample import UserFaceSample # ตรวจสอบให้แน่ใจว่ามีไฟล์ user_face_sample.py
from .association import user_roles, role_permissions, class_students # ตรวจสอบให้แน่ใจว่ามีไฟล์ association.py
from .teacher_location import TeacherLocation
from .student_location import StudentLocation
from .classwork_assignment import ClassworkAssignment
from .classwork_submission import ClassworkSubmission
from .announcement import Announcement
from .attendance_report import AttendanceReport 
from .otp import OTP
from .attendance_session import AttendanceSession
from .classwork_enums import SubmissionLateness

