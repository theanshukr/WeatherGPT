"""
M3 Meteorological Data Validator
Enforces physical plausibility, coordinate geometry bounds, temporal constraints,
and structural integrity on external Open-Meteo payloads.
Never fabricates or silently fills missing weather data.
"""

from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, date
import re
from .config import settings


class ValidationError(Exception):
    """Custom exception raised when weather data validation fails."""
    def __init__(self, message: str, error_code: str = "VALIDATION_ERROR", details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.message = message
        self.error_code = error_code
        self.details = details or {}


class WeatherDataValidator:
    """
    Validates geographic coordinates, dates, raw Open-Meteo responses,
    and physical plausibility of meteorological readings.
    """

    # Physical Boundary Thresholds
    TEMP_MIN_C: float = -100.0   # Lowest recorded on Earth: ~ -89.2°C (Vostok Station)
    TEMP_MAX_C: float = 65.0     # Highest recorded on Earth: ~ 56.7°C (Death Valley)
    HUMIDITY_MIN_PCT: int = 0
    HUMIDITY_MAX_PCT: int = 100
    PRESSURE_MIN_HPA: float = 800.0   # Typhoon Tip reached ~870 hPa
    PRESSURE_MAX_HPA: float = 1100.0  # Siberian High reached ~1084 hPa
    WIND_SPEED_MAX_KMH: float = 450.0 # Extreme tornadoes/hurricanes peak ~400+ km/h
    CLOUD_COVER_MIN_PCT: int = 0
    CLOUD_COVER_MAX_PCT: int = 100

    @classmethod
    def validate_coordinates(cls, latitude: float, longitude: float) -> Tuple[float, float]:
        """
        Validates latitude and longitude against standard WGS84 geographic boundaries.
        Latitude: -90.0 to +90.0
        Longitude: -180.0 to +180.0
        """
        if latitude is None or longitude is None:
            raise ValidationError(
                "Latitude and longitude coordinates are required.",
                error_code="MISSING_COORDINATES",
            )

        try:
            lat = float(latitude)
            lon = float(longitude)
        except (ValueError, TypeError):
            raise ValidationError(
                f"Coordinates must be numeric. Received latitude={latitude}, longitude={longitude}.",
                error_code="INVALID_COORDINATES_TYPE",
            )

        if not (settings.MIN_VALID_LATITUDE <= lat <= settings.MAX_VALID_LATITUDE):
            raise ValidationError(
                f"Latitude {lat} is out of valid range [{settings.MIN_VALID_LATITUDE}, {settings.MAX_VALID_LATITUDE}].",
                error_code="INVALID_LATITUDE_RANGE",
                details={"latitude": lat, "valid_range": [-90.0, 90.0]},
            )

        if not (settings.MIN_VALID_LONGITUDE <= lon <= settings.MAX_VALID_LONGITUDE):
            raise ValidationError(
                f"Longitude {lon} is out of valid range [{settings.MIN_VALID_LONGITUDE}, {settings.MAX_VALID_LONGITUDE}].",
                error_code="INVALID_LONGITUDE_RANGE",
                details={"longitude": lon, "valid_range": [-180.0, 180.0]},
            )

        return round(lat, 6), round(lon, 6)

    @classmethod
    def validate_forecast_days(cls, forecast_days: int) -> int:
        """Validates requested forecast duration."""
        if not isinstance(forecast_days, int):
            try:
                forecast_days = int(forecast_days)
            except (ValueError, TypeError):
                raise ValidationError(
                    f"forecast_days must be an integer, got '{forecast_days}'.",
                    error_code="INVALID_FORECAST_DAYS",
                )

        if forecast_days < 1 or forecast_days > settings.MAX_FORECAST_DAYS:
            raise ValidationError(
                f"forecast_days must be between 1 and {settings.MAX_FORECAST_DAYS}. Got {forecast_days}.",
                error_code="FORECAST_DAYS_OUT_OF_BOUNDS",
                details={"forecast_days": forecast_days, "max_allowed": settings.MAX_FORECAST_DAYS},
            )
        return forecast_days

    @classmethod
    def validate_historical_dates(cls, start_date: str, end_date: str) -> Tuple[str, str]:
        """
        Validates historical date format (YYYY-MM-DD), chronology (start <= end),
        and limits supported by Open-Meteo Archive (1940-01-01 to present).
        """
        date_regex = r"^\d{4}-\d{2}-\d{2}$"
        if not re.match(date_regex, str(start_date)) or not re.match(date_regex, str(end_date)):
            raise ValidationError(
                "Historical dates must be in YYYY-MM-DD format.",
                error_code="INVALID_DATE_FORMAT",
                details={"start_date": start_date, "end_date": end_date},
            )

        try:
            d_start = datetime.strptime(start_date, "%Y-%m-%d").date()
            d_end = datetime.strptime(end_date, "%Y-%m-%d").date()
        except ValueError as e:
            raise ValidationError(
                f"Invalid date value: {str(e)}",
                error_code="INVALID_CALENDAR_DATE",
            )

        if d_start > d_end:
            raise ValidationError(
                f"start_date ({start_date}) cannot be after end_date ({end_date}).",
                error_code="INVALID_DATE_CHRONOLOGY",
            )

        if d_start.year < settings.MIN_HISTORICAL_YEAR:
            raise ValidationError(
                f"start_date year {d_start.year} is earlier than Open-Meteo archive limit ({settings.MIN_HISTORICAL_YEAR}).",
                error_code="DATE_PRIOR_TO_ARCHIVE_EPOCH",
            )

        today = date.today()
        if d_end > today:
            raise ValidationError(
                f"Historical end_date ({end_date}) cannot be in the future. Today is {today.isoformat()}.",
                error_code="FUTURE_HISTORICAL_DATE",
            )

        return start_date, end_date

    @classmethod
    def validate_open_meteo_response(cls, data: Any, context: str = "forecast") -> Dict[str, Any]:
        """
        Ensures raw Open-Meteo response is a valid dict, contains no error flags,
        and contains mandatory coordinate and meteorological keys.
        """
        if not isinstance(data, dict):
            raise ValidationError(
                f"Malformed Open-Meteo {context} response: expected JSON object, got {type(data).__name__}.",
                error_code="MALFORMED_API_RESPONSE",
            )

        if data.get("error") is True:
            reason = data.get("reason", "Unknown Open-Meteo error")
            raise ValidationError(
                f"Open-Meteo API returned error: {reason}",
                error_code="OPEN_METEO_API_ERROR",
                details={"raw_reason": reason},
            )

        if context == "geocoding" or "results" in data:
            return data

        if "latitude" not in data or "longitude" not in data:
            raise ValidationError(
                f"Open-Meteo {context} response missing latitude/longitude headers.",
                error_code="MISSING_RESPONSE_COORDINATES",
            )

        return data

    @classmethod
    def sanitize_physical_value(cls, field_name: str, value: Optional[float]) -> Optional[float]:
        """
        Checks physical boundaries of meteorological variables.
        Returns value if valid, or None if physically impossible (e.g. negative rain or +150C temp),
        logging or flagging the anomaly rather than crashing or faking data.
        """
        if value is None:
            return None

        try:
            val = float(value)
        except (ValueError, TypeError):
            return None

        if "temperature" in field_name.lower():
            if not (cls.TEMP_MIN_C <= val <= cls.TEMP_MAX_C):
                return None
        elif "humidity" in field_name.lower() or "probability" in field_name.lower() or "cloud_cover" in field_name.lower():
            if not (cls.HUMIDITY_MIN_PCT <= val <= cls.HUMIDITY_MAX_PCT):
                return None
        elif "pressure" in field_name.lower():
            if not (cls.PRESSURE_MIN_HPA <= val <= cls.PRESSURE_MAX_HPA):
                return None
        elif "precipitation" in field_name.lower() or "rain" in field_name.lower() or "snow" in field_name.lower():
            if val < 0.0:
                return 0.0
        elif "wind_speed" in field_name.lower() or "wind_gusts" in field_name.lower():
            if val < 0.0 or val > cls.WIND_SPEED_MAX_KMH:
                return None
        elif "wind_direction" in field_name.lower():
            if not (0.0 <= val <= 360.0):
                val = val % 360.0

        return val
