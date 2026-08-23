"""
Background Alert Poller.

Periodically checks for severe weather alerts and pushes them to all
connected WebSocket clients. This is what actually connects
`ConnectionManager.broadcast()` (previously dead code — defined but never
called anywhere) to a real trigger.

Two sources are merged:
1. Official government alerts via `official_alert_client` (NDMA SACHET CAP
   feed) — real source, currently returns [] until OFFICIAL_ALERT_IDENTIFIER
   is configured (see that module for why).
2. Computed forecast-threshold alerts for a small set of watched cities,
   via the existing weather_processor risk engine — always available,
   clearly labeled as "computed_forecast_threshold" so it's never confused
   with an official warning.

Only SEVERE and HIGH risk alerts are broadcast, to avoid spamming
connected clients with routine MODERATE/LOW items.
"""

import asyncio
import logging
from typing import Optional, Set, Tuple
from app.core.config import settings
from app.services.alerts.official_alert_client import official_alert_client
from app.services.weather.open_meteo_service import weather_service
from app.services.weather.weather_processor import weather_processor

logger = logging.getLogger(__name__)

# Cities polled for computed severe-weather alerts. This is a placeholder
# watch list — in a fuller build this would come from active user sessions'
# saved/current locations instead of a fixed list. Kept small and India-wide
# to bound the number of Open-Meteo calls the poller makes.
WATCHED_CITIES: Tuple[Tuple[str, float, float], ...] = (
    ("New Delhi, India", 28.6139, 77.2090),
    ("Mumbai, India", 19.0760, 72.8777),
    ("Kolkata, India", 22.5726, 88.3639),
    ("Chennai, India", 13.0827, 80.2707),
)

_BROADCASTABLE_RISK_LEVELS = {"HIGH", "SEVERE"}


class AlertPoller:
    def __init__(self):
        self._task: Optional[asyncio.Task] = None
        # Track (source, identifier/headline) pairs already broadcast this
        # run, so a restart doesn't re-spam clients but a *new* alert for
        # an already-seen city still goes out.
        self._seen: Set[str] = set()

    async def _poll_once(self, broadcast_fn):
        # 1. Official source (currently a no-op until configured — see
        # official_alert_client.py)
        try:
            official = await official_alert_client.fetch_official_alerts()
            for alert in official:
                if alert.severity not in ("Severe", "Extreme"):
                    continue
                key = f"official:{alert.identifier}"
                if key in self._seen:
                    continue
                self._seen.add(key)
                await broadcast_fn({
                    "type": "severe_weather_alert",
                    "source": alert.source,
                    "sender": alert.sender,
                    "risk_level": "SEVERE" if alert.severity == "Extreme" else "HIGH",
                    "headline": alert.headline,
                    "description": alert.description,
                    "area": alert.area_description,
                    "expires": alert.expires,
                })
        except Exception as e:
            logger.error(f"Official alert poll failed: {e}")

        # 2. Computed threshold alerts for watched cities
        for city_name, lat, lon in WATCHED_CITIES:
            try:
                raw = await weather_service.get_comprehensive_weather(lat, lon, city_name)
                if not raw:
                    continue
                snapshot = weather_processor.process(raw, city_name)
                for alert in snapshot.alerts:
                    if alert.risk_level not in _BROADCASTABLE_RISK_LEVELS:
                        continue
                    key = f"computed:{city_name}:{alert.headline}"
                    if key in self._seen:
                        continue
                    self._seen.add(key)
                    await broadcast_fn({
                        "type": "severe_weather_alert",
                        "source": alert.source,
                        "sender": None,
                        "risk_level": alert.risk_level,
                        "headline": alert.headline,
                        "description": alert.description,
                        "advisory": alert.advisory,
                        "area": city_name,
                    })
            except Exception as e:
                logger.error(f"Computed alert poll failed for {city_name}: {e}")

    async def _run_loop(self, broadcast_fn):
        interval = settings.ALERT_POLL_INTERVAL_SECONDS
        logger.info(f"Alert poller started (interval={interval}s).")
        while True:
            try:
                await self._poll_once(broadcast_fn)
            except Exception as e:
                logger.error(f"Alert poller iteration failed: {e}")
            await asyncio.sleep(interval)

    def start(self, broadcast_fn):
        if self._task is None:
            self._task = asyncio.create_task(self._run_loop(broadcast_fn))

    def stop(self):
        if self._task is not None:
            self._task.cancel()
            self._task = None


alert_poller = AlertPoller()
