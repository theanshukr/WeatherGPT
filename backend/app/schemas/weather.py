from typing import Optional, List, Dict, Any
from pydantic import BaseModel


class CurrentWeatherResponse(BaseModel):
    location: str
    latitude: float
    longitude: float
    temperature: float
    wind_speed: float
    wind_direction: float
    weather_code: int
    condition: str
    is_day: int
    humidity: Optional[float] = None
    precipitation: Optional[float] = None
    time: str


class ForecastResponse(BaseModel):
    location: str
    latitude: float
    longitude: float
    current: CurrentWeatherResponse
    daily: Dict[str, Any]
