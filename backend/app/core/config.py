from typing import Optional, List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    PROJECT_NAME: str = "WeatherGPT Backend"
    API_V1_STR: str = "/api/v1"
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = True

    # CORS
    BACKEND_CORS_ORIGINS: List[str] = ["*"]

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/weathergpt"

    # Supabase Cloud
    SUPABASE_URL: str = "https://your-supabase-project.supabase.co"
    SUPABASE_KEY: Optional[str] = None

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # LLM Configuration
    DEFAULT_LLM_PROVIDER: str = "gemini"  # gemini, sarvam
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_MODEL: str = "gemini-3.5-flash-lite"
    SARVAM_API_KEY: Optional[str] = None

    # Weather APIs
    OPEN_METEO_BASE_URL: str = "https://api.open-meteo.com/v1"
    OPEN_METEO_API_KEY: Optional[str] = None
    GEOCODING_BASE_URL: str = "https://geocoding-api.open-meteo.com/v1"
    WEATHERAPI_KEY: Optional[str] = None
    WEATHERAPI_BASE_URL: str = "https://api.weatherapi.com/v1"
    # Historical Weather (Archive) API — separate host from the forecast API.
    # Used for the /weather/climate-trend endpoint (item #4 of the
    # completion plan): simple "last N years" aggregates, not a full
    # climate-analytics platform.
    OPEN_METEO_ARCHIVE_URL: str = "https://archive-api.open-meteo.com/v1"

    # Official Alert Source (NDMA SACHET CAP feed). Leave unset until you
    # have a real agency identifier from NDMA/C-DOT — see
    # app/services/alerts/official_alert_client.py for details. Without
    # this, alerts are computed threshold-based only (clearly labeled as
    # such), not official government warnings.
    OFFICIAL_ALERT_IDENTIFIER: Optional[str] = None
    # How often (seconds) the background poller checks for new official
    # alerts and broadcasts severe ones over WebSocket.
    ALERT_POLL_INTERVAL_SECONDS: int = 300


settings = Settings()
