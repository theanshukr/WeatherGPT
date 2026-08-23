"""
M3 Meteorological / Weather Data Integration Service
Provides standardized, validated weather telemetry to M2 (FastAPI Backend) and M4 (Conversational AI).
Strictly integrated with Open-Meteo, WMO WIS2.0, and OGC standards.
"""

from .config import settings
from .models import (
    Coordinates,
    LocationInfo,
    StandardizedCurrentWeather,
    HourlyForecastItem,
    DailyForecastItem,
    M2WeatherResponse,
    M4WeatherContext,
    WeatherServiceError,
)
from .validator import WeatherDataValidator
from .normalizer import WeatherDataNormalizer
from .weather_api import OpenMeteoClient

__all__ = [
    "settings",
    "Coordinates",
    "LocationInfo",
    "StandardizedCurrentWeather",
    "HourlyForecastItem",
    "DailyForecastItem",
    "M2WeatherResponse",
    "M4WeatherContext",
    "WeatherServiceError",
    "WeatherDataValidator",
    "WeatherDataNormalizer",
    "OpenMeteoClient",
]
