"""
LLM-based Query Understanding Engine.

This is the PRIMARY intent/entity extractor for WeatherGPT, using Gemini's
structured JSON output. It replaces regex/keyword matching as the main path
per the SIH requirement for an "AI/LLM-based query understanding engine."

`app.services.weather.query_parser.QueryUnderstandingService` (the original
regex-based parser) is kept and used as a FAST-PATH FALLBACK:
- when GEMINI_API_KEY isn't configured,
- when the LLM call errors or times out,
- or when latency matters more than nuance (not currently invoked that way,
  but the option is there).

Keeping the fallback is intentional: it costs nothing to keep, gives the
system graceful degradation instead of a hard failure, and the regex parser
already has decent multilingual keyword coverage worth reusing rather than
discarding.
"""

import json
import logging
from typing import Optional
from app.services.llm.context_manager import SessionContext
from app.services.weather.query_parser import ParsedQuery, query_parser
from app.core.config import settings

logger = logging.getLogger(__name__)

# JSON schema Gemini must fill in. Kept intentionally close to ParsedQuery's
# fields so the LLM output maps onto the existing schema with no glue code
# needed downstream (advisory engines, prompt assembly, etc. don't change).
RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "primary_intent": {
            "type": "string",
            "enum": [
                "GREETING",
                "CURRENT_WEATHER",
                "TOMORROW_FORECAST",
                "DAY_AFTER_TOMORROW_FORECAST",
                "MULTI_DAY_FORECAST",
                "HOURLY_TIMELINE",
                "RAIN_CHECK",
                "TEMPERATURE_QUERY",
                "TRAVEL_PLANNING",
                "FARMER_ASSISTANCE",
                "WEATHER_WARNING",
                "URBAN_ADVISORY",
                "CLIMATE_TREND",
            ],
        },
        "secondary_intents": {
            "type": "array",
            "items": {"type": "string"},
        },
        "location": {
            "type": "string",
            "description": "The city/place the user is asking about, in English. "
            "Null if no location was mentioned or implied AND none can be "
            "inherited from prior conversation context.",
        },
        "time_range": {
            "type": "string",
            "enum": [
                "current", "today", "tomorrow", "day_after_tomorrow",
                "morning", "afternoon", "evening", "night",
                "weekend", "7_days", "hourly",
            ],
        },
        "activity": {
            "type": "string",
            "enum": [
                "driving", "biking", "travel", "spraying", "irrigation",
                "harvesting", "outdoor",
            ],
        },
        "crop": {
            "type": "string",
            "enum": [
                "wheat", "rice", "mustard", "cotton", "sugarcane",
                "potato", "maize", "vegetables",
            ],
        },
        "metrics_requested": {
            "type": "array",
            "items": {
                "type": "string",
                "enum": ["rain", "temperature", "wind", "humidity", "alert"],
            },
        },
        "language_hint": {
            "type": "string",
            "description": "BCP-47 short code for the language/script: en, hi, bn, ta, te, gu, kn, pa, ml, mr, od.",
        },
        "target_month": {
            "type": "integer",
            "description": "1-12 for the calendar month for historical climate trend.",
        },
        "years_back": {
            "type": "integer",
            "description": "Number of years back for climate trend, if specified (e.g. 10).",
        },
    },
    "required": ["primary_intent", "language_hint"],
}

SYSTEM_PROMPT = """You are the query-understanding module for WeatherGPT, an \
Indian multilingual weather assistant. Given a user's message (and optionally \
recent conversation context), extract structured intent and entities.

Rules:
- If the user is inheriting context from a previous turn (e.g. "what about \
tomorrow?", "aur udhar?"), use the provided context to fill in location/time \
sensibly rather than leaving them null.
- location must be a real place name in English (transliterate/translate if \
the user wrote it in Hindi/another script or language), or null if genuinely \
unspecified and not inferable from context. Do NOT default to any specific \
city — null is correct when you don't know.
- Only mark primary_intent as GREETING if the message is a pure greeting with \
no weather/travel/farming content at all.
- Use CLIMATE_TREND when the user asks about historical/average/typical \
weather for a specific month across past years (e.g. "average rainfall in \
Delhi in August", "how has Mumbai's monsoon changed over the years"), as \
opposed to a live forecast. Set target_month (1-12) and years_back \
(if a number of years was mentioned) for this intent.
- secondary_intents can be empty.
- Respond with ONLY the JSON object, matching the schema exactly."""


class LLMQueryUnderstandingEngine:
    """Primary (LLM-based) query understanding path, with automatic fallback
    to the regex-based QueryUnderstandingService."""

    def __init__(self):
        self._client = None
        raw_model = settings.GEMINI_MODEL or "gemini-2.0-flash"
        if "3.5" in raw_model or "3.6" in raw_model or "preview" in raw_model:
            self._model_name = "gemini-2.0-flash"
        else:
            self._model_name = raw_model

    def _get_client(self):
        """Lazily create the Gemini client. Reused across calls (not
        recreated per request) to avoid the per-request client overhead
        flagged elsewhere in this codebase."""
        if self._client is None and settings.GEMINI_API_KEY:
            from google import genai
            self._client = genai.Client(api_key=settings.GEMINI_API_KEY)
        return self._client

    async def parse_query(
        self, message: str, context: Optional[SessionContext] = None
    ) -> ParsedQuery:
        """Extract structured intent/entities using Gemini. Falls back to
        the regex parser on any failure (missing key, API error, malformed
        JSON, timeout) so a single LLM hiccup never breaks the whole chat
        turn."""
        client = self._get_client()
        if client is None:
            logger.info("No Gemini client available; using regex query parser fallback.")
            return query_parser.parse_query(message, context=context)

        try:
            import asyncio
            from google.genai import types

            context_block = "None"
            if context and (context.active_location or context.history):
                loc = context.active_location.name if context.active_location else "unknown"
                recent = "; ".join(
                    f"{h['role']}: {h['text']}" for h in (context.history[-3:] if context.history else [])
                )
                context_block = f"Last known location: {loc}\nRecent turns: {recent or 'none'}"

            prompt = f"[CONTEXT]\n{context_block}\n\n[USER MESSAGE]\n{message}"

            response = await asyncio.to_thread(
                client.models.generate_content,
                model=self._model_name,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    temperature=0.1,  # low temperature: this is extraction, not creative writing
                    response_mime_type="application/json",
                    response_schema=RESPONSE_SCHEMA,
                ),
            )

            if not response or not response.text:
                raise ValueError("Empty response from Gemini query understanding call")

            data = json.loads(response.text)

            # Fill in location from context if the LLM left it null but we
            # have an active location from a prior turn (belt-and-braces —
            # the prompt already asks for this, but don't rely solely on
            # the model following instructions).
            location = data.get("location")
            if not location and context and context.active_location:
                location = context.active_location.name

            return ParsedQuery(
                original_message=message.strip(),
                primary_intent=data.get("primary_intent", "CURRENT_WEATHER"),
                secondary_intents=data.get("secondary_intents") or [],
                location=location,
                time_range=data.get("time_range", "current"),
                activity=data.get("activity"),
                crop=data.get("crop") or "general",
                metrics_requested=data.get("metrics_requested") or [],
                language_hint=data.get("language_hint", "en"),
                target_month=data.get("target_month"),
                years_back=data.get("years_back"),
            )

        except Exception as e:
            logger.warning(
                f"LLM query understanding failed ({type(e).__name__}: {e}); "
                f"falling back to regex parser."
            )
            return query_parser.parse_query(message, context=context)


llm_query_engine = LLMQueryUnderstandingEngine()
