"""
Gemini Function Calling (Tool) Wrapper Module for WeatherGPT.

Exposes free, type-annotated async functions with clean docstrings for
Google GenAI SDK function-calling / tool use.

Each function:
1. Accepts plain string / typed arguments that Gemini extracts from user messages.
2. Resolves location using an in-memory cached geocoder.
3. Executes deterministic methods in `tool_registry`.
4. Stashes structured card data into a thread-safe `contextvars.ContextVar`
   so `gemini_service.py` can populate typed response cards seamlessly.
"""

import logging
from contextvars import ContextVar
from typing import Dict, Any, List, Optional
from pydantic import BaseModel
from app.services.llm.tool_registry import tool_registry
from app.services.weather.open_meteo_service import weather_service
from app.schemas.chat import (
    WeatherCardData,
    TravelAssessmentData,
    FarmingAdvisoryData,
    UrbanAdvisoryData,
    ClimateTrendData,
)

logger = logging.getLogger(__name__)

# Fast in-process geocode cache to prevent redundant roundtrips in a single turn
_GEOCODE_CACHE: Dict[str, tuple] = {}


class ToolExecutionContext(BaseModel):
    tools_called: List[str] = []
    card_data: Optional[WeatherCardData] = None
    travel_assessment_data: Optional[TravelAssessmentData] = None
    farming_advisory_data: Optional[FarmingAdvisoryData] = None
    urban_advisory_data: Optional[UrbanAdvisoryData] = None
    climate_trend_data: Optional[ClimateTrendData] = None
    nwp_data: Optional[Dict[str, Any]] = None
    official_alerts_data: Optional[List[Dict[str, Any]]] = None
    risk_level: str = "LOW"
    resolved_location_name: Optional[str] = None
    resolved_lat: Optional[float] = None
    resolved_lon: Optional[float] = None


# Thread-safe, per-request context variable
_tool_context_var: ContextVar[ToolExecutionContext] = ContextVar("tool_context")


def get_current_tool_context() -> ToolExecutionContext:
    try:
        return _tool_context_var.get()
    except LookupError:
        ctx = ToolExecutionContext()
        _tool_context_var.set(ctx)
        return ctx


def init_tool_context() -> ToolExecutionContext:
    ctx = ToolExecutionContext()
    _tool_context_var.set(ctx)
    return ctx


async def _resolve_location(location: str) -> tuple[float, float, str]:
    """Helper to geocode city names with local caching, prioritizing user's live coordinates."""
    ctx = get_current_tool_context()
    generic_words = {"here", "my location", "current location", "current", "this location", "khet", "farm", "city", "village", "town", "home", "my area", ""}
    clean_loc = (location or "").strip()

    # If location is generic or empty, use user's resolved live location immediately
    if (not clean_loc or clean_loc.lower() in generic_words) and ctx.resolved_lat is not None and ctx.resolved_lon is not None:
        return (ctx.resolved_lat, ctx.resolved_lon, ctx.resolved_location_name or "My Location")

    clean_loc = clean_loc or (ctx.resolved_location_name or "New Delhi, India")
    key = clean_loc.lower()
    if key in _GEOCODE_CACHE:
        return _GEOCODE_CACHE[key]

    geocoded = await weather_service.geocode(clean_loc)
    if geocoded:
        lat, lon, name = geocoded
        res = (lat, lon, name)
        _GEOCODE_CACHE[key] = res
        return res

    # Fallback to user live location if geocoding fails
    if ctx.resolved_lat is not None and ctx.resolved_lon is not None:
        res = (ctx.resolved_lat, ctx.resolved_lon, ctx.resolved_location_name or clean_loc)
        _GEOCODE_CACHE[key] = res
        return res

    # Fallback to Delhi if unrecognized
    res = (28.6139, 77.2090, clean_loc)
    _GEOCODE_CACHE[key] = res
    return res


# ---------------------------------------------------------------------------
# Gemini Free Tool Functions (Inspected by Google GenAI SDK for Schema)
# ---------------------------------------------------------------------------

async def get_current_weather(location: str) -> dict:
    """Get real-time current weather metrics (temperature, humidity, precipitation, wind speed, weather condition) for a city.

    Args:
        location: City and country name, e.g. 'Jaipur, India' or 'London, UK'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("get_current_weather")
    lat, lon, name = await _resolve_location(location)
    ctx.resolved_lat, ctx.resolved_lon, ctx.resolved_location_name = lat, lon, name

    result = await tool_registry.get_current_weather(lat, lon, name)
    data = result.get("data", {})
    if data:
        ctx.card_data = WeatherCardData(
            location=name,
            temperature=float(data.get("temperature", 0.0)),
            condition=str(data.get("condition", "Clear")),
            weather_code=int(data.get("weather_code", 0)),
            humidity=float(data.get("humidity", 0.0)),
            wind_speed=float(data.get("wind_speed", 0.0)),
            precipitation=float(data.get("precipitation", 0.0)),
        )
    return result


async def get_hourly_forecast(location: str) -> dict:
    """Get the next 24-hour timeline of hourly temperatures, precipitation probabilities, and weather conditions.

    Args:
        location: City and country name, e.g. 'Mumbai, India'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("get_hourly_forecast")
    lat, lon, name = await _resolve_location(location)
    return await tool_registry.get_hourly_forecast(lat, lon, name)


