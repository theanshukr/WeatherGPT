from typing import Dict, Any, List
from pydantic import BaseModel
from app.services.weather.weather_processor import WeatherFactSnapshot


class UrbanAdvisoryResult(BaseModel):
    location: str
    time_frame: str
    activity: str
    risk_level: str  # LOW, MODERATE, HIGH, SEVERE
    advisory_headline: str
    verdict: str
    reasons: List[str]
    actionable_steps: List[str]
    weather_facts: Dict[str, Any]


class UrbanAdvisoryEngine:
    """
    Deterministic Smart-City / Urban Monitoring Advisory Engine.

    Covers the "smart city weather monitoring" SIH use case: waterlogging /
    drainage risk from heavy rainfall, heat-index warnings for outdoor
    municipal/gig workers, and traffic-disruption flags from wind/visibility
    hazards — the same rule-based-engine-over-forecast-data pattern already
    used by FarmingAdvisoryEngine and TravelAssessmentEngine, so it plugs
    into the existing tool_registry / gemini_service prompt pipeline with no
    other architectural changes.
    """

    def evaluate(
        self,
        snapshot: WeatherFactSnapshot,
        location: str,
        time_frame: str = "current",
        activity: str = "general",
    ) -> UrbanAdvisoryResult:
        is_future = time_frame in ["tomorrow", "weekend", "7_days"]
        rain_prob = snapshot.tomorrow_rain_prob if is_future else snapshot.rain_timeline.peak_probability
        precip_mm = snapshot.tomorrow_rain_sum_mm if is_future else snapshot.current_precipitation_mm
        temp_max = snapshot.tomorrow_temp_max if is_future else snapshot.current_temp
        wind_speed = snapshot.current_wind_kmh
        humidity = snapshot.current_humidity
        condition = snapshot.tomorrow_condition if is_future else snapshot.current_condition

        reasons: List[str] = []
        actionable_steps: List[str] = []
        risk_score = 0

        # 1. Official / computed severe alerts propagate straight through
        for alert in snapshot.alerts:
            if alert.risk_level == "SEVERE":
                risk_score += 5
                reasons.append(f"Active alert: {alert.headline}")
                actionable_steps.append(alert.advisory)
            elif alert.risk_level == "HIGH":
                risk_score += 3
                reasons.append(f"Advisory: {alert.headline}")
                actionable_steps.append(alert.advisory)

        # 2. Waterlogging / drainage risk (municipal ops relevant threshold)
        if precip_mm >= 50.0:
            risk_score += 4
            reasons.append(f"Very heavy rainfall expected ({round(precip_mm, 1)} mm) — high waterlogging risk in low-lying areas.")
            actionable_steps.append("Pre-position pumps at known waterlogging points and alert traffic police for underpass closures.")
        elif precip_mm >= 20.0 or rain_prob >= 70:
            risk_score += 2
            reasons.append(f"Heavy rain likely ({rain_prob}% chance, {round(precip_mm, 1)} mm) — drains may back up in older localities.")
            actionable_steps.append("Clear known drainage choke points proactively; advise commuters to avoid underpasses.")
        elif rain_prob >= 40:
            risk_score += 1
            reasons.append(f"Moderate rain chance ({rain_prob}%) possible over the city.")

        # 3. Heat-index risk for outdoor / gig / municipal workers
        if temp_max >= 43.0:
            risk_score += 3
            reasons.append(f"Extreme heat ({round(temp_max, 1)}°C) — high heat-stress risk for outdoor and delivery workers.")
            actionable_steps.append("Advise outdoor/gig workers to avoid work during 12-4 PM peak heat window; ensure hydration points at worksites.")
        elif temp_max >= 39.0:
            risk_score += 1
            reasons.append(f"High daytime temperature ({round(temp_max, 1)}°C) with humidity {round(humidity, 1)}%.")
            actionable_steps.append("Recommend shaded rest breaks for construction and delivery staff during afternoon hours.")

        # 4. Wind / traffic disruption
        if wind_speed >= 45.0:
            risk_score += 3
            reasons.append(f"Strong winds ({round(wind_speed, 1)} km/h) — risk of hoarding/tree falls disrupting traffic.")
            actionable_steps.append("Flag high-mast signage and loose hoardings for inspection; caution two-wheeler and e-rickshaw traffic on flyovers.")
        elif wind_speed >= 30.0:
            risk_score += 1
            reasons.append(f"Brisk winds ({round(wind_speed, 1)} km/h) expected.")

        # 5. Categorize
        if risk_score >= 6:
            risk_level = "SEVERE"
            verdict = "City Operations Alert — Coordinate Emergency Response Readiness"
            headline = "🚨 Severe Urban Weather Risk"
        elif risk_score >= 3:
            risk_level = "HIGH"
            verdict = "Elevated Risk — Proactive Municipal Action Recommended"
            headline = "⚠️ Elevated Urban Weather Risk"
        elif risk_score >= 1:
            risk_level = "MODERATE"
            verdict = "Minor Precautions Advised for City Operations"
            headline = "🏙️ Moderate Urban Weather Watch"
        else:
            risk_level = "LOW"
            verdict = "Normal City Operations — No Weather-Driven Risk"
            headline = f"🏙️ Stable Urban Conditions ({condition})"

        if not reasons:
            reasons.append(f"Clear/stable conditions ({condition}, {round(temp_max, 1)}°C) with low rain and wind risk.")
        if not actionable_steps:
            actionable_steps.append("No special municipal action needed; continue routine monitoring.")

        weather_facts = {
            "rain_probability": rain_prob,
            "rainfall_mm": round(precip_mm, 1),
            "wind_speed_kmh": round(wind_speed, 1),
            "humidity": round(humidity, 1),
            "temp_max": round(temp_max, 1),
            "condition": condition,
        }

        return UrbanAdvisoryResult(
            location=location,
            time_frame=time_frame,
            activity=activity,
            risk_level=risk_level,
            advisory_headline=headline,
            verdict=verdict,
            reasons=reasons,
            actionable_steps=actionable_steps,
            weather_facts=weather_facts,
        )


urban_engine = UrbanAdvisoryEngine()
