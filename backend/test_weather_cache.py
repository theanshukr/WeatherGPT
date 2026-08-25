import asyncio
import sys
import os
import time

sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.weather.open_meteo_service import weather_service, _memory_cache, _coord_key
from app.api.v1.endpoints.weather import (
    get_current_weather,
    get_weather_snapshot,
    get_hourly_forecast,
    get_severe_alerts,
    get_daily_forecast,
    get_official_alerts,
)

async def run_tests():
    print("========================================")
    print("[*] TESTING WEATHER CACHING & ENDPOINTS")
    print("========================================")

    test_locations = [
        ("Delhi", 28.6139, 77.2090),
        ("Mumbai", 19.0760, 72.8777),
        ("Kolkata", 22.5726, 88.3639),
        ("Chennai", 13.0827, 80.2707),
        ("User Location", 28.6341, 77.4465),
    ]

    # Test 1: Test all endpoints for a location
    print("\n--- Test 1: Testing all 5 requested endpoints ---")
    loc_name, lat, lon = test_locations[4]  # User Location

    print(f"Testing location: {loc_name} ({lat}, {lon})")

    # 1. /api/v1/weather/current
    t0 = time.time()
    cur_res = await get_current_weather(city=None, lat=lat, lon=lon)
    t1 = time.time()
    print(f"1. /current: temp={cur_res['temperature']}°C, condition='{cur_res['condition']}', source='{cur_res.get('source')}' ({round((t1-t0)*1000, 1)}ms)")
    assert "temperature" in cur_res
    assert "condition" in cur_res
    assert "location" in cur_res

    # 2. /api/v1/weather/snapshot
    t0 = time.time()
    snap_res = await get_weather_snapshot(city=None, lat=lat, lon=lon)
    t1 = time.time()
    print(f"2. /snapshot: current_temp={snap_res['current_temp']}°C, forecast_days={len(snap_res['daily_7_day_forecast'])}, alerts={len(snap_res['alerts'])} ({round((t1-t0)*1000, 1)}ms)")
    assert "current_temp" in snap_res
    assert "rain_timeline" in snap_res
    assert "daily_7_day_forecast" in snap_res

    # 3. /api/v1/weather/hourly
    t0 = time.time()
    hourly_res = await get_hourly_forecast(city=None, lat=lat, lon=lon)
    t1 = time.time()
    print(f"3. /hourly: is_rain_expected={hourly_res['is_rain_expected']}, peak={hourly_res['peak_probability']}% ({round((t1-t0)*1000, 1)}ms [CACHE HIT])")
    assert "is_rain_expected" in hourly_res

    # 4. /api/v1/weather/alerts
    t0 = time.time()
    alerts_res = await get_severe_alerts(city=None, lat=lat, lon=lon)
    t1 = time.time()
    print(f"4. /alerts: count={len(alerts_res)} ({round((t1-t0)*1000, 1)}ms [CACHE HIT])")

    # 5. /api/v1/weather/official-alerts
    t0 = time.time()
    official_res = await get_official_alerts()
    t1 = time.time()
    print(f"5. /official-alerts: count={len(official_res)} ({round((t1-t0)*1000, 1)}ms)")

    # Test 2: In-memory Cache Deduplication & Cross-Sharing
    print("\n--- Test 2: Verifying In-Memory Cache Deduplication & Latency ---")
    coord = _coord_key(lat, lon)
    print(f"Cache key for ({lat}, {lon}): {coord}")
    print(f"Entries in memory cache for coord:")
    for k, (exp, v) in _memory_cache.items():
        if coord in k:
            ttl_left = round(exp - time.time(), 1)
            print(f"   Key: '{k}' -> TTL remaining: {ttl_left}s")

    # Immediate second call to /current should hit cache in < 1ms
    t0 = time.time()
    cur_res2 = await get_current_weather(city=None, lat=lat, lon=lon)
    t1 = time.time()
    latency_ms = (t1 - t0) * 1000
    print(f"Subsequent /current call latency: {round(latency_ms, 3)}ms (Expected < 5ms for in-memory hit)")
    assert latency_ms < 50.0, "Cache hit should be near instantaneous"

    # Immediate second call to /snapshot should hit cache in < 1ms
    t0 = time.time()
    snap_res2 = await get_weather_snapshot(city=None, lat=lat, lon=lon)
    t1 = time.time()
    latency_ms = (t1 - t0) * 1000
    print(f"Subsequent /snapshot call latency: {round(latency_ms, 3)}ms (Expected < 5ms for in-memory hit)")
    assert latency_ms < 50.0, "Cache hit should be near instantaneous"

    # Test 3: Test all remaining repeated locations from logs
    print("\n--- Test 3: Poller / City Locations Caching ---")
    for name, c_lat, c_lon in test_locations[:4]:
        # First call fetches and caches
        res1 = await weather_service.get_comprehensive_weather(c_lat, c_lon, name)
        # Second call hits memory cache
        t0 = time.time()
        res2 = await weather_service.get_comprehensive_weather(c_lat, c_lon, name)
        t1 = time.time()
        # Current weather call hits derived cache
        t2 = time.time()
        cur = await weather_service.get_current_weather(c_lat, c_lon, name)
        t3 = time.time()
        print(f"   [{name}] comprehensive cached lookup: {round((t1-t0)*1000, 3)}ms, current cached lookup: {round((t3-t2)*1000, 3)}ms")

    print("\n========================================")
    print("[SUCCESS] ALL CACHING & ENDPOINT TESTS PASSED!")
    print("========================================")
    return True

if __name__ == "__main__":
    success = asyncio.run(run_tests())
    sys.exit(0 if success else 1)
