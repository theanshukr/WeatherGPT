import logging
from typing import Dict, Any, List, Optional
from pydantic import BaseModel
from app.services.weather.open_meteo_service import weather_service
from app.services.weather.weather_processor import weather_processor, WeatherFactSnapshot
from app.services.advisory.travel_engine import travel_engine, TravelAssessmentResult
from app.services.advisory.farming_engine import farming_engine, FarmingAdvisoryResult
from app.services.advisory.urban_engine import urban_engine, UrbanAdvisoryResult
from app.services.weather.climate_trend_service import climate_trend_service

logger = logging.getLogger(__name__)


class ToolRegistry:
    """
    Standardized Tool & Function Calling Registry for WeatherGPT.
    Exposes clean Python-named deterministic weather tools and advisory engines.
    """

    async def get_current_weather(self, lat: float, lon: float, location: str) -> Dict[str, Any]:
        """Fetch real-time current weather metrics (temperature, humidity, wind, condition)."""
        data = await weather_service.get_current_weather(lat, lon, location)
        return {
            "tool": "get_current_weather",
            "location": location,
            "latitude": lat,
            "longitude": lon,
            "data": data or {},
        }

    async def get_hourly_forecast(self, lat: float, lon: float, location: str) -> Dict[str, Any]:
        """Fetch next 24-hour timeline of temperatures, precipitation, and conditions."""
        raw = await weather_service.get_comprehensive_weather(lat, lon, location)
        snap = weather_processor.process(raw or {}, location)
        return {
            "tool": "get_hourly_forecast",
            "location": location,
            "rain_timeline": snap.rain_timeline.model_dump(),
        }

    async def get_rain_timeline(self, lat: float, lon: float, location: str, time_ref: str = "current") -> Dict[str, Any]:
        """Analyze precipitation probability, start time, peak hour, and accumulated rainfall."""
        raw = await weather_service.get_comprehensive_weather(lat, lon, location)
        snap = weather_processor.process(raw or {}, location)
        return {
            "tool": "get_rain_timeline",
            "location": location,
            "time_reference": time_ref,
            "is_rain_expected": snap.rain_timeline.is_rain_expected,
            "peak_probability": snap.rain_timeline.peak_probability,
            "peak_time": snap.rain_timeline.peak_time,
            "expected_rain_amount_mm": snap.rain_timeline.expected_rain_amount_mm,
            "rainy_hours": snap.rain_timeline.rainy_hours,
            "summary": snap.rain_timeline.summary,
        }

    async def get_multi_day_forecast(self, lat: float, lon: float, location: str, days: int = 7) -> Dict[str, Any]:
        """Fetch 7-day daily forecast breakdown."""
        raw = await weather_service.get_comprehensive_weather(lat, lon, location)
        snap = weather_processor.process(raw or {}, location)
        return {
            "tool": "get_multi_day_forecast",
            "location": location,
            "forecast_days": [d.model_dump() for d in snap.daily_7_day_forecast[:days]],
        }

    async def get_weather_risk(self, lat: float, lon: float, location: str) -> Dict[str, Any]:
        """Classify meteorological risk levels (Heatwave, Storm, Gale, Heavy Rain)."""
        raw = await weather_service.get_comprehensive_weather(lat, lon, location)
        snap = weather_processor.process(raw or {}, location)
        risk_level = "LOW"
        if any(a.risk_level == "SEVERE" for a in snap.alerts):
            risk_level = "SEVERE"
        elif any(a.risk_level == "HIGH" for a in snap.alerts):
            risk_level = "HIGH"
        elif any(a.risk_level == "MODERATE" for a in snap.alerts):
            risk_level = "MODERATE"

        return {
            "tool": "get_weather_risk",
            "location": location,
            "overall_risk": risk_level,
            "alerts_count": len(snap.alerts),
            "alerts": [a.model_dump() for a in snap.alerts],
        }

    async def get_official_alerts(self, lat: float, lon: float, location: str) -> Dict[str, Any]:
        """Retrieve active severe weather alerts with headlines, descriptions, and advisories."""
        raw = await weather_service.get_comprehensive_weather(lat, lon, location)
        snap = weather_processor.process(raw or {}, location)
        return {
            "tool": "get_official_alerts",
            "location": location,
            "alerts": [a.model_dump() for a in snap.alerts],
        }

    async def evaluate_travel_conditions(
        self,
        lat: float,
        lon: float,
        destination: str,
        time_ref: str = "current",
        activity: str = "driving",
    ) -> Dict[str, Any]:
        """Evaluate deterministic travel safety and produce LOW/MODERATE/HIGH/SEVERE assessment."""
        raw = await weather_service.get_comprehensive_weather(lat, lon, destination)
        snap = weather_processor.process(raw or {}, destination)
        result = travel_engine.evaluate(snap, destination, time_frame=time_ref, activity=activity)
        return {
            "tool": "evaluate_travel_conditions",
            **result.model_dump(),
        }

    async def evaluate_farming_conditions(
        self,
        lat: float,
        lon: float,
        location: str,
        time_ref: str = "current",
        crop: str = "general",
        activity: str = "general",
    ) -> Dict[str, Any]:
        """Evaluate deterministic agricultural rules for irrigation, spraying, harvesting, and crop hazards."""
        raw = await weather_service.get_comprehensive_weather(lat, lon, location)
        snap = weather_processor.process(raw or {}, location)
        result = farming_engine.evaluate(snap, location, time_frame=time_ref, crop=crop, activity=activity)
        return {
            "tool": "evaluate_farming_conditions",
            **result.model_dump(),
        }

    async def evaluate_urban_conditions(
        self,
        lat: float,
        lon: float,
        location: str,
        time_ref: str = "current",
        activity: str = "general",
    ) -> Dict[str, Any]:
        """Evaluate deterministic smart-city rules for waterlogging, heat-index worker risk, and wind traffic disruption."""
        raw = await weather_service.get_comprehensive_weather(lat, lon, location)
        snap = weather_processor.process(raw or {}, location)
        result = urban_engine.evaluate(snap, location, time_frame=time_ref, activity=activity)
        return {
            "tool": "evaluate_urban_conditions",
            **result.model_dump(),
        }

    async def evaluate_climate_trend(
        self,
        lat: float,
        lon: float,
        location: str,
        month: int,
        years_back: int = 10,
    ) -> Dict[str, Any]:
        """Compute historical climate aggregates (avg/max/min rainfall, avg temps, rainfall trend) for a given month over past years."""
        result = await climate_trend_service.get_monthly_trend(
            lat, lon, location, month=month, years_back=years_back
        )
        if not result:
            return {
                "tool": "evaluate_climate_trend",
                "location": location,
                "month": month,
                "error": "No historical data available for this location/month.",
            }
        return {
            "tool": "evaluate_climate_trend",
            **result,
        }

    async def get_nwp_comparison(
        self,
        lat: float,
        lon: float,
        location: str,
    ) -> Dict[str, Any]:
        """Fetch raw Numerical Weather Prediction (NWP) model runs from NOAA GFS, ECMWF IFS, and DWD ICON, and compute ensemble consensus and spread."""
        from app.services.weather.nwp_service import nwp_service
        result = await nwp_service.get_multi_model_comparison(lat, lon, location)
        if not result:
            return {
                "tool": "get_nwp_comparison",
                "location": location,
                "error": "Failed to retrieve NWP model intercomparison data.",
            }
        return {
            "tool": "get_nwp_comparison",
            **result.model_dump(),
        }

    async def get_official_disaster_alerts(
        self,
        country: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Fetch live official disaster and severe weather warnings from GDACS (UN OCHA / EC JRC) and NDMA SACHET."""
        from app.services.alerts.official_alert_client import official_alert_client
        alerts = await official_alert_client.fetch_official_alerts(country=country)
        return {
            "tool": "get_official_disaster_alerts",
            "count": len(alerts),
            "alerts": [a.model_dump() for a in alerts],
        }


tool_registry = ToolRegistry()
