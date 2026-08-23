"""
M3 Meteorological Data Normalizer
Transforms raw Open-Meteo payloads into standardized M3 formats, enforcing
consistent SI/meteorological units (Celsius, km/h, hPa, mm, %, degrees) and ISO-8601 timestamps.
Produces tailored outputs for M2 (Backend) and M4 (AI / LLM).
"""

from typing import Dict, Any, List, Optional
from datetime import datetime, timezone
from .models import (
    LocationInfo,
    StandardizedCurrentWeather,
    HourlyForecastItem,
    DailyForecastItem,
    HistoricalDailyItem,
    M2WeatherResponse,
    M4WeatherContext,
    M4ForecastSummary,
    get_wmo_description,
    degrees_to_cardinal,
)
from .validator import WeatherDataValidator


class WeatherDataNormalizer:
    """
    Normalizes Open-Meteo API outputs into consistent M3 standardized objects.
    """

    @classmethod
    def _normalize_timestamp(cls, raw_ts: Optional[str]) -> str:
        """Ensures timestamp is standard ISO-8601 with UTC Z indicator if missing."""
        if not raw_ts:
            return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        # If open-meteo provides '2026-08-23T03:00'
        if len(raw_ts) == 16 and "T" in raw_ts:
            return f"{raw_ts}:00Z"
        if not raw_ts.endswith("Z") and "+" not in raw_ts:
            return f"{raw_ts}Z"
        return raw_ts

    @classmethod
    def normalize_current(cls, raw_current: Dict[str, Any]) -> StandardizedCurrentWeather:
        """
        Normalizes raw Open-Meteo 'current' or 'current_weather' object.
        Applies physical boundary sanitization and WMO code enrichment.
        """
        raw_temp = WeatherDataValidator.sanitize_physical_value("temperature", raw_current.get("temperature_2m") or raw_current.get("temperature"))
        if raw_temp is None:
            raw_temp = 0.0 # fallback only if missing in non-strict test, but validated before

        wmo_code = raw_current.get("weather_code")
        if wmo_code is None:
            wmo_code = raw_current.get("weathercode")

        wind_deg = raw_current.get("wind_direction_10m") or raw_current.get("winddirection")
        wind_cardinal = degrees_to_cardinal(wind_deg) if wind_deg is not None else None

        humidity = raw_current.get("relative_humidity_2m")
        if humidity is not None:
            humidity = int(WeatherDataValidator.sanitize_physical_value("humidity", humidity) or humidity)

        cloud_cover = raw_current.get("cloud_cover")
        if cloud_cover is not None:
            cloud_cover = int(WeatherDataValidator.sanitize_physical_value("cloud_cover", cloud_cover) or cloud_cover)

        is_day_val = raw_current.get("is_day")
        is_day = bool(is_day_val == 1) if is_day_val is not None else None

        return StandardizedCurrentWeather(
            timestamp=cls._normalize_timestamp(raw_current.get("time")),
            temperature_c=round(raw_temp, 1) if raw_temp is not None else 0.0,
            apparent_temperature_c=round(raw_current["apparent_temperature"], 1) if raw_current.get("apparent_temperature") is not None else None,
            humidity_percent=humidity,
            precipitation_mm=WeatherDataValidator.sanitize_physical_value("precipitation", raw_current.get("precipitation")),
            rain_mm=WeatherDataValidator.sanitize_physical_value("rain", raw_current.get("rain")),
            showers_mm=WeatherDataValidator.sanitize_physical_value("showers", raw_current.get("showers")),
            snowfall_cm=raw_current.get("snowfall"),
            weather_code=wmo_code,
            weather_description=get_wmo_description(wmo_code),
            cloud_cover_percent=cloud_cover,
            pressure_hpa=WeatherDataValidator.sanitize_physical_value("pressure", raw_current.get("pressure_msl") or raw_current.get("surface_pressure")),
            surface_pressure_hpa=WeatherDataValidator.sanitize_physical_value("pressure", raw_current.get("surface_pressure")),
            wind_speed_kmh=WeatherDataValidator.sanitize_physical_value("wind_speed", raw_current.get("wind_speed_10m") or raw_current.get("windspeed")),
            wind_direction_deg=int(wind_deg) if wind_deg is not None else None,
            wind_direction_cardinal=wind_cardinal,
            wind_gusts_kmh=WeatherDataValidator.sanitize_physical_value("wind_gusts", raw_current.get("wind_gusts_10m")),
            visibility_m=raw_current.get("visibility"),
            is_day=is_day,
            uv_index=raw_current.get("uv_index"),
        )

    @classmethod
    def normalize_hourly(cls, raw_hourly: Dict[str, Any], limit: Optional[int] = 24) -> List[HourlyForecastItem]:
        """Normalizes Open-Meteo 'hourly' dictionary of arrays into a list of structured items."""
        if not raw_hourly or "time" not in raw_hourly:
            return []

        times = raw_hourly.get("time", [])
        length = len(times)
        if limit is not None:
            length = min(length, limit)

        items: List[HourlyForecastItem] = []
        for i in range(length):
            w_code = raw_hourly.get("weather_code", [None]*length)[i]
            if w_code is None:
                w_code = raw_hourly.get("weathercode", [None]*length)[i]

            items.append(
                HourlyForecastItem(
                    timestamp=cls._normalize_timestamp(times[i]),
                    temperature_c=raw_hourly.get("temperature_2m", [None]*length)[i],
                    apparent_temperature_c=raw_hourly.get("apparent_temperature", [None]*length)[i],
                    humidity_percent=raw_hourly.get("relative_humidity_2m", [None]*length)[i],
                    precipitation_probability_percent=raw_hourly.get("precipitation_probability", [None]*length)[i],
                    precipitation_mm=raw_hourly.get("precipitation", [None]*length)[i],
                    weather_code=w_code,
                    weather_description=get_wmo_description(w_code),
                    cloud_cover_percent=raw_hourly.get("cloud_cover", [None]*length)[i],
                    pressure_hpa=raw_hourly.get("surface_pressure", [None]*length)[i] or raw_hourly.get("pressure_msl", [None]*length)[i],
                    wind_speed_kmh=raw_hourly.get("wind_speed_10m", [None]*length)[i],
                    wind_direction_deg=raw_hourly.get("wind_direction_10m", [None]*length)[i],
                    uv_index=raw_hourly.get("uv_index", [None]*length)[i],
                    is_day=bool(raw_hourly.get("is_day", [None]*length)[i] == 1) if raw_hourly.get("is_day") else None,
                )
            )
        return items

    @classmethod
    def normalize_daily(cls, raw_daily: Dict[str, Any]) -> List[DailyForecastItem]:
        """Normalizes Open-Meteo 'daily' dictionary of arrays into a list of structured daily forecast items."""
        if not raw_daily or "time" not in raw_daily:
            return []

        times = raw_daily.get("time", [])
        length = len(times)
        items: List[DailyForecastItem] = []

        for i in range(length):
            w_code = raw_daily.get("weather_code", [None]*length)[i]
            if w_code is None:
                w_code = raw_daily.get("weathercode", [None]*length)[i]

            items.append(
                DailyForecastItem(
                    date=str(times[i]),
                    temp_max_c=raw_daily.get("temperature_2m_max", [None]*length)[i],
                    temp_min_c=raw_daily.get("temperature_2m_min", [None]*length)[i],
                    apparent_temp_max_c=raw_daily.get("apparent_temperature_max", [None]*length)[i],
                    apparent_temp_min_c=raw_daily.get("apparent_temperature_min", [None]*length)[i],
                    precipitation_sum_mm=raw_daily.get("precipitation_sum", [None]*length)[i],
                    rain_sum_mm=raw_daily.get("rain_sum", [None]*length)[i],
                    precipitation_probability_max_percent=raw_daily.get("precipitation_probability_max", [None]*length)[i],
                    weather_code=w_code,
                    weather_description=get_wmo_description(w_code),
                    wind_speed_max_kmh=raw_daily.get("wind_speed_10m_max", [None]*length)[i],
                    wind_gusts_max_kmh=raw_daily.get("wind_gusts_10m_max", [None]*length)[i],
                    wind_direction_dominant_deg=raw_daily.get("wind_direction_10m_dominant", [None]*length)[i],
                    uv_index_max=raw_daily.get("uv_index_max", [None]*length)[i],
                    sunrise=raw_daily.get("sunrise", [None]*length)[i],
                    sunset=raw_daily.get("sunset", [None]*length)[i],
                )
            )
        return items

    @classmethod
    def normalize_historical_daily(cls, raw_daily: Dict[str, Any]) -> List[HistoricalDailyItem]:
        """Normalizes Open-Meteo Archive 'daily' object into historical daily items."""
        if not raw_daily or "time" not in raw_daily:
            return []

        times = raw_daily.get("time", [])
        length = len(times)
        items: List[HistoricalDailyItem] = []

        for i in range(length):
            w_code = raw_daily.get("weather_code", [None]*length)[i]
            items.append(
                HistoricalDailyItem(
                    date=str(times[i]),
                    temp_max_c=raw_daily.get("temperature_2m_max", [None]*length)[i],
                    temp_min_c=raw_daily.get("temperature_2m_min", [None]*length)[i],
                    temp_mean_c=raw_daily.get("temperature_2m_mean", [None]*length)[i],
                    precipitation_sum_mm=raw_daily.get("precipitation_sum", [None]*length)[i],
                    rain_sum_mm=raw_daily.get("rain_sum", [None]*length)[i],
                    weather_code=w_code,
                    weather_description=get_wmo_description(w_code),
                    wind_speed_max_kmh=raw_daily.get("wind_speed_10m_max", [None]*length)[i],
                )
            )
        return items

    @classmethod
    def to_m2_response(
        cls,
        raw_data: Dict[str, Any],
        location_name: Optional[str] = None,
        include_hourly: bool = True,
        include_daily: bool = True,
        is_historical: bool = False,
    ) -> M2WeatherResponse:
        """
        Converts raw Open-Meteo payload into standard M2 backend response.
        """
        loc_info = LocationInfo(
            name=location_name or "Unknown Location",
            latitude=raw_data.get("latitude", 0.0),
            longitude=raw_data.get("longitude", 0.0),
            elevation_m=raw_data.get("elevation"),
            timezone=raw_data.get("timezone", "UTC"),
        )

        current_norm = None
        if "current" in raw_data or "current_weather" in raw_data:
            current_raw = raw_data.get("current") or raw_data.get("current_weather", {})
            current_norm = cls.normalize_current(current_raw)

        hourly_norm = None
        if include_hourly and "hourly" in raw_data:
            hourly_norm = cls.normalize_hourly(raw_data["hourly"])

        daily_norm = None
        if include_daily and "daily" in raw_data and not is_historical:
            daily_norm = cls.normalize_daily(raw_data["daily"])

        hist_norm = None
        if is_historical and "daily" in raw_data:
            hist_norm = cls.normalize_historical_daily(raw_data["daily"])

        utc_now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        return M2WeatherResponse(
            status="success",
            source="Open-Meteo",
            retrieved_at_utc=utc_now,
            location=loc_info,
            current=current_norm,
            forecast_hourly=hourly_norm,
            forecast_daily=daily_norm,
            historical_daily=hist_norm,
            metadata={
                "generationtime_ms": raw_data.get("generationtime_ms"),
                "utc_offset_seconds": raw_data.get("utc_offset_seconds"),
                "elevation": raw_data.get("elevation"),
            }
        )

    @classmethod
    def to_m4_context(
        cls,
        m2_resp: M2WeatherResponse,
    ) -> M4WeatherContext:
        """
        Transforms M2 response into a compact, factual LLM prompt injection context.
        """
        cur = m2_resp.current
        loc = m2_resp.location

        temp_c = cur.temperature_c if cur else 0.0
        feels_like = cur.apparent_temperature_c if cur else None
        condition = cur.weather_description if cur and cur.weather_description else "Unknown"
        humidity = cur.humidity_percent if cur else None
        rain_mm = cur.rain_mm or cur.precipitation_mm if cur else None
        wind_kmh = cur.wind_speed_kmh if cur else None
        wind_dir = cur.wind_direction_cardinal if cur else None
        pressure = cur.pressure_hpa if cur else None
        cloud = cur.cloud_cover_percent if cur else None
        uv = cur.uv_index if cur else None

        # Extract 24h summary if daily or hourly forecast is present
        forecast_summary = None
        rain_prob_today = None
        if m2_resp.forecast_daily and len(m2_resp.forecast_daily) > 0:
            today_f = m2_resp.forecast_daily[0]
            rain_prob_today = today_f.precipitation_probability_max_percent
            forecast_summary = M4ForecastSummary(
                temp_min_c=today_f.temp_min_c,
                temp_max_c=today_f.temp_max_c,
                expected_condition=today_f.weather_description,
                max_rain_probability_pct=today_f.precipitation_probability_max_percent,
                precipitation_expected_mm=today_f.precipitation_sum_mm,
            )

        return M4WeatherContext(
            location=f"{loc.name} ({loc.country})" if loc.country else (loc.name or f"{loc.latitude},{loc.longitude}"),
            coordinates=[loc.latitude, loc.longitude],
            as_of_utc=cur.timestamp if cur else m2_resp.retrieved_at_utc,
            temperature_c=temp_c,
            feels_like_c=feels_like,
            condition=condition,
            humidity_pct=humidity,
            rain_mm=rain_mm,
            rain_probability_pct=rain_prob_today,
            wind_kmh=wind_kmh,
            wind_direction=wind_dir,
            pressure_hpa=pressure,
            cloud_cover_pct=cloud,
            uv_index=uv,
            forecast_24h=forecast_summary,
            source="Open-Meteo / WMO",
        )
