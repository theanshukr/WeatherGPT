import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, JSON, Float
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    phone_number = Column(String, unique=True, nullable=True)
    preferred_language = Column(String, default="en")
    inferred_persona = Column(String, default="general")  # farmer, traveller, commuter, general
    persona_confidence = Column(Float, default=0.5)
    preferences = Column(JSON, default=dict)
    saved_locations = Column(JSON, default=list)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