async def get_rain_timeline(location: str, time_reference: str = "current") -> dict:
    """Get precise precipitation timeline: whether rain is expected, peak rain probability %, peak hour, and expected rainfall amount in mm.

    Args:
        location: City and country name, e.g. 'Bengaluru, India'.
        time_reference: Time frame reference such as 'current', 'today', 'tomorrow', or 'morning'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("get_rain_timeline")
    lat, lon, name = await _resolve_location(location)
    return await tool_registry.get_rain_timeline(lat, lon, name, time_reference)


async def get_multi_day_forecast(location: str, days: int = 7) -> dict:
    """Get multi-day (up to 7 days) daily forecast including max/min temperatures, rain chances, and conditions.

    Args:
        location: City and country name, e.g. 'Shimla, India'.
        days: Number of forecast days (1 to 7).
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("get_multi_day_forecast")
    lat, lon, name = await _resolve_location(location)
    return await tool_registry.get_multi_day_forecast(lat, lon, name, days)


async def get_weather_risk(location: str) -> dict:
    """Classify meteorological severe weather risks (Heatwaves, Gale winds, Heavy downpours, Severe storms) and active risk level.

    Args:
        location: City and country name, e.g. 'Chennai, India'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("get_weather_risk")
    lat, lon, name = await _resolve_location(location)
    result = await tool_registry.get_weather_risk(lat, lon, name)
    risk = result.get("overall_risk", "LOW")
    if risk in ("HIGH", "SEVERE") or ctx.risk_level == "LOW":
        ctx.risk_level = risk
    return result


async def get_official_alerts(location: str) -> dict:
    """Get active severe weather alerts with headlines, official descriptions, and safety advisories for a location.

    Args:
        location: City and country name, e.g. 'Kolkata, India'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("get_official_alerts")
    lat, lon, name = await _resolve_location(location)
    return await tool_registry.get_official_alerts(lat, lon, name)


async def evaluate_travel_conditions(
    destination: str,
    time_reference: str = "current",
    activity: str = "driving",
) -> dict:
    """Evaluate deterministic road, commute, or flight travel safety, risk levels, best departure windows, and weather hazard guidelines.

    Args:
        destination: Travel destination or commute route city, e.g. 'Manali, India' or 'Pune, India'.
        time_reference: Time frame of travel, e.g. 'today', 'tomorrow', 'morning', 'evening'.
        activity: Mode of travel or outdoor activity, e.g. 'driving', 'flight', 'two_wheeler', 'walking', 'highway'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("evaluate_travel_conditions")
    lat, lon, name = await _resolve_location(destination)
    result = await tool_registry.evaluate_travel_conditions(
        lat=lat,
        lon=lon,
        destination=name,
        time_ref=time_reference,
        activity=activity,
    )
    ctx.travel_assessment_data = TravelAssessmentData(
        destination=result.get("destination", name),
        time_frame=result.get("time_frame", time_reference),
        activity=result.get("activity", activity),
        travel_risk=result.get("travel_risk", "LOW"),
        verdict=result.get("verdict", "Safe"),
        reasons=result.get("reasons", []),
        guidelines=result.get("guidelines", []),
    )
    if result.get("travel_risk") in ("HIGH", "SEVERE"):
        ctx.risk_level = result.get("travel_risk")
    return result


async def evaluate_farming_conditions(
    location: str,
    time_reference: str = "current",
    crop: str = "general",
    activity: str = "general",
) -> dict:
    """Evaluate deterministic agricultural and agronomic rules for crop irrigation, pesticide/fertilizer spraying, harvesting, and pest risks.

    Args:
        location: Farming region or district, e.g. 'Ludhiana, India' or 'Nashik, India'.
        time_reference: Target time frame, e.g. 'today', 'tomorrow', 'this_week'.
        crop: Target crop name, e.g. 'wheat', 'rice', 'cotton', 'mustard', 'vegetables'.
        activity: Agricultural operation, e.g. 'irrigation', 'spraying', 'harvesting', 'sowing'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("evaluate_farming_conditions")
    lat, lon, name = await _resolve_location(location)
    result = await tool_registry.evaluate_farming_conditions(
        lat=lat,
        lon=lon,
        location=name,
        time_ref=time_reference,
        crop=crop,
        activity=activity,
    )
    ctx.farming_advisory_data = FarmingAdvisoryData(
        crop=result.get("crop", crop),
        activity=result.get("activity", activity),
        recommendation=result.get("recommendation", "Proceed with caution"),
        advisory_headline=result.get("advisory_headline", "Farming Advisory"),
        reasons=result.get("reasons", []),
        actionable_steps=result.get("actionable_steps", []),
    )
    return result


