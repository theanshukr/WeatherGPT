# WeatherGPT — SIH Completion Plan

**Purpose:** Close the gap between the current codebase and the SIH problem
statement ("WeatherGPT: Conversational AI for Weather Forecasting, Alerts,
and Climate Information"), in priority order, with realistic effort.

**How to read this file:** Each item has a Status, why it matters for
evaluation, what to actually build, and an effort estimate. Work top to
bottom — items are ordered by (evaluator visibility × current gap size),
not by ease. Check items off as they land. This file is the single source
of truth for "what's left" — update it as you go instead of re-deriving
scope from memory.

Effort estimates assume one person working solo, already familiar with
this codebase.

---

## Legend

- ❌ Not started — 🔶 Partially built — ✅ Done
- Priority: **P0** (evaluator will notice immediately) / **P1** (matters for
  demo depth) / **P2** (nice-to-have, do if time remains)

## Status at a glance (updated 2026-08-23, this session)

| # | Item | Status |
|---|------|--------|
| 1 | LLM query understanding | ✅ Done |
| 2 | Real alert source | 🔶 Blocked on external NDMA identifier; everything buildable is built |
| 3 | New use-case persona (smart city) | 🔶 3/5 SIH use cases (aviation, marine still 0/2 by design) |
| 4 | Historical/climate trend | ✅ Done, incl. chat wiring |
| 5 | Postgres persistence | ✅ Done, not yet live-DB verified |
| 6 | On-device TTS fallback | ✅ Done, not yet compiled/run |
| 7 | Dockerfile + docker-compose | ✅ Done, not yet run against real Docker |
| 8 | GIS/map view | ❌ Not started |
| 9 | Redis round-trip cleanup | ❌ Not started |
| 10 | CORS lockdown + secrets | ✅ Done |

**Bottom line:** every P0/P1 item is now built (#2's remaining piece is
external, not code). What's left is P2 polish (#8, #9) and — most
importantly — **running the unverified items against real
infrastructure**, since several sessions in a row have built correct-
looking code without a live Docker/Postgres/Gemini environment to
confirm it against.

---

## P0 — Core requirement gaps (do these first)

### 1. ✅ LLM-based query understanding engine — DONE
**What was built:**
- New `app/services/llm/query_understanding_engine.py` — Gemini structured
  JSON-mode extractor (`LLMQueryUnderstandingEngine.parse_query`), reusing
  a singleton Gemini client (not recreated per request).
- `gemini_service.py` now calls this as the PRIMARY path instead of the
  regex parser.
- The old regex parser (`query_parser.py` / `QueryUnderstandingService`)
  is kept and used as an automatic fallback inside the new engine — if
  Gemini errors, times out, or returns malformed JSON, it transparently
  falls back to regex instead of breaking the chat turn.
- Fixed the "silently defaults to Delhi" bug as part of this: when no
  location can be determined (LLM says null, no context to inherit from),
  the system prompt now tells Megha to say she's guessing and ask the
  user to confirm, instead of answering confidently for the wrong city.

**Still worth doing later:** collect a small set of real user queries from
testing and spot-check the LLM extractor's accuracy vs. the old regex
parser, especially for non-Indian cities and mixed-language queries.

---



### 2. 🔶 Real alert / early-warning source — PARTIALLY DONE (documented limitation)

**What was found:** NDMA's SACHET portal does have a real, documented CAP
XML feed (`sachet.ndma.gov.in/cap_public_website/FetchXMLFile?identifier=...`
with ETag caching, per their published Integration Guide for Agencies).
**However the `identifier` parameter is agency-specific and not published
publicly** — it requires registering as a consuming agency with NDMA/C-DOT.
No public self-serve identifier could be found. This is the schedule risk
this plan flagged in advance, and it materialized.

**What was built instead of faking it:**
- `app/services/alerts/official_alert_client.py` — a REAL client built
  against NDMA's actual documented protocol (CAP XML parsing, ETag
  caching, correct endpoint). It's wired and ready but safely returns `[]`
  and logs a clear one-time warning until `OFFICIAL_ALERT_IDENTIFIER` is
  set in `.env`. If/when an identifier is obtained (by contacting
  NDMA/C-DOT), this starts working with zero other code changes.
- `SevereAlert` (in `weather_processor.py`) now carries a `source` field
  (`"computed_forecast_threshold"` vs `"ndma_sachet_cap"`) so alerts are
  never presented with false authority.
- New `/weather/alerts/source-status` endpoint reports honestly which
  source(s) are active — useful to show a judge/demo audience the real
  state rather than claiming something that isn't true.
- **The dead WebSocket broadcast is now connected:**
  `app/services/alerts/alert_poller.py` is a background task (started in
  `main.py`'s lifespan) that polls both the official source (currently
  empty) and computed thresholds for a watched-city list every
  `ALERT_POLL_INTERVAL_SECONDS` (default 300s), and calls
  `ConnectionManager.broadcast()` for any new HIGH/SEVERE alert. This was
  previously defined but never invoked anywhere — now it actually fires.

