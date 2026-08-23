from typing import Dict, Any, List, Optional
from pydantic import BaseModel
from app.services.weather.open_meteo_service import WMO_CODE_MAP


class RainTimeline(BaseModel):
    is_rain_expected: bool
    peak_probability: int  # 0 - 100%
    peak_time: Optional[str] = None
    expected_rain_amount_mm: float
    rainy_hours: List[str] = []
    summary: str


class DailyOutlook(BaseModel):
    date: str
    condition: str
    weather_code: int
    temp_max: float
    temp_min: float
    rain_probability_max: int
    precipitation_sum_mm: float
    uv_index_max: Optional[float] = None
    wind_max_kmh: Optional[float] = None


class SevereAlert(BaseModel):
    risk_level: str  # LOW, MODERATE, HIGH, SEVERE
    headline: str
    description: str
    advisory: str
    # Provenance matters for a disaster-alert feature: this is a locally
    # computed threshold check against forecast data, NOT an official
    # government warning. Kept explicit so the UI/LLM never implies this
    # carries the authority of an IMD/NDMA-issued alert. See
    # app/services/alerts/official_alert_client.py for the real-source path.
    source: str = "computed_forecast_threshold"


class WeatherFactSnapshot(BaseModel):
    location: str
    latitude: float
    longitude: float
    current_temp: float
    current_condition: str
    current_humidity: float
    current_wind_kmh: float
    current_precipitation_mm: float
    is_day: int
    
    # Tomorrow overview
    tomorrow_condition: str
    tomorrow_temp_max: float
    tomorrow_temp_min: float
    tomorrow_rain_prob: int
    tomorrow_rain_sum_mm: float
    
    # Analyses
    rain_timeline: RainTimeline
    daily_7_day_forecast: List[DailyOutlook]
    alerts: List[SevereAlert]


