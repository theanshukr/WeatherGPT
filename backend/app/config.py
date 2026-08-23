"""
M3 Configuration Module
Manages API endpoints, timeouts, retry policies, and operational thresholds for Open-Meteo services.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    # Service Metadata
    SERVICE_NAME: str = "m3-weather-data-service"
    SERVICE_VERSION: str = "1.0.0"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False

    # Open-Meteo Official Endpoints
    OPEN_METEO_FORECAST_URL: str = Field(
        default="https://api.open-meteo.com/v1/forecast",
        description="Official Open-Meteo Weather Forecast API endpoint",
    )
    OPEN_METEO_ARCHIVE_URL: str = Field(
        default="https://archive-api.open-meteo.com/v1/archive",
        description="Official Open-Meteo Historical Weather Archive API endpoint",
    )
    OPEN_METEO_GEOCODING_URL: str = Field(
        default="https://geocoding-api.open-meteo.com/v1/search",
        description="Official Open-Meteo Geocoding API endpoint for lat/lon resolution",
    )
    OPEN_METEO_AIR_QUALITY_URL: str = Field(
        default="https://air-quality-api.open-meteo.com/v1/air-quality",
        description="Official Open-Meteo Air Quality API endpoint",
    )
    OPEN_METEO_ELEVATION_URL: str = Field(
        default="https://api.open-meteo.com/v1/elevation",
        description="Official Open-Meteo Elevation API endpoint",
    )

    # Optional API Key (for Open-Meteo Commercial subscription if deployed, otherwise empty)
    OPEN_METEO_API_KEY: str = Field(
        default="",
        description="Optional API key for Open-Meteo commercial tier (leave empty for open access)",
    )

    # Network and Resilience Policies
    REQUEST_TIMEOUT_SECONDS: float = Field(
        default=10.0,
        description="Timeout for HTTP requests in seconds",
    )
    MAX_RETRIES: int = Field(
        default=3,
        description="Maximum retry attempts on transient network errors or HTTP 5xx",
    )
    RETRY_BACKOFF_FACTOR: float = Field(
        default=0.5,
        description="Exponential backoff factor in seconds",
    )

    # Meteorological Safety & Physical Sanity Limits
    MIN_VALID_LATITUDE: float = -90.0
    MAX_VALID_LATITUDE: float = 90.0
    MIN_VALID_LONGITUDE: float = -180.0
    MAX_VALID_LONGITUDE: float = 180.0

    # Max forecast horizon allowed by Open-Meteo
    MAX_FORECAST_DAYS: int = 16
    DEFAULT_FORECAST_DAYS: int = 7

    # Earliest available historical date in Open-Meteo Archive
    MIN_HISTORICAL_YEAR: int = 1940

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()
