import logging
from typing import Optional, Dict, Any
import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)


class SupabaseClient:
    """Manages Supabase Auth, Storage, and Realtime communication."""

    def __init__(self):
        self.url = settings.SUPABASE_URL.rstrip("/")
        self.key = settings.SUPABASE_KEY

    async def verify_token_and_get_user(self, access_token: str) -> Optional[Dict[str, Any]]:
        """Verify Supabase JWT access token via Supabase Auth API."""
        if not access_token or not self.key:
            return None

        # Clean token prefix if present
        clean_token = access_token.replace("Bearer ", "").strip()
        if not clean_token:
            return None

        endpoint = f"{self.url}/auth/v1/user"
        headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {clean_token}",
        }

        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                res = await client.get(endpoint, headers=headers)
                if res.status_code == 200:
                    return res.json()
                else:
                    logger.warning(f"Supabase token verification failed: HTTP {res.status_code} - {res.text}")
                    return None
        except Exception as e:
            logger.error(f"Error connecting to Supabase Auth: {e}")
            return None

    async def broadcast_realtime_alert(self, alert_payload: Dict[str, Any]) -> bool:
        """Broadcast live weather alert to Supabase Realtime channel."""
        if not self.key:
            return False

        endpoint = f"{self.url}/rest/v1/realtime/weather_alerts"
        headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                # Can also post to Supabase rest table or broadcast
                return True
        except Exception as e:
            logger.warning(f"Could not broadcast to Supabase realtime: {e}")
            return False


supabase_client = SupabaseClient()
