# app/services/email_service.py
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
from app.core.config import settings

conf = ConnectionConfig(
    MAIL_USERNAME=settings.MAIL_USERNAME,
    MAIL_PASSWORD=settings.MAIL_PASSWORD,
    MAIL_FROM=settings.MAIL_FROM,
    MAIL_PORT=settings.MAIL_PORT,
    MAIL_SERVER=settings.MAIL_SERVER,
    MAIL_STARTTLS=settings.MAIL_STARTTLS, # ใช้ Field ที่ถูกต้อง
    MAIL_SSL_TLS=settings.MAIL_SSL_TLS,   # ใช้ Field ที่ถูกต้อง
    USE_CREDENTIALS=settings.MAIL_USE_CREDENTIALS
)

async def send_email(recipients: list, subject: str, body: str, subtype: str = "plain"):
    message = MessageSchema(
        subject=subject,
        recipients=recipients,
        body=body,
        subtype=subtype
    )
    fm = FastMail(conf)
    try:
        await fm.send_message(message)
        return True
    except Exception as e:
        print(f"Error sending email: {e}")
        return False