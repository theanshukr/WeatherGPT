from typing import Dict, Any, List, Optional
from pydantic import BaseModel
from app.services.weather.weather_processor import WeatherFactSnapshot


class TravelAssessmentResult(BaseModel):
    travel_risk: str  # LOW, MODERATE, HIGH, SEVERE
    destination: str
    time_frame: str
    activity: str
    verdict: str
    reasons: List[str]
    guidelines: List[str]
    weather_facts: Dict[str, Any]


class TravelAssessmentEngine:
    """
    Deterministic Travel Safety Assessment Engine.
    Evaluates meteorological factors to produce authoritative risk ratings
    without relying on LLM guesswork.
    """

    def evaluate(
        self,
        snapshot: WeatherFactSnapshot,
        destination: str,
        time_frame: str = "current",
        activity: str = "driving",
    ) -> TravelAssessmentResult:
        reasons: List[str] = []
        guidelines: List[str] = []
        risk_score = 0  # 0: LOW, 1-2: MODERATE, 3-4: HIGH, >=5: SEVERE

        # 1. Inspect Relevant Weather Period
        is_future = time_frame in ["tomorrow", "weekend", "7_days"]
        rain_prob = snapshot.tomorrow_rain_prob if is_future else snapshot.rain_timeline.peak_probability
        precip_mm = snapshot.tomorrow_rain_sum_mm if is_future else snapshot.current_precipitation_mm
        temp_max = snapshot.tomorrow_temp_max if is_future else snapshot.current_temp
        temp_min = snapshot.tomorrow_temp_min if is_future else snapshot.current_temp
        wind_speed = snapshot.current_wind_kmh
        condition = snapshot.tomorrow_condition if is_future else snapshot.current_condition

        # 2. Check Severe Weather Alerts from Snapshot
        for alert in snapshot.alerts:
            if alert.risk_level == "SEVERE":
                risk_score += 5
                reasons.append(f"Official Severe Alert: {alert.headline}")
                guidelines.append(alert.advisory)
            elif alert.risk_level == "HIGH":
                risk_score += 3
                reasons.append(f"Official Alert: {alert.headline}")
                guidelines.append(alert.advisory)
            elif alert.risk_level == "MODERATE":
                risk_score += 2
                reasons.append(f"Advisory: {alert.headline}")

        # 3. Precipitation & Aquaplaning / Visibility Risk
        if precip_mm >= 40.0 or (snapshot.rain_timeline.expected_rain_amount_mm >= 40.0):
            risk_score += 3
            reasons.append(f"Heavy rainfall expected ({round(precip_mm, 1)} mm) causing waterlogging and reduced visibility.")
            guidelines.append("Avoid low-lying underpasses and roads prone to flash waterlogging.")
        elif rain_prob >= 70 or precip_mm >= 15.0:
            risk_score += 2
            reasons.append(f"High rain probability ({rain_prob}%) with slippery road surfaces.")
            guidelines.append("Maintain safe braking distance and keep vehicle wipers in good condition.")
        elif rain_prob >= 40:
            risk_score += 1
            reasons.append(f"Moderate chance of rain ({rain_prob}%).")
            guidelines.append("Keep an umbrella and rain gear accessible.")

        # 4. Wind & Gale Hazard
        if wind_speed >= 50.0:
            risk_score += 3
            reasons.append(f"High gale winds ({round(wind_speed, 1)} km/h) dangerous for two-wheelers and high-sided vehicles.")
            guidelines.append("Avoid driving two-wheelers on flyovers or open highways.")
        elif wind_speed >= 35.0:
            risk_score += 1
            reasons.append(f"Brisk crosswinds ({round(wind_speed, 1)} km/h).")

        # 5. Temperature Extremes
        if temp_max >= 42.0:
            risk_score += 2
            reasons.append(f"Extreme heat ({temp_max}°C) with tire blowout and overheating risks.")
            guidelines.append("Check vehicle coolant and tire pressure before highway travel. Carry extra drinking water.")
        elif temp_min <= 4.0:
            risk_score += 2
            reasons.append(f"Near-freezing temperatures ({temp_min}°C) with dense fog / black ice hazard.")
            guidelines.append("Use fog lights and drive at reduced speeds during morning/night hours.")

        # 6. Final Risk Categorization
        if risk_score >= 5:
            travel_risk = "SEVERE"
            verdict = "Travel Not Recommended — High Hazard / Severe Conditions"
        elif risk_score >= 3:
            travel_risk = "HIGH"
            verdict = "Caution Advised — Potential Delays & Hazardous Roads"
        elif risk_score >= 1:
            travel_risk = "MODERATE"
            verdict = "Fair with Minor Precautions — Wet Roads or Wind Possible"
        else:
            travel_risk = "LOW"
            verdict = "Safe & Clear Travel Conditions"

        if not reasons:
            reasons.append(f"Clear and pleasant conditions ({condition}, {round(temp_max, 1)}°C) with low precipitation risk ({rain_prob}%).")
        if not guidelines:
            guidelines.append("Standard road safety precautions apply.")

        weather_facts = {
            "rain_probability": rain_prob,
            "rainfall_mm": round(precip_mm, 1),
            "wind_speed_kmh": round(wind_speed, 1),
            "temperature_range": f"{round(temp_min, 1)}°C - {round(temp_max, 1)}°C",
            "condition": condition,
        }

        return TravelAssessmentResult(
            travel_risk=travel_risk,
            destination=destination,
            time_frame=time_frame,
            activity=activity,
            verdict=verdict,
            reasons=reasons,
            guidelines=guidelines,
            weather_facts=weather_facts,
        )


travel_engine = TravelAssessmentEngine()
