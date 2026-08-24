import logging
import uuid
import re
import json
import asyncio
from datetime import date
from typing import Optional, List, Dict, Any

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
from app.services.llm import gemini_tools
from app.services.advisory.travel_engine import travel_engine
from app.services.advisory.farming_engine import farming_engine
from app.services.advisory.urban_engine import urban_engine
from app.services.weather.climate_trend_service import climate_trend_service
from app.services.personalization.persona_engine import persona_engine
from app.core.config import settings
from google import genai
from google.genai import types

logger = logging.getLogger(__name__)

# Map of tool names to callable async wrappers in gemini_tools
TOOL_FUNCTIONS_MAP: Dict[str, Any] = {
    "get_current_weather": gemini_tools.get_current_weather,
    "get_hourly_forecast": gemini_tools.get_hourly_forecast,
    "get_rain_timeline": gemini_tools.get_rain_timeline,
    "get_multi_day_forecast": gemini_tools.get_multi_day_forecast,
    "get_weather_risk": gemini_tools.get_weather_risk,
    "get_official_alerts": gemini_tools.get_official_alerts,
    "evaluate_travel_conditions": gemini_tools.evaluate_travel_conditions,
    "evaluate_farming_conditions": gemini_tools.evaluate_farming_conditions,
    "evaluate_urban_conditions": gemini_tools.evaluate_urban_conditions,
    "evaluate_climate_trend": gemini_tools.evaluate_climate_trend,
    "get_nwp_comparison": gemini_tools.get_nwp_comparison,
    "get_official_disaster_alerts": gemini_tools.get_official_disaster_alerts,
}


