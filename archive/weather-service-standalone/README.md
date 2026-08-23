# M3 Meteorological & Weather Data Integration Service

**Role**: M3 — Meteorological / Weather Data Integration Engineer  
**Platform**: Conversational AI Weather Mobile Application  
**Authoritative Standards & Sources**:
- **Open-Meteo API**: [https://open-meteo.com/](https://open-meteo.com/) (Official documentation: [https://open-meteo.com/en/docs](https://open-meteo.com/en/docs))
- **World Meteorological Organization (WMO)**: [https://wmo.int/](https://wmo.int/) & [WIS 2.0 Guide](https://community.wmo.int/site/knowledge-hub/programmes-and-initiatives/wmo-information-system-wis/about-guide-wis2-volume-ii)
- **Open Geospatial Consortium (OGC)**: [https://www.ogc.org/standards/](https://www.ogc.org/standards/)

---

## 1. System Architecture & Component Boundary

In the 5-tier conversational AI weather platform, **M3** is solely responsible for meteorological data acquisition, geographic coordinates validation, telemetry normalization, physical plausibility checking, and providing standardized data contracts for **M2 (FastAPI Backend)** and **M4 (Conversational AI / LLM)**.

```
+-----------------------------------------------------------------------------+
|                          END-USER MOBILE APPLICATION                        |
|                            (M1 - Flutter Mobile)                            |
+-----------------------------------------------------------------------------+
                                       │
                                       ▼ (User Query / Location)
+-----------------------------------------------------------------------------+
|                            M2 FASTAPI BACKEND                               |
|          (API Gateway, Auth, Session Management, Database Persistence)      |
+-----------------------------------------------------------------------------+
            │                                                 ▲
            │ 1. Request Weather Telemetry                    │ 4. Prompt Context +
            │    (lat, lon, date, horizon)                    │    Factual Weather
            ▼                                                 ▼
+------------------------------------+      +---------------------------------+
|       M3 WEATHER DATA SERVICE      |      |      M4 CONVERSATIONAL AI       |
|  - Open-Meteo Integration Client   |      |  - Intent Parsing               |
|  - Geographic Bounds Validator     |      |  - Meteorological Grounding     |
|  - Physical Plausibility Engine    |      |  - LLM Natural Language Speech  |
|  - WMO 4677 Code Mapper            |      +---------------------------------+
|  - Unified Normalization Engine    |                        ▲
+------------------------------------+                        │
            │                                                 │
            │ 2. Normalized Weather Data ─────────────────────┘
            ▼    (M2 Full Schema & M4 Compact Factual Context)
+─────────────────────────────────────────────────────────────────────────────+
|                     AUTHORITATIVE METEOROLOGICAL SOURCES                    |
|  1. Open-Meteo (Forecast, Historical Archive, Geocoding) [Active Prototype]  |
|  2. WMO WIS 2.0 (Global Broker / MQTT Real-Time Sync)    [Roadmap]          |
|  3. OGC Standards (OGC API - Features / EDR / GeoJSON)   [Geospatial Standard]
+─────────────────────────────────────────────────────────────────────────────+
```

---

## 2. Project Folder Structure

```
weather-service/
│
├── app/
│   ├── __init__.py          # Package initialization and public exports
│   ├── config.py            # Pydantic Settings, environment variables, timeout & retry policies
│   ├── models.py            # Pydantic v2 schemas (WMO codes, coordinates, current, forecast, historical, M2/M4 models)
│   ├── validator.py         # Geographic bounds, physical plausibility, temporal checks, zero-hallucination guardrails
│   ├── normalizer.py        # Unit standardization (Celsius, km/h, hPa, mm, %), WMO code descriptions, M2/M4 adapters
│   ├── weather_api.py       # Asynchronous HTTP client with connection pooling, retries, exponential backoff
│   └── main.py              # Standalone FastAPI service and mountable APIRouter for M2
│
├── tests/
│   ├── __init__.py
│   ├── conftest.py          # Pytest fixtures and mock Open-Meteo payloads
│   ├── test_validator.py    # Unit tests for geographic coordinates, physical limits, date boundaries
│   ├── test_normalizer.py   # Unit tests for unit consistency, WMO code mapping, cardinal directions, M2/M4 schemas
│   ├── test_weather.py      # Client tests (respx mocked HTTP 200, 400, 429, 500, retries, timeouts, malformed JSON)
│   └── test_api_endpoints.py# Integration tests for FastAPI endpoints via TestClient
│
├── requirements.txt         # Runtime and test dependencies
└── README.md                # Comprehensive documentation
```

---

## 3. Data Validation & Normalization Rules

### A. Zero Hallucination & Zero Fake Data Policy
- Weather data must **never** be fabricated or silently replaced with default values if missing.
- Incomplete variables remain `None` / `null` with warning diagnostics.
- Out-of-bounds inputs (e.g., latitude $> 90^{\circ}$) immediately reject with a structured `400 Bad Request`.

### B. Geographic Validation (WGS 84 / EPSG:4326)
- **Latitude**: $-90.0 \le \text{lat} \le +90.0$
- **Longitude**: $-180.0 \le \text{lon} \le +180.0$

### C. Physical Plausibility Checks
| Meteorological Variable | Valid Range | Standardized Unit | Notes |
| :--- | :--- | :--- | :--- |
| **Temperature** | $-100.0^\circ\text{C}$ to $+65.0^\circ\text{C}$ | Celsius ($^\circ\text{C}$) | Standard at 2m above ground |
| **Relative Humidity** | $0\%$ to $100\%$ | Percentage ($\%$) | Physical relative humidity |
| **Atmospheric Pressure** | $800.0\,\text{hPa}$ to $1100.0\,\text{hPa}$ | Hectopascal ($\text{hPa}$) | Sea-level ($MSL$) / Surface |
| **Precipitation / Rain** | $\ge 0.0\,\text{mm}$ | Millimeter ($\text{mm}$) | Negative values clamped to $0.0$ |
| **Wind Speed / Gusts** | $0.0\,\text{km/h}$ to $450.0\,\text{km/h}$ | Kilometers per hour ($\text{km/h}$) | Standard at 10m above ground |
| **Wind Direction** | $0^\circ$ to $360^\circ$ | Degrees ($^\circ$) & Cardinal ($\text{N, NE, ...}$) | $0^\circ = \text{North}, 180^\circ = \text{South}$ |
| **Cloud Cover** | $0\%$ to $100\%$ | Percentage ($\%$) | Total cloud cover fraction |
| **Timestamps** | ISO-8601 UTC | `YYYY-MM-DDTHH:MM:SSZ` | Explicit UTC $Z$ timezone indicator |

### D. WMO Weather Code Standard (WMO Code Table 4677)
Open-Meteo returns numeric weather codes based on WMO 4677. M3 maps these into clear descriptions:
- `0`: Clear sky
- `1`: Mainly clear
- `2`: Partly cloudy
- `3`: Overcast
- `45`: Fog
- `48`: Depositing rime fog
- `51`, `53`, `55`: Drizzle (Light, Moderate, Dense)
- `61`, `63`, `65`: Rain (Slight, Moderate, Heavy)
- `71`, `73`, `75`: Snow fall (Slight, Moderate, Heavy)
- `80`, `81`, `82`: Rain showers (Slight, Moderate, Violent)
- `95`, `96`, `99`: Thunderstorm (Moderate, with Hail)

---

## 4. M3 ↔ M2 Integration Contract

M2 can interact with M3 in two ways:
1. **As a Sub-Router** (In-process): Import `from app.main import router as m3_weather_router` and mount via `app.include_router(m3_weather_router)`.
2. **As an HTTP Microservice**: Call M3's REST API.

### Endpoints

#### 1. `GET /api/v1/weather/current`
- **Parameters**:
  - `latitude` (float, required): $-90.0 \dots 90.0$
  - `longitude` (float, required): $-180.0 \dots 180.0$
  - `location_name` (string, optional): Human-readable name
- **Success Response (200 OK)**:
```json
{
  "status": "success",
  "source": "Open-Meteo",
  "retrieved_at_utc": "2026-08-23T03:14:32Z",
  "location": {
    "name": "Delhi",
    "latitude": 28.576448,
    "longitude": 77.18678,
    "elevation_m": 216.0,
    "timezone": "Asia/Kolkata"
  },
  "current": {
    "timestamp": "2026-08-23T03:00:00Z",
    "temperature_c": 26.9,
    "apparent_temperature_c": 32.6,
    "humidity_percent": 88,
    "precipitation_mm": 0.0,
    "rain_mm": 0.0,
    "showers_mm": 0.0,
    "snowfall_cm": 0.0,
    "weather_code": 1,
    "weather_description": "Mainly clear",
    "cloud_cover_percent": 20,
    "pressure_hpa": 1002.2,
    "surface_pressure_hpa": 978.4,
    "wind_speed_kmh": 5.5,
    "wind_direction_deg": 225,
    "wind_direction_cardinal": "SW",
    "wind_gusts_kmh": 12.0,
    "visibility_m": 6000.0,
    "is_day": true,
    "uv_index": 0.0
  },
  "forecast_hourly": null,
  "forecast_daily": null,
  "historical_daily": null,
  "metadata": {
    "generationtime_ms": 0.045,
    "utc_offset_seconds": 19800,
    "elevation": 216.0
  }
}
```

#### 2. `GET /api/v1/weather/forecast`
- **Parameters**:
  - `latitude` (float, required), `longitude` (float, required)
  - `forecast_days` (int, optional, default=7, min=1, max=16)
- **Response**: Includes `current`, `forecast_hourly` (time series), and `forecast_daily` (daily summaries with `temp_max_c`, `temp_min_c`, `precipitation_probability_max_percent`, `sunrise`, `sunset`).

#### 3. `GET /api/v1/weather/historical`
- **Parameters**:
  - `latitude` (float, required), `longitude` (float, required)
  - `start_date` (YYYY-MM-DD, required): $\ge 1940-01-01$
  - `end_date` (YYYY-MM-DD, required): $\le \text{today}$
- **Response**: Returns `historical_daily` observation time series.

#### 4. `GET /api/v1/weather/geocode`
- **Parameters**:
  - `query` (string, required): City or locality name (e.g. "Tokyo", "London")
  - `count` (int, optional, default=5, max=20)
- **Response**: Array of `GeocodingResult` objects with `latitude`, `longitude`, `country`, `admin1`, `timezone`.

---

## 5. M3 ↔ M4 Conversational AI Data Contract

### Design Purpose
LLMs hallucinate when fed unstructured text or overloaded payloads. M4 requires a **high-density, factual context** that provides strictly the necessary meteorological facts with zero unnecessary tokens.

### Endpoint: `GET /api/v1/weather/m4-context`
- **Query Params**: `latitude`, `longitude`, `location_name` (optional)
- **Payload Schema (`M4WeatherContext`)**:
```json
{
  "location": "Delhi, India",
  "coordinates": [28.576448, 77.18678],
  "as_of_utc": "2026-08-23T03:00:00Z",
  "temperature_c": 26.9,
  "feels_like_c": 32.6,
  "condition": "Mainly clear",
  "humidity_pct": 88,
  "rain_mm": 0.0,
  "rain_probability_pct": 61,
  "wind_kmh": 5.5,
  "wind_direction": "SW",
  "pressure_hpa": 1002.2,
  "cloud_cover_pct": 20,
  "uv_index": null,
  "forecast_24h": {
    "temp_min_c": 24.3,
    "temp_max_c": 32.1,
    "expected_condition": "Rain showers: Moderate",
    "max_rain_probability_pct": 61,
    "precipitation_expected_mm": 10.7
  },
  "source": "Open-Meteo / WMO"
}
```

### M4 LLM Utilization Example
- **M3 Input to LLM System Prompt**:
  `[WEATHER_FACTS]: {"location": "Delhi, India", "temperature_c": 26.9, "condition": "Mainly clear", "rain_probability_pct": 61, "forecast_24h": {"expected_condition": "Rain showers: Moderate"}}`
- **User Query**: "Do I need an umbrella in Delhi today?"
- **M4 Answer**: "Currently in Delhi it's mainly clear and 26.9°C, but there is a 61% chance of moderate rain showers later today. I recommend carrying an umbrella!"

---

## 6. Error Handling Strategy

Standardized HTTP error envelope returned for all failure scenarios:

```json
{
  "status": "error",
  "error_code": "INVALID_LATITUDE_RANGE",
  "message": "Latitude 999.0 is out of valid range [-90.0, 90.0].",
  "details": {
    "latitude": 999.0,
    "valid_range": [-90.0, 90.0]
  },
  "timestamp": "2026-08-23T03:14:32.123456Z"
}
```

### Handled Error Scenarios
- `MISSING_COORDINATES` (400): Coordinates omitted.
- `INVALID_LATITUDE_RANGE` / `INVALID_LONGITUDE_RANGE` (400): Values outside $[-90, 90]$ or $[-180, 180]$.
- `INVALID_DATE_FORMAT` / `INVALID_DATE_CHRONOLOGY` (400): Bad YYYY-MM-DD or start date after end date.
- `DATE_PRIOR_TO_ARCHIVE_EPOCH` (400): Dates before 1940.
- `BAD_REQUEST_PARAMETERS` (400): Open-Meteo parameter rejection.
- `RATE_LIMIT_EXCEEDED` (429): Upstream throttle reached.
- `UPSTREAM_SERVER_ERROR` (502): Open-Meteo 5xx error after 3 retries.
- `UPSTREAM_TIMEOUT` (504): Network timeout exceeding 10 seconds.
- `INVALID_JSON_RESPONSE` (502): Non-JSON payload received from upstream.

---

## 7. WMO WIS 2.0 Integration Roadmap

### Context & Standard
The **World Meteorological Organization (WMO) Information System 2.0 (WIS 2.0)** is the modern global data-sharing framework for real-time exchange of meteorological, hydrological, and climatological data among WMO Member States.

### Architectural Roadmap for M3 Ingestion
In future phases beyond the Open-Meteo HTTP prototype, M3 can ingest high-frequency, real-time observation bulletins directly via WIS 2.0:

```
[WMO Global Broker / Node]
          │
          │ (MQTT Subscription: origin/a/wis2/{centre-id}/data/core/...)
          ▼
[M3 WIS 2.0 Ingestion Worker]
          │
          │ 1. Receives WMO Core Profile 2.0 JSON notification
          │ 2. Downloads payload (WMO BUFR / GRIB2 / GeoJSON)
          ▼
[M3 Meteorological Decoder & Normalizer]
          │
          │ Standardizes observations into M3 Unified Schema
          ▼
[PostgreSQL Telemetry Cache] ──▶ [M2 Backend / M4 AI]
```

1. **Protocol**: Secure MQTT (TLS over port 8883) subscribing to Global Broker topics following the standard topic hierarchy: `origin/a/wis2/{centre-id}/data/core/weather/...`.
2. **Notification Envelope**: WMO Core Profile metadata message containing metadata, geographic bounding box, and download URL (`canonical` HTTP link) to observation payload.
3. **Payload Formats**: Decodes standard WMO BUFR (Binary Universal Form for Representation of meteorological data), GRIB2, and OGC GeoJSON-FG.
4. **Resilience**: Operates an asynchronous background worker with automatic reconnect and message deduplication.

---

## 8. Open Geospatial Consortium (OGC) Standards

M3 strictly aligns geospatial data representations with OGC standards:

1. **OGC API - Features & OGC API - Environmental Data Retrieval (EDR)**:
   - Coordinates conform to the **WGS 84** (EPSG:4326) reference system.
   - Point queries follow `coords=POINT(longitude latitude)` formatting.
   - Temporal intervals follow ISO 8601 formatting (`start/end` or `instant`).
2. **GeoJSON Standard (RFC 7946)**:
   - When geospatial features are shared with M1/M2 for map rendering, coordinate arrays adhere to `[longitude, latitude, elevation]`.

---

## 9. PostgreSQL Database Schema Design

For persistent caching and historical telemetry storage in M2's database:

```sql
-- 1. Locations Table
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    country VARCHAR(100),
    country_code VARCHAR(2),
    admin1 VARCHAR(150),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    elevation_m DOUBLE PRECISION,
    timezone VARCHAR(100) DEFAULT 'UTC',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_lat CHECK (latitude BETWEEN -90.0 AND 90.0),
    CONSTRAINT chk_lon CHECK (longitude BETWEEN -180.0 AND 180.0)
);
CREATE INDEX idx_locations_coords ON locations(latitude, longitude);

-- 2. Weather Observations Table (Current telemetry)
CREATE TABLE weather_observations (
    id BIGSERIAL PRIMARY KEY,
    location_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    observed_at TIMESTAMPTZ NOT NULL,
    temperature_c REAL NOT NULL,
    apparent_temperature_c REAL,
    humidity_percent SMALLINT CHECK (humidity_percent BETWEEN 0 AND 100),
    pressure_hpa REAL CHECK (pressure_hpa BETWEEN 800.0 AND 1100.0),
    precipitation_mm REAL CHECK (precipitation_mm >= 0.0),
    rain_mm REAL CHECK (rain_mm >= 0.0),
    weather_code SMALLINT,
    weather_description VARCHAR(100),
    cloud_cover_percent SMALLINT CHECK (cloud_cover_percent BETWEEN 0 AND 100),
    wind_speed_kmh REAL CHECK (wind_speed_kmh >= 0.0),
    wind_direction_deg SMALLINT CHECK (wind_direction_deg BETWEEN 0 AND 360),
    wind_gusts_kmh REAL,
    visibility_m REAL,
    is_day BOOLEAN,
    uv_index REAL,
    data_source VARCHAR(50) DEFAULT 'Open-Meteo',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (location_id, observed_at)
);
CREATE INDEX idx_observations_loc_time ON weather_observations(location_id, observed_at DESC);

-- 3. Weather Forecasts Table (Aggregated daily projections)
CREATE TABLE weather_forecasts (
    id BIGSERIAL PRIMARY KEY,
    location_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    forecast_generated_at TIMESTAMPTZ NOT NULL,
    forecast_target_date DATE NOT NULL,
    temp_min_c REAL,
    temp_max_c REAL,
    precipitation_sum_mm REAL CHECK (precipitation_sum_mm >= 0.0),
    precipitation_probability_max SMALLINT CHECK (precipitation_probability_max BETWEEN 0 AND 100),
    weather_code SMALLINT,
    weather_description VARCHAR(100),
    wind_speed_max_kmh REAL,
    sunrise TIMESTAMPTZ,
    sunset TIMESTAMPTZ,
    data_source VARCHAR(50) DEFAULT 'Open-Meteo',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (location_id, forecast_generated_at, forecast_target_date)
);

-- 4. Weather Alerts Table
CREATE TABLE weather_alerts (
    id BIGSERIAL PRIMARY KEY,
    location_id INTEGER REFERENCES locations(id) ON DELETE CASCADE,
    event_name VARCHAR(255) NOT NULL,
    severity VARCHAR(50),
    headline TEXT,
    description TEXT,
    effective_from TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    source VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_alerts_active ON weather_alerts(location_id, expires_at);
```

---

## 10. Security & Operational Recommendations

1. **API Key Protection**: Optional commercial keys (`OPEN_METEO_API_KEY`) are read strictly from environment variables or `.env`. Never commit secrets to source control.
2. **TLS 1.3 Encryption**: All upstream network requests to Open-Meteo utilize HTTPS with strict certificate validation (`certifi`).
3. **Connection Pooling & Lifespan**: Single shared `httpx.AsyncClient` managed via FastAPI lifespan to prevent socket leaks and file descriptor exhaustion.
4. **Rate Limit Buffer & Cache**: Implement Redis or in-memory caching (TTL 10-15 minutes for current observations) at M2 gateway to preserve API quotas.
5. **Circuit Breaking**: Automatic exponential backoff with a maximum of 3 retries to prevent thundering herd problems during upstream outages.
6. **Input Sanitization**: Numeric casting and strict Pydantic / boundary validation on all coordinates to prevent parameter injection.

---

## 11. Setup, Running & Verification Guide

### Prerequisites
- Python 3.10+ (Tested on Python 3.12.10)

### Installation
```bash
cd weather-service
pip install -r requirements.txt
```

### Running the Test Suite
Run the 44-test pytest suite:
```bash
pytest -v
```

### Running the FastAPI Server
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Interactive Swagger Documentation available at: [http://localhost:8000/docs](http://localhost:8000/docs)

### Sample API Requests (cURL)

#### 1. Current Weather (Delhi)
```bash
curl -X GET "http://localhost:8000/api/v1/weather/current?latitude=28.6139&longitude=77.2090&location_name=Delhi"
```

#### 2. M4 LLM Factual Prompt Context (Delhi)
```bash
curl -X GET "http://localhost:8000/api/v1/weather/m4-context?latitude=28.6139&longitude=77.2090&location_name=Delhi,%20India"
```

#### 3. 7-Day Forecast (London)
```bash
curl -X GET "http://localhost:8000/api/v1/weather/forecast?latitude=51.5074&longitude=-0.1278&forecast_days=7&location_name=London"
```

#### 4. Historical Archive (Tokyo, Jan 2023)
```bash
curl -X GET "http://localhost:8000/api/v1/weather/historical?latitude=35.6762&longitude=139.6503&start_date=2023-01-01&end_date=2023-01-07&location_name=Tokyo"
```

#### 5. Geocode Search
```bash
curl -X GET "http://localhost:8000/api/v1/weather/geocode?query=Delhi&count=5"
```