**Still to do if an identifier is obtained:**
- Set `OFFICIAL_ALERT_IDENTIFIER` in `.env` — no code changes needed.
- Consider replacing the fixed `WATCHED_CITIES` list in `alert_poller.py`
  with active user sessions' locations once there's a way to enumerate
  them (currently no such registry exists).
- Persist alerts to a DB table instead of only in-memory ETag cache, if
  alert history/audit matters for the demo.

**Also fixed while in this area:** the CORS `allow_origin_regex` that
defeated the origin allowlist (flagged in the earlier code review) — was a
one-line fix in the same file (`main.py`) touched for the poller wiring.

---

### 3. 🔶 Aviation, marine, smart-city, climate-analytics use cases — SMART CITY DONE
**Why it matters:** SIH lists 5 use cases; only "farmer" and "traveler"
exist originally. A judge scanning use cases will see coverage grow as
more are added.

**What was built (smart-city persona, per this plan's own recommendation):**
- `app/services/advisory/urban_engine.py` — waterlogging/drainage risk,
  heat-index warnings for outdoor/gig workers, wind-driven traffic
  disruption risk, following the `travel_engine.py`/`farming_engine.py`
  pattern.
- `urban_worker` persona wired end-to-end: signal extraction, confidence
  tracking, personalization context, `persona_engine.py` defaults.
- `UrbanAdvisoryData` schema + `urban_advisory` field on
  `ChatMessageResponse`; `evaluate_urban_conditions` tool; `URBAN_ADVISORY`
  intent wired into `gemini_service.py` with prompt block + suggestion
  chips.

**Still not built (by design):** Aviation and marine use cases —
documented as future work needing domain data (METAR/TAF, marine wave
forecasts) this project doesn't have. Faking domain-specific safety
guidance was judged worse than not having it. **3/5 SIH use cases now
covered** (farmer, traveler, smart city); aviation and marine remain 0/2.

**Effort:** ~1 day. (spent)

---

## P1 — Strengthens what's already built

### 4. ✅ Historical / climate trend analysis — DONE (incl. chat wiring)
**What was built:**
- `open_meteo_service.py` — `get_historical_daily()` against Open-Meteo's
  Historical Weather (Archive) API.
- `climate_trend_service.py` — aggregates N years of a given month
  (mean/max/min rainfall, avg temp max/min, common condition, simple
  increasing/decreasing/stable trend).
- Standalone `GET /weather/climate-trend?city=...&month=...&years_back=10`.
- **Chat/LLM path (closes the gap an earlier pass left open):**
  `ClimateTrendData` schema + `climate_trend` field on
  `ChatMessageResponse`; `evaluate_climate_trend` tool_registry method;
  regex-fallback parser extended with month/year extraction;
  `query_understanding_engine.py`'s Gemini schema extended with
  `target_month`/`years_back`; `gemini_service.py` invokes the trend
  service on the `CLIMATE_TREND` intent and narrates it via a dedicated
  prompt block + suggestion chips.

**Not done:** No automated test, and not yet run against a live Gemini
key — smoke-test with "What's the average rainfall in Mumbai in July
over the last 10 years?" before a demo. Regex-fallback month detection
only recognizes English month names (the LLM path has no such
limitation).

**Effort:** ~0.5–1 day. (spent)

---

### 5. ✅ User persistence contradiction (Postgres vs Redis-only) — DONE
**What was built:**
- `core/database.py`'s `init_db()` now locally imports `app.models`
  before `Base.metadata.create_all()`, so `User`/`ChatSession`/
  `ChatMessage`/`CachedWeather` tables actually register and get created
  (previously a silent no-op).
- `persona_engine.py` — `get_profile`/`save_profile` write-through:
  read order Redis → local cache → Postgres → fresh profile; writes hit
  both Redis and Postgres; Postgres failures are caught and logged at
  debug level without breaking a chat turn (fail-open, matching the
  existing Redis philosophy).

**Verified this session:** Code reviewed line-by-line — field mapping
between `UserProfileState` and the `User` SQLAlchemy model is consistent,
session handling is correctly scoped, and both files parse cleanly.
**Still not verified against a live Postgres instance** (no Docker daemon
in this environment) — run the smoke test below before a demo:
`docker-compose up postgres` → run backend → send a persona-triggering
chat message → confirm a row appears in `users`.

**Effort:** ~0.5 day. (spent)

---

### 6. ✅ Local/on-device TTS fallback (cost + offline reliability) — DONE
**What was found first:** No TTS/voice playback existed in the Flutter
app at all — the "Speak" button referenced in a code comment was never
implemented, and the Settings "Voice Auto-Speech" toggle only set local
widget state with nothing reading it. Sarvam TTS existed only as an
unused backend endpoint (`/voice/tts`). This was a bigger gap than
originally scoped ("add a fallback" implied a working primary path).

**What was built:**
- `flutter_tts` (on-device, offline, default) + `just_audio` (plays the
  Sarvam response's base64 audio) added to `pubspec.yaml`.
- New `services/voice_service.dart` — single class wrapping both engines
  so only one can ever play at a time; `speak()` returns success/failure
  so callers can detect a failed natural-voice request.
- New `providers/voice_provider.dart` — app-wide state (auto-speech
  on/off, natural-voice opt-in, currently-speaking message id);
  automatically falls back to on-device TTS if a natural-voice request
  fails (e.g. missing Sarvam API key), so a reply is never silently
  dropped.
- `widgets/chat_message_view.dart` — real "Speak"/"Stop" button per
  assistant message (was previously Copy-only despite the comment); new
  messages auto-speak once finished streaming if the setting is on.
- `screens/settings_screen.dart` — "Voice Auto-Speech Feedback" toggle
  now wired to real state; new "Natural Voice (Cloud)" toggle added as
  the explicit opt-in for Sarvam, defaulting **off** (on-device is
  default, per the plan).
- `main.dart` — `VoiceProvider` registered app-wide.

**Not done:** No Flutter/Dart toolchain was available in this
environment to run `flutter analyze` or `flutter pub get` — changes were
reviewed manually (import correctness, bracket/paren balance, provider
signatures) but not compiled. Run `flutter pub get && flutter analyze`
before relying on this in a demo. STT (voice input) was already
unconnected before this session and remains so — out of scope for #6,
which is about TTS/output only.

**Effort:** ~0.5 day, ended up closer to ~1 day given the missing
baseline integration. (spent)

---

## P2 — Polish / do if time remains

### 7. ✅ Backend Dockerfile + full docker-compose — DONE
- `backend/Dockerfile` (python:3.11-slim, `EXPOSE 8000`, runs
  `uvicorn app.main:app`).
- `docker-compose.yml` — `backend` service builds from `./backend`,
  `depends_on` postgres/redis with `condition: service_healthy`, loads
  `.env` then overrides `POSTGRES_SERVER`/`DATABASE_URL`/`REDIS_URL` to
  use compose service names, exposes port 8000.
- **Verified statically this session:** Dockerfile and compose file
  structure reviewed and correct. **Not run against a live Docker
  daemon** (none available in this environment) — do one real
  `docker-compose up` before demo day.
**Effort:** ~0.25 day. (spent)

### 8. ❌ Basic GIS/map view in the app
SIH tech stack suggests GIS tools; currently no map visualization
anywhere (just text + cards). A simple map screen showing the alert
locations / current location would visually strengthen the demo.
**Effort:** ~0.5–1 day (Flutter `google_maps_flutter` or `flutter_map`).
**Still not started.**

### 9. 🔶 Redis round-trip / redundant API call cleanup
Performance-only, not evaluator-visible in a demo, but worth doing before
final submission so a live demo doesn't feel laggy under judges' questions
(each chat turn currently does ~5 Redis round trips + the `/weather/*`
endpoints triple-fetch the same data). See earlier code review notes.
**Effort:** ~0.5 day. **Still not started** — deliberately not touched
this session; it's a cross-cutting perf refactor better done with tests
in place rather than guessed at blind.

### 10. ✅ CORS lockdown + secret rotation — DONE
- `main.py`'s `allow_origin_regex=r"https?://.*"` (which defeated the
  origin allowlist when combined with `allow_credentials=True`) has been
  removed; only the explicit `allow_origins` list is trusted.
- Repo now only ships `.env.example` with placeholder values — no live
  `.env` with real keys is committed.
**Effort:** ~0.25 day. (spent)

---

## Suggested order of execution (remaining work only)

1. **Run the three unverified pieces against real infrastructure** —
   this is the actual highest-priority item now, not new feature work:
   - `docker-compose up` end-to-end (backend container builds, reaches
     Postgres/Redis by service name, `GET /health` responds).
   - Postgres write-through: send a persona-triggering chat message,
     confirm a row lands in `users`.
   - `flutter pub get && flutter analyze` on the frontend, then a real
     device/emulator run to confirm the Speak button and auto-speech
     actually produce audio.
   - `CLIMATE_TREND` chat path with a live Gemini key.
2. GIS/map view (#8) — visual demo strengthener, P2.
3. Redis round-trip cleanup (#9) — do this with tests in place, not
   blind, since it touches many call sites.
4. If time remains: attempt registering with NDMA/C-DOT for a real
   `OFFICIAL_ALERT_IDENTIFIER` (#2's one remaining gap, external/non-code).

## Total estimated remaining effort

All P0/P1 feature work is built. Remaining effort is now dominated by
**verification, not construction**: roughly 0.5–1 day to run the four
smoke tests above (assuming no bugs surface), plus ~1–1.5 days for P2
polish (#8 GIS view, #9 Redis cleanup) if time allows. If a smoke test
does surface a bug, budget extra time — several sessions of code review
without live infrastructure means this is the first real test of
whether the "done" items actually work end-to-end.
