import asyncio
import sys
import os
import time
import httpx

sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.weather.open_meteo_service import weather_service, _memory_cache, _coord_key
from app.api.v1.endpoints.weather import (
    get_current_weather,
    get_weather_snapshot,
    get_hourly_forecast,
    get_severe_alerts,
)

async def test_concurrency_suite():
    print("=========================================================")
    print("[*] VERIFYING CONCURRENT REQUESTS & CACHE STAMPEDE PREVENT")
    print("=========================================================")

    from app.core.config import settings
    settings.WEATHERAPI_KEY = "test_demo_key"

    http_call_count = 0
    http_log = []

    original_get = httpx.AsyncClient.get

    async def mock_httpx_get(self, url, *args, **kwargs):
        nonlocal http_call_count
        if "weatherapi.com" in str(url):
            http_call_count += 1
            params = kwargs.get("params", {})
            req_info = f"Call #{http_call_count}: URL={url}, params={params}"
            http_log.append(req_info)
            print(f"   [WeatherAPI Network HTTP Call] {req_info}")
            await asyncio.sleep(0.1)  # Simulate 100ms network latency
            class MockResponse:
                status_code = 200
                def json(self):
                    return {
                        "location": {"name": "Delhi", "country": "India"},
                        "current": {
                            "temp_c": 28.0, "humidity": 60, "precip_mm": 0.0,
                            "wind_kph": 10.0, "wind_degree": 180, "is_day": 1,
                            "condition": {"text": "Partly cloudy"}, "last_updated": "2026-08-25 09:30"
                        },
                        "forecast": {
                            "forecastday": [{
                                "date": "2026-08-25",
                                "day": {"maxtemp_c": 32.0, "mintemp_c": 24.0, "daily_chance_of_rain": 10, "totalprecip_mm": 0.0, "maxwind_kph": 12.0, "uv": 6.0},
                                "hour": [{"time": "2026-08-25 09:00", "temp_c": 28.0, "humidity": 60, "chance_of_rain": 10, "precip_mm": 0.0, "wind_kph": 10.0}]
                            }]
                        }
                    }
            return MockResponse()
        return await original_get(self, url, *args, **kwargs)

    httpx.AsyncClient.get = mock_httpx_get

    # -------------------------------------------------------------
    # Test 1: 4 Concurrent Requests on EMPTY Cache for Delhi
    # -------------------------------------------------------------
    _memory_cache.clear()
    http_call_count = 0
    lat, lon = 28.6139, 77.2090

    print(f"\n1. Launching 4 concurrent requests for Delhi ({lat}, {lon}) on EMPTY cache...")
    t0 = time.time()
    results = await asyncio.gather(
        get_current_weather(city=None, lat=lat, lon=lon),
        get_weather_snapshot(city=None, lat=lat, lon=lon),
        get_hourly_forecast(city=None, lat=lat, lon=lon),
        get_severe_alerts(city=None, lat=lat, lon=lon),
    )
    t1 = time.time()
    print(f"   Elapsed: {round((t1-t0)*1000, 1)}ms | WeatherAPI network calls made: {http_call_count}")
    assert http_call_count <= 2, f"Expected <= 2 calls for empty-cache concurrent stampede, got {http_call_count}"

    # -------------------------------------------------------------
    # Test 2: Subsequent Requests within 10-minute TTL
    # -------------------------------------------------------------
    print(f"\n2. Executing subsequent requests for Delhi within TTL...")
    calls_before = http_call_count
    t0 = time.time()
    res_cur = await get_current_weather(city=None, lat=lat, lon=lon)
    res_snap = await get_weather_snapshot(city=None, lat=lat, lon=lon)
    res_hour = await get_hourly_forecast(city=None, lat=lat, lon=lon)
    res_alert = await get_severe_alerts(city=None, lat=lat, lon=lon)
    t1 = time.time()
    new_calls = http_call_count - calls_before
    print(f"   Elapsed: {round((t1-t0)*1000, 1)}ms | New WeatherAPI calls made: {new_calls}")
    assert new_calls == 0, f"Expected 0 new WeatherAPI calls within TTL, got {new_calls}"

    # -------------------------------------------------------------
    # Test 3: Different locations have SEPARATE cache entries
    # -------------------------------------------------------------
    print(f"\n3. Testing different location (Mumbai: 19.0760, 72.8777)...")
    mumbai_lat, mumbai_lon = 19.0760, 72.8777
    calls_before = http_call_count
    res_mumbai = await get_current_weather(city=None, lat=mumbai_lat, lon=mumbai_lon)
    new_calls = http_call_count - calls_before
    print(f"   Mumbai fetch resulted in {new_calls} new WeatherAPI call(s).")
    assert new_calls == 1, f"Expected 1 WeatherAPI call for fresh location, got {new_calls}"

    # -------------------------------------------------------------
    # Test 4: Expired Entries trigger a fresh request
    # -------------------------------------------------------------
    print(f"\n4. Simulating cache expiration (modifying timestamp to >10 min in past)...")
    coord = _coord_key(lat, lon)
    for k in list(_memory_cache.keys()):
        if coord in k:
            exp, data = _memory_cache[k]
            _memory_cache[k] = (time.time() - 100, data)  # Force expired

    calls_before = http_call_count
    res_expired = await get_current_weather(city=None, lat=lat, lon=lon)
    new_calls = http_call_count - calls_before
    print(f"   Request after expiration resulted in {new_calls} new WeatherAPI call(s).")
    assert new_calls >= 1, f"Expected >= 1 WeatherAPI call after expiration, got {new_calls}"

    print("\n=========================================================")
    print("[SUCCESS] CONCURRENCY & CACHE STAMPEDE PREVENTION PASSED!")
    print("=========================================================")
    return True

if __name__ == "__main__":
    asyncio.run(test_concurrency_suite())
