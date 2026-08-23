"""
M3 Models and Schemas
Defines standardized Pydantic models for meteorological parameters, Open-Meteo payloads,
M2 integration contracts, and M4 conversational AI factual context.
"""

from typing import List, Optional, Dict, Any
from datetime import datetime, date
from pydantic import BaseModel, Field, field_validator


# =====================================================================
# WMO Code Standard (WMO Code Table 4677: Present Weather)
# =====================================================================
WMO_WEATHER_CODE_DESCRIPTIONS: Dict[int, str] = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Depositing rime fog",
    51: "Drizzle: Light intensity",
    53: "Drizzle: Moderate intensity",
    55: "Drizzle: Dense intensity",
    56: "Freezing Drizzle: Light intensity",
    57: "Freezing Drizzle: Dense intensity",
    61: "Rain: Slight intensity",
    63: "Rain: Moderate intensity",
    65: "Rain: Heavy intensity",
    66: "Freezing Rain: Light intensity",
    67: "Freezing Rain: Heavy intensity",
    71: "Snow fall: Slight intensity",
    73: "Snow fall: Moderate intensity",
    75: "Snow fall: Heavy intensity",
    77: "Snow grains",
    80: "Rain showers: Slight",
    81: "Rain showers: Moderate",
    82: "Rain showers: Violent",
    85: "Snow showers: Slight",
    86: "Snow showers: Heavy",
    95: "Thunderstorm: Slight or moderate",
    96: "Thunderstorm with slight hail",
    99: "Thunderstorm with heavy hail",
}


def get_wmo_description(code: Optional[int]) -> str:
    """Returns the standardized WMO 4677 text description for a given weather code."""
    if code is None:
        return "Unknown"
    return WMO_WEATHER_CODE_DESCRIPTIONS.get(code, f"Weather code {code}")


def degrees_to_cardinal(deg: Optional[float]) -> Optional[str]:
    """Converts wind direction in degrees (0-360) to 8-point cardinal compass direction."""
    if deg is None:
        return None
    val = int((deg / 45) + 0.5) % 8
    cardinals = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return cardinals[val]


# =====================================================================
# Location & Geographic Models
# =====================================================================
class Coordinates(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0, description="Latitude in decimal degrees WGS84")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="Longitude in decimal degrees WGS84")


class LocationInfo(BaseModel):
    name: Optional[str] = Field(None, description="City or locality name")
    latitude: float = Field(..., ge=-90.0, le=90.0, description="Latitude in decimal degrees")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="Longitude in decimal degrees")
    elevation_m: Optional[float] = Field(None, description="Elevation above sea level in meters")
    timezone: Optional[str] = Field("UTC", description="Timezone identifier e.g. 'Asia/Kolkata'")
    country: Optional[str] = Field(None, description="Country name")
    country_code: Optional[str] = Field(None, description="ISO 2-letter country code")
    admin1: Optional[str] = Field(None, description="State, province or primary administrative division")


class GeocodingResult(BaseModel):
    id: Optional[int] = None
    name: str
    latitude: float
    longitude: float
    elevation: Optional[float] = None
    country: Optional[str] = None
    country_code: Optional[str] = None
    admin1: Optional[str] = None
    timezone: Optional[str] = "UTC"


