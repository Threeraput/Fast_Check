from pydantic import BaseModel, Field

# backend/app/schemas/otp_schema.py


class OTPRequest(BaseModel):
    email: str = Field(..., example="user@example.com", description="Email to send OTP to")

class OTPVerification(BaseModel):
    email: str = Field(..., example="user@example.com", description="Email used for OTP")
    otp_code: str = Field(..., min_length=6, max_length=6, example="123456", description="The OTP received via email")

class PasswordResetRequest(BaseModel):
    email: str = Field(..., example="user@example.com", description="Email of the user requesting password reset")
    otp_code: str = Field(..., min_length=6, max_length=6, example="123456", description="OTP for verification")
    new_password: str = Field(..., min_length=8, description="New password for the user")