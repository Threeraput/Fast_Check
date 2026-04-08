# backend/app/main.py
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from sqlalchemy.exc import SQLAlchemyError
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from contextlib import asynccontextmanager
from app.database import engine, Base, get_db
from app.api.v1 import (
    auth,
    users,
    admin,
    face_recognition,
    classes,
    attendance,
    sessions,
)
from app.services.db_service import initialize_roles_permissions
from fastapi.staticfiles import StaticFiles
from app.api.v1 import announcements as announcements_router
from app.api.v1 import classwork_simple
from app.api.v1 import attendance_report
from app.api.v1 import attendance_report_detail
from pathlib import Path
from app.core.config import settings


MEDIA_ROOT = Path("media")
MEDIA_ROOT.mkdir(parents=True, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    db_session = next(get_db())
    try:
        Base.metadata.create_all(bind=engine)
        initialize_roles_permissions(db_session)
    finally:
        db_session.close()
    yield


app = FastAPI(
    title="Face Attendance API", version="1.0.0", lifespan=lifespan, debug=True
)


# ---------- Middleware: เก็บ request body บางส่วนไว้ใน log ----------
@app.middleware("http")
async def attach_request_body(request: Request, call_next):
    try:
        request.state.body = await request.body()
    except Exception:
        request.state.body = b""
    response = await call_next(request)
    return response


# ---------- Exception Handlers ----------
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={
            "error": "validation_error",
            "detail": exc.errors(),
            "body_excerpt": getattr(request.state, "body", b"")[:512].decode(
                "utf-8", "ignore"
            ),
        },
    )


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError):
    return JSONResponse(
        status_code=500,
        content={
            "error": "database_error",
            "message": str(getattr(exc, "orig", exc)),  # โชว์ข้อความจาก psycopg2 ถ้ามี
        },
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={
            "error": "internal_error",
            "message": str(exc),
            "path": str(request.url),
        },
    )


# ----- CORS & routers ปรับตาม .env -----
origins = [
    "http://localhost",
    "http://localhost:8000",
    "http://127.0.0.1",
    f"http://{settings.BACKEND_IP}:8000",
    "file://",
    "null",
]

origins.append(f"http://{settings.BACKEND_IP}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
app.mount("/workpdf", StaticFiles(directory="workpdf"), name="workpdf")
app.mount("/media", StaticFiles(directory=str(MEDIA_ROOT)), name="media")
app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(face_recognition.router, prefix="/api/v1")
app.include_router(classes.router, prefix="/api/v1")
app.include_router(attendance.router, prefix="/api/v1")
app.include_router(admin.router, prefix="/api/v1")
app.include_router(sessions.router, prefix="/api/v1")
app.include_router(classwork_simple.router, prefix="/api/v1")
app.include_router(announcements_router.router, prefix="/api/v1")
app.include_router(attendance_report.router, prefix="/api/v1")
app.include_router(attendance_report_detail.router, prefix="/api/v1")


@app.get("/")
async def read_root():
    return {"message": "Welcome to the Face Attendance API!"}
