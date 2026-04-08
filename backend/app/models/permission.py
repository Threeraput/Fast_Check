# backend/app/models/permission.py
from sqlalchemy import Column, String, Integer
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.association import role_permissions # ต้อง import ตารางเชื่อมความสัมพันธ์

class Permission(Base):
    __tablename__ = "permissions"
    id = Column(Integer, primary_key=True, index=True) # Primary Key คือ 'id'
    name = Column(String(50), unique=True, index=True, nullable=False)
    description = Column(String(255), nullable=True)

    # Relationships
    # Permission -> Roles (Many-to-Many)
    roles = relationship("Role", secondary=role_permissions, back_populates="permissions")

    def __repr__(self):
        return f"<Permission(name='{self.name}')>"