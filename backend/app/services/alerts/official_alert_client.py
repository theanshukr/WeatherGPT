"""
Official Alert Source Client — GDACS Global Disaster & Extreme Weather Feed + NDMA SACHET CAP.

Sources:
1. GDACS (Global Disaster Alert and Coordination System - UN OCHA / European Commission):
   - Fully open, live real-time XML/RSS feed for severe weather, tropical cyclones, floods,
     droughts, and earthquakes worldwide including India & South Asia.
   - Provides official multi-agency early warnings and impact assessments.
2. NDMA SACHET CAP Feed (India National Disaster Management Authority):
   - Official CAP 1.2 XML feed from C-DOT/NDMA. Activated whenever `OFFICIAL_ALERT_IDENTIFIER`
     is configured.

Both sources are normalized into `OfficialAlert` structures and merged seamlessly into
the alerting engine and WebSocket push poller.
"""

import logging
from typing import List, Optional
from xml.etree import ElementTree as ET
import httpx
from pydantic import BaseModel
from app.core.config import settings

logger = logging.getLogger(__name__)

CAP_NS = {"cap": "urn:oasis:names:tc:emergency:cap:1.2"}
GDACS_NS = {
    "gdacs": "http://www.gdacs.org",
    "geo": "http://www.w3.org/2003/01/geo/wgs84_pos#",
    "dc": "http://purl.org/dc/elements/1.1/",
}


class OfficialAlert(BaseModel):
    identifier: str
    sender: str  # e.g. "GDACS / UN OCHA", "IMD / NDMA"
    event_type: Optional[str] = None  # e.g. "Tropical Cyclone", "Flood", "Severe Weather"
    headline: str
    description: str
    severity: str  # "Severe", "Extreme", "Moderate", "Minor"
    urgency: str  # "Immediate", "Expected", "Future"
    area_description: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    effective: Optional[str] = None
    expires: Optional[str] = None
    source: str = "gdacs_live"


