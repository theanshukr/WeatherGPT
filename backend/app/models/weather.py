import uuid
from datetime import datetime
from sqlalchemy import Column, String, DateTime, JSON, Float
from app.core.database import Base


class CachedWeather(Base):
    __tablename__ = "cached_weather"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    location_name = Column(String, index=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    data = Column(JSON, nullable=False)
    fetched_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)
