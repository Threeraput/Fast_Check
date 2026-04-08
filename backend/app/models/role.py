# backend/app/models/role.py
from sqlalchemy import Column, String, Integer
from sqlalchemy.orm import relationship
from app.database import Base
from app.models.association import role_permissions, user_roles # ต้อง import ตารางเชื่อมความสัมพันธ์

class Role(Base):
    __tablename__ = "roles"
    id = Column(Integer, primary_key=True, index=True) # Primary Key คือ 'id'
    name = Column(String(50), unique=True, index=True, nullable=False)
    description = Column(String(255), nullable=True)

    # Relationships
    # Role -> Permissions (Many-to-Many)
    permissions = relationship("Permission", secondary=role_permissions, back_populates="roles")
    # Role -> Users (Many-to-Many)
    users = relationship("User", secondary=user_roles, back_populates="roles")

    def __repr__(self):
        return f"<Role(name='{self.name}')>"