async def evaluate_urban_conditions(
    location: str,
    time_reference: str = "current",
    activity: str = "general",
) -> dict:
    """Evaluate deterministic urban/smart-city rules for road waterlogging, outdoor worker heat-index stress, and wind traffic disruptions.

    Args:
        location: City or municipal area, e.g. 'Delhi, India' or 'Mumbai, India'.
        time_reference: Target time frame, e.g. 'today', 'tomorrow'.
        activity: Urban activity, e.g. 'outdoor_construction', 'delivery', 'commute'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("evaluate_urban_conditions")
    lat, lon, name = await _resolve_location(location)
    result = await tool_registry.evaluate_urban_conditions(
        lat=lat,
        lon=lon,
        location=name,
        time_ref=time_reference,
        activity=activity,
    )
    ctx.urban_advisory_data = UrbanAdvisoryData(
        location=result.get("location", name),
        time_frame=result.get("time_frame", time_reference),
        activity=result.get("activity", activity),
        risk_level=result.get("risk_level", "LOW"),
        verdict=result.get("verdict", "Normal urban conditions"),
        reasons=result.get("reasons", []),
        actionable_steps=result.get("actionable_steps", []),
    )
    if result.get("risk_level") in ("HIGH", "SEVERE"):
        ctx.risk_level = result.get("risk_level")
    return result


async def evaluate_climate_trend(
    location: str,
    month: int,
    years_back: int = 10,
) -> dict:
    """Compute historical climate averages (average total rainfall, max/min temperature range, 10-year trend direction) for a given month.

    Args:
        location: City and country name, e.g. 'Delhi, India'.
        month: Calendar month number (1 for Jan, 2 for Feb, ..., 12 for Dec).
        years_back: Number of historical years to analyze (e.g. 10).
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("evaluate_climate_trend")
    lat, lon, name = await _resolve_location(location)
    result = await tool_registry.evaluate_climate_trend(
        lat=lat,
        lon=lon,
        location=name,
        month=month,
        years_back=years_back,
    )
    if "error" not in result:
        ctx.climate_trend_data = ClimateTrendData(
            location=result.get("location", name),
            month=result.get("month", month),
            years_covered=result.get("years_covered", []),
            avg_total_rainfall_mm=result.get("avg_total_rainfall_mm", 0.0),
            min_total_rainfall_mm=result.get("min_total_rainfall_mm", 0.0),
            max_total_rainfall_mm=result.get("max_total_rainfall_mm", 0.0),
            avg_temp_max=result.get("avg_temp_max", 0.0),
            avg_temp_min=result.get("avg_temp_min", 0.0),
            typical_condition=result.get("typical_condition", "Normal"),
            rainfall_trend=result.get("rainfall_trend", "stable"),
            summary=result.get("summary", ""),
        )
    return result


async def get_nwp_comparison(location: str) -> dict:
    """Fetch raw Numerical Weather Prediction (NWP) physics model outputs from NOAA GFS, ECMWF IFS, and DWD ICON, comparing temperature spread and model confidence score.

    Args:
        location: City and country name, e.g. 'Delhi, India'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("get_nwp_comparison")
    lat, lon, name = await _resolve_location(location)
    result = await tool_registry.get_nwp_comparison(lat, lon, name)
    ctx.nwp_data = result
    return result


async def get_official_disaster_alerts(country: Optional[str] = None) -> dict:
    """Fetch live official emergency disaster and extreme weather early warnings from GDACS (UN OCHA / EC JRC) and NDMA SACHET.

    Args:
        country: Optional country name filter, e.g. 'India'.
    """
    ctx = get_current_tool_context()
    ctx.tools_called.append("get_official_disaster_alerts")
    result = await tool_registry.get_official_disaster_alerts(country=country)
    ctx.official_alerts_data = result.get("alerts", [])
    return result


# Standard tools list to pass into Google GenAI SDK GenerateContentConfig
ALL_GEMINI_TOOLS = [
    get_current_weather,
    get_hourly_forecast,
    get_rain_timeline,
    get_multi_day_forecast,
    get_weather_risk,
    get_official_alerts,
    evaluate_travel_conditions,
    evaluate_farming_conditions,
    evaluate_urban_conditions,
    evaluate_climate_trend,
    get_nwp_comparison,
    get_official_disaster_alerts,
]
