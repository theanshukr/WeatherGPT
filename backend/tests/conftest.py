"""
Pytest configuration and mock Open-Meteo fixtures.
"""

import pytest
from typing import Dict, Any


@pytest.fixture
def sample_open_meteo_forecast_raw() -> Dict[str, Any]:
    """Sample raw payload returned by Open-Meteo Forecast endpoint."""
    return {
        "latitude": 28.625,
        "longitude": 77.25,
        "generationtime_ms": 0.045,
        "utc_offset_seconds": 0,
        "timezone": "UTC",
        "timezone_abbreviation": "UTC",
        "elevation": 216.0,
        "current": {
            "time": "2026-08-23T03:00",
            "interval": 900,
            "temperature_2m": 31.2,
            "relative_humidity_2m": 78,
            "apparent_temperature": 36.5,
            "is_day": 1,
            "precipitation": 0.0,
            "rain": 0.0,
            "showers": 0.0,
            "snowfall": 0.0,
            "weather_code": 1,
            "cloud_cover": 25,
            "pressure_msl": 1004.2,
            "surface_pressure": 980.1,
            "wind_speed_10m": 14.5,
            "wind_direction_10m": 180,
            "wind_gusts_10m": 22.0,
        },
        "hourly": {
            "time": ["2026-08-23T00:00", "2026-08-23T01:00", "2026-08-23T02:00", "2026-08-23T03:00"],
            "temperature_2m": [28.0, 27.5, 29.0, 31.2],
            "relative_humidity_2m": [85, 88, 82, 78],
            "apparent_temperature": [32.0, 31.0, 33.5, 36.5],
            "precipitation_probability": [10, 15, 20, 10],
            "precipitation": [0.0, 0.0, 0.0, 0.0],
            "weather_code": [0, 1, 1, 1],
            "surface_pressure": [982.0, 981.5, 981.0, 980.1],
            "cloud_cover": [10, 20, 20, 25],
            "wind_speed_10m": [8.0, 9.5, 12.0, 14.5],
            "wind_direction_10m": [160, 170, 175, 180],
            "uv_index": [0.0, 0.0, 2.1, 5.4],
            "is_day": [0, 0, 1, 1],
        },
        "daily": {
            "time": ["2026-08-23", "2026-08-24"],
            "weather_code": [1, 61],
            "temperature_2m_max": [36.2, 34.0],
            "temperature_2m_min": [26.5, 25.8],
            "apparent_temperature_max": [41.0, 39.5],
            "apparent_temperature_min": [29.0, 28.0],
            "sunrise": ["2026-08-23T05:54", "2026-08-24T05:55"],
            "sunset": ["2026-08-23T18:52", "2026-08-24T18:51"],
            "uv_index_max": [8.5, 6.2],
            "precipitation_sum": [0.0, 4.2],
            "rain_sum": [0.0, 4.2],
            "precipitation_probability_max": [25, 75],
            "wind_speed_10m_max": [18.2, 22.4],
            "wind_gusts_10m_max": [28.0, 35.0],
            "wind_direction_10m_dominant": [185, 110],
        },
    }


@pytest.fixture
def sample_open_meteo_archive_raw() -> Dict[str, Any]:
    """Sample raw payload returned by Open-Meteo Historical Archive endpoint."""
    return {
        "latitude": 28.625,
        "longitude": 77.25,
        "generationtime_ms": 0.082,
        "utc_offset_seconds": 0,
        "timezone": "UTC",
        "timezone_abbreviation": "UTC",
        "elevation": 216.0,
        "daily": {
            "time": ["2023-01-01", "2023-01-02"],
            "weather_code": [45, 0],
            "temperature_2m_max": [18.5, 20.1],
            "temperature_2m_min": [8.2, 7.5],
            "temperature_2m_mean": [13.3, 13.8],
            "precipitation_sum": [0.0, 0.0],
            "rain_sum": [0.0, 0.0],
            "wind_speed_10m_max": [10.2, 8.5],
        }
    }


@pytest.fixture
def sample_open_meteo_geocoding_raw() -> Dict[str, Any]:
    """Sample raw payload returned by Open-Meteo Geocoding endpoint."""
    return {
        "results": [
            {
                "id": 1273294,
                "name": "Delhi",
                "latitude": 28.65195,
                "longitude": 77.23149,
                "elevation": 216.0,
                "feature_code": "PPLA",
                "country_code": "IN",
                "admin1_id": 1273293,
                "timezone": "Asia/Kolkata",
                "country": "India",
                "admin1": "National Capital Territory of Delhi",
            },
            {
                "id": 1261481,
                "name": "New Delhi",
                "latitude": 28.63576,
                "longitude": 77.22445,
                "elevation": 216.0,
                "feature_code": "PPLC",
                "country_code": "IN",
                "timezone": "Asia/Kolkata",
                "country": "India",
                "admin1": "National Capital Territory of Delhi",
            }
        ],
        "generationtime_ms": 0.12
    }