# =====================================================================
# Core Standardized Weather Models
# =====================================================================
class StandardizedCurrentWeather(BaseModel):
    timestamp: str = Field(..., description="Observation timestamp in ISO-8601 UTC format")
    temperature_c: float = Field(..., description="Air temperature at 2 meters in degrees Celsius")
    apparent_temperature_c: Optional[float] = Field(None, description="Apparent ('feels like') temperature in °C")
    humidity_percent: Optional[int] = Field(None, ge=0, le=100, description="Relative humidity percentage (0-100%)")
    precipitation_mm: Optional[float] = Field(None, ge=0.0, description="Total precipitation in millimeters")
    rain_mm: Optional[float] = Field(None, ge=0.0, description="Rainfall in millimeters")
    showers_mm: Optional[float] = Field(None, ge=0.0, description="Shower precipitation in millimeters")
    snowfall_cm: Optional[float] = Field(None, ge=0.0, description="Snowfall amount in centimeters")
    weather_code: Optional[int] = Field(None, description="WMO 4677 weather interpretation code")
    weather_description: Optional[str] = Field(None, description="Human-readable WMO weather condition")
    cloud_cover_percent: Optional[int] = Field(None, ge=0, le=100, description="Cloud cover percentage (0-100%)")
    pressure_hpa: Optional[float] = Field(None, description="Atmospheric pressure in hectopascals / hPa")
    surface_pressure_hpa: Optional[float] = Field(None, description="Surface level pressure in hPa")
    wind_speed_kmh: Optional[float] = Field(None, ge=0.0, description="Wind speed at 10m in km/h")
    wind_direction_deg: Optional[int] = Field(None, ge=0, le=360, description="Wind direction in degrees (0-360°)")
    wind_direction_cardinal: Optional[str] = Field(None, description="Cardinal wind direction (e.g. 'N', 'SW')")
    wind_gusts_kmh: Optional[float] = Field(None, ge=0.0, description="Wind gusts in km/h")
    visibility_m: Optional[float] = Field(None, ge=0.0, description="Horizontal visibility in meters")
    is_day: Optional[bool] = Field(None, description="True if sun is above horizon at observation time")
    uv_index: Optional[float] = Field(None, ge=0.0, description="UV Index (0-15+)")


class HourlyForecastItem(BaseModel):
    timestamp: str = Field(..., description="Forecast time in ISO-8601 format")
    temperature_c: Optional[float] = Field(None, description="Temperature in °C")
    apparent_temperature_c: Optional[float] = Field(None, description="Apparent temperature in °C")
    humidity_percent: Optional[int] = Field(None, ge=0, le=100, description="Relative humidity %")
    precipitation_probability_percent: Optional[int] = Field(None, ge=0, le=100, description="Precipitation probability %")
    precipitation_mm: Optional[float] = Field(None, ge=0.0, description="Precipitation amount in mm")
    weather_code: Optional[int] = Field(None, description="WMO weather code")
    weather_description: Optional[str] = Field(None, description="WMO condition description")
    cloud_cover_percent: Optional[int] = Field(None, ge=0, le=100, description="Cloud cover %")
    pressure_hpa: Optional[float] = Field(None, description="Pressure in hPa")
    wind_speed_kmh: Optional[float] = Field(None, ge=0.0, description="Wind speed in km/h")
    wind_direction_deg: Optional[int] = Field(None, ge=0, le=360, description="Wind direction in degrees")
    uv_index: Optional[float] = Field(None, ge=0.0, description="UV Index")
    is_day: Optional[bool] = Field(None, description="Daylight indicator")


class DailyForecastItem(BaseModel):
    date: str = Field(..., description="Date in YYYY-MM-DD format")
    temp_max_c: Optional[float] = Field(None, description="Maximum temperature in °C")
    temp_min_c: Optional[float] = Field(None, description="Minimum temperature in °C")
    apparent_temp_max_c: Optional[float] = Field(None, description="Max apparent temperature in °C")
    apparent_temp_min_c: Optional[float] = Field(None, description="Min apparent temperature in °C")
    precipitation_sum_mm: Optional[float] = Field(None, ge=0.0, description="Total daily precipitation in mm")
    rain_sum_mm: Optional[float] = Field(None, ge=0.0, description="Total daily rain in mm")
    precipitation_probability_max_percent: Optional[int] = Field(None, ge=0, le=100, description="Peak rain probability %")
    weather_code: Optional[int] = Field(None, description="Dominant WMO weather code")
    weather_description: Optional[str] = Field(None, description="Dominant WMO weather description")
    wind_speed_max_kmh: Optional[float] = Field(None, ge=0.0, description="Max wind speed in km/h")
    wind_gusts_max_kmh: Optional[float] = Field(None, ge=0.0, description="Max wind gusts in km/h")
    wind_direction_dominant_deg: Optional[int] = Field(None, ge=0, le=360, description="Dominant wind direction deg")
    uv_index_max: Optional[float] = Field(None, ge=0.0, description="Max daily UV index")
    sunrise: Optional[str] = Field(None, description="Sunrise timestamp in ISO-8601")
    sunset: Optional[str] = Field(None, description="Sunset timestamp in ISO-8601")


