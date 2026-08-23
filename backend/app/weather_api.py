"""
M3 Weather API Client
Asynchronous HTTP client interface with Open-Meteo services (Forecast, Archive, Geocoding).
Handles connection pooling, retries with exponential backoff, timeouts, and structured error propagation.
"""

import logging
from typing import Dict, Any, Optional, List, Tuple
import asyncio
import httpx
from .config import settings
from .validator import WeatherDataValidator, ValidationError
from .normalizer import WeatherDataNormalizer
from .models import (
    M2WeatherResponse,
    M4WeatherContext,
    GeocodingResult,
)

logger = logging.getLogger("m3.weather_api")


class WeatherApiError(Exception):
    """Exception raised for external Open-Meteo API communication errors."""
    def __init__(self, message: str, status_code: int = 502, error_code: str = "UPSTREAM_API_ERROR", details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        self.details = details or {}


class OpenMeteoClient:
    """
    Client for interacting with Open-Meteo endpoints:
    - Weather Forecast API (current + hourly + daily)
    - Historical Weather Archive API
    - Geocoding API
    """

    def __init__(self, client: Optional[httpx.AsyncClient] = None):
        self._external_client = client
        self._timeout = httpx.Timeout(settings.REQUEST_TIMEOUT_SECONDS)

    async def _get_client(self) -> httpx.AsyncClient:
        if self._external_client is not None and not self._external_client.is_closed:
            return self._external_client
        return httpx.AsyncClient(timeout=self._timeout)

    async def _execute_request(self, url: str, params: Dict[str, Any], context: str = "forecast") -> Dict[str, Any]:
        """
        Executes HTTP GET request with retries and exponential backoff.
        """
        # Inject API key if configured
        if settings.OPEN_METEO_API_KEY:
            params["apikey"] = settings.OPEN_METEO_API_KEY

        last_exception: Optional[Exception] = None
        for attempt in range(1, settings.MAX_RETRIES + 1):
            try:
                # We either use injected client or manage single-request client
                if self._external_client is not None:
                    response = await self._external_client.get(url, params=params)
                else:
                    async with httpx.AsyncClient(timeout=self._timeout) as client:
                        response = await client.get(url, params=params)

                if response.status_code == 200:
                    try:
                        data = response.json()
                    except Exception as json_err:
                        raise WeatherApiError(
                            f"Failed to parse Open-Meteo JSON response: {str(json_err)}",
                            status_code=502,
                            error_code="INVALID_JSON_RESPONSE",
                        )
                    return WeatherDataValidator.validate_open_meteo_response(data, context=context)

                elif response.status_code == 400:
                    try:
                        err_payload = response.json()
                        reason = err_payload.get("reason", response.text)
                    except Exception:
                        reason = response.text
                    raise WeatherApiError(
                        f"Open-Meteo Bad Request: {reason}",
                        status_code=400,
                        error_code="BAD_REQUEST_PARAMETERS",
                        details={"response_text": reason, "params": params},
                    )

                elif response.status_code == 429:
                    raise WeatherApiError(
                        "Open-Meteo rate limit exceeded. Please apply caching or throttle requests.",
                        status_code=429,
                        error_code="RATE_LIMIT_EXCEEDED",
                    )

                elif response.status_code >= 500:
                    logger.warning(f"Open-Meteo 5xx error (attempt {attempt}/{settings.MAX_RETRIES}): HTTP {response.status_code}")
                    if attempt == settings.MAX_RETRIES:
                        raise WeatherApiError(
                            f"Open-Meteo server error: HTTP {response.status_code}",
                            status_code=502,
                            error_code="UPSTREAM_SERVER_ERROR",
                            details={"status_code": response.status_code},
                        )

            except (httpx.ConnectTimeout, httpx.ReadTimeout) as timeout_err:
                last_exception = timeout_err
                logger.warning(f"Timeout contacting Open-Meteo (attempt {attempt}/{settings.MAX_RETRIES}): {url}")
                if attempt == settings.MAX_RETRIES:
                    raise WeatherApiError(
                        f"Timeout connecting to Open-Meteo weather service ({settings.REQUEST_TIMEOUT_SECONDS}s).",
                        status_code=504,
                        error_code="UPSTREAM_TIMEOUT",
                    )

            except httpx.RequestError as req_err:
                last_exception = req_err
                logger.warning(f"Network error contacting Open-Meteo (attempt {attempt}/{settings.MAX_RETRIES}): {str(req_err)}")
                if attempt == settings.MAX_RETRIES:
                    raise WeatherApiError(
                        f"Network connectivity error reaching Open-Meteo: {str(req_err)}",
                        status_code=502,
                        error_code="NETWORK_FAILURE",
                    )

            # Exponential backoff before retry
            await asyncio.sleep(settings.RETRY_BACKOFF_FACTOR * (2 ** (attempt - 1)))

        raise WeatherApiError(
            f"Failed to fetch data from Open-Meteo after {settings.MAX_RETRIES} attempts. Reason: {last_exception}",
            status_code=502,
            error_code="MAX_RETRIES_EXCEEDED",
        )

    async def get_current_weather(
        self,
        latitude: float,
        longitude: float,
        location_name: Optional[str] = None,
    ) -> M2WeatherResponse:
        """
        Fetches real-time current weather observation from Open-Meteo Forecast API.
        """
        lat, lon = WeatherDataValidator.validate_coordinates(latitude, longitude)

        params = {
            "latitude": lat,
            "longitude": lon,
            "current": [
                "temperature_2m",
                "relative_humidity_2m",
                "apparent_temperature",
                "is_day",
                "precipitation",
                "rain",
                "showers",
                "snowfall",
                "weather_code",
                "cloud_cover",
                "pressure_msl",
                "surface_pressure",
                "wind_speed_10m",
                "wind_direction_10m",
                "wind_gusts_10m",
            ],
            "timezone": "auto",
        }

        raw_data = await self._execute_request(settings.OPEN_METEO_FORECAST_URL, params)
        return WeatherDataNormalizer.to_m2_response(
            raw_data=raw_data,
            location_name=location_name,
            include_hourly=False,
            include_daily=False,
        )

    async def get_forecast(
        self,
        latitude: float,
        longitude: float,
        forecast_days: int = 7,
        location_name: Optional[str] = None,
    ) -> M2WeatherResponse:
        """
        Fetches current weather, hourly forecast, and daily forecast from Open-Meteo.
        """
        lat, lon = WeatherDataValidator.validate_coordinates(latitude, longitude)
        days = WeatherDataValidator.validate_forecast_days(forecast_days)

        params = {
            "latitude": lat,
            "longitude": lon,
            "forecast_days": days,
            "current": [
                "temperature_2m",
                "relative_humidity_2m",
                "apparent_temperature",
                "is_day",
                "precipitation",
                "rain",
                "showers",
                "snowfall",
                "weather_code",
                "cloud_cover",
                "pressure_msl",
                "surface_pressure",
                "wind_speed_10m",
                "wind_direction_10m",
                "wind_gusts_10m",
            ],
            "hourly": [
                "temperature_2m",
                "relative_humidity_2m",
                "apparent_temperature",
                "precipitation_probability",
                "precipitation",
                "weather_code",
                "surface_pressure",
                "cloud_cover",
                "wind_speed_10m",
                "wind_direction_10m",
                "uv_index",
                "is_day",
            ],
            "daily": [
                "weather_code",
                "temperature_2m_max",
                "temperature_2m_min",
                "apparent_temperature_max",
                "apparent_temperature_min",
                "sunrise",
                "sunset",
                "uv_index_max",
                "precipitation_sum",
                "rain_sum",
                "precipitation_probability_max",
                "wind_speed_10m_max",
                "wind_gusts_10m_max",
                "wind_direction_10m_dominant",
            ],
            "timezone": "auto",
        }

        raw_data = await self._execute_request(settings.OPEN_METEO_FORECAST_URL, params)
        return WeatherDataNormalizer.to_m2_response(
            raw_data=raw_data,
            location_name=location_name,
            include_hourly=True,
            include_daily=True,
        )

    async def get_historical_weather(
        self,
        latitude: float,
        longitude: float,
        start_date: str,
        end_date: str,
        location_name: Optional[str] = None,
    ) -> M2WeatherResponse:
        """
        Fetches historical observations from the Open-Meteo Historical Archive API.
        """
        lat, lon = WeatherDataValidator.validate_coordinates(latitude, longitude)
        s_date, e_date = WeatherDataValidator.validate_historical_dates(start_date, end_date)

        params = {
            "latitude": lat,
            "longitude": lon,
            "start_date": s_date,
            "end_date": e_date,
            "daily": [
                "weather_code",
                "temperature_2m_max",
                "temperature_2m_min",
                "temperature_2m_mean",
                "precipitation_sum",
                "rain_sum",
                "wind_speed_10m_max",
            ],
            "timezone": "auto",
        }

        raw_data = await self._execute_request(settings.OPEN_METEO_ARCHIVE_URL, params)
        return WeatherDataNormalizer.to_m2_response(
            raw_data=raw_data,
            location_name=location_name,
            include_hourly=False,
            include_daily=False,
            is_historical=True,
        )

    async def geocode_location(self, query: str, count: int = 5) -> List[GeocodingResult]:
        """
        Resolves city/place names to geographic coordinates via Open-Meteo Geocoding API.
        """
        if not query or not query.strip():
            raise ValidationError("Location query cannot be empty.", error_code="EMPTY_GEOCODING_QUERY")

        params = {
            "name": query.strip(),
            "count": min(max(1, count), 20),
            "language": "en",
            "format": "json",
        }

        raw_data = await self._execute_request(settings.OPEN_METEO_GEOCODING_URL, params, context="geocoding")
        results = raw_data.get("results", [])
        if not results:
            return []

        return [
            GeocodingResult(
                id=item.get("id"),
                name=item.get("name", query),
                latitude=item.get("latitude"),
                longitude=item.get("longitude"),
                elevation=item.get("elevation"),
                country=item.get("country"),
                country_code=item.get("country_code"),
                admin1=item.get("admin1"),
                timezone=item.get("timezone", "UTC"),
            )
            for item in results
        ]

    async def get_m4_context(
        self,
        latitude: float,
        longitude: float,
        location_name: Optional[str] = None,
    ) -> M4WeatherContext:
        """
        Fetches current weather & 24h summary and transforms it into M4 LLM prompt context.
        """
        m2_resp = await self.get_forecast(latitude, longitude, forecast_days=2, location_name=location_name)
        return WeatherDataNormalizer.to_m4_context(m2_resp)
