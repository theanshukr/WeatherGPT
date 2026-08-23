"""
Official Alert Source Client — NDMA SACHET CAP feed.

IMPORTANT / HONEST STATUS:
NDMA's SACHET portal exposes a CAP (Common Alerting Protocol) XML feed at:
    GET https://sachet.ndma.gov.in/cap_public_website/FetchXMLFile?identifier=<AGENCY_ID>
using ETag-based caching (see their published Integration Guide for
Agencies). HOWEVER, the `identifier` parameter is agency-specific and is
NOT published anywhere publicly — it appears to require registering as a
"consuming agency" with NDMA/C-DOT to obtain one. As of writing, no public,
self-serve identifier could be found.

Rather than fake this integration (e.g. by silently falling back to the
locally-computed thresholds and calling them "IMD alerts"), this client is
built against the REAL documented protocol and ships DISABLED until a real
identifier is configured (OFFICIAL_ALERT_IDENTIFIER in .env). This means:

  - If you obtain an identifier (by contacting NDMA/C-DOT, or if a public
    one surfaces later), set OFFICIAL_ALERT_IDENTIFIER and this starts
    working with no other code changes.
  - Until then, `fetch_official_alerts()` returns an empty list and logs
    once that the official source is not configured — the system falls
    back to (clearly-labeled) computed threshold alerts only, which is the
    honest current state of this feature.

This keeps the architecture ready for the real integration without
pretending it's already connected.
"""

import logging
from typing import List, Optional
from xml.etree import ElementTree as ET
import httpx
from pydantic import BaseModel
from app.core.config import settings

logger = logging.getLogger(__name__)

CAP_NS = {"cap": "urn:oasis:names:tc:emergency:cap:1.2"}


class OfficialAlert(BaseModel):
    identifier: str
    sender: str  # e.g. "IMD", "CWC", "GSI" via NDMA SACHET
    headline: str
    description: str
    severity: str  # CAP: Minor, Moderate, Severe, Extreme
    urgency: str  # CAP: Immediate, Expected, Future, Past
    area_description: str
    effective: Optional[str] = None
    expires: Optional[str] = None
    source: str = "ndma_sachet_cap"


class OfficialAlertClient:
    """Fetches and parses NDMA SACHET's CAP XML feed, with the ETag caching
    their integration guide requires. No-ops safely if not configured."""

    BASE_URL = "https://sachet.ndma.gov.in/cap_public_website/FetchXMLFile"

    def __init__(self):
        self.identifier = getattr(settings, "OFFICIAL_ALERT_IDENTIFIER", None)
        self._etag: Optional[str] = None
        self._cached_alerts: List[OfficialAlert] = []
        self._warned_not_configured = False

    def is_configured(self) -> bool:
        return bool(self.identifier)

    async def fetch_official_alerts(self) -> List[OfficialAlert]:
        """Returns official government alerts, or an empty list if the
        feed isn't configured / unreachable. Never raises — a failure here
        should never take down the rest of the alert pipeline."""
        if not self.is_configured():
            if not self._warned_not_configured:
                logger.warning(
                    "OFFICIAL_ALERT_IDENTIFIER not set — no NDMA/IMD official "
                    "alert source is connected. Falling back to computed "
                    "forecast-threshold alerts only. See "
                    "official_alert_client.py for how to enable this."
                )
                self._warned_not_configured = True
            return []

        headers = {}
        if self._etag:
            headers["If-None-Match"] = self._etag

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(
                    self.BASE_URL,
                    params={"identifier": self.identifier},
                    headers=headers,
                )
                if resp.status_code == 304:
                    # Unchanged — use cache, per NDMA's required behaviour.
                    return self._cached_alerts

                if resp.status_code != 200:
                    logger.error(f"NDMA CAP feed returned {resp.status_code}")
                    return self._cached_alerts

                self._etag = resp.headers.get("ETag", self._etag)
                self._cached_alerts = self._parse_cap_xml(resp.text)
                return self._cached_alerts

        except Exception as e:
            logger.error(f"NDMA CAP feed fetch failed: {e}")
            return self._cached_alerts  # serve stale cache rather than nothing

    def _parse_cap_xml(self, xml_text: str) -> List[OfficialAlert]:
        """Parse CAP 1.2 XML into OfficialAlert objects. Tolerant of
        multiple <alert> or <info> blocks; skips anything malformed rather
        than failing the whole batch."""
        alerts: List[OfficialAlert] = []
        try:
            root = ET.fromstring(xml_text)
            alert_elements = root.findall(".//cap:alert", CAP_NS) or [root]

            for alert_el in alert_elements:
                identifier = self._text(alert_el, "cap:identifier") or "unknown"
                sender = self._text(alert_el, "cap:sender") or "NDMA"

                for info_el in alert_el.findall("cap:info", CAP_NS):
                    try:
                        area_el = info_el.find("cap:area", CAP_NS)
                        area_desc = self._text(area_el, "cap:areaDesc") if area_el is not None else "India"

                        alerts.append(OfficialAlert(
                            identifier=identifier,
                            sender=sender,
                            headline=self._text(info_el, "cap:headline") or "Weather Alert",
                            description=self._text(info_el, "cap:description") or "",
                            severity=self._text(info_el, "cap:severity") or "Moderate",
                            urgency=self._text(info_el, "cap:urgency") or "Expected",
                            area_description=area_desc or "India",
                            effective=self._text(info_el, "cap:effective"),
                            expires=self._text(info_el, "cap:expires"),
                        ))
                    except Exception as e:
                        logger.debug(f"Skipping malformed CAP <info> block: {e}")
                        continue

        except ET.ParseError as e:
            logger.error(f"Failed to parse CAP XML: {e}")

        return alerts

    @staticmethod
    def _text(el, path: str) -> Optional[str]:
        if el is None:
            return None
        found = el.find(path, CAP_NS)
        return found.text.strip() if found is not None and found.text else None


official_alert_client = OfficialAlertClient()