class WeatherProcessor:
    """Processes raw meteorological data into structured facts and risk assessments."""

    def process(self, raw_data: Dict[str, Any], location_name: str) -> WeatherFactSnapshot:
        lat = raw_data.get("latitude", 0.0)
        lon = raw_data.get("longitude", 0.0)
        cur = raw_data.get("current", {})
        hourly = raw_data.get("hourly", {})
        daily = raw_data.get("daily", {})

        # 1. Current Weather
        code = cur.get("weather_code", 0)
        condition = WMO_CODE_MAP.get(code, "Clear")
        current_temp = cur.get("temperature_2m", 25.0)
        current_humidity = cur.get("relative_humidity_2m", 50.0)
        current_wind = cur.get("wind_speed_10m", 10.0)
        current_precip = cur.get("precipitation", 0.0)
        is_day = cur.get("is_day", 1)

        # 2. Hourly Rain Timeline Analysis (Next 24 hours)
        hourly_times = hourly.get("time", [])[:24]
        hourly_precip_prob = hourly.get("precipitation_probability", [])[:24]
        hourly_precip = hourly.get("precipitation", [])[:24]
        hourly_temp = hourly.get("temperature_2m", [])[:24]

        peak_prob = 0
        peak_time = None
        total_precip = 0.0
        rainy_hours = []

        for idx, t in enumerate(hourly_times):
            prob = hourly_precip_prob[idx] if idx < len(hourly_precip_prob) else 0
            prec = hourly_precip[idx] if idx < len(hourly_precip) else 0.0
            total_precip += prec

            if prob > peak_prob:
                peak_prob = prob
                # Format time string e.g. "2026-08-23T16:00" -> "4:00 PM"
                try:
                    hour_int = int(t.split("T")[1].split(":")[0])
                    am_pm = "AM" if hour_int < 12 else "PM"
                    display_hr = hour_int if hour_int <= 12 else hour_int - 12
                    if display_hr == 0:
                        display_hr = 12
                    peak_time = f"{display_hr}:00 {am_pm}"
                except Exception:
                    peak_time = t

            if prob >= 40 or prec > 0.1:
                try:
                    hour_int = int(t.split("T")[1].split(":")[0])
                    am_pm = "AM" if hour_int < 12 else "PM"
                    display_hr = hour_int if hour_int <= 12 else hour_int - 12
                    if display_hr == 0:
                        display_hr = 12
                    rainy_hours.append(f"{display_hr} {am_pm}")
                except Exception:
                    rainy_hours.append(t)

        is_rain_expected = peak_prob >= 35 or total_precip > 0.2
        if is_rain_expected:
            rain_summary = f"Rain likely (up to {peak_prob}% chance around {peak_time or 'evening'}) with estimated {round(total_precip, 1)} mm accumulation."
        else:
            rain_summary = f"Dry conditions expected (rain probability below {peak_prob}%)."

        rain_timeline = RainTimeline(
            is_rain_expected=is_rain_expected,
            peak_probability=peak_prob,
            peak_time=peak_time,
            expected_rain_amount_mm=round(total_precip, 1),
            rainy_hours=rainy_hours,
            summary=rain_summary,
        )

        # 3. 7-Day Forecast Analysis
        daily_dates = daily.get("time", [])
        daily_codes = daily.get("weather_code", [])
        daily_max = daily.get("temperature_2m_max", [])
        daily_min = daily.get("temperature_2m_min", [])
        daily_rain_prob = daily.get("precipitation_probability_max", [])
        daily_rain_sum = daily.get("precipitation_sum", [])
        daily_uv = daily.get("uv_index_max", [])
        daily_wind = daily.get("wind_speed_10m_max", [])

        daily_outlooks: List[DailyOutlook] = []
        for i, dt in enumerate(daily_dates):
            wcode = daily_codes[i] if i < len(daily_codes) else 0
            daily_outlooks.append(DailyOutlook(
                date=dt,
                condition=WMO_CODE_MAP.get(wcode, "Clear"),
                weather_code=wcode,
                temp_max=daily_max[i] if i < len(daily_max) else 30.0,
                temp_min=daily_min[i] if i < len(daily_min) else 20.0,
                rain_probability_max=daily_rain_prob[i] if i < len(daily_rain_prob) else 0,
                precipitation_sum_mm=daily_rain_sum[i] if i < len(daily_rain_sum) else 0.0,
                uv_index_max=daily_uv[i] if i < len(daily_uv) else None,
                wind_max_kmh=daily_wind[i] if i < len(daily_wind) else None,
            ))

        # Tomorrow values (Index 1)
        if len(daily_outlooks) > 1:
            tomorrow = daily_outlooks[1]
            tomorrow_condition = tomorrow.condition
            tomorrow_max = tomorrow.temp_max
            tomorrow_min = tomorrow.temp_min
            tomorrow_rain_prob = tomorrow.rain_probability_max
            tomorrow_rain_sum = tomorrow.precipitation_sum_mm
        else:
            tomorrow_condition = condition
            tomorrow_max = current_temp + 2
            tomorrow_min = current_temp - 5
            tomorrow_rain_prob = 10
            tomorrow_rain_sum = 0.0

        # 4. Risk Engine (Severe Weather Classification)
        alerts: List[SevereAlert] = []

        # Heatwave check
        if current_temp >= 42 or (daily_outlooks and daily_outlooks[0].temp_max >= 42):
            alerts.append(SevereAlert(
                risk_level="HIGH",
                headline="🔥 Heatwave Warning",
                description=f"Extreme high temperatures approaching {daily_outlooks[0].temp_max if daily_outlooks else current_temp}°C.",
                advisory="Avoid direct sun exposure between 12 PM - 4 PM. Stay hydrated and avoid strenuous outdoor work.",
            ))
        # Heavy rain / flood risk check
        if total_precip >= 50 or (daily_outlooks and daily_outlooks[0].precipitation_sum_mm >= 50):
            alerts.append(SevereAlert(
                risk_level="SEVERE",
                headline="🌧️ Heavy Rainfall & Waterlogging Alert",
                description="Heavy precipitation forecast exceeding 50 mm.",
                advisory="Avoid travel through low-lying or underpass roads. Farmers should ensure field drainage to protect crops.",
            ))
        # Thunderstorm check
        if code in [95, 96, 99] or (daily_outlooks and daily_outlooks[0].weather_code in [95, 96, 99]):
            alerts.append(SevereAlert(
                risk_level="HIGH",
                headline="⚡ Thunderstorm & Lightning Warning",
                description="Severe convective storm with potential lightning and hail.",
                advisory="Seek indoor shelter. Do not stand under tall trees or operate exposed electrical equipment.",
            ))
        # High Wind / Storm check
        if current_wind >= 50 or (daily_outlooks and (daily_outlooks[0].wind_max_kmh or 0) >= 50):
            alerts.append(SevereAlert(
                risk_level="MODERATE",
                headline="💨 Strong Gale Winds Alert",
                description=f"Wind gusts reaching {current_wind} km/h.",
                advisory="Two-wheeler riders should exercise caution. Secure loose outdoor objects and farm coverings.",
            ))

        return WeatherFactSnapshot(
            location=location_name,
            latitude=lat,
            longitude=lon,
            current_temp=current_temp,
            current_condition=condition,
            current_humidity=current_humidity,
            current_wind_kmh=current_wind,
            current_precipitation_mm=current_precip,
            is_day=is_day,
            tomorrow_condition=tomorrow_condition,
            tomorrow_temp_max=tomorrow_max,
            tomorrow_temp_min=tomorrow_min,
            tomorrow_rain_prob=tomorrow_rain_prob,
            tomorrow_rain_sum_mm=tomorrow_rain_sum,
            rain_timeline=rain_timeline,
            daily_7_day_forecast=daily_outlooks,
            alerts=alerts,
        )


weather_processor = WeatherProcessor()
