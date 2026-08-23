from typing import Dict, Any, List, Optional
from pydantic import BaseModel
from app.services.weather.weather_processor import WeatherFactSnapshot


class FarmingAdvisoryResult(BaseModel):
    crop: str
    location: str
    time_frame: str
    activity: str
    recommendation: str  # DELAY_IRRIGATION, SAFE_TO_IRRIGATE, AVOID_SPRAYING, OPTIMAL_SPRAY_WINDOW, etc.
    advisory_headline: str
    reasons: List[str]
    actionable_steps: List[str]
    weather_facts: Dict[str, Any]


class FarmingAdvisoryEngine:
    """
    Deterministic Agricultural Advisory Engine.
    Evaluates agronomic rules for crop management, spraying windows,
    irrigation scheduling, and weather hazards.
    """

    def evaluate(
        self,
        snapshot: WeatherFactSnapshot,
        location: str,
        time_frame: str = "current",
        crop: str = "general",
        activity: str = "general",
    ) -> FarmingAdvisoryResult:
        is_future = time_frame in ["tomorrow", "weekend", "7_days"]
        rain_prob = snapshot.tomorrow_rain_prob if is_future else snapshot.rain_timeline.peak_probability
        precip_mm = snapshot.tomorrow_rain_sum_mm if is_future else snapshot.current_precipitation_mm
        temp_max = snapshot.tomorrow_temp_max if is_future else snapshot.current_temp
        temp_min = snapshot.tomorrow_temp_min if is_future else snapshot.current_temp
        wind_speed = snapshot.current_wind_kmh
        humidity = snapshot.current_humidity
        condition = snapshot.tomorrow_condition if is_future else snapshot.current_condition

        reasons: List[str] = []
        actionable_steps: List[str] = []
        recommendation = "FAVORABLE_CONDITIONS"
        headline = f"Favorable Agricultural Outlook for {crop.title()}"

        act_lower = activity.lower()

        # 1. Irrigation Rule
        if "irrigat" in act_lower or "pani" in act_lower:
            if rain_prob >= 40 or precip_mm >= 3.0:
                recommendation = "DELAY_IRRIGATION"
                headline = "🌧️ Hold Off Irrigation — Rain Expected"
                reasons.append(f"Rain probability is {rain_prob}% with estimated {round(precip_mm, 1)} mm precipitation.")
                actionable_steps.append("Delay canal or tubewell irrigation for 24-48 hours to conserve electricity and avoid root waterlogging.")
                actionable_steps.append("Ensure drainage bunds are clear to channel excess rainwater.")
            else:
                recommendation = "SAFE_TO_IRRIGATE"
                headline = "💧 Safe for Scheduled Irrigation"
                reasons.append(f"Dry conditions expected (Rain chance only {rain_prob}%).")
                actionable_steps.append("Proceed with light to moderate field irrigation as scheduled.")

        # 2. Pesticide / Foliar Spray Rule
        elif "spray" in act_lower or "pesticide" in act_lower or "chhidkaw" in act_lower or "fertiliz" in act_lower:
            if rain_prob >= 35 or precip_mm >= 1.0:
                recommendation = "AVOID_SPRAYING"
                headline = "🚫 Avoid Chemical Spraying — Rain Washout Risk"
                reasons.append(f"High risk of rain ({rain_prob}%) which will wash away applied chemicals.")
                actionable_steps.append("Postpone foliar sprays and urea top-dressing until skies clear.")
            elif wind_speed >= 15.0:
                recommendation = "AVOID_SPRAYING"
                headline = "💨 Postpone Spraying — High Wind Drift"
                reasons.append(f"Wind speed ({round(wind_speed, 1)} km/h) exceeds safe spraying threshold (15 km/h).")
                actionable_steps.append("Wind drift causes chemical waste and uneven coverage. Spray during calm morning hours.")
            else:
                recommendation = "OPTIMAL_SPRAY_WINDOW"
                headline = "✨ Optimal Window for Pesticide / Nutrient Spray"
                reasons.append(f"Low rain probability ({rain_prob}%) and calm winds ({round(wind_speed, 1)} km/h).")
                actionable_steps.append("Optimal spraying window is between 7:00 AM - 11:00 AM.")

        # 3. Harvesting / Mandi drying Rule
        elif "harvest" in act_lower or "katai" in act_lower or "dry" in act_lower:
            if rain_prob >= 35 or precip_mm >= 2.0:
                recommendation = "POSTPONE_HARVEST_OR_COVER"
                headline = "⚠️ Protect Harvested Produce — Moisture Risk"
                reasons.append(f"Rain probability of {rain_prob}% poses risk to moisture-sensitive grains.")
                actionable_steps.append("Cover harvested produce in fields or open grain markets (mandis) with tarpaulins.")
                actionable_steps.append("Delay combine harvesting until field soil dries.")
            else:
                recommendation = "FAVORABLE_FOR_HARVEST"
                headline = "🌾 Favorable Weather for Crop Harvesting"
                reasons.append(f"Sunny/dry spell ({condition}, {round(temp_max, 1)}°C) suitable for harvesting.")
                actionable_steps.append("Safe to harvest, thresh, and sun-dry crops.")

        # 4. General Weather Hazard Assessment for Crops
        else:
            if snapshot.alerts:
                alert = snapshot.alerts[0]
                recommendation = "HAZARD_ADVISORY"
                headline = f"⚠️ {alert.headline}"
                reasons.append(alert.description)
                actionable_steps.append(alert.advisory)
            elif rain_prob >= 60:
                recommendation = "RAIN_PROTECTION"
                headline = "🌧️ High Rain Likelihood — Field Drainage Advisory"
                reasons.append(f"Rain probability is {rain_prob}% with potential {round(precip_mm, 1)} mm accumulation.")
                actionable_steps.append("Inspect crop field drainage outlets to prevent stagnant waterlogging.")
            elif temp_max >= 40.0:
                recommendation = "HEAT_STRESS_MITIGATION"
                headline = "🔥 Extreme Heat Warning for Crops"
                reasons.append(f"High daytime temperatures reaching {round(temp_max, 1)}°C.")
                actionable_steps.append("Provide light frequent evening irrigation to maintain soil moisture and mitigate heat stress.")
            elif temp_min <= 4.0:
                recommendation = "FROST_PROTECTION_NEEDED"
                headline = "❄️ Frost Warning for Standing Crops"
                reasons.append(f"Night temperatures dropping to {round(temp_min, 1)}°C.")
                actionable_steps.append("Apply light evening irrigation or create micro-smoke around field borders to guard against frost damage.")
            else:
                recommendation = "ROUTINE_MANAGEMENT"
                headline = f"🌾 Stable Agricultural Weather for {crop.title()}"
                reasons.append(f"Temperature {round(temp_min, 1)}°C - {round(temp_max, 1)}°C, humidity {round(humidity, 1)}%, and {round(wind_speed, 1)} km/h wind.")
                actionable_steps.append("Continue standard crop nutrition and weeding management.")

        weather_facts = {
            "rain_probability": rain_prob,
            "rainfall_mm": round(precip_mm, 1),
            "wind_speed_kmh": round(wind_speed, 1),
            "humidity": round(humidity, 1),
            "temp_range": f"{round(temp_min, 1)}°C - {round(temp_max, 1)}°C",
            "condition": condition,
        }

        return FarmingAdvisoryResult(
            crop=crop,
            location=location,
            time_frame=time_frame,
            activity=activity,
            recommendation=recommendation,
            advisory_headline=headline,
            reasons=reasons,
            actionable_steps=actionable_steps,
            weather_facts=weather_facts,
        )


farming_engine = FarmingAdvisoryEngine()
