"""
Numerical Weather Prediction (NWP) Service.

Directly queries and compares raw numerical weather prediction models:
1. NOAA GFS (Global Forecast System - 0.25°/0.13° global resolution)
2. ECMWF IFS (European Centre for Medium-Range Weather Forecasts - high resolution)
3. DWD ICON (Deutscher Wetterdienst ICON - WRF-grade global & mesoscale model)

Provides:
- Raw model retrieval (per model)
- Multi-model intercomparison & ensemble consensus analysis
- Model spread (temperature/precipitation/wind standard deviation)
- Forecast Confidence Score (0-100%) based on inter-model agreement
- Divergence detection (alerts when major models contradict each other)
"""

import json
import logging
import math
from typing import Dict, Any, List, Optional, Tuple
import httpx
from pydantic import BaseModel
from app.core.config import settings
from app.core.redis import redis_manager

logger = logging.getLogger(__name__)


class NWPModelSnapshot(BaseModel):
    model_name: str
    model_provider: str
    resolution: str
    current_temp: float
    current_humidity: float
    current_wind_speed: float
    total_precip_24h: float
    max_temp_24h: float
    min_temp_24h: float
    hourly_temperatures: List[float]
    hourly_precipitations: List[float]
    hourly_timestamps: List[str]


class NWPComparisonResult(BaseModel):
    location: str
    latitude: float
    longitude: float
    models_evaluated: List[str]
    model_count: int
    ensemble_mean_temp_current: float
    temperature_spread_c: float
    ensemble_24h_precip_mean_mm: float
    precip_agreement_pct: float
    wind_spread_kmh: float
    forecast_confidence_score: int  # 0-100%
    confidence_level: str  # "VERY_HIGH", "HIGH", "MODERATE", "LOW"
    model_divergence_note: Optional[str] = None
    model_data: Dict[str, NWPModelSnapshot]


