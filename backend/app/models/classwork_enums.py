# backend/app/models/classwork_enums.py
from enum import Enum

class SubmissionLateness(str, Enum):
    ON_TIME = "On_Time"
    LATE = "Late"
    NOT_SUBMITTED = "Not_Submitted"
