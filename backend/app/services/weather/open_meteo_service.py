import json
import time
import asyncio
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

# In-memory TTL cache: key -> (expiry_timestamp, data)
_memory_cache: Dict[str, Tuple[float, Any]] = {}
_CACHE_TTL_WEATHER = 300        # 5 minutes for weather data (fresh)
_CACHE_TTL_COMPREHENSIVE = 300  # 5 minutes for comprehensive (fresh)
_CACHE_TTL_GEOCODE = 86400      # 24 hours for geocoding
_STALE_GRACE_PERIOD = 3600      # keep stale weather data around for 1hr as emergency fallback
_MAX_CACHE_SIZE = 500           # Prevent unbounded memory growth


def _cache_get(key: str) -> Optional[Any]:
    """Get value from in-memory cache if not expired (fresh only)."""
    entry = _memory_cache.get(key)
    if entry is None:
        return None
    expiry, data = entry
    if time.time() > expiry:
        return None
    return data


def _cache_get_stale(key: str) -> Optional[Any]:
    """Get value from in-memory cache even if past its normal TTL, as long as
    it's still within the stale grace period. Used only as an emergency
    fallback when a live fetch fails (e.g. upstream rate-limited), so we can
    serve slightly-old data instead of erroring out to the user."""
    entry = _memory_cache.get(key)
    if entry is None:
        return None
    expiry, data = entry
    if time.time() > expiry + _STALE_GRACE_PERIOD:
        del _memory_cache[key]
        return None
    return data


def _cache_set(key: str, data: Any, ttl: int):
    """Set value in in-memory cache with TTL."""
    # Evict oldest entries if cache is too large
    if len(_memory_cache) >= _MAX_CACHE_SIZE:
        oldest_key = min(_memory_cache, key=lambda k: _memory_cache[k][0])
        del _memory_cache[oldest_key]
    _memory_cache[key] = (time.time() + ttl, data)


def _coord_key(lat: float, lon: float) -> str:
    """Round coordinates to 2 decimal places for cache key deduplication."""
    return f"{round(lat, 2)}:{round(lon, 2)}"



