"""
Unit tests for WeatherDataNormalizer.
Tests data transformations, WMO code interpretation, unit standardization,
and M2 / M4 contract conversions.
"""

import pytest
from app.normalizer import WeatherDataNormalizer
from app.models import (
    get_wmo_description,
    degrees_to_cardinal,
    M2WeatherResponse,
    M4WeatherContext,
)


class TestWmoCodeDescriptions:
    def test_wmo_code_mapping(self):
        assert get_wmo_description(0) == "Clear sky"
        assert get_wmo_description(1) == "Mainly clear"
        assert get_wmo_description(2) == "Partly cloudy"
        assert get_wmo_description(3) == "Overcast"
        assert get_wmo_description(45) == "Fog"
        assert get_wmo_description(51) == "Drizzle: Light intensity"
        assert get_wmo_description(61) == "Rain: Slight intensity"
        assert get_wmo_description(71) == "Snow fall: Slight intensity"
        assert get_wmo_description(80) == "Rain showers: Slight"
        assert get_wmo_description(95) == "Thunderstorm: Slight or moderate"
        assert get_wmo_description(999) == "Weather code 999"
        assert get_wmo_description(None) == "Unknown"


class TestWindCardinalConversion:
    def test_degrees_to_cardinal(self):
        assert degrees_to_cardinal(0) == "N"
        assert degrees_to_cardinal(45) == "NE"
        assert degrees_to_cardinal(90) == "E"
        assert degrees_to_cardinal(135) == "SE"
        assert degrees_to_cardinal(180) == "S"
        assert degrees_to_cardinal(225) == "SW"
        assert degrees_to_cardinal(270) == "W"
        assert degrees_to_cardinal(315) == "NW"
        assert degrees_to_cardinal(360) == "N"
        assert degrees_to_cardinal(None) is None


class TestCurrentWeatherNormalization:
    def test_normalize_current_payload(self, sample_open_meteo_forecast_raw):
        current_raw = sample_open_meteo_forecast_raw["current"]
        norm = WeatherDataNormalizer.normalize_current(current_raw)

        assert norm.temperature_c == 31.2
        assert norm.apparent_temperature_c == 36.5
        assert norm.humidity_percent == 78
        assert norm.weather_code == 1
        assert norm.weather_description == "Mainly clear"
        assert norm.wind_speed_kmh == 14.5
        assert norm.wind_direction_deg == 180
        assert norm.wind_direction_cardinal == "S"
        assert norm.pressure_hpa == 1004.2
        assert norm.is_day is True
        assert norm.precipitation_mm == 0.0
        assert "T" in norm.timestamp
        assert norm.timestamp.endswith("Z")


class TestHourlyAndDailyNormalization:
    def test_normalize_hourly_series(self, sample_open_meteo_forecast_raw):
        hourly_raw = sample_open_meteo_forecast_raw["hourly"]
        items = WeatherDataNormalizer.normalize_hourly(hourly_raw, limit=4)

        assert len(items) == 4
        assert items[0].temperature_c == 28.0
        assert items[0].humidity_percent == 85
        assert items[0].weather_code == 0
        assert items[0].weather_description == "Clear sky"
        assert items[3].temperature_c == 31.2
        assert items[3].weather_description == "Mainly clear"

    def test_normalize_daily_series(self, sample_open_meteo_forecast_raw):
        daily_raw = sample_open_meteo_forecast_raw["daily"]
        items = WeatherDataNormalizer.normalize_daily(daily_raw)

        assert len(items) == 2
        assert items[0].date == "2026-08-23"
        assert items[0].temp_max_c == 36.2
        assert items[0].temp_min_c == 26.5
        assert items[0].weather_description == "Mainly clear"
        assert items[1].date == "2026-08-24"
        assert items[1].precipitation_probability_max_percent == 75
        assert items[1].weather_description == "Rain: Slight intensity"


class TestM2AndM4PayloadContract:
    def test_to_m2_response(self, sample_open_meteo_forecast_raw):
        m2_resp = WeatherDataNormalizer.to_m2_response(
            raw_data=sample_open_meteo_forecast_raw,
            location_name="Delhi",
            include_hourly=True,
            include_daily=True,
        )

        assert isinstance(m2_resp, M2WeatherResponse)
        assert m2_resp.status == "success"
        assert m2_resp.source == "Open-Meteo"
        assert m2_resp.location.name == "Delhi"
        assert m2_resp.current is not None
        assert m2_resp.current.temperature_c == 31.2
        assert len(m2_resp.forecast_hourly) == 4
        assert len(m2_resp.forecast_daily) == 2

    def test_to_m4_context(self, sample_open_meteo_forecast_raw):
        m2_resp = WeatherDataNormalizer.to_m2_response(
            raw_data=sample_open_meteo_forecast_raw,
            location_name="Delhi, India",
            include_hourly=True,
            include_daily=True,
        )
        m4_ctx = WeatherDataNormalizer.to_m4_context(m2_resp)

        assert isinstance(m4_ctx, M4WeatherContext)
        assert m4_ctx.location == "Delhi, India"
        assert m4_ctx.temperature_c == 31.2
        assert m4_ctx.feels_like_c == 36.5
        assert m4_ctx.condition == "Mainly clear"
        assert m4_ctx.humidity_pct == 78
        assert m4_ctx.wind_direction == "S"
        assert m4_ctx.forecast_24h is not None
        assert m4_ctx.forecast_24h.temp_max_c == 36.2
        assert m4_ctx.forecast_24h.max_rain_probability_pct == 25
        assert m4_ctx.source == "Open-Meteo / WMO"
