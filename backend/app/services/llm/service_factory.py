import logging
from app.services.llm.base import BaseLLMService
from app.services.llm.gemini_service import GeminiLLMService
from app.services.llm.sarvam_service import SarvamLLMService
from app.core.config import settings

logger = logging.getLogger(__name__)


def get_llm_service() -> BaseLLMService:
    if settings.GEMINI_API_KEY:
        logger.info("Using Gemini LLM Service (Pure Real AI)")
        return GeminiLLMService()
    elif settings.SARVAM_API_KEY:
        logger.info("Using Sarvam LLM Service")
        return SarvamLLMService()
    else:
        raise RuntimeError("No valid LLM API key configured in .env (GEMINI_API_KEY is required).")
