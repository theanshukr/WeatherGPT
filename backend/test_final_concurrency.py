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

async def test_concurrency_report():
    print("=========================================================")
    print("[*] FINAL CONCURRENCY & ENDPOINT VERIFICATION")
    print("=========================================================")

    from app.core.config import settings
    settings.WEATHERAPI_KEY = "test_demo_key"

    endpoints_called = []
    http_call_count = 0

    original_get = httpx.AsyncClient.get

    async def mock_httpx_get(self, url, *args, **kwargs):
        nonlocal http_call_count
        if "weatherapi.com" in str(url):
            http_call_count += 1
            endpoint = str(url).split("weatherapi.com/v1")[1]
            params = kwargs.get("params", {})
            endpoints_called.append((endpoint, params))
            print(f"   [WeatherAPI HTTP Call #{http_call_count}] Endpoint: {endpoint} | Params: {params}")
            await asyncio.sleep(0.1)  # Simulate 100ms network roundtrip
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

    # 1. Cold Cache Concurrent Test
    _memory_cache.clear()
    endpoints_called.clear()
    http_call_count = 0
    lat, lon = 28.6139, 77.2090

    print(f"\n1. Executing concurrent [/current, /snapshot, /hourly, /alerts] for ({lat}, {lon}) on COLD CACHE...")
    t0 = time.time()
    results = await asyncio.gather(
        get_current_weather(city=None, lat=lat, lon=lon),
        get_weather_snapshot(city=None, lat=lat, lon=lon),
        get_hourly_forecast(city=None, lat=lat, lon=lon),
        get_severe_alerts(city=None, lat=lat, lon=lon),
    )
    t1 = time.time()

    cold_calls = http_call_count
    cold_endpoints = list(endpoints_called)

    print(f"\n--- COLD CACHE RESULTS ---")
    print(f"Total WeatherAPI HTTP calls: {cold_calls}")
    print(f"Endpoints called: {[ep for ep, p in cold_endpoints]}")
    print(f"Total latency: {round((t1-t0)*1000, 1)}ms")

    # 2. Warm Cache Test (within 10 minutes)
    endpoints_called.clear()
    calls_before_warm = http_call_count

    print(f"\n2. Repeating all 4 requests for ({lat}, {lon}) within 10-minute TTL (WARM CACHE)...")
    t0 = time.time()
    results_warm = await asyncio.gather(
        get_current_weather(city=None, lat=lat, lon=lon),
        get_weather_snapshot(city=None, lat=lat, lon=lon),
        get_hourly_forecast(city=None, lat=lat, lon=lon),
        get_severe_alerts(city=None, lat=lat, lon=lon),
    )
    t1 = time.time()

    warm_calls = http_call_count - calls_before_warm

    print(f"\n--- WARM CACHE RESULTS ---")
    print(f"Total WeatherAPI HTTP calls: {warm_calls}")
    print(f"Served from cache: {warm_calls == 0}")
    print(f"Total latency: {round((t1-t0)*1000, 1)}ms")

    return cold_calls, cold_endpoints, warm_calls

if __name__ == "__main__":
    asyncio.run(test_concurrency_report())