class OfficialAlertClient:
    """Fetches and normalizes official government and intergovernmental early warnings."""

    GDACS_FEED_URL = "https://www.gdacs.org/xml/rss.xml"
    NDMA_BASE_URL = "https://sachet.ndma.gov.in/cap_public_website/FetchXMLFile"

    def __init__(self):
        self.ndma_identifier = getattr(settings, "OFFICIAL_ALERT_IDENTIFIER", None)
        self._ndma_etag: Optional[str] = None
        self._cached_ndma_alerts: List[OfficialAlert] = []
        self._cached_gdacs_alerts: List[OfficialAlert] = []

    def is_configured(self) -> bool:
        """GDACS is fully open and active out-of-the-box."""
        return True

    def is_ndma_configured(self) -> bool:
        return bool(self.ndma_identifier)

    async def fetch_gdacs_alerts(self, country: Optional[str] = None) -> List[OfficialAlert]:
        """Fetch live alerts from GDACS (UN OCHA / EC Joint Research Centre)."""
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(self.GDACS_FEED_URL)
                if resp.status_code != 200:
                    logger.warning(f"GDACS RSS feed returned status {resp.status_code}")
                    return self._cached_gdacs_alerts

                alerts: List[OfficialAlert] = []
                root = ET.fromstring(resp.content)
                items = root.findall(".//item")

                for item in items:
                    try:
                        title = item.find("title").text if item.find("title") is not None else "Disaster Alert"
                        link = item.find("link").text if item.find("link") is not None else ""
                        desc = item.find("description").text if item.find("description") is not None else ""
                        pub_date = item.find("pubDate").text if item.find("pubDate") is not None else None

                        # Parse GDACS custom tags if available
                        event_type_tag = item.find("{http://www.gdacs.org}eventtype")
                        alert_level_tag = item.find("{http://www.gdacs.org}alertlevel")
                        country_tag = item.find("{http://www.gdacs.org}country")
                        event_id_tag = item.find("{http://www.gdacs.org}eventid")

                        lat_tag = item.find("{http://www.w3.org/2003/01/geo/wgs84_pos#}lat")
                        lon_tag = item.find("{http://www.w3.org/2003/01/geo/wgs84_pos#}long")

                        event_type_code = event_type_tag.text if event_type_tag is not None else "Weather"
                        alert_level = alert_level_tag.text if alert_level_tag is not None else "Green"
                        event_country = country_tag.text if country_tag is not None else "Global"
                        event_id = event_id_tag.text if event_id_tag is not None else link

                        # Filter by country if requested
                        if country and country.lower() not in (event_country or "").lower() and country.lower() not in title.lower():
                            continue

                        # Map GDACS alert levels (Red, Orange, Green) to CAP severity
                        if alert_level.lower() == "red":
                            severity = "Extreme"
                        elif alert_level.lower() == "orange":
                            severity = "Severe"
                        else:
                            severity = "Moderate"

                        event_type_names = {
                            "TC": "Tropical Cyclone",
                            "FL": "Flood",
                            "DR": "Drought",
                            "EQ": "Earthquake",
                            "VO": "Volcano",
                            "WF": "Wildfire",
                        }
                        event_name = event_type_names.get(event_type_code, event_type_code)

                        lat_val = float(lat_tag.text) if lat_tag is not None and lat_tag.text else None
                        lon_val = float(lon_tag.text) if lon_tag is not None and lon_tag.text else None

                        alerts.append(
                            OfficialAlert(
                                identifier=f"GDACS-{event_id}",
                                sender="GDACS (UN OCHA / EC JRC)",
                                event_type=event_name,
                                headline=title,
                                description=desc or title,
                                severity=severity,
                                urgency="Immediate" if severity in ("Extreme", "Severe") else "Expected",
                                area_description=event_country or "Global",
                                latitude=lat_val,
                                longitude=lon_val,
                                effective=pub_date,
                                source="gdacs_official",
                            )
                        )
                    except Exception as item_err:
                        logger.debug(f"Error parsing GDACS item: {item_err}")
                        continue

                self._cached_gdacs_alerts = alerts
                return alerts

        except Exception as e:
            logger.error(f"GDACS RSS fetch failed: {e}")
            return self._cached_gdacs_alerts

    async def fetch_ndma_alerts(self) -> List[OfficialAlert]:
        """Fetch NDMA SACHET CAP feed if configured with agency identifier."""
        if not self.is_ndma_configured():
            return []

        headers = {}
        if self._ndma_etag:
            headers["If-None-Match"] = self._ndma_etag

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(
                    self.NDMA_BASE_URL,
                    params={"identifier": self.ndma_identifier},
                    headers=headers,
                )
                if resp.status_code == 304:
                    return self._cached_ndma_alerts

                if resp.status_code != 200:
                    logger.error(f"NDMA CAP feed returned {resp.status_code}")
                    return self._cached_ndma_alerts

                self._ndma_etag = resp.headers.get("ETag", self._ndma_etag)
                self._cached_ndma_alerts = self._parse_ndma_cap_xml(resp.text)
                return self._cached_ndma_alerts

        except Exception as e:
            logger.error(f"NDMA CAP feed fetch failed: {e}")
            return self._cached_ndma_alerts

    def _parse_ndma_cap_xml(self, xml_text: str) -> List[OfficialAlert]:
        alerts: List[OfficialAlert] = []
        try:
            root = ET.fromstring(xml_text)
            alert_elements = root.findall(".//cap:alert", CAP_NS) or [root]

            for alert_el in alert_elements:
                identifier = self._text(alert_el, "cap:identifier") or "unknown"
                sender = self._text(alert_el, "cap:sender") or "NDMA / IMD"

                for info_el in alert_el.findall("cap:info", CAP_NS):
                    try:
                        area_el = info_el.find("cap:area", CAP_NS)
                        area_desc = self._text(area_el, "cap:areaDesc") if area_el is not None else "India"

                        alerts.append(
                            OfficialAlert(
                                identifier=identifier,
                                sender=sender,
                                event_type=self._text(info_el, "cap:event"),
                                headline=self._text(info_el, "cap:headline") or "Severe Weather Alert",
                                description=self._text(info_el, "cap:description") or "",
                                severity=self._text(info_el, "cap:severity") or "Moderate",
                                urgency=self._text(info_el, "cap:urgency") or "Expected",
                                area_description=area_desc or "India",
                                effective=self._text(info_el, "cap:effective"),
                                expires=self._text(info_el, "cap:expires"),
                                source="ndma_sachet_cap",
                            )
                        )
                    except Exception as e:
                        logger.debug(f"Skipping malformed CAP <info> block: {e}")
                        continue
        except ET.ParseError as e:
            logger.error(f"Failed to parse CAP XML: {e}")

        return alerts

    async def fetch_official_alerts(self, country: Optional[str] = None) -> List[OfficialAlert]:
        """Fetch and aggregate official alerts from all configured live sources."""
        import asyncio

        gdacs_res, ndma_res = await asyncio.gather(
            self.fetch_gdacs_alerts(country=country),
            self.fetch_ndma_alerts(),
            return_exceptions=True,
        )

        all_alerts: List[OfficialAlert] = []
        if isinstance(gdacs_res, list):
            all_alerts.extend(gdacs_res)
        if isinstance(ndma_res, list):
            all_alerts.extend(ndma_res)

        return all_alerts

    @staticmethod
    def _text(el, path: str) -> Optional[str]:
        if el is None:
            return None
        found = el.find(path, CAP_NS)
        return found.text.strip() if found is not None and found.text else None


official_alert_client = OfficialAlertClient()
