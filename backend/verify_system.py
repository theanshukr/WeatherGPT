import asyncio
import sys
import os

sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.weather.open_meteo_service import weather_service
from app.services.weather.nwp_service import nwp_service
from app.services.alerts.official_alert_client import official_alert_client
from app.services.llm.gemini_service import gemini_service
from app.schemas.chat import ChatMessageRequest
from app.services.weather.weather_processor import weather_processor

async def main():
    print("========================================")
    print("[*] RUNNING FULL SYSTEM VERIFICATION")
    print("========================================")

    # 1. Test Weather Service
    print("\n1. Testing Open-Meteo Current Weather...")
    try:
        weather = await weather_service.get_current_weather(28.6139, 77.2090, "New Delhi, India")
        assert weather is not None, "Weather data is None"
        print(f"   [OK] Weather: {weather.get('location')}, Temp: {weather.get('temperature')} C, Cond: {weather.get('condition')}")
    except Exception as e:
        print(f"   [FAIL] Weather Failed: {e}")
        return False

    # 2. Test Snapshot Processor
    print("\n2. Testing Comprehensive Snapshot Processor...")
    try:
        raw_data = await weather_service.get_comprehensive_weather(28.6139, 77.2090, "New Delhi, India")
        snapshot = weather_processor.process(raw_data, "New Delhi, India")
        assert snapshot is not None, "Snapshot is None"
        print(f"   [OK] Snapshot: Rain peak prob: {snapshot.rain_timeline.peak_probability}%, 7-day forecast days: {len(snapshot.daily_7_day_forecast)}")
    except Exception as e:
        print(f"   [FAIL] Snapshot Failed: {e}")
        return False

    # 3. Test NWP Multi-Model Service
    print("\n3. Testing NWP Multi-Model Integration (GFS, ECMWF, ICON)...")
    try:
        nwp_result = await nwp_service.get_multi_model_comparison(28.6139, 77.2090, "New Delhi")
        assert nwp_result is not None, "NWP result is None"
        print(f"   [OK] NWP: Confidence: {nwp_result.forecast_confidence_score}% ({nwp_result.confidence_level}), Models evaluated: {nwp_result.models_evaluated}")
    except Exception as e:
        print(f"   [FAIL] NWP Failed: {e}")
        return False

    # 4. Test Official Disaster Alerts (GDACS)
    print("\n4. Testing GDACS Official Disaster Alerts Feed...")
    try:
        alerts = await official_alert_client.fetch_official_alerts()
        print(f"   [OK] Official Alerts Feed: Retrieved {len(alerts)} live disaster advisories")
    except Exception as e:
        print(f"   [FAIL] Official Alerts Failed: {e}")
        return False

    # 5. Test Gemini Function-Calling Loop (Megha AI)
    print("\n5. Testing Gemini Function-Calling & Advisory Engine...")
    try:
        req = ChatMessageRequest(
            message="What is the current weather in Delhi and is it safe to spray crops?",
            latitude=28.6139,
            longitude=77.2090,
            location="New Delhi, India",
            persona="farmer",
            language="en",
        )
        chat_resp = await gemini_service.process_chat(req)
        assert chat_resp is not None, "Chat response is None"
        print(f"   [OK] Gemini AI: Response length: {len(chat_resp.response)} chars")
        print(f"      - Tools called: {chat_resp.tools_called}")
        print(f"      - Risk Level: {chat_resp.risk_level}")
        print(f"      - Farming Advisory Present: {chat_resp.farming_advisory is not None}")
        print(f"      - Response snippet: {chat_resp.response[:120]}...")
    except Exception as e:
        print(f"   [FAIL] Gemini AI Failed: {e}")
        return False

    print("\n========================================")
    print("[SUCCESS] ALL BACKEND SYSTEMS FULLY OPERATIONAL!")
    print("========================================")
    return True

if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)
