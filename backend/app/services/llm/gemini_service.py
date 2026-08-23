import logging
import uuid
import json
import asyncio
from datetime import date
from fastapi import HTTPException
from typing import Optional, List
from app.services.llm.base import BaseLLMService
from app.schemas.chat import (
    ChatMessageRequest,
    ChatMessageResponse,
    WeatherCardData,
    TravelAssessmentData,
    FarmingAdvisoryData,
    UrbanAdvisoryData,
    ClimateTrendData,
    PersonaConfirmationDTO,
)
from app.services.weather.open_meteo_service import weather_service
from app.services.llm.query_understanding_engine import llm_query_engine
from app.services.weather.weather_processor import weather_processor, WeatherFactSnapshot
from app.services.llm.context_manager import context_manager
from app.services.llm.tool_registry import tool_registry
from app.services.advisory.travel_engine import travel_engine
from app.services.advisory.farming_engine import farming_engine
from app.services.advisory.urban_engine import urban_engine
from app.services.weather.climate_trend_service import climate_trend_service
from app.services.personalization.persona_engine import persona_engine
from app.core.config import settings
from google import genai
from google.genai import types

logger = logging.getLogger(__name__)


class GeminiLLMService(BaseLLMService):
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.model_name = settings.GEMINI_MODEL
        self.client = None
        if self.api_key:
            try:
                self.client = genai.Client(api_key=self.api_key)
            except Exception as e:
                logger.error(f"Failed to initialize Gemini client: {e}")

    async def process_chat(self, request: ChatMessageRequest) -> ChatMessageResponse:
        session_id = request.session_id or str(uuid.uuid4())
        user_id = request.user_id or session_id

        # 1. Retrieve Active Session Context
        ctx = await context_manager.get_context(session_id)

        # 2. Process Personalization & Behavioral Signals
        personalization_ctx, confirmation_suggestion = await persona_engine.process_turn(
            user_id=user_id,
            message=request.message,
            explicit_session_persona=request.persona,
        )

        # 3. Multi-Intent & Contextual Entity Understanding (LLM-based, with
        # automatic regex fallback inside llm_query_engine if Gemini fails)
        parsed = await llm_query_engine.parse_query(request.message, context=ctx)
        # Track whether we're guessing the location vs. it being genuinely
        # known, so the LLM response prompt can be honest about it (e.g. ask
        # for clarification) instead of silently answering for the wrong
        # city as the old regex parser used to.
        location_was_defaulted = False
        if parsed.location:
            target_city = parsed.location
        elif ctx.active_location:
            target_city = ctx.active_location.name
        else:
            target_city = "New Delhi"
            location_was_defaulted = True

        # 4. Geocode location & Deterministic Data Retrieval (Skip for pure greetings)
        tools_called: List[str] = ["query_understanding"]
        lat = request.latitude or (ctx.active_location.latitude if ctx.active_location else 28.6139)
        lon = request.longitude or (ctx.active_location.longitude if ctx.active_location else 77.2090)
        loc_name = target_city
        card_data = None
        snapshot = None

        if parsed.primary_intent != "GREETING":
            geocoded = await weather_service.geocode(target_city)
            if geocoded:
                lat, lon, loc_name = geocoded

            tools_called.extend(["get_current_weather", "get_multi_day_forecast"])
            raw_weather = await weather_service.get_comprehensive_weather(lat, lon, loc_name)
            snapshot = weather_processor.process(raw_weather or {}, loc_name)

            card_data = WeatherCardData(
                location=loc_name,
                temperature=snapshot.current_temp,
                condition=snapshot.current_condition,
                weather_code=(raw_weather or {}).get("current", {}).get("weather_code", 0),
                humidity=snapshot.current_humidity,
                wind_speed=snapshot.current_wind_kmh,
                precipitation=snapshot.current_precipitation_mm,
            )

        effective_persona = personalization_ctx.active_persona
        active_lang = parsed.language_hint if parsed.language_hint != "en" else (request.language or ctx.language or "en")

        travel_assessment_data: Optional[TravelAssessmentData] = None
        farming_advisory_data: Optional[FarmingAdvisoryData] = None
        urban_advisory_data: Optional[UrbanAdvisoryData] = None
        climate_trend_data: Optional[ClimateTrendData] = None
        risk_level = "LOW"

        # 7. Execute Deterministic Advisory Engines based on Intents
        if parsed.primary_intent != "GREETING":
            if "TRAVEL_PLANNING" in [parsed.primary_intent] + parsed.secondary_intents or effective_persona == "traveler":
                tools_called.append("evaluate_travel_conditions")
                res = travel_engine.evaluate(
                    snapshot=snapshot,
                    destination=loc_name,
                    time_frame=parsed.time_range,
                    activity=parsed.activity or "driving",
                )
                travel_assessment_data = TravelAssessmentData(**res.model_dump())
                risk_level = res.travel_risk

            if "FARMER_ASSISTANCE" in [parsed.primary_intent] + parsed.secondary_intents or effective_persona == "farmer":
                tools_called.append("evaluate_farming_conditions")
                res = farming_engine.evaluate(
                    snapshot=snapshot,
                    location=loc_name,
                    time_frame=parsed.time_range,
                    crop=parsed.crop or "general",
                    activity=parsed.activity or "general",
                )
                farming_advisory_data = FarmingAdvisoryData(**res.model_dump())

            if "URBAN_ADVISORY" in [parsed.primary_intent] + parsed.secondary_intents or effective_persona == "urban_worker":
                tools_called.append("evaluate_urban_conditions")
                res = urban_engine.evaluate(
                    snapshot=snapshot,
                    location=loc_name,
                    time_frame=parsed.time_range,
                    activity=parsed.activity or "general",
                )
                urban_advisory_data = UrbanAdvisoryData(**res.model_dump())
                if res.risk_level in ("HIGH", "SEVERE"):
                    risk_level = res.risk_level

            if "CLIMATE_TREND" in [parsed.primary_intent] + parsed.secondary_intents:
                tools_called.append("evaluate_climate_trend")
                month = parsed.target_month or date.today().month
                years_back = parsed.years_back or 10
                trend_res = await climate_trend_service.get_monthly_trend(
                    lat, lon, loc_name, month=month, years_back=years_back
                )
                if trend_res:
                    climate_trend_data = ClimateTrendData(**trend_res)

            if "WEATHER_WARNING" in [parsed.primary_intent] + parsed.secondary_intents:
                tools_called.append("get_official_alerts")
                if any(a.risk_level == "SEVERE" for a in snapshot.alerts):
                    risk_level = "SEVERE"
                elif any(a.risk_level == "HIGH" for a in snapshot.alerts):
                    risk_level = "HIGH"
                elif any(a.risk_level == "MODERATE" for a in snapshot.alerts):
                    risk_level = "MODERATE"

        # 8. Check Gemini Client Availability
        if not self.client:
            raise RuntimeError("Gemini API key is required. Please set GEMINI_API_KEY in .env.")

        # 9. Construct Factual Grounding Snapshot for Gemini Prompt
        forecast_summary = ""
        if snapshot:
            forecast_summary = "\n".join([
                f"- {d.date}: {d.condition} | Max: {d.temp_max}°C, Min: {d.temp_min}°C | Rain Prob: {d.rain_probability_max}% (Rain: {d.precipitation_sum_mm} mm)"
                for d in snapshot.daily_7_day_forecast[:5]
            ])

        travel_block = f"""
[TRAVEL ASSESSMENT ENGINE OUTPUT - AUTHORITATIVE VERDICT]
- Destination: {travel_assessment_data.destination}
- Time Frame: {travel_assessment_data.time_frame}
- Travel Risk Level: {travel_assessment_data.travel_risk}
- Official Verdict: {travel_assessment_data.verdict}
- Reasons: {', '.join(travel_assessment_data.reasons)}
- Required Safety Guidelines: {', '.join(travel_assessment_data.guidelines)}
""" if travel_assessment_data else ""

        farming_block = f"""
[FARMING ADVISORY ENGINE OUTPUT - AGRONOMIC RULES]
- Crop: {farming_advisory_data.crop}
- Activity: {farming_advisory_data.activity}
- Agronomic Recommendation: {farming_advisory_data.recommendation}
- Advisory Headline: {farming_advisory_data.advisory_headline}
- Reasons: {', '.join(farming_advisory_data.reasons)}
- Required Action Steps: {', '.join(farming_advisory_data.actionable_steps)}
""" if farming_advisory_data else ""

        urban_block = f"""
[URBAN / SMART-CITY ADVISORY ENGINE OUTPUT]
- Location: {urban_advisory_data.location}
- Risk Level: {urban_advisory_data.risk_level}
- Verdict: {urban_advisory_data.verdict}
- Reasons: {', '.join(urban_advisory_data.reasons)}
- Required Actions: {', '.join(urban_advisory_data.actionable_steps)}
""" if urban_advisory_data else ""

        climate_trend_block = f"""
[HISTORICAL CLIMATE TREND ENGINE OUTPUT - {climate_trend_data.years_covered[0] if climate_trend_data.years_covered else ''}-{climate_trend_data.years_covered[-1] if climate_trend_data.years_covered else ''}]
- Location: {climate_trend_data.location}
- Month: {climate_trend_data.month}
- Years Covered: {', '.join(str(y) for y in climate_trend_data.years_covered)}
- Average Total Rainfall: {climate_trend_data.avg_total_rainfall_mm} mm (range {climate_trend_data.min_total_rainfall_mm}-{climate_trend_data.max_total_rainfall_mm} mm)
- Average Max/Min Temp: {climate_trend_data.avg_temp_max}°C / {climate_trend_data.avg_temp_min}°C
- Typical Condition: {climate_trend_data.typical_condition}
- Rainfall Trend Over Period: {climate_trend_data.rainfall_trend}
- Summary: {climate_trend_data.summary}
""" if climate_trend_data else ""

        history_block = "\n".join([
            f"{m['role'].upper()}: {m['text']}"
            for m in ctx.history[-4:]
        ]) if ctx.history else "None"

        if parsed.primary_intent == "GREETING":
            system_instruction = f"""
You are Megha (मेघा) — a sweet, polite, and caring personal AI weather companion and friend.
The user has just greeted you (e.g. Hi, Hello, Kaise ho, Namaste).
Reply warmly, sweetly, and conversationally in the user's language. 
Tell them you are doing well and ask how you can help them with weather, rain updates, travel, or farming plans today.
IMPORTANT RULE: DO NOT provide unasked weather numbers, temperatures, or technical stats for simple greetings!
"""
        else:
            loc_disp = snapshot.location if snapshot else loc_name
            location_note = (
                f"8. The user didn't mention a specific city, so you're currently showing "
                f"{loc_disp} as a default. Gently ask which city they mean (in the same "
                f"reply) rather than assuming they meant {loc_disp}.\n"
                if location_was_defaulted else ""
            )
            system_instruction = f"""
You are Megha (मेघा) — a super friendly, helpful, and smart personal AI weather assistant (just like talking to a caring friend on ChatGPT).

[METEOROLOGICAL LIVE DATA FOR {loc_disp}]
• Location: {loc_disp}
• Current: {snapshot.current_temp if snapshot else ''}°C, {snapshot.current_condition if snapshot else ''}, Humidity: {snapshot.current_humidity if snapshot else ''}%, Wind: {snapshot.current_wind_kmh if snapshot else ''} km/h
• Tomorrow: {snapshot.tomorrow_condition if snapshot else ''}, {snapshot.tomorrow_temp_min if snapshot else ''}°C to {snapshot.tomorrow_temp_max if snapshot else ''}°C, Rain chance: {snapshot.tomorrow_rain_prob if snapshot else ''}%
• Next 24h Rain Chance Peak: {snapshot.rain_timeline.peak_probability if snapshot else ''}% ({snapshot.rain_timeline.summary if snapshot else ''})
• 5-Day Outlook:
{forecast_summary}
{travel_block}
{farming_block}
{urban_block}
{climate_trend_block}
[RECENT CONVERSATION HISTORY]
{history_block}

[HOW TO REPLY - CONVERSATIONAL FRIEND STYLE]
1. NEVER start with "नमस्ते! मैं आपकी दोस्त मेघा हूँ" or any self-introduction. Start directly with the clear answer in the very first sentence.
2. Directly answer the user's specific question (commute, travel, farming, rain timing) with warm, practical guidance.
3. If they ask about travel/commuting, tell them whether it's safe and what time is best to leave.
4. If they ask about crops or farming, advise them simply and practically (e.g. if rain will wash spray away).
5. If historical climate trend data is provided above, narrate it naturally (e.g. "August in Delhi usually sees around X mm of rain, and it's been trending up over the last few years") instead of dumping raw numbers.
6. MULTILINGUAL FLUENCY: Always reply in the EXACT language and script the user asked in (e.g., Hindi हिंदी, Hinglish, Bengali বাংলা, Marathi मराठी, Tamil தமிழ், Telugu తెలుగు, Gujarati ગુજરાતી, Punjabi ਪੰਜਾਬੀ, Kannada ಕನ್ನಡ, Malayalam മലയാളം, Odia ଓଡ଼ିଆ, or English). Ensure high cultural fluency and natural spoken tone.
7. DO NOT use robotic headings, formal report templates, or technical labels (like "सलाह:", "Reasons:", "Advisory Headline:"). Just write naturally in friendly paragraphs!
8. NO ROBOTIC NUMBER DUMPING: Never mechanically rattle off raw statistics (humidity %, wind speed km/h, etc.) unless specifically asked. Talk like a friendly human companion so the response sounds sweet and natural when spoken aloud.
9. NO GREETINGS: Do NOT greet or say hello. Jump straight into the advice.
{location_note}
"""

        tools_called.append("gemini_generate_content")
        reply_text = None
        # Configured model first, then a couple of verified-stable fallbacks.
        # Keep this list to models you've actually confirmed your API key can
        # access — an unverified/incorrect model ID here silently burns a
        # request and makes every fallback attempt fail the same way.
        candidate_models = [self.model_name, "gemini-3.5-flash", "gemini-3.5-flash-lite"]
        seen_models = set()
        last_err = None

        for mdl in candidate_models:
            if mdl in seen_models:
                continue
            seen_models.add(mdl)
            try:
                response = await asyncio.to_thread(
                    self.client.models.generate_content,
                    model=mdl,
                    contents=request.message,
                    config=types.GenerateContentConfig(
                        system_instruction=system_instruction,
                        temperature=0.7,
                    ),
                )
                if response and response.text:
                    reply_text = response.text
                    break
            except Exception as e:
                last_err = e
                logger.error(f"Gemini model '{mdl}' failed: {type(e).__name__}: {e}")

        if not reply_text:
            # Log loudly with the actual upstream error so failures are
            # diagnosable from server logs instead of showing up to the user
            # as a generic "technical" error with no explanation.
            logger.error(
                f"Gemini generation failed across all candidate models "
                f"{candidate_models}. Last error: {last_err}"
            )
            raise RuntimeError(
                f"Gemini generation failed across all available models: {last_err}"
            )

        # Clean any accidental repetitive greetings on non-greeting turns
        if reply_text and parsed.primary_intent != "GREETING":
            import re
            greeting_patterns = [
                r"^(?:नमस्ते|नमस्कार|हेलो|हाय|हैलो)[!।,.\s]*(?:मैं\s+(?:आपकी\s+)?(?:दोस्त\s+|सहेली\s+|वेदर\s+दोस्त\s+)?मेघा\s+हूँ[।!.,\s]*)?",
                r"^(?:Hello|Hi|Hey)[!।,.\s]*(?:I am|I'm|this is)?\s*(?:your\s+)?(?:friend\s+|weather\s+assistant\s+)?Megha[।!.,\s]*",
                r"^मैं\s+(?:आपकी\s+)?(?:दोस्त\s+|सहेली\s+)?मेघा\s+हूँ[।!.,\s]*",
            ]
            for pat in greeting_patterns:
                reply_text = re.sub(pat, "", reply_text, flags=re.IGNORECASE).strip()

        # 11. Suggestion Chips
        suggestions = []
        if "TRAVEL_PLANNING" in [parsed.primary_intent] + parsed.secondary_intents or effective_persona == "traveler":
            suggestions = [
                f"Road visibility in {loc_name}",
                f"Will it rain tomorrow in {loc_name}?",
                "Packing tips for this trip",
            ]
        elif "FARMER_ASSISTANCE" in [parsed.primary_intent] + parsed.secondary_intents or effective_persona == "farmer":
            suggestions = [
                f"Should I irrigate my fields in {loc_name}?",
                "Best time for pesticide spraying",
                "7-day rainfall accumulation",
            ]
        elif effective_persona == "daily_commuter":
            suggestions = [
                f"Morning commute rain timing in {loc_name}",
                f"Evening commute forecast in {loc_name}",
                "Two-wheeler road conditions",
            ]
        elif "URBAN_ADVISORY" in [parsed.primary_intent] + parsed.secondary_intents or effective_persona == "urban_worker":
            suggestions = [
                f"Waterlogging risk in {loc_name} today",
                f"Heat advisory for outdoor workers in {loc_name}",
                f"Wind/traffic disruption risk in {loc_name}",
            ]
        elif "CLIMATE_TREND" in [parsed.primary_intent] + parsed.secondary_intents:
            suggestions = [
                f"Compare to this year's forecast in {loc_name}",
                f"Rainfall trend for {loc_name} last 10 years",
                f"Best time of year to visit {loc_name}",
            ]
        elif parsed.primary_intent in ["TOMORROW_FORECAST", "RAIN_CHECK"]:
            suggestions = [
                f"Hourly rain timing in {loc_name}",
                f"Can I travel to {loc_name} tomorrow?",
                f"5-day forecast for {loc_name}",
            ]
        else:
            suggestions = [
                f"Will it rain tomorrow in {loc_name}?",
                f"Can I travel to {loc_name} tomorrow?",
                f"7-day forecast for {loc_name}",
            ]

        # If confirmation suggestion is active, append confirmation chips
        confirmation_dto = None
        if confirmation_suggestion:
            confirmation_dto = PersonaConfirmationDTO(
                persona=confirmation_suggestion.persona,
                confidence=confirmation_suggestion.confidence,
                title=confirmation_suggestion.title,
                message=confirmation_suggestion.message,
                action_chips=confirmation_suggestion.action_chips,
            )
            for chip in confirmation_suggestion.action_chips:
                if chip["label"] not in suggestions:
                    suggestions.append(chip["label"])

        # 11. Update Session Memory & Context in Redis / Local Store (Single batched roundtrip)
        await context_manager.record_turn(
            session_id=session_id,
            user_message=request.message,
            ai_response=reply_text,
            active_location={"name": loc_name, "latitude": lat, "longitude": lon},
            persona=effective_persona,
            language=active_lang,
            recent_intent=parsed.primary_intent,
            secondary_intents=parsed.secondary_intents,
            recent_time_reference=parsed.time_range,
        )

        # 12. Sarvam Bulbul Studio Voice Audio Synthesis (for sweet human voice)
        audio_base64 = None
        audio_chunks = None
        if settings.SARVAM_API_KEY:
            try:
                from app.services.voice.sarvam_voice_service import sarvam_voice_service
                lang_map = {
                    "hi": "hi-IN", "en": "en-IN", "mr": "mr-IN", "bn": "bn-IN",
                    "ta": "ta-IN", "te": "te-IN", "gu": "gu-IN", "kn": "kn-IN",
                    "ml": "ml-IN", "pa": "pa-IN", "od": "od-IN"
                }
                target_tts_lang = lang_map.get(active_lang, "hi-IN")
                tts_result = await sarvam_voice_service.text_to_speech(
                    text=reply_text,
                    target_language_code=target_tts_lang,
                    model="bulbul:v2",
                )
                if tts_result.get("status") == "success":
                    audio_chunks = tts_result.get("audio_chunks") or []
                    audio_base64 = tts_result.get("audio_base64") or (audio_chunks[0] if audio_chunks else None)
                    tools_called.append("sarvam_bulbul_tts")
            except Exception as e:
                logger.warning(f"Sarvam TTS generation error: {e}")

        # Retrieve profile for inferred personas scores
        user_profile = await persona_engine.get_profile(user_id)

        return ChatMessageResponse(
            session_id=session_id,
            response=reply_text,
            language=active_lang,
            primary_intent=parsed.primary_intent,
            secondary_intents=parsed.secondary_intents,
            intent=parsed.primary_intent,
            persona_applied=effective_persona,
            weather_data=card_data,
            travel_assessment=travel_assessment_data,
            farming_advisory=farming_advisory_data,
            urban_advisory=urban_advisory_data,
            climate_trend=climate_trend_data,
            risk_level=risk_level,
            tools_called=tools_called,
            suggestions=suggestions,
            audio_base64=audio_base64,
            audio_chunks=audio_chunks,
            persona_confirmation=confirmation_dto,
            inferred_personas=user_profile.inferred_personas,
        )