class NWPService:
    GFS_URL = "https://api.open-meteo.com/v1/gfs"
    ECMWF_URL = "https://api.open-meteo.com/v1/ecmwf"
    ICON_URL = "https://api.open-meteo.com/v1/dwd-icon"

    async def fetch_model_raw(
        self,
        endpoint_url: str,
        model_name: str,
        lat: float,
        lon: float,
    ) -> Optional[Dict[str, Any]]:
        """Fetch raw model output from a dedicated NWP endpoint."""
        cache_key = f"weathergpt:nwp:{model_name.lower()}:{round(lat, 2)}:{round(lon, 2)}"
        try:
            cached = await redis_manager.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(
                    endpoint_url,
                    params={
                        "latitude": lat,
                        "longitude": lon,
                        "current": "temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,surface_pressure",
                        "hourly": "temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m",
                        "forecast_days": 3,
                        "timezone": "auto",
                    },
                )
                if resp.status_code == 200:
                    data = resp.json()
                    try:
                        await redis_manager.set(cache_key, json.dumps(data), expire=300)  # 5 min TTL
                    except Exception:
                        pass
                    return data
                logger.warning(f"NWP endpoint {endpoint_url} returned status {resp.status_code}")
        except Exception as e:
            logger.error(f"Failed to fetch raw NWP model {model_name}: {e}")
        return None

    def _parse_model_snapshot(
        self,
        model_name: str,
        provider: str,
        resolution: str,
        raw_json: Dict[str, Any],
    ) -> Optional[NWPModelSnapshot]:
        """Convert raw NWP model response into structured NWPModelSnapshot."""
        try:
            current = raw_json.get("current") or {}
            hourly = raw_json.get("hourly") or {}

            h_temps = [float(t) for t in (hourly.get("temperature_2m", []) or [])[:24]]
            h_precip = [float(p) for p in (hourly.get("precipitation", []) or [])[:24]]
            h_hum = [float(h) for h in (hourly.get("relative_humidity_2m", []) or [])[:24]]
            h_wind = [float(w) for w in (hourly.get("wind_speed_10m", []) or [])[:24]]
            h_times = (hourly.get("time", []) or [])[:24]

            cur_temp = float(current.get("temperature_2m")) if current.get("temperature_2m") is not None else (h_temps[0] if h_temps else 0.0)
            cur_hum = float(current.get("relative_humidity_2m")) if current.get("relative_humidity_2m") is not None else (h_hum[0] if h_hum else 50.0)
            cur_wind = float(current.get("wind_speed_10m")) if current.get("wind_speed_10m") is not None else (h_wind[0] if h_wind else 0.0)

            total_precip_24h = round(sum(h_precip), 2) if h_precip else 0.0
            max_temp = round(max(h_temps), 1) if h_temps else cur_temp
            min_temp = round(min(h_temps), 1) if h_temps else cur_temp

            return NWPModelSnapshot(
                model_name=model_name,
                model_provider=provider,
                resolution=resolution,
                current_temp=round(cur_temp, 1),
                current_humidity=round(cur_hum, 1),
                current_wind_speed=round(cur_wind, 1),
                total_precip_24h=total_precip_24h,
                max_temp_24h=max_temp,
                min_temp_24h=min_temp,
                hourly_temperatures=h_temps,
                hourly_precipitations=h_precip,
                hourly_timestamps=h_times,
            )
        except Exception as e:
            logger.error(f"Error parsing NWP snapshot for {model_name}: {e}")
            return None

    async def get_multi_model_comparison(
        self,
        lat: float,
        lon: float,
        location_name: str = "Location",
    ) -> Optional[NWPComparisonResult]:
        """
        Runs concurrent raw model fetches across NOAA GFS, ECMWF IFS, and DWD ICON,
        and computes inter-model consensus, spread, and confidence metrics.
        """
        import asyncio

        # Concurrently fetch raw NWP models
        gfs_raw, ecmwf_raw, icon_raw = await asyncio.gather(
            self.fetch_model_raw(self.GFS_URL, "GFS", lat, lon),
            self.fetch_model_raw(self.ECMWF_URL, "ECMWF", lat, lon),
            self.fetch_model_raw(self.ICON_URL, "ICON", lat, lon),
            return_exceptions=True,
        )

        model_snapshots: Dict[str, NWPModelSnapshot] = {}

        if isinstance(gfs_raw, dict):
            s = self._parse_model_snapshot("NOAA GFS", "NOAA / NCEP (USA)", "0.25° (~27 km)", gfs_raw)
            if s:
                model_snapshots["GFS"] = s

        if isinstance(ecmwf_raw, dict):
            s = self._parse_model_snapshot("ECMWF IFS", "European Centre for Medium-Range Weather Forecasts", "0.25° / 0.1° (~11 km)", ecmwf_raw)
            if s:
                model_snapshots["ECMWF"] = s

        if isinstance(icon_raw, dict):
            s = self._parse_model_snapshot("DWD ICON", "Deutscher Wetterdienst (Germany)", "0.125° / Mesoscale (~13 km)", icon_raw)
            if s:
                model_snapshots["ICON"] = s

        if not model_snapshots:
            return None

        # Compute multi-model statistics
        temps = [m.current_temp for m in model_snapshots.values()]
        precips = [m.total_precip_24h for m in model_snapshots.values()]
        winds = [m.current_wind_speed for m in model_snapshots.values()]

        mean_temp = round(sum(temps) / len(temps), 1)
        mean_precip = round(sum(precips) / len(precips), 2)

        # Temperature Spread (Standard Deviation or max-min)
        if len(temps) > 1:
            variance = sum((t - mean_temp) ** 2 for t in temps) / (len(temps) - 1)
            temp_std = math.sqrt(variance)
            temp_spread = round(max(temps) - min(temps), 1)
            wind_spread = round(max(winds) - min(winds), 1)
        else:
            temp_std = 0.0
            temp_spread = 0.0
            wind_spread = 0.0

        # Precipitation Agreement (Count of models agreeing on rain vs no-rain)
        rain_models = sum(1 for p in precips if p >= 0.5)
        no_rain_models = sum(1 for p in precips if p < 0.5)
        majority_count = max(rain_models, no_rain_models)
        precip_agreement_pct = round((majority_count / len(precips)) * 100.0, 1)

        # Calculate Confidence Score (0 - 100)
        # Deductions:
        # - Temp spread > 1.5°C reduces score
        # - Precip disagreement reduces score
        # - Wind spread > 10 km/h reduces score
        penalty = (temp_spread * 8.0) + ((100.0 - precip_agreement_pct) * 0.4) + (wind_spread * 0.5)
        confidence_score = max(25, min(99, int(round(100.0 - penalty))))

        if confidence_score >= 85:
            confidence_level = "VERY_HIGH"
        elif confidence_score >= 70:
            confidence_level = "HIGH"
        elif confidence_score >= 50:
            confidence_level = "MODERATE"
        else:
            confidence_level = "LOW"

        # Check for model divergence note
        divergence_notes = []
        if temp_spread >= 2.5:
            divergence_notes.append(f"Temperature spread is {temp_spread}°C between models ({min(temps)}°C to {max(temps)}°C).")
        if rain_models > 0 and no_rain_models > 0:
            rainy = [k for k, v in model_snapshots.items() if v.total_precip_24h >= 0.5]
            dry = [k for k, v in model_snapshots.items() if v.total_precip_24h < 0.5]
            divergence_notes.append(f"Precipitation divergence: {', '.join(rainy)} predicts rain while {', '.join(dry)} forecasts dry conditions.")

        divergence_note = " ".join(divergence_notes) if divergence_notes else None

        return NWPComparisonResult(
            location=location_name,
            latitude=lat,
            longitude=lon,
            models_evaluated=list(model_snapshots.keys()),
            model_count=len(model_snapshots),
            ensemble_mean_temp_current=mean_temp,
            temperature_spread_c=temp_spread,
            ensemble_24h_precip_mean_mm=mean_precip,
            precip_agreement_pct=precip_agreement_pct,
            wind_spread_kmh=wind_spread,
            forecast_confidence_score=confidence_score,
            confidence_level=confidence_level,
            model_divergence_note=divergence_note,
            model_data=model_snapshots,
        )


nwp_service = NWPService()
