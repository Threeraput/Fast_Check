# alembic/env.py
from __future__ import annotations

import os
import sys
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool, create_engine

# ------------- Logging -------------
config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# ------------- PYTHONPATH & Base.metadata -------------
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BASE_DIR not in sys.path:
    sys.path.append(BASE_DIR)

from app.database import Base  # ต้องมี Base ในโปรเจกต์
target_metadata = Base.metadata

# ------------- Safe import models -------------
def _safe_import_models() -> None:
    """
    พยายาม import models ให้ครบเพื่อ register ตารางลง Base.metadata
    - ลอง import รวมผ่าน app.models ก่อน
    - ถ้าไม่สำเร็จ ไล่ import รายไฟล์ตามลำดับที่ปลอดภัย (users -> roles -> classes -> association -> ที่เหลือ)
    - รองรับชื่อไฟล์/โมดูลหลายรูปแบบ (classroom/classes, attendance_session(s), ฯลฯ)
    - ถ้าไฟล์ไหนพังจะ log warning แล้วข้าม เพื่อไม่ให้ migration ล้ม
    """
    try:
        import app.models  # noqa: F401
        return
    except Exception as e:
        print(f"[alembic] warning: failed to import app.models: {e!r}")

    ordered_candidates: list[list[str]] = [
        # --- Core entities ต้องมาก่อน (ถูกอ้าง FK บ่อย) ---
        ["app.models.user"],
        ["app.models.role"],
        ["app.models.classes", "app.models.classroom", "app.models.class_model"],
        ["app.models.association", "app.models.associations"],  # m2m เช่น class_students

        # --- Rest (ลำดับหลวม ๆ) ---
        ["app.models.otp"],
        ["app.models.attendance_session", "app.models.attendance_sessions"],
        ["app.models.attendance", "app.models.attendances", "app.models.attendance_model"],
        ["app.models.attendance_report", "app.models.attendance_reports"],
        ["app.models.announcement", "app.models.announcements"],
    ]

    for group in ordered_candidates:
        imported = False
        last_err = None
        for mod in group:
            try:
                __import__(mod)
                imported = True
                break
            except Exception as e:
                last_err = e
                continue
        if not imported:
            print(f"[alembic] warning: skip importing {group}: {last_err!r}")

_safe_import_models()

# ------------- Helper: URL -------------
def _get_sqlalchemy_url() -> str:
    env_url = os.environ.get("DATABASE_URL")
    if env_url:
        config.set_main_option("sqlalchemy.url", env_url)
        return env_url
    return config.get_main_option("sqlalchemy.url")

# ------------- Alembic run modes -------------
def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = _get_sqlalchemy_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        compare_server_default=True,
        version_table="alembic_version",
    )
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    url = _get_sqlalchemy_url()
    connectable = create_engine(url, poolclass=pool.NullPool, future=True)

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
            compare_server_default=True,
            render_as_batch=False,       # ตั้ง True ถ้า dev ด้วย SQLite
            version_table="alembic_version",
        )
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
