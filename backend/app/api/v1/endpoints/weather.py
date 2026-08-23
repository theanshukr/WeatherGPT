from datetime import date
from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from app.services.weather.open_meteo_service import weather_service
from app.services.weather.weather_processor import weather_processor, WeatherFactSnapshot
from app.services.weather.climate_trend_service import climate_trend_service
from app.services.alerts.official_alert_client import official_alert_client
from app.schemas.weather import CurrentWeatherResponse

router = APIRouter()


@router.get("/alerts/source-status", tags=["Weather"])
async def get_alert_source_status():
    """
    Reports which alert source(s) are actually active. Useful for a demo
    to show honestly whether alerts are official-government-sourced or
    computed-threshold-only — see app/services/alerts/official_alert_client.py
    for why the official NDMA source may not be configured.
    """
    return {
        "official_source_configured": official_alert_client.is_configured(),
        "official_source": "NDMA SACHET CAP feed" if official_alert_client.is_configured() else None,
        "computed_threshold_source": "always_active",
        "note": (
            "Official government alerts require a registered NDMA/C-DOT "
            "agency identifier which is not currently configured. Alerts "
            "shown are computed from forecast thresholds and labeled "
            "'computed_forecast_threshold' rather than presented as "
            "official warnings."
            if not official_alert_client.is_configured()
            else "Official NDMA SACHET CAP feed is active."
        ),
    }


@router.get("/current", response_model=CurrentWeatherResponse, tags=["Weather"])
async def get_current_weather(
    city: Optional[str] = Query(None, description="City name to search"),
    lat: Optional[float] = Query(None, description="Latitude"),
    lon: Optional[float] = Query(None, description="Longitude"),
):
    target_lat = lat
    target_lon = lon
    location_name = city or "Location"

    if city and (lat is None or lon is None):
        geocoded = await weather_service.geocode(city)
        if not geocoded:
            raise HTTPException(status_code=404, detail=f"Could not find coordinates for '{city}'")
        target_lat, target_lon, location_name = geocoded

    if target_lat is None or target_lon is None:
        target_lat, target_lon, location_name = 28.6139, 77.2090, "Delhi, India"

    weather = await weather_service.get_current_weather(target_lat, target_lon, location_name)
    if not weather:
        raise HTTPException(status_code=502, detail="Failed to fetch weather data from provider")

    return weather


@router.get("/snapshot", tags=["Weather"])
async def get_weather_snapshot(
    city: Optional[str] = Query(None, description="City name"),
    lat: Optional[float] = Query(None, description="Latitude"),
    lon: Optional[float] = Query(None, description="Longitude"),
):
    """Retrieve full factual snapshot (Current, Hourly Rain Timeline, 7-Day Forecast, and Severe Alerts)."""
    target_lat = lat
    target_lon = lon
    location_name = city or "Location"

    if city and (lat is None or lon is None):
        geocoded = await weather_service.geocode(city)
        if not geocoded:
            raise HTTPException(status_code=404, detail=f"Could not find coordinates for '{city}'")
        target_lat, target_lon, location_name = geocoded

    if target_lat is None or target_lon is None:
        target_lat, target_lon, location_name = 28.6139, 77.2090, "New Delhi, India"

    raw_data = await weather_service.get_comprehensive_weather(target_lat, target_lon, location_name)
    if not raw_data:
        raise HTTPException(status_code=502, detail="Failed to fetch comprehensive weather data")

    snapshot = weather_processor.process(raw_data, location_name)
    return snapshot.model_dump()


@router.get("/hourly", tags=["Weather"])
async def get_hourly_forecast(
    city: Optional[str] = Query(None, description="City name"),
    lat: Optional[float] = Query(None, description="Latitude"),
    lon: Optional[float] = Query(None, description="Longitude"),
):
    """Retrieve next 24 hours rain probability and temperature timeline."""
    snapshot = await get_weather_snapshot(city=city, lat=lat, lon=lon)
    return snapshot["rain_timeline"]


@router.get("/forecast", tags=["Weather"])
async def get_daily_forecast(
    city: Optional[str] = Query(None, description="City name"),
    lat: Optional[float] = Query(None, description="Latitude"),
    lon: Optional[float] = Query(None, description="Longitude"),
):
    """Retrieve 7-day daily forecast outlook."""
    snapshot = await get_weather_snapshot(city=city, lat=lat, lon=lon)
    return snapshot["daily_7_day_forecast"]


@router.get("/climate-trend", tags=["Weather"])
async def get_climate_trend(
    city: Optional[str] = Query(None, description="City name"),
    lat: Optional[float] = Query(None, description="Latitude"),
    lon: Optional[float] = Query(None, description="Longitude"),
    month: Optional[int] = Query(None, ge=1, le=12, description="Month number (1-12); defaults to current month"),
    years_back: int = Query(10, ge=3, le=20, description="How many years of history to average over"),
):
    """
    Historical / climate trend analysis: average rainfall, temperature, and
    typical conditions for a given month over the last N years, plus a
    simple increasing/decreasing/stable rainfall trend — e.g. "average
    rainfall in Delhi in August over the last 10 years".

    Backed by Open-Meteo's free Historical Weather (Archive) API. Scoped
    intentionally small: simple aggregates over a fixed window, not a full
    climate-analytics platform.
    """
    target_lat = lat
    target_lon = lon
    location_name = city or "Location"

    if city and (lat is None or lon is None):
        geocoded = await weather_service.geocode(city)
        if not geocoded:
            raise HTTPException(status_code=404, detail=f"Could not find coordinates for '{city}'")
        target_lat, target_lon, location_name = geocoded

    if target_lat is None or target_lon is None:
        target_lat, target_lon, location_name = 28.6139, 77.2090, "New Delhi, India"

    target_month = month or date.today().month

    result = await climate_trend_service.get_monthly_trend(
        target_lat, target_lon, location_name, target_month, years_back=years_back
    )
    if not result:
        raise HTTPException(status_code=502, detail="Failed to fetch historical climate data from provider")

    return result


@router.get("/alerts", tags=["Weather"])
async def get_severe_alerts(
    city: Optional[str] = Query(None, description="City name"),
    lat: Optional[float] = Query(None, description="Latitude"),
    lon: Optional[float] = Query(None, description="Longitude"),
):
    """Retrieve active severe weather alerts and risk classifications."""
    snapshot = await get_weather_snapshot(city=city, lat=lat, lon=lon)
    return snapshot["alerts"]