class HistoricalDailyItem(BaseModel):
    date: str = Field(..., description="Historical date in YYYY-MM-DD format")
    temp_max_c: Optional[float] = None
    temp_min_c: Optional[float] = None
    temp_mean_c: Optional[float] = None
    precipitation_sum_mm: Optional[float] = None
    rain_sum_mm: Optional[float] = None
    weather_code: Optional[int] = None
    weather_description: Optional[str] = None
    wind_speed_max_kmh: Optional[float] = None


# =====================================================================
# M2 Backend Integration Contract (Standard Full Response)
# =====================================================================
class M2WeatherResponse(BaseModel):
    status: str = Field(default="success", description="Status string: 'success' | 'error'")
    source: str = Field(default="Open-Meteo", description="Authoritative meteorological data source")
    retrieved_at_utc: str = Field(..., description="Timestamp when data was normalized in UTC")
    location: LocationInfo = Field(..., description="Resolved location metadata")
    current: Optional[StandardizedCurrentWeather] = Field(None, description="Current normalized observations")
    forecast_hourly: Optional[List[HourlyForecastItem]] = Field(None, description="Hourly forecast time-series")
    forecast_daily: Optional[List[DailyForecastItem]] = Field(None, description="Daily aggregated forecast")
    historical_daily: Optional[List[HistoricalDailyItem]] = Field(None, description="Historical observations")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Metadata including coordinate precision, model generation time")


# =====================================================================
# M4 AI / LLM Context Contract (Compact, Factual, Hallucination-Proof)
# =====================================================================
class M4ForecastSummary(BaseModel):
    temp_min_c: Optional[float] = None
    temp_max_c: Optional[float] = None
    expected_condition: Optional[str] = None
    max_rain_probability_pct: Optional[int] = None
    precipitation_expected_mm: Optional[float] = None


class M4WeatherContext(BaseModel):
    """
    Compact, high-density factual payload strictly tailored for M4 LLM prompt feeding.
    Free of verbose boilerplate, containing only verified meteorological facts to eliminate hallucination.
    """
    location: str = Field(..., description="Formatted location name")
    coordinates: List[float] = Field(..., description="[Latitude, Longitude]")
    as_of_utc: str = Field(..., description="Observation timestamp UTC")
    temperature_c: float = Field(..., description="Current temperature in Celsius")
    feels_like_c: Optional[float] = Field(None, description="Feels like temperature in Celsius")
    condition: str = Field(..., description="WMO weather condition text")
    humidity_pct: Optional[int] = Field(None, description="Relative humidity %")
    rain_mm: Optional[float] = Field(None, description="Current rain in mm")
    rain_probability_pct: Optional[int] = Field(None, description="Today's max rain probability %")
    wind_kmh: Optional[float] = Field(None, description="Wind speed in km/h")
    wind_direction: Optional[str] = Field(None, description="Cardinal wind direction (e.g. 'NW')")
    pressure_hpa: Optional[float] = Field(None, description="Pressure in hPa")
    cloud_cover_pct: Optional[int] = Field(None, description="Cloud cover %")
    uv_index: Optional[float] = Field(None, description="UV Index")
    forecast_24h: Optional[M4ForecastSummary] = Field(None, description="Summary for next 24 hours")
    source: str = Field(default="Open-Meteo / WMO", description="Data source verification")


# =====================================================================
# Standardized Error Response Model
# =====================================================================
class WeatherServiceError(BaseModel):
    status: str = "error"
    error_code: str = Field(..., description="Standardized error machine code e.g. 'INVALID_COORDINATES'")
    message: str = Field(..., description="Human-readable description of error")
    details: Optional[Dict[str, Any]] = Field(None, description="Detailed diagnostic context")
    timestamp: str = Field(default_factory=lambda: datetime.utcnow().isoformat() + "Z")