class OpenMeteoService:
    def __init__(self):
        self.weather_url = settings.OPEN_METEO_BASE_URL
        self.geocoding_url = settings.GEOCODING_BASE_URL
        self.archive_url = settings.OPEN_METEO_ARCHIVE_URL
        self._local_geocode_cache: Dict[str, Tuple[float, float, str]] = {}

    async def _fetch_with_retry(self, client: httpx.AsyncClient, url: str, params: dict, max_retries: int = 2) -> Optional[httpx.Response]:
        """Fetch URL with exponential backoff on 429 responses."""
        for attempt in range(max_retries + 1):
            try:
                resp = await client.get(url, params=params)
                if resp.status_code == 200:
                    return resp
                if resp.status_code == 429:
                    wait_time = min(2 ** attempt * 1.5, 10)  # 1.5s, 3s, 6s
                    logger.info(f"Open-Meteo 429 rate limited, retrying in {wait_time:.1f}s (attempt {attempt + 1}/{max_retries + 1})")
                    await asyncio.sleep(wait_time)
                    continue
                logger.warning(f"Open-Meteo returned status {resp.status_code}")
                return None
            except httpx.TimeoutException:
                logger.warning(f"Open-Meteo timeout (attempt {attempt + 1})")
                if attempt < max_retries:
                    await asyncio.sleep(1)
                    continue
                return None
        return None

    async def geocode(self, city_name: str) -> Optional[Tuple[float, float, str]]:
        """Convert a city/location name to (latitude, longitude, formatted_name) with local & Redis caching."""
        key = city_name.strip().lower()

        # 1. Local in-memory cache
        if key in self._local_geocode_cache:
            return self._local_geocode_cache[key]

        mem_key = f"geocode:{key}"
        cached = _cache_get(mem_key)
        if cached:
            return cached

        # 2. Redis cache
        redis_key = f"weathergpt:geocode:{key}"
        try:
            cached_json = await redis_manager.get(redis_key)
            if cached_json:
                data = json.loads(cached_json)
                res = (float(data["lat"]), float(data["lon"]), str(data["name"]))
                self._local_geocode_cache[key] = res
                _cache_set(mem_key, res, _CACHE_TTL_GEOCODE)
                return res
        except Exception:
            pass

        # 3. API call
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
                        _cache_set(mem_key, res, _CACHE_TTL_GEOCODE)
                        try:
                            await redis_manager.set(
                                redis_key,
                                json.dumps({"lat": lat, "lon": lon, "name": name}),
                                expire=86400 * 7,
                            )
                        except Exception:
                            pass
                        return res
        except Exception as e:
            logger.error(f"Geocoding error for '{city_name}': {e}")
        return None

    async def get_current_weather(self, lat: float, lon: float, location_name: str = "Location") -> Optional[Dict[str, Any]]:
        """Fetch current weather for given coordinates with in-memory caching."""
        cache_key = f"current:{_coord_key(lat, lon)}"
        cached = _cache_get(cache_key)
        if cached:
            cached["location"] = location_name
            return cached

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await self._fetch_with_retry(
                    client,
                    f"{self.weather_url}/forecast",
                    params={
                        "latitude": lat,
                        "longitude": lon,
                        "current": "temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,is_day",
                        "timezone": "auto",
                    },
                )
                if resp and resp.status_code == 200:
                    data = resp.json()
                    cur = data.get("current", {})
                    code = cur.get("weather_code", 0)
                    condition = WMO_CODE_MAP.get(code, "Clear")

                    result = {
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
                    _cache_set(cache_key, result, _CACHE_TTL_WEATHER)
                    return result
        except Exception as e:
            logger.error(f"Open-Meteo weather fetch error: {e}")

        # Live fetch failed (e.g. rate-limited) — fall back to stale cache
        # instead of erroring out to the user.
        stale = _cache_get_stale(cache_key)
        if stale:
            logger.info(f"Serving stale weather cache for ({lat}, {lon}) after live fetch failure")
            stale = dict(stale)
            stale["location"] = location_name
            stale["stale"] = True
            return stale
        return None

    async def get_historical_daily(
        self,
        lat: float,
        lon: float,
        start_date: str,
        end_date: str,
    ) -> Optional[Dict[str, Any]]:
        """Fetch daily historical weather for a date range with in-memory + Redis caching."""
        mem_key = f"archive:{_coord_key(lat, lon)}:{start_date}:{end_date}"
        cached = _cache_get(mem_key)
        if cached:
            return cached

        redis_cache_key = f"weathergpt:archive:{round(lat, 2)}:{round(lon, 2)}:{start_date}:{end_date}"
        try:
            redis_cached = await redis_manager.get(redis_cache_key)
            if redis_cached:
                data = json.loads(redis_cached)
                _cache_set(mem_key, data, 3600)  # 1 hour in memory
                return data
        except Exception:
            pass

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await self._fetch_with_retry(
                    client,
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
                if resp and resp.status_code == 200:
                    data = resp.json()
                    _cache_set(mem_key, data, 3600)
                    try:
                        await redis_manager.set(redis_cache_key, json.dumps(data), expire=86400 * 30)
                    except Exception:
                        pass
                    return data
                if resp:
                    logger.warning(f"Open-Meteo archive API returned {resp.status_code} for {start_date}..{end_date}")
        except Exception as e:
            logger.error(f"Open-Meteo historical fetch error: {e}")
        return None

    async def get_comprehensive_weather(self, lat: float, lon: float, location_name: str = "Location") -> Optional[Dict[str, Any]]:
        """Fetch complete current, hourly (48h), and daily (7 days) meteorological data with in-memory + Redis caching."""
        mem_key = f"comprehensive:{_coord_key(lat, lon)}"
        cached = _cache_get(mem_key)
        if cached:
            cached["location_name"] = location_name
            return cached

        redis_cache_key = f"weathergpt:weather:{round(lat, 2)}:{round(lon, 2)}"
        try:
            redis_cached = await redis_manager.get(redis_cache_key)
            if redis_cached:
                data = json.loads(redis_cached)
                data["location_name"] = location_name
                _cache_set(mem_key, data, _CACHE_TTL_COMPREHENSIVE)
                return data
        except Exception:
            pass

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await self._fetch_with_retry(
                    client,
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
                if resp and resp.status_code == 200:
                    data = resp.json()
                    data["location_name"] = location_name
                    _cache_set(mem_key, data, _CACHE_TTL_COMPREHENSIVE)
                    try:
                        await redis_manager.set(redis_cache_key, json.dumps(data), expire=300)
                    except Exception:
                        pass
                    return data
                if resp:
                    logger.warning(f"Open-Meteo returned status {resp.status_code} for ({lat}, {lon})")
        except httpx.TimeoutException:
            logger.warning(f"Open-Meteo forecast timeout for ({lat}, {lon}) ({location_name})")
        except Exception as e:
            logger.warning(f"Open-Meteo forecast fetch error for ({lat}, {lon}): {type(e).__name__} - {e}")

        # Live fetch failed (e.g. rate-limited) — fall back to stale cache
        # instead of erroring out to the user.
        stale = _cache_get_stale(mem_key)
        if stale:
            logger.info(f"Serving stale comprehensive-weather cache for ({lat}, {lon}) after live fetch failure")
            stale = dict(stale)
            stale["location_name"] = location_name
            stale["stale"] = True
            return stale
        return None


weather_service = OpenMeteoService()
