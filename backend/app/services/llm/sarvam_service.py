import logging
import httpx
import uuid
from typing import Optional
from app.services.llm.base import BaseLLMService
from app.schemas.chat import ChatMessageRequest, ChatMessageResponse, WeatherCardData
from app.services.weather.open_meteo_service import weather_service
from app.core.config import settings

logger = logging.getLogger(__name__)


class SarvamLLMService(BaseLLMService):
    """Sarvam AI integration for specialized Indian language / Indic chat."""

    def __init__(self):
        self.api_key = settings.SARVAM_API_KEY
        self.base_url = "https://api.sarvam.ai/v1"

    async def process_chat(self, request: ChatMessageRequest) -> ChatMessageResponse:
        from app.services.llm.gemini_service import GeminiLLMService
        return await GeminiLLMService().process_chat(request)
