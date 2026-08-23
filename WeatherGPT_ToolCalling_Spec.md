# WeatherGPT — Real Gemini Function-Calling Migration

*Engineering spec for Antigravity / any AI coding agent implementing this change.*

**Backend:** FastAPI + google-genai SDK.
**Target file:** `backend/app/services/llm/gemini_service.py`, plus a new tool-execution module.

---

## 1. Goal

Replace the current two-pass, manually-orchestrated pipeline (LLM called once to extract intent, backend Python if/else decides what to fetch, LLM called again to write the final reply) with real Gemini function-calling (tool use). The model itself should decide which weather/advisory/climate tools to call, call them (via the SDK's Automatic Function Calling), and write the final response — in one guided flow instead of two hand-wired passes.

---

## 2. Current Architecture (as-is, verified in code)

File: `app/services/llm/gemini_service.py`, method `process_chat()`. Confirmed by direct code read — this is not a guess.

```
1. User message arrives (ChatMessageRequest)
2. context_manager.get_context(session_id)          -> prior turns, active location
3. persona_engine.process_turn(...)                  -> persona signal extraction,
                                                         confidence scoring (Redis-backed)
4. llm_query_engine.parse_query(message, context)    -> GEMINI CALL #1 (JSON mode)
     - returns: primary_intent, secondary_intents, location, time_range,
       activity, crop, language_hint
     - falls back to regex parser (query_parser.py) if this call fails
5. Backend Python code (NOT the LLM) decides what to fetch, using plain
   if/elif on parsed.primary_intent:
     - weather_service.geocode() + get_comprehensive_weather()   (Open-Meteo)
     - weather_processor.process()  -> WeatherFactSnapshot
     - if TRAVEL_PLANNING or persona==traveler:  travel_engine.evaluate()
     - if FARMER_ASSISTANCE or persona==farmer:  farming_engine.evaluate()
     - if URBAN_ADVISORY or persona==urban_worker: urban_engine.evaluate()
     - if CLIMATE_TREND: climate_trend_service.get_monthly_trend()
     - if WEATHER_WARNING: snapshot.alerts already computed in step 5's
       weather_processor.process() call
6. All fetched results are string-formatted into large f-string blocks
   (travel_block, farming_block, urban_block, climate_trend_block)
   and concatenated into one big system_instruction prompt.
7. client.models.generate_content(...)                -> GEMINI CALL #2
     - this call has NO tools= parameter at all
     - it only writes prose from the pre-assembled facts already in the prompt
8. Response returned to user.
```

> **NOTE:** `app/services/llm/tool_registry.py` already exists with clean, well-documented async methods (`get_current_weather`, `get_rain_timeline`, `evaluate_travel_conditions`, `evaluate_farming_conditions`, `evaluate_urban_conditions`, `evaluate_climate_trend`, `get_official_alerts`, `get_weather_risk`, `get_multi_day_forecast`) — but it is imported in `gemini_service.py` and never called anywhere. Confirmed by grep: zero call sites for `tool_registry.<anything>` in the whole codebase. This file is the natural basis for the new tool set — reuse it, don't rewrite the underlying logic.

---

## 3. Target Architecture

```
1. User message arrives
2. context_manager + persona_engine run as today (unchanged — this part
   is fine, keep it)
3. ONE Gemini call, with tools=[...] set to the ToolRegistry methods:

     response = await asyncio.to_thread(
         client.models.generate_content,
         model=self.model_name,
         contents=full_conversation_or_message,
         config=types.GenerateContentConfig(
             system_instruction=system_instruction,   # persona + Megha style only
             tools=[tool_fn_1, tool_fn_2, ...],        # plain async python callables
             temperature=0.4,
         ),
     )

4. The SDK's Automatic Function Calling (AFC) intercepts function_call
   parts, executes the matching Python function with the model-chosen
   arguments, feeds the result back to the model automatically, and
   returns only after the model has produced its final text answer.
5. response.text is the final reply — no second LLM call, no manually
   built f-string blocks.
```

> **NOTE:** This removes GEMINI CALL #1 (`query_understanding_engine`) as a separate pass. Intent/location/time extraction becomes implicit: the model reads the raw user message and decides for itself which tool(s) to call and with what arguments, the same way it would decide in ChatGPT's tool-use flow. Keep `query_understanding_engine.py` in the codebase as an optional fallback path only (see Section 6) — do not delete it.

---

## 4. Why the SDK supports this (verified against docs, google-genai)

`google-genai` (already pinned in `requirements.txt` as `google-genai>=0.1.1`) supports passing plain async Python functions directly in the `tools=` list. The SDK auto-generates the JSON schema from the function's type hints and docstring, calls the function when the model requests it, and appends the result back into the conversation before continuing — this is called **Automatic Function Calling (AFC)**. Minimal shape:

```python
from google.genai import types

async def get_current_weather(location: str) -> dict:
    """Get current weather for a city.

    Args:
        location: City name, e.g. 'Jaipur, India'
    """
    ...

response = await asyncio.to_thread(
    client.models.generate_content,
    model='gemini-3.5-flash',
    contents=user_message,
    config=types.GenerateContentConfig(tools=[get_current_weather]),
)
print(response.text)
```

> **NOTE:** AFC requires plain functions with type-annotated parameters and a docstring the SDK can introspect — it does NOT work directly on bound instance methods with `self` as the first argument in the same auto-schema way. See Section 5, step 2 for the required wrapper pattern.

---

## 5. Step-by-step implementation instructions

### Step 1 — Do not touch `tool_registry.py`'s internal logic

The existing methods on `ToolRegistry` (`get_current_weather`, `get_hourly_forecast`, `get_rain_timeline`, `get_multi_day_forecast`, `get_weather_risk`, `get_official_alerts`, `evaluate_travel_conditions`, `evaluate_farming_conditions`, `evaluate_urban_conditions`, `evaluate_climate_trend`) already do the right thing and call the right underlying services (`open_meteo_service`, `weather_processor`, `travel_engine`, `farming_engine`, `urban_engine`, `climate_trend_service`). Keep them exactly as-is.

### Step 2 — Create module-level wrapper functions for AFC

Add a new file: `app/services/llm/gemini_tools.py`. This module defines free (non-method) async functions with clean docstrings — these are what get passed into `tools=[...]`. Each wrapper simply calls the corresponding `tool_registry` method. Function names, parameter names, and docstrings matter a lot here: Gemini uses them to decide which tool to call and how to fill arguments, so keep parameter names self-explanatory (e.g. `location`, not `loc`) and docstrings specific about units and expected formats.

```python
# app/services/llm/gemini_tools.py
from app.services.llm.tool_registry import tool_registry
from app.services.weather.open_meteo_service import weather_service

async def get_current_weather(location: str) -> dict:
    """Get real-time current weather (temperature, humidity, wind,
    condition) for a named city.

    Args:
        location: City and country, e.g. 'Jaipur, India'.
    """
    geocoded = await weather_service.geocode(location)
    lat, lon, resolved_name = geocoded or (28.6139, 77.2090, location)
    return await tool_registry.get_current_weather(lat, lon, resolved_name)

async def get_rain_timeline(location: str, time_reference: str = 'current') -> dict:
    """Get the next-24h rain probability timeline: whether rain is
    expected, peak probability, peak time, and expected rainfall in mm.

    Args:
        location: City and country, e.g. 'Mumbai, India'.
        time_reference: One of 'current', 'today', 'tomorrow'.
    """
    geocoded = await weather_service.geocode(location)
    lat, lon, resolved_name = geocoded or (28.6139, 77.2090, location)
    return await tool_registry.get_rain_timeline(lat, lon, resolved_name, time_reference)

# ... repeat the same thin-wrapper pattern for:
#   get_multi_day_forecast, get_weather_risk, get_official_alerts,
#   evaluate_travel_conditions, evaluate_farming_conditions,
#   evaluate_urban_conditions, evaluate_climate_trend
#
# Each wrapper: (a) takes a plain 'location: str' the model can fill in
# from the user's message directly, (b) geocodes it internally (the
# model should never have to supply raw lat/lon), (c) delegates to the
# matching tool_registry method.
```

> **NOTE:** Geocoding inside every wrapper repeats an Open-Meteo geocode call per tool invocation. If the model calls two tools for the same city in one turn (e.g. `get_current_weather` then `evaluate_travel_conditions`), that's two geocode calls. Acceptable for a hackathon demo; if time allows, add a short-lived (60s) in-process geocode cache keyed by the lowercased location string to avoid the duplicate round trip.

### Step 3 — Rewrite `gemini_service.process_chat()` to use `tools=`

Replace steps 3–9 of the current flow (query understanding call, manual if/elif dispatch, manual f-string block assembly, second `generate_content` call) with a single call:

```python
from app.services.llm import gemini_tools

TOOLS = [
    gemini_tools.get_current_weather,
    gemini_tools.get_rain_timeline,
    gemini_tools.get_multi_day_forecast,
    gemini_tools.get_weather_risk,
    gemini_tools.get_official_alerts,
    gemini_tools.evaluate_travel_conditions,
    gemini_tools.evaluate_farming_conditions,
    gemini_tools.evaluate_urban_conditions,
    gemini_tools.evaluate_climate_trend,
]

async def process_chat(self, request: ChatMessageRequest) -> ChatMessageResponse:
    ctx = await context_manager.get_context(session_id)
    personalization_ctx, _ = await persona_engine.process_turn(...)  # unchanged

    system_instruction = self._build_persona_system_prompt(
        personalization_ctx, ctx
    )  # Megha persona + style rules + active_persona guidance text only —
       # NO pre-fetched weather facts baked in here anymore.

    response = await asyncio.to_thread(
        self.client.models.generate_content,
        model=self.model_name,
        contents=self._build_contents(ctx, request.message),
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            tools=TOOLS,
            temperature=0.4,
        ),
    )

    reply_text = response.text
    tools_called = [
        fc.name for fc in (response.automatic_function_calling_history or [])
    ]  # exact attribute name to confirm against installed SDK version — see Step 6

    # ... build ChatMessageResponse as before, but weather_data /
    # travel_assessment / farming_advisory / urban_advisory fields
    # now come from the tool call results captured during AFC, not
    # from manually-run engine calls. See Step 4 for how to recover
    # those structured results for the response schema.
```

### Step 4 — Recovering structured card data (weather_data, travel_assessment, etc.)

The current API response schema (`ChatMessageResponse`) returns not just prose but structured cards: `WeatherCardData`, `TravelAssessmentData`, `FarmingAdvisoryData`, `UrbanAdvisoryData`, `ClimateTrendData`. With AFC, the raw dict each tool function returns is available in the function-call history the SDK tracks internally. Two implementation options — pick one:

- **Option A (simpler, recommended for hackathon timeline):** keep each `gemini_tools.*` wrapper function as-is, but additionally have it stash its own return value on a per-request context object (e.g. a mutable dict passed via a contextvar or a simple instance attribute reset per request) so `process_chat()` can read back "what data did each tool actually return this turn" after `generate_content()` completes, independent of what AFC internally tracks.

- **Option B (cleaner, more SDK-idiomatic):** disable AFC (`automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True)`), manually loop: call `generate_content` → read `response.function_calls` → execute the matched `tool_registry` method yourself → build `Part.from_function_response(...)` → call `generate_content` again with the function result appended to `contents` → repeat until the model returns text instead of a function call. This gives full control over which structured payload maps to which response field, at the cost of writing the loop yourself instead of letting AFC do it.

> **NOTE:** Recommend **Option B** for this migration despite slightly more code, because the current response schema depends on typed Pydantic models per advisory engine (`TravelAssessmentData`, `FarmingAdvisoryData`, etc.) and Option A's implicit stashing is fragile under concurrent requests unless very carefully scoped per-request. Option B's explicit loop makes the mapping from "which tool ran" to "which response field to fill" unambiguous.

### Step 5 — `system_instruction` changes

The current `system_instruction` is one giant string with all fetched facts (temperature, forecast, `travel_block`, `farming_block`, `urban_block`, `climate_trend_block`) interpolated in. In the new flow, none of that data exists yet when the prompt is built — the model has to call tools to get it. The new `system_instruction` should keep only:

- The Megha persona description and reply-style rules (points 1-8 in the current prompt about warmth, no robotic headings, language matching, etc.) — unchanged, keep as-is.
- Persona guidance text from `personalization_context_builder` (unchanged — still inject e.g. "User is a verified farmer, highlight irrigation timing...").
- An explicit instruction telling the model it has tools available and must call them before answering any question requiring live data: e.g. *"You have tools to fetch live weather, forecasts, and run travel/farming/urban risk assessments. ALWAYS call the relevant tool(s) before answering weather-related questions — never guess or fabricate numbers."*
- **Remove entirely:** `forecast_summary`, `travel_block`, `farming_block`, `urban_block`, `climate_trend_block`, and the `[METEOROLOGICAL LIVE DATA]` section — these no longer exist at prompt-build time.

### Step 6 — Verify exact AFC API shape against the installed SDK version before writing final code

The `google-genai` SDK's exact attribute names for accessing function-call history (`automatic_function_calling_history` vs. `response.candidates[0].content.parts` inspection) have varied across releases mentioned in different docs snapshots. Before finalizing Step 3/4 code:

- Run: `pip show google-genai` (get exact installed version)
- Check that version's own docstrings/source: `python -c "from google import genai; help(genai.Client)"` or inspect `google/genai/_extra_utils.py` in the installed package for the AFC history attribute name.
- If uncertain, default to **Option B** in Step 4 (manual loop with automatic function calling disabled) — it only depends on the stable, well-documented `response.function_calls` and `types.Part.from_function_response(...)` API surface, which has been consistent across the versions referenced in current docs.

---

## 6. What to keep unchanged

- `context_manager.py` — session/history handling stays as-is.
- `persona_engine.py`, `signal_extractor.py`, `confidence_calculator.py`, `confirmation_manager.py` — entire personalization pipeline stays as-is, feeds into `system_instruction` as today.
- `query_understanding_engine.py` / `query_parser.py` — do NOT delete. Keep as a fallback path: if the Gemini `tools=` call fails outright (network error, quota, malformed tool response) catch the exception and fall back to today's two-pass flow (regex/LLM query parsing + manual engine dispatch + plain `generate_content` with no tools) so the chat endpoint never hard-fails. This mirrors the existing fallback pattern already used elsewhere in the codebase (e.g. `llm_query_engine` already falls back to `query_parser` internally) — same philosophy, applied one level up.
- All advisory engines (`travel_engine.py`, `farming_engine.py`, `urban_engine.py`) and `climate_trend_service.py` — logic unchanged, only how they get invoked changes (model-triggered tool call vs. manual if/elif).
- `official_alert_client.py` and `alert_poller.py` (WebSocket broadcast) — entirely separate subsystem, not part of this migration.

---

## 7. Testing checklist

- [ ] Simple current-weather query ("Jaipur mein mausam kaisa hai?") → model should call `get_current_weather` exactly once, no other tools.
- [ ] Farming query with crop mentioned ("gehu ki sinchai ke liye mausam theek hai?") → model should call `evaluate_farming_conditions` (and likely `get_current_weather` first, or the wrapper geocodes+fetches internally — confirm no duplicate unnecessary calls).
- [ ] Multi-intent query ("kal Jaipur jaana hai driving se, aur udhar barish ka chance kya hai") → model should call both `evaluate_travel_conditions` and `get_rain_timeline` (or the travel tool's own output already covers rain — check for redundant calls).
- [ ] Pure greeting ("hi", "namaste") → model should call zero tools and just reply warmly, per the existing GREETING-path style rule.
- [ ] Climate/historical query ("Delhi mein August mein average barish kitni hoti hai?") → model should call `evaluate_climate_trend` with the correct month number inferred from "August".
- [ ] Fallback path: temporarily break `GEMINI_API_KEY` or force an exception in one tool wrapper, confirm the chat endpoint falls back gracefully instead of 500ing (per Section 6's fallback requirement).
- [ ] Compare `tools_called` list in the response against the old pipeline's `tools_called` list for the same test queries — should be equal or a reasonable subset, not wildly different.

---

## 8. Files touched (summary)

| File | Change |
|---|---|
| `app/services/llm/gemini_tools.py` | **NEW** — thin async wrapper functions for AFC, one per `tool_registry` method |
| `app/services/llm/gemini_service.py` | **REWRITE** `process_chat()` per Steps 3-5; keep everything else |
| `app/services/llm/tool_registry.py` | UNCHANGED — reused as-is |
| `app/services/llm/query_understanding_engine.py` | UNCHANGED — kept as fallback only, per Section 6 |
| `app/services/llm/query_parser.py` | UNCHANGED — kept as deepest fallback, per Section 6 |
| `app/services/advisory/*.py`, `climate_trend_service.py` | UNCHANGED — logic reused via `tool_registry` |