class GeminiLLMService(BaseLLMService):
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.model_name = settings.GEMINI_MODEL or "gemini-2.0-flash"
        self.client = None
        if self.api_key:
            try:
                self.client = genai.Client(api_key=self.api_key)
            except Exception as e:
                logger.error(f"Failed to initialize Gemini client: {e}")

    def _build_system_instruction(
        self,
        personalization_ctx,
        ctx,
        tool_ctx,
        user_message: str,
        user_lang: str = "en",
    ) -> str:
        """
        Builds Megha persona system prompt with live location context and tool execution instructions.
        """
        persona_guidance = ""
        if personalization_ctx.active_persona == "farmer":
            persona_guidance = "• Active User Persona: Farmer / Agricultural Operator. Prioritize practical agricultural decisions (pesticide/fertilizer spraying, irrigation, soil moisture, crop harvesting)."
        elif personalization_ctx.active_persona == "traveler":
            persona_guidance = "• Active User Persona: Commuter / Long-distance Traveler. Prioritize road safety, driving hazards, route timing, visibility, and travel advisories."
        elif personalization_ctx.active_persona == "urban_worker":
            persona_guidance = "• Active User Persona: Outdoor / Urban Worker. Highlight waterlogging risk, heat index stress, and wind disruption."
        elif personalization_ctx.active_persona == "daily_commuter":
            persona_guidance = "• Active User Persona: Daily Office/School Commuter. Highlight peak commute rain timing and two-wheeler road conditions."

        active_loc_name = tool_ctx.resolved_location_name or (ctx.active_location.name if ctx.active_location else "Delhi NCR, India")
        coords_str = f" (Latitude: {tool_ctx.resolved_lat:.4f}, Longitude: {tool_ctx.resolved_lon:.4f})" if tool_ctx.resolved_lat is not None else ""

        return f"""
You are Megha (मेघा) — an exceptionally warm, intelligent, and caring personal AI weather companion (like a trusted friend on ChatGPT).

[CORE ROLE & CAPABILITIES]
You have direct access to authoritative meteorological tools. Whenever a user asks about current weather, rain, forecasts, travel safety, farming decisions, spraying pesticides, irrigation, urban risks, climate trends, physics NWP models, or official disaster warnings, you MUST call the relevant tool(s) to fetch real, grounded facts. NEVER fabricate or guess numbers.

[USER'S ACTIVE LOCATION CONTEXT]
• User's Current Live Location: {active_loc_name}{coords_str}
• Preferred Language/Locale: {user_lang}
{persona_guidance}

[CRITICAL LOCATION BEHAVIOR]
• DEFAULT LOCATION: If the user asks a weather or activity question without mentioning a specific other city (for example: "mujhe kitnashak dalne h", "should I spray pesticide", "baarish kab hogi", "aaj ka mausam kaisa hai", "can I travel today"), you MUST use their Current Live Location ({active_loc_name}) and pass location='{active_loc_name}' to tools.
• EXPLICIT LOCATION: Only if the user mentions another specific city (e.g. 'Mumbai', 'Jaipur', 'London'), use that specific city.

[HOW TO REPLY - CONVERSATIONAL FRIEND STYLE]
1. NO ROBOTIC GREETINGS: NEVER start with "नमस्ते! मैं आपकी दोस्त मेघा हूँ" or robotic self-introductions. Start directly with the clear, conversational answer in the very first sentence. (Exception: If the user ONLY said 'Hi' or 'Hello', reply warmly and ask how you can help).
2. DIRECT & ACTIONABLE: Give crisp, practical answers. For example, if asking about spraying pesticides (कीटनाशक), check precipitation and wind, give a clear recommendation on whether it is safe to spray, the best time window, and reasons.
3. MULTILINGUAL & CULTURAL FLUENCY: Always respond in the EXACT language and script the user wrote in (Hindi हिंदी, Hinglish, Bengali বাংলা, Marathi मराठी, Tamil தமிழ், Telugu తెలుగు, Gujarati ગુજરાતી, Punjabi ਪੰਜਾਬੀ, Kannada ಕನ್ನಡ, Malayalam മലയാളം, Odia ଓଡ଼ିଆ, or English).
4. NO RIGID TEMPLATES: Never use rigid labels like "सलाह:", "Reasons:", or bullet dumps unless requested. Write in natural, warm paragraphs.
5. TOOL USAGE: Call whatever tools are needed (get_current_weather, get_hourly_forecast, evaluate_farming_conditions, evaluate_travel_conditions, etc.) to get live facts before answering.
""".strip()

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

        active_lang = request.language or ctx.language or "en"
        effective_persona = personalization_ctx.active_persona

        if not self.client:
            raise RuntimeError("Gemini API key is required. Please set GEMINI_API_KEY in .env.")

        # Initialize thread-safe tool execution context with user's live coordinates
        tool_ctx = gemini_tools.init_tool_context()
        if request.latitude is not None and request.latitude != 0.0 and request.longitude is not None and request.longitude != 0.0:
            tool_ctx.resolved_lat = request.latitude
            tool_ctx.resolved_lon = request.longitude
            tool_ctx.resolved_location_name = request.location or (ctx.active_location.name if ctx.active_location else "My Location")
        elif ctx.active_location:
            tool_ctx.resolved_lat = ctx.active_location.latitude
            tool_ctx.resolved_lon = ctx.active_location.longitude
            tool_ctx.resolved_location_name = ctx.active_location.name

        system_instruction = self._build_system_instruction(
            personalization_ctx=personalization_ctx,
            ctx=ctx,
            tool_ctx=tool_ctx,
            user_message=request.message,
            user_lang=active_lang,
        )

        reply_text = None
        tools_called: List[str] = []

        try:
            # ---------------------------------------------------------------
            # Real Gemini Tool-Calling Loop (Option B: Explicit Multi-Turn AFC)
            # ---------------------------------------------------------------
            contents: List[Any] = []

            # Include recent conversation turns for context
            for hist_msg in (ctx.history[-4:] if ctx.history else []):
                role = "user" if hist_msg.get("role") == "user" else "model"
                text = hist_msg.get("text")
                if text:
                    contents.append(types.Content(role=role, parts=[types.Part.from_text(text=text)]))

            # Current user query
            contents.append(types.Content(role="user", parts=[types.Part.from_text(text=request.message)]))

            max_turns = 5
            for turn in range(max_turns):
                resp = await self.client.aio.models.generate_content(
                    model=self.model_name,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        system_instruction=system_instruction,
                        tools=gemini_tools.ALL_GEMINI_TOOLS,
                        temperature=0.4,
                    ),
                )

                if not resp.candidates:
                    break

                candidate = resp.candidates[0]
                has_function_calls = bool(resp.function_calls)

                if has_function_calls:
                    # Append model's thought / tool calls to conversation
                    contents.append(candidate.content)

                    # Execute model-requested tools
                    tool_response_parts: List[types.Part] = []
                    for fc in resp.function_calls:
                        fn_name = fc.name
                        fn = TOOL_FUNCTIONS_MAP.get(fn_name)
                        fn_args = dict(fc.args) if fc.args else {}

                        logger.info(f"Gemini requested tool: {fn_name}({fn_args})")
                        try:
                            if fn:
                                result = await fn(**fn_args)
                            else:
                                result = {"error": f"Tool '{fn_name}' not recognized."}
                        except Exception as tool_err:
                            logger.error(f"Error executing tool {fn_name}: {tool_err}")
                            result = {"error": str(tool_err)}

                        tool_response_parts.append(
                            types.Part.from_function_response(
                                name=fn_name,
                                response={"result": result},
                            )
                        )

                    contents.append(types.Content(role="tool", parts=tool_response_parts))
                else:
                    # Model produced final text response
                    reply_text = resp.text
                    break

            tools_called = list(tool_ctx.tools_called)

        except Exception as tool_flow_err:
            logger.warning(
                f"Gemini tool-calling flow encountered an error: {tool_flow_err}. "
                f"Activating resilient two-pass fallback path."
            )
            # Fallback path per Section 6 of specification
            return await self._process_chat_fallback(
                request=request,
                ctx=ctx,
                personalization_ctx=personalization_ctx,
                confirmation_suggestion=confirmation_suggestion,
                user_id=user_id,
                session_id=session_id,
            )

        if not reply_text:
            logger.warning("Gemini tool loop produced no text; triggering fallback.")
            return await self._process_chat_fallback(
                request=request,
                ctx=ctx,
                personalization_ctx=personalization_ctx,
                confirmation_suggestion=confirmation_suggestion,
                user_id=user_id,
                session_id=session_id,
            )

        # Clean accidental self-introduction if present
        if reply_text:
            greeting_patterns = [
                r"^(?:नमस्ते|नमस्कार|हेलो|हाय|हैलो)[!।,.\s]*(?:मैं\s+(?:आपकी\s+)?(?:दोस्त\s+|सहेली\s+|वेदर\s+दोस्त\s+)?मेघा\s+हूँ[।!.,\s]*)?",
                r"^(?:Hello|Hi|Hey)[!।,.\s]*(?:I am|I'm|this is)?\s*(?:your\s+)?(?:friend\s+|weather\s+assistant\s+)?Megha[।!.,\s]*",
                r"^मैं\s+(?:आपकी\s+)?(?:दोस्त\s+|सहेली\s+)?मेघा\s+हूँ[।!.,\s]*",
            ]
            for pat in greeting_patterns:
                reply_text = re.sub(pat, "", reply_text, flags=re.IGNORECASE).strip()

        # Extract structured artifacts captured during tool execution
        card_data = tool_ctx.card_data
        travel_assessment_data = tool_ctx.travel_assessment_data
        farming_advisory_data = tool_ctx.farming_advisory_data
        urban_advisory_data = tool_ctx.urban_advisory_data
        climate_trend_data = tool_ctx.climate_trend_data
        risk_level = tool_ctx.risk_level
        loc_name = tool_ctx.resolved_location_name or (ctx.active_location.name if ctx.active_location else "New Delhi")
        lat = tool_ctx.resolved_lat or (ctx.active_location.latitude if ctx.active_location else 28.6139)
        lon = tool_ctx.resolved_lon or (ctx.active_location.longitude if ctx.active_location else 77.2090)

        # Primary intent mapping
        if "evaluate_travel_conditions" in tools_called:
            primary_intent = "TRAVEL_PLANNING"
        elif "evaluate_farming_conditions" in tools_called:
            primary_intent = "FARMER_ASSISTANCE"
        elif "evaluate_urban_conditions" in tools_called:
            primary_intent = "URBAN_ADVISORY"
        elif "evaluate_climate_trend" in tools_called:
            primary_intent = "CLIMATE_TREND"
        elif "get_rain_timeline" in tools_called:
            primary_intent = "RAIN_CHECK"
        elif "get_multi_day_forecast" in tools_called:
            primary_intent = "MULTI_DAY_FORECAST"
        elif "get_nwp_comparison" in tools_called:
            primary_intent = "NWP_ANALYSIS"
        elif "get_current_weather" in tools_called:
            primary_intent = "CURRENT_WEATHER"
        else:
            primary_intent = "GENERAL_WEATHER"

        secondary_intents = [t for t in tools_called if t != primary_intent]

        # Suggestion chips
        suggestions = self._build_suggestions(primary_intent, effective_persona, loc_name)

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

        # Update Session Memory
        await context_manager.record_turn(
            session_id=session_id,
            user_message=request.message,
            ai_response=reply_text,
            active_location={"name": loc_name, "latitude": lat, "longitude": lon},
            persona=effective_persona,
            language=active_lang,
            recent_intent=primary_intent,
            secondary_intents=secondary_intents,
            recent_time_reference="current",
        )

        # Sarvam Voice Audio Synthesis
        audio_base64 = None
        audio_chunks = None
        if settings.SARVAM_API_KEY and reply_text:
            try:
                from app.services.voice.sarvam_voice_service import sarvam_voice_service
                lang_map = {
                    "hi": "hi-IN", "en": "en-IN", "mr": "mr-IN", "bn": "bn-IN",
                    "ta": "ta-IN", "te": "te-IN", "gu": "gu-IN", "kn": "kn-IN",
                    "ml": "ml-IN", "pa": "pa-IN", "od": "od-IN",
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

        user_profile = await persona_engine.get_profile(user_id)

        return ChatMessageResponse(
            session_id=session_id,
            response=reply_text,
            language=active_lang,
            primary_intent=primary_intent,
            secondary_intents=secondary_intents,
            intent=primary_intent,
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

    def _build_suggestions(self, primary_intent: str, persona: str, location: str) -> List[str]:
        if primary_intent == "TRAVEL_PLANNING" or persona == "traveler":
            return [
                f"Road visibility in {location}",
                f"Will it rain tomorrow in {location}?",
                "Packing tips for this trip",
            ]
        elif primary_intent == "FARMER_ASSISTANCE" or persona == "farmer":
            return [
                f"Should I irrigate my fields in {location}?",
                "Best time for pesticide spraying",
                "7-day rainfall accumulation",
            ]
        elif persona == "daily_commuter":
            return [
                f"Morning commute rain timing in {location}",
                f"Evening commute forecast in {location}",
                "Two-wheeler road conditions",
            ]
        elif primary_intent == "URBAN_ADVISORY" or persona == "urban_worker":
            return [
                f"Waterlogging risk in {location} today",
                f"Heat advisory for outdoor workers in {location}",
                f"Wind/traffic disruption risk in {location}",
            ]
        elif primary_intent == "CLIMATE_TREND":
            return [
                f"Compare to this year's forecast in {location}",
                f"Rainfall trend for {location} last 10 years",
                f"Best time of year to visit {location}",
            ]
        return [
            f"Will it rain tomorrow in {location}?",
            f"Can I travel to {location} tomorrow?",
            f"7-day forecast for {location}",
        ]

    async def _process_chat_fallback(
        self,
        request: ChatMessageRequest,
        ctx,
        personalization_ctx,
        confirmation_suggestion,
        user_id: str,
        session_id: str,
    ) -> ChatMessageResponse:
        """
        Resilient two-pass fallback path (query parsing + manual engine dispatch + prose generation)
        used if direct tool-calling fails.
        """
        logger.info("Executing two-pass fallback chat generation.")
        parsed = await llm_query_engine.parse_query(request.message, context=ctx)

        target_city = parsed.location or (ctx.active_location.name if ctx.active_location else "New Delhi")
        tools_called = ["query_understanding_fallback"]

        lat = request.latitude or (ctx.active_location.latitude if ctx.active_location else 28.6139)
        lon = request.longitude or (ctx.active_location.longitude if ctx.active_location else 77.2090)
        loc_name = target_city

        geocoded = await weather_service.geocode(target_city)
        if geocoded:
            lat, lon, loc_name = geocoded

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

        travel_data = None
        farming_data = None
        urban_data = None
        climate_data = None
        risk_level = "LOW"

        if "TRAVEL_PLANNING" in [parsed.primary_intent] + parsed.secondary_intents or personalization_ctx.active_persona == "traveler":
            res = travel_engine.evaluate(snapshot, loc_name, time_frame=parsed.time_range, activity=parsed.activity or "driving")
            travel_data = TravelAssessmentData(**res.model_dump())
            risk_level = res.travel_risk

        if "FARMER_ASSISTANCE" in [parsed.primary_intent] + parsed.secondary_intents or personalization_ctx.active_persona == "farmer":
            res = farming_engine.evaluate(snapshot, loc_name, time_frame=parsed.time_range, crop=parsed.crop or "general", activity=parsed.activity or "general")
            farming_data = FarmingAdvisoryData(**res.model_dump())

        if "URBAN_ADVISORY" in [parsed.primary_intent] + parsed.secondary_intents or personalization_ctx.active_persona == "urban_worker":
            res = urban_engine.evaluate(snapshot, loc_name, time_frame=parsed.time_range, activity=parsed.activity or "general")
            urban_data = UrbanAdvisoryData(**res.model_dump())

        # Build comprehensive advisory facts for fallback generation
        advisory_context = ""
        if farming_data:
            advisory_context += f" Farming Advisory: {farming_data.suitability}. {farming_data.headline}. Reasons: {', '.join(farming_data.reasons)}. Recommendation: {farming_data.recommendation}."
        elif travel_data:
            advisory_context += f" Travel Assessment: Risk Level {travel_data.travel_risk}. {travel_data.advisory_headline}. Safe Departure Windows: {', '.join(travel_data.safe_departure_windows)}."
        elif urban_data:
            advisory_context += f" Urban Advisory: {urban_data.headline}. {urban_data.primary_recommendation}."

        fallback_prompt = (
            f"You are Megha (मेघा), an expert, caring personal AI weather companion. "
            f"User Location: {loc_name} (Current Temp: {snapshot.current_temp}°C, Condition: {snapshot.current_condition}, Rain: {snapshot.current_precipitation_mm}mm, Wind: {snapshot.current_wind_kmh}km/h, Humidity: {snapshot.current_humidity}%). "
            f"{advisory_context} "
            f"Directly answer the user's specific question in their language and tone ({parsed.language_hint}). Never start with robotic self-introductions or headings. Give practical, conversational guidance."
        )
        reply_text = None
        try:
            resp = await self.client.aio.models.generate_content(
                model=self.model_name,
                contents=request.message,
                config=types.GenerateContentConfig(system_instruction=fallback_prompt, temperature=0.6),
            )
            if resp and resp.text:
                reply_text = resp.text
        except Exception as fb_err:
            logger.warning(f"Fallback generation model call failed: {fb_err}. Using factual template.")

        if not reply_text:
            if farming_data:
                if parsed.language_hint in ("hi", "hinglish"):
                    reply_text = f"{loc_name} में {farming_data.headline}। {farming_data.recommendation} (वर्तमान तापमान: {snapshot.current_temp}°C, {snapshot.current_condition})"
                else:
                    reply_text = f"In {loc_name}: {farming_data.headline}. {farming_data.recommendation} (Current: {snapshot.current_temp}°C, {snapshot.current_condition})"
            elif parsed.language_hint in ("hi", "hinglish"):
                reply_text = f"{loc_name} में अभी तापमान {snapshot.current_temp}°C है और मौसम {snapshot.current_condition} बना हुआ है।"
            else:
                reply_text = f"In {loc_name}, it is currently {snapshot.current_temp}°C with {snapshot.current_condition}."

        user_profile = await persona_engine.get_profile(user_id)

        return ChatMessageResponse(
            session_id=session_id,
            response=reply_text,
            language=parsed.language_hint or "en",
            primary_intent=parsed.primary_intent,
            secondary_intents=parsed.secondary_intents,
            intent=parsed.primary_intent,
            persona_applied=personalization_ctx.active_persona,
            weather_data=card_data,
            travel_assessment=travel_data,
            farming_advisory=farming_data,
            urban_advisory=urban_data,
            climate_trend=climate_data,
            risk_level=risk_level,
            tools_called=tools_called,
            suggestions=self._build_suggestions(parsed.primary_intent, personalization_ctx.active_persona, loc_name),
            inferred_personas=user_profile.inferred_personas,
        )


gemini_service = GeminiLLMService()
