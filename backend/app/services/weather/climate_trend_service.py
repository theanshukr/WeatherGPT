import asyncio
import logging
from datetime import date
from typing import Any, Dict, List, Optional

from app.services.weather.open_meteo_service import weather_service, WMO_CODE_MAP

logger = logging.getLogger(__name__)


class ClimateTrendService:
    """
    Computes simple historical-climate aggregates ("average rainfall in
    Delhi in August over the last N years") from Open-Meteo's Historical
    Weather (Archive) API.

    Deliberately scoped small (mean/max/trend over a fixed window), per
    COMPLETION_PLAN.md item #4 — this is enough to legitimately claim the
    "climate trend and historical weather analysis" feature without trying
    to build a full climate-analytics platform.
    """

    async def get_monthly_trend(
        self,
        lat: float,
        lon: float,
        location_name: str,
        month: int,
        years_back: int = 10,
    ) -> Optional[Dict[str, Any]]:
        today = date.today()
        # Historical archive data typically has a few days' lag, so anchor
        # "current year" at last year if we're early in the target month of
        # the current year to avoid requesting a mostly-empty in-progress month.
        last_full_year = today.year - 1 if today.month <= month else today.year

        years = list(range(last_full_year - years_back + 1, last_full_year + 1))

        async def fetch_year(yr: int):
            start = date(yr, month, 1)
            if month == 12:
                end = date(yr, 12, 31)
            else:
                next_month_first = date(yr, month + 1, 1)
                end = date(yr, month, (next_month_first - start).days)
            data = await weather_service.get_historical_daily(
                lat, lon, start.isoformat(), end.isoformat()
            )
            return yr, data

        results = await asyncio.gather(*[fetch_year(y) for y in years], return_exceptions=True)

        yearly_summaries: List[Dict[str, Any]] = []
        all_rain_sums: List[float] = []
        all_temp_maxes: List[float] = []
        all_temp_mins: List[float] = []
        condition_counts: Dict[str, int] = {}

        for r in results:
            if isinstance(r, Exception):
                continue
            yr, data = r
            if not data:
                continue
            daily = data.get("daily", {})
            precip = [p for p in daily.get("precipitation_sum", []) if p is not None]
            tmax = [t for t in daily.get("temperature_2m_max", []) if t is not None]
            tmin = [t for t in daily.get("temperature_2m_min", []) if t is not None]
            codes = [c for c in daily.get("weather_code", []) if c is not None]

            if not precip and not tmax:
                continue

            rain_sum = round(sum(precip), 1) if precip else 0.0
            avg_max = round(sum(tmax) / len(tmax), 1) if tmax else None
            avg_min = round(sum(tmin) / len(tmin), 1) if tmin else None

            yearly_summaries.append({
                "year": yr,
                "total_rainfall_mm": rain_sum,
                "avg_temp_max": avg_max,
                "avg_temp_min": avg_min,
                "rainy_days": sum(1 for p in precip if p >= 1.0),
            })
            all_rain_sums.append(rain_sum)
            if avg_max is not None:
                all_temp_maxes.append(avg_max)
            if avg_min is not None:
                all_temp_mins.append(avg_min)
            for c in codes:
                condition_counts[c] = condition_counts.get(c, 0) + 1

        if not yearly_summaries:
            return None

        yearly_summaries.sort(key=lambda x: x["year"])

        # Simple linear trend (slope) on rainfall across years, so the LLM
        # can narrate "rainfall has been rising/falling" rather than just
        # listing numbers.
        trend_direction = "stable"
        if len(all_rain_sums) >= 3:
            first_half = all_rain_sums[: len(all_rain_sums) // 2]
            second_half = all_rain_sums[len(all_rain_sums) // 2:]
            if sum(second_half) / len(second_half) > sum(first_half) / len(first_half) * 1.1:
                trend_direction = "increasing"
            elif sum(second_half) / len(second_half) < sum(first_half) / len(first_half) * 0.9:
                trend_direction = "decreasing"

        most_common_code = max(condition_counts, key=condition_counts.get) if condition_counts else 0

        month_name = date(2000, month, 1).strftime("%B")

        return {
            "location": location_name,
            "month": month_name,
            "years_covered": [s["year"] for s in yearly_summaries],
            "avg_total_rainfall_mm": round(sum(all_rain_sums) / len(all_rain_sums), 1) if all_rain_sums else None,
            "max_total_rainfall_mm": round(max(all_rain_sums), 1) if all_rain_sums else None,
            "min_total_rainfall_mm": round(min(all_rain_sums), 1) if all_rain_sums else None,
            "avg_temp_max": round(sum(all_temp_maxes) / len(all_temp_maxes), 1) if all_temp_maxes else None,
            "avg_temp_min": round(sum(all_temp_mins) / len(all_temp_mins), 1) if all_temp_mins else None,
            "typical_condition": WMO_CODE_MAP.get(most_common_code, "Variable"),
            "rainfall_trend": trend_direction,
            "yearly_breakdown": yearly_summaries,
            "summary": (
                f"Over {len(yearly_summaries)} years of data, {location_name} averages "
                f"{round(sum(all_rain_sums) / len(all_rain_sums), 1) if all_rain_sums else 'N/A'} mm of rain in "
                f"{month_name}, with rainfall {trend_direction} over that period."
            ),
        }


climate_trend_service = ClimateTrendService()
