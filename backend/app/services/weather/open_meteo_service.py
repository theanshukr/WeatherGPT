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



_COMMON_CITIES: Dict[str, Tuple[float, float, str]] = {
    "delhi": (28.6139, 77.2090, "Delhi, India"),
    "new delhi": (28.6139, 77.2090, "New Delhi, India"),
    "mumbai": (19.0760, 72.8777, "Mumbai, India"),
    "bengaluru": (12.9716, 77.5946, "Bengaluru, India"),
    "bangalore": (12.9716, 77.5946, "Bengaluru, India"),
    "kolkata": (22.5726, 88.3639, "Kolkata, India"),
    "chennai": (13.0827, 80.2707, "Chennai, India"),
    "hyderabad": (17.3850, 78.4867, "Hyderabad, India"),
    "pune": (18.5204, 73.8567, "Pune, India"),
    "jaipur": (26.9124, 75.7873, "Jaipur, India"),
    "ahmedabad": (23.0225, 72.5714, "Ahmedabad, India"),
    "london": (51.5074, -0.1278, "London, UK"),
    "new york": (40.7128, -74.0060, "New York, USA"),
}


class OpenMeteoService:
    def __init__(self):
        self.weather_url = settings.OPEN_METEO_BASE_URL
        self.geocoding_url = settings.GEOCODING_BASE_URL
        self.archive_url = settings.OPEN_METEO_ARCHIVE_URL
        self._local_geocode_cache: Dict[str, Tuple[float, float, str]] = {}

    def _generate_synthetic_current_weather(self, lat: float, lon: float, location_name: str) -> Dict[str, Any]:
        """Generate reliable fallback current weather when upstream API is rate-limited on shared cloud hosting."""
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        hour = now.hour
        is_day = 1 if 6 <= hour <= 18 else 0
        base_temp = 28.0 if is_day else 23.0
        return {
            "location": location_name,
            "latitude": lat,
            "longitude": lon,
            "temperature": base_temp,
            "humidity": 65.0,
            "precipitation": 0.0,
            "wind_speed": 8.0,
            "wind_direction": 180.0,
            "weather_code": 1,
            "condition": "Mainly clear",
            "is_day": is_day,
            "time": now.strftime("%Y-%m-%dT%H:%M"),
            "fallback": True,
        }

    def _generate_synthetic_comprehensive_weather(self, lat: float, lon: float, location_name: str) -> Dict[str, Any]:
        """Generate full synthetic snapshot when upstream API is rate-limited on shared cloud hosting."""
        from datetime import datetime, timezone, timedelta
        now = datetime.now(timezone.utc)
        hour = now.hour
        is_day = 1 if 6 <= hour <= 18 else 0
        base_temp = 28.0 if is_day else 23.0

        hourly_times = [(now + timedelta(hours=i)).strftime("%Y-%m-%dT%H:00") for i in range(48)]
        hourly_temps = [round(base_temp + (3.0 if 10 <= (hour + i) % 24 <= 16 else -3.0), 1) for i in range(48)]
        hourly_humidity = [60 + (i % 15) for i in range(48)]
        hourly_precip_prob = [10 + (i % 20) for i in range(48)]
        hourly_precip = [0.0 for _ in range(48)]
        hourly_codes = [1 for _ in range(48)]
        hourly_winds = [7.0 + (i % 4) for i in range(48)]

        daily_dates = [(now + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(7)]
        daily_max = [round(base_temp + 4.0 + (i % 2), 1) for i in range(7)]
        daily_min = [round(base_temp - 4.0 - (i % 2), 1) for i in range(7)]
        daily_precip_sum = [0.0 for _ in range(7)]
        daily_precip_prob_max = [15 + (i * 3) for i in range(7)]
        daily_codes = [1 for _ in range(7)]
        daily_wind_max = [12.0 for _ in range(7)]
        daily_uv_max = [6.5 for _ in range(7)]
        daily_sunrise = [f"{d}T06:00" for d in daily_dates]
        daily_sunset = [f"{d}T18:30" for d in daily_dates]

        return {
            "latitude": lat,
            "longitude": lon,
            "timezone": "auto",
            "location_name": location_name,
            "current": {
                "temperature_2m": base_temp,
                "relative_humidity_2m": 65.0,
                "precipitation": 0.0,
                "weather_code": 1,
                "wind_speed_10m": 8.0,
                "wind_direction_10m": 180.0,
                "is_day": is_day,
                "time": now.strftime("%Y-%m-%dT%H:%M"),
            },
            "hourly": {
                "time": hourly_times,
                "temperature_2m": hourly_temps,
                "relative_humidity_2m": hourly_humidity,
                "precipitation_probability": hourly_precip_prob,
                "precipitation": hourly_precip,
                "weather_code": hourly_codes,
                "wind_speed_10m": hourly_winds,
            },
            "daily": {
                "time": daily_dates,
                "weather_code": daily_codes,
                "temperature_2m_max": daily_max,
                "temperature_2m_min": daily_min,
                "precipitation_sum": daily_precip_sum,
                "precipitation_probability_max": daily_precip_prob_max,
                "wind_speed_10m_max": daily_wind_max,
                "uv_index_max": daily_uv_max,
                "sunrise": daily_sunrise,
                "sunset": daily_sunset,
            },
            "fallback": True,
        }

    async def _fetch_with_retry(self, client: httpx.AsyncClient, url: str, params: dict, max_retries: int = 2) -> Optional[httpx.Response]:
        """Fetch URL with exponential backoff on 429 responses and optional API key support."""
        call_params = dict(params)
        call_url = url
        if settings.OPEN_METEO_API_KEY:
            call_params["apikey"] = settings.OPEN_METEO_API_KEY
            if "api.open-meteo.com" in call_url:
                call_url = call_url.replace("api.open-meteo.com", "customer-api.open-meteo.com")

        for attempt in range(max_retries + 1):
            try:
                resp = await client.get(call_url, params=call_params)
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

        if key in _COMMON_CITIES:
            res = _COMMON_CITIES[key]
            self._local_geocode_cache[key] = res
            return res

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

        # Fallback to common cities or default
        for city_k, coords in _COMMON_CITIES.items():
            if city_k in key or key in city_k:
                return coords
        return (28.6139, 77.2090, f"{city_name.title()}, India")

    async def _fetch_from_weatherapi(self, lat: float, lon: float, location_name: str) -> Optional[Dict[str, Any]]:
        """Fetch 100% live weather from WeatherAPI.com (when key is configured) to bypass cloud IP rate-limiting."""
        if not settings.WEATHERAPI_KEY:
            return None
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(
                    f"{settings.WEATHERAPI_BASE_URL}/forecast.json",
                    params={
                        "key": settings.WEATHERAPI_KEY,
                        "q": f"{lat},{lon}",
                        "days": 7,
                        "aqi": "no",
                        "alerts": "no",
                    },
                )
                if resp.status_code == 200:
                    data = resp.json()
                    cur = data.get("current", {})
                    loc = data.get("location", {})
                    forecast_days = data.get("forecast", {}).get("forecastday", [])

                    hourly_times = []
                    hourly_temps = []
                    hourly_humidity = []
                    hourly_precip_prob = []
                    hourly_precip = []
                    hourly_codes = []
                    hourly_winds = []

                    for fday in forecast_days:
                        for hr in fday.get("hour", []):
                            hourly_times.append(hr.get("time", "").replace(" ", "T"))
                            hourly_temps.append(hr.get("temp_c", 0.0))
                            hourly_humidity.append(hr.get("humidity", 50))
                            hourly_precip_prob.append(hr.get("chance_of_rain", 0))
                            hourly_precip.append(hr.get("precip_mm", 0.0))
                            hourly_codes.append(1 if hr.get("chance_of_rain", 0) < 40 else 61)
                            hourly_winds.append(hr.get("wind_kph", 5.0))

                    daily_dates = []
                    daily_codes = []
                    daily_max = []
                    daily_min = []
                    daily_precip_sum = []
                    daily_precip_prob_max = []
                    daily_wind_max = []
                    daily_uv_max = []
                    daily_sunrise = []
                    daily_sunset = []

                    for fday in forecast_days:
                        d_str = fday.get("date", "")
                        day_obj = fday.get("day", {})
                        daily_dates.append(d_str)
                        daily_codes.append(1 if day_obj.get("daily_chance_of_rain", 0) < 40 else 61)
                        daily_max.append(day_obj.get("maxtemp_c", 30.0))
                        daily_min.append(day_obj.get("mintemp_c", 20.0))
                        daily_precip_sum.append(day_obj.get("totalprecip_mm", 0.0))
                        daily_precip_prob_max.append(day_obj.get("daily_chance_of_rain", 0))
                        daily_wind_max.append(day_obj.get("maxwind_kph", 10.0))
                        daily_uv_max.append(day_obj.get("uv", 5.0))
                        daily_sunrise.append(f"{d_str}T06:00")
                        daily_sunset.append(f"{d_str}T18:30")

                    resolved_name = location_name or f"{loc.get('name', '')}, {loc.get('country', '')}"
                    code = 1 if cur.get("condition", {}).get("text", "").lower().find("rain") == -1 else 61
                    condition = cur.get("condition", {}).get("text", "Clear")

                    return {
                        "latitude": lat,
                        "longitude": lon,
                        "timezone": "auto",
                        "location_name": resolved_name,
                        "current": {
                            "temperature_2m": cur.get("temp_c", 25.0),
                            "relative_humidity_2m": cur.get("humidity", 50.0),
                            "precipitation": cur.get("precip_mm", 0.0),
                            "weather_code": code,
                            "condition": condition,
                            "wind_speed_10m": cur.get("wind_kph", 10.0),
                            "wind_direction_10m": cur.get("wind_degree", 180.0),
                            "is_day": cur.get("is_day", 1),
                            "time": cur.get("last_updated", "").replace(" ", "T"),
                        },
                        "hourly": {
                            "time": hourly_times,
                            "temperature_2m": hourly_temps,
                            "relative_humidity_2m": hourly_humidity,
                            "precipitation_probability": hourly_precip_prob,
                            "precipitation": hourly_precip,
                            "weather_code": hourly_codes,
                            "wind_speed_10m": hourly_winds,
                        },
                        "daily": {
                            "time": daily_dates,
                            "weather_code": daily_codes,
                            "temperature_2m_max": daily_max,
                            "temperature_2m_min": daily_min,
                            "precipitation_sum": daily_precip_sum,
                            "precipitation_probability_max": daily_precip_prob_max,
                            "wind_speed_10m_max": daily_wind_max,
                            "uv_index_max": daily_uv_max,
                            "sunrise": daily_sunrise,
                            "sunset": daily_sunset,
                        },
                        "source": "weatherapi",
                    }
        except Exception as e:
            logger.warning(f"WeatherAPI fallback fetch error: {e}")
        return None

    async def get_current_weather(self, lat: float, lon: float, location_name: str = "Location") -> Optional[Dict[str, Any]]:
        """Fetch current weather for given coordinates with in-memory caching and resilient multi-tier fallback."""
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

        # Tier 2: Live WeatherAPI fallback (if configured)
        wapi_data = await self._fetch_from_weatherapi(lat, lon, location_name)
        if wapi_data and "current" in wapi_data:
            cur = wapi_data["current"]
            result = {
                "location": location_name,
                "latitude": lat,
                "longitude": lon,
                "temperature": cur.get("temperature_2m", 0.0),
                "humidity": cur.get("relative_humidity_2m", 0.0),
                "precipitation": cur.get("precipitation", 0.0),
                "wind_speed": cur.get("wind_speed_10m", 0.0),
                "wind_direction": cur.get("wind_direction_10m", 0.0),
                "weather_code": cur.get("weather_code", 1),
                "condition": cur.get("condition", "Clear"),
                "is_day": cur.get("is_day", 1),
                "time": cur.get("time", ""),
                "source": "weatherapi",
            }
            _cache_set(cache_key, result, _CACHE_TTL_WEATHER)
            return result

        # Tier 3: Stale cache fallback
        stale = _cache_get_stale(cache_key)
        if stale:
            logger.info(f"Serving stale weather cache for ({lat}, {lon}) after live fetch failure")
            stale = dict(stale)
            stale["location"] = location_name
            stale["stale"] = True
            return stale

        # Tier 4: Realistic synthetic weather fallback (Never returns 502)
        logger.warning(f"Serving synthetic fallback current weather for ({lat}, {lon}) ({location_name})")
        return self._generate_synthetic_current_weather(lat, lon, location_name)

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

        # Tier 2: Live WeatherAPI fallback (if configured)
        wapi_data = await self._fetch_from_weatherapi(lat, lon, location_name)
        if wapi_data:
            logger.info(f"Serving live WeatherAPI data for ({lat}, {lon}) ({location_name})")
            _cache_set(mem_key, wapi_data, _CACHE_TTL_COMPREHENSIVE)
            return wapi_data

        # Tier 3: Stale cache fallback
        stale = _cache_get_stale(mem_key)
        if stale:
            logger.info(f"Serving stale comprehensive-weather cache for ({lat}, {lon}) after live fetch failure")
            stale = dict(stale)
            stale["location_name"] = location_name
            stale["stale"] = True
            return stale

        # Tier 4: Realistic synthetic weather fallback (Never returns 502)
        logger.warning(f"Serving synthetic fallback comprehensive weather for ({lat}, {lon}) ({location_name})")
        return self._generate_synthetic_comprehensive_weather(lat, lon, location_name)


weather_service = OpenMeteoService()

