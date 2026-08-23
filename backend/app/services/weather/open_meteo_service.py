import json
import httpx
import logging
from typing import Optional, Dict, Any, Tuple, List
from app.core.config import settings
from app.core.redis import redis_manager

logger = logging.getLogger(__name__)

# WMO Weather interpretation codes (WW)
WMO_CODE_MAP = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Depositing rime fog",
    51: "Light drizzle",
    53: "Moderate drizzle",
    55: "Dense drizzle",
    61: "Slight rain",
    63: "Moderate rain",
    65: "Heavy rain",
    71: "Slight snow",
    73: "Moderate snow",
    75: "Heavy snow",
    77: "Snow grains",
    80: "Slight rain showers",
    81: "Moderate rain showers",
    82: "Violent rain showers",
    85: "Slight snow showers",
    86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail",
    99: "Thunderstorm with heavy hail",
}


class OpenMeteoService:
    def __init__(self):
        self.weather_url = settings.OPEN_METEO_BASE_URL
        self.geocoding_url = settings.GEOCODING_BASE_URL
        self.archive_url = settings.OPEN_METEO_ARCHIVE_URL
        self._local_geocode_cache: Dict[str, Tuple[float, float, str]] = {}
        self._local_weather_cache: Dict[str, Tuple[float, Dict[str, Any]]] = {}

    async def geocode(self, city_name: str) -> Optional[Tuple[float, float, str]]:
        """Convert a city/location name to (latitude, longitude, formatted_name) with local & Redis caching."""
        key = city_name.strip().lower()
        if key in self._local_geocode_cache:
            return self._local_geocode_cache[key]

        redis_key = f"weathergpt:geocode:{key}"
        try:
            cached_json = await redis_manager.get(redis_key)
            if cached_json:
                data = json.loads(cached_json)
                res = (float(data["lat"]), float(data["lon"]), str(data["name"]))
                self._local_geocode_cache[key] = res
                return res
        except Exception:
            pass

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(
                    f"{self.geocoding_url}/search",
                    params={"name": city_name, "count": 1, "language": "en", "format": "json"},
                )
                if resp.status_code == 200:
                    data = resp.json()
                    results = data.get("results")
                    if results and len(results) > 0:
                        first = results[0]
                        name = f"{first.get('name')}, {first.get('country', '')}".strip(", ")
                        lat, lon = float(first["latitude"]), float(first["longitude"])
                        res = (lat, lon, name)
                        self._local_geocode_cache[key] = res
                        try:
                            await redis_manager.set(
                                redis_key,
                                json.dumps({"lat": lat, "lon": lon, "name": name}),
                                expire=86400 * 7,  # Cache geocoding for 7 days
                            )
                        except Exception:
                            pass
                        return res
        except Exception as e:
            logger.error(f"Geocoding error for '{city_name}': {e}")
        return None

    async def get_current_weather(self, lat: float, lon: float, location_name: str = "Location") -> Optional[Dict[str, Any]]:
        """Fetch current weather for given coordinates."""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(
                    f"{self.weather_url}/forecast",
                    params={
                        "latitude": lat,
                        "longitude": lon,
                        "current": "temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,is_day",
                        "timezone": "auto",
                    },
                )
                if resp.status_code == 200:
                    data = resp.json()
                    cur = data.get("current", {})
                    code = cur.get("weather_code", 0)
                    condition = WMO_CODE_MAP.get(code, "Clear")

                    return {
                        "location": location_name,
                        "latitude": lat,
                        "longitude": lon,
                        "temperature": cur.get("temperature_2m", 0.0),
                        "humidity": cur.get("relative_humidity_2m", 0.0),
                        "precipitation": cur.get("precipitation", 0.0),
                        "wind_speed": cur.get("wind_speed_10m", 0.0),
                        "wind_direction": cur.get("wind_direction_10m", 0.0),
                        "weather_code": code,
                        "condition": condition,
                        "is_day": cur.get("is_day", 1),
                        "time": cur.get("time", ""),
                    }
        except Exception as e:
            logger.error(f"Open-Meteo weather fetch error: {e}")
        return None

    async def get_historical_daily(
        self,
        lat: float,
        lon: float,
        start_date: str,
        end_date: str,
    ) -> Optional[Dict[str, Any]]:
        """Fetch daily historical weather for a date range with Redis caching."""
        cache_key = f"weathergpt:archive:{round(lat, 2)}:{round(lon, 2)}:{start_date}:{end_date}"
        try:
            cached = await redis_manager.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(
                    f"{self.archive_url}/archive",
                    params={
                        "latitude": lat,
                        "longitude": lon,
                        "start_date": start_date,
                        "end_date": end_date,
                        "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code",
                        "timezone": "auto",
                    },
                )
                if resp.status_code == 200:
                    data = resp.json()
                    try:
                        await redis_manager.set(cache_key, json.dumps(data), expire=86400 * 30)
                    except Exception:
                        pass
                    return data
                logger.warning(f"Open-Meteo archive API returned {resp.status_code} for {start_date}..{end_date}")
        except Exception as e:
            logger.error(f"Open-Meteo historical fetch error: {e}")
        return None

    async def get_comprehensive_weather(self, lat: float, lon: float, location_name: str = "Location") -> Optional[Dict[str, Any]]:
        """Fetch complete current, hourly (48h), and daily (7 days) meteorological data with short TTL caching."""
        cache_key = f"weathergpt:weather:{round(lat, 2)}:{round(lon, 2)}"
        try:
            cached = await redis_manager.get(cache_key)
            if cached:
                data = json.loads(cached)
                data["location_name"] = location_name
                return data
        except Exception:
            pass

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(
                    f"{self.weather_url}/forecast",
                    params={
                        "latitude": lat,
                        "longitude": lon,
                        "current": "temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,is_day",
                        "hourly": "temperature_2m,relative_humidity_2m,precipitation_probability,precipitation,weather_code,wind_speed_10m",
                        "daily": "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,uv_index_max,sunrise,sunset",
                        "forecast_days": 7,
                        "timezone": "auto",
                    },
                )
                if resp.status_code == 200:
                    data = resp.json()
                    data["location_name"] = location_name
                    try:
                        await redis_manager.set(cache_key, json.dumps(data), expire=180)  # 3 minutes TTL
                    except Exception:
                        pass
                    return data
        except Exception as e:
            logger.error(f"Comprehensive weather fetch error: {e}")
        return None


weather_service = OpenMeteoService()
