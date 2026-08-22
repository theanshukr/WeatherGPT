WEATHERGPT – DATA MODEL

1. USERS

Table: users

- id: UUID (Primary Key)
- phone: VARCHAR
- email: VARCHAR
- password_hash: VARCHAR
- name: VARCHAR
- preferred_language: VARCHAR
- timezone: VARCHAR
- status: ENUM (active, inactive, blocked)
- created_at: TIMESTAMP
- updated_at: TIMESTAMP


2. USER PROFILES

Table: user_profiles

- id: UUID (Primary Key)
- user_id: UUID (Foreign Key → users)
- age_group: VARCHAR
- occupation: VARCHAR
- interests: JSONB
- ai_detected_role: VARCHAR
- profile_confidence: DECIMAL
- created_at: TIMESTAMP
- updated_at: TIMESTAMP

Example roles:
- Farmer
- Traveller
- Student
- General User


3. LOCATIONS

Table: locations

- id: UUID (Primary Key)
- name: VARCHAR
- country_code: VARCHAR
- state: VARCHAR
- district: VARCHAR
- latitude: DECIMAL
- longitude: DECIMAL
- elevation: DECIMAL
- timezone: VARCHAR
- created_at: TIMESTAMP


4. USER LOCATIONS

Table: user_locations

- id: UUID (Primary Key)
- user_id: UUID (Foreign Key → users)
- location_id: UUID (Foreign Key → locations)
- name: VARCHAR
- is_primary: BOOLEAN
- is_current: BOOLEAN
- created_at: TIMESTAMP

Examples:
- Home
- Farm
- Office
- Current Location
- Favourite Location


5. CURRENT WEATHER

Table: weather_current

- id: UUID (Primary Key)
- location_id: UUID (Foreign Key → locations)
- observed_at: TIMESTAMP
- temperature: DECIMAL
- feels_like: DECIMAL
- humidity: DECIMAL
- pressure: DECIMAL
- wind_speed: DECIMAL
- wind_direction: DECIMAL
- rainfall: DECIMAL
- visibility: DECIMAL
- uv_index: DECIMAL
- cloud_cover: DECIMAL
- weather_condition: VARCHAR
- source_id: UUID
- raw_data: JSONB


6. WEATHER FORECASTS

Table: weather_forecasts

- id: UUID (Primary Key)
- location_id: UUID (Foreign Key → locations)
- forecast_time: TIMESTAMP
- generated_at: TIMESTAMP
- temperature_min: DECIMAL
- temperature_max: DECIMAL
- rain_probability: DECIMAL
- rainfall_amount: DECIMAL
- humidity: DECIMAL
- wind_speed: DECIMAL
- wind_direction: DECIMAL
- uv_index: DECIMAL
- weather_condition: VARCHAR
- source_id: UUID

Supports:
- Hourly forecast
- Daily forecast
- 7-day forecast
- Rain probability
- Temperature trends


7. DATA SOURCES

Table: data_sources

- id: UUID (Primary Key)
- name: VARCHAR
- provider_type: VARCHAR
- api_endpoint: TEXT
- country: VARCHAR
- data_type: JSONB
- status: ENUM
- last_sync_at: TIMESTAMP
- created_at: TIMESTAMP

Possible Sources:
- IMD
- Weather APIs
- Satellite Data
- Radar Data
- WIS2.0
- Government Meteorological Data
- Forecast Models


8. WEATHER OBSERVATIONS

Table: weather_observations

- id: UUID (Primary Key)
- location_id: UUID
- source_id: UUID
- observed_at: TIMESTAMP
- temperature: DECIMAL
- humidity: DECIMAL
- pressure: DECIMAL
- rainfall: DECIMAL
- wind_speed: DECIMAL
- wind_direction: DECIMAL
- radiation: DECIMAL
- raw_data: JSONB


9. WEATHER ALERTS

Table: weather_alerts

- id: UUID (Primary Key)
- location_id: UUID
- source_id: UUID
- alert_type: VARCHAR
- severity: ENUM
- title: VARCHAR
- description: TEXT
- instructions: TEXT
- issued_at: TIMESTAMP
- starts_at: TIMESTAMP
- expires_at: TIMESTAMP
- status: ENUM
- source_alert_id: VARCHAR
- raw_data: JSONB

Alert Types:
- Thunderstorm
- Heavy Rain
- Flood
- Flash Flood
- Cyclone
- Heatwave
- Cold Wave
- Lightning
- Strong Wind
- Dust Storm
- Dense Fog
- Hailstorm


10. NOTIFICATION PREFERENCES

Table: notification_preferences

- id: UUID (Primary Key)
- user_id: UUID
- weather_alerts: BOOLEAN
- rain_alerts: BOOLEAN
- storm_alerts: BOOLEAN
- heat_alerts: BOOLEAN
- flood_alerts: BOOLEAN
- daily_forecast: BOOLEAN
- severe_weather: BOOLEAN
- quiet_hours_start: TIME
- quiet_hours_end: TIME


11. NOTIFICATIONS

Table: notifications

- id: UUID (Primary Key)
- user_id: UUID
- alert_id: UUID
- type: VARCHAR
- title: VARCHAR
- message: TEXT
- channel: ENUM
- status: ENUM
- sent_at: TIMESTAMP
- read_at: TIMESTAMP

Notification Channels:
- Push Notification
- SMS
- Email
- In-App Notification


12. AI CONVERSATIONS

Table: conversations

- id: UUID (Primary Key)
- user_id: UUID
- title: VARCHAR
- context_type: VARCHAR
- location_id: UUID
- created_at: TIMESTAMP
- updated_at: TIMESTAMP

Context Types:
- General Weather
- Farmer
- Traveller
- Disaster
- Forecast
- Location


13. AI MESSAGES

Table: messages

- id: UUID (Primary Key)
- conversation_id: UUID
- role: ENUM
- content: TEXT
- language: VARCHAR
- intent: VARCHAR
- location_id: UUID
- created_at: TIMESTAMP

Roles:
- user
- assistant
- system
- tool


14. USER AI CONTEXT

Table: user_contexts

- id: UUID (Primary Key)
- user_id: UUID
- context_type: VARCHAR
- context_data: JSONB
- confidence: DECIMAL
- source: VARCHAR
- expires_at: TIMESTAMP

Example:

{
  "role": "farmer",
  "crops": ["wheat", "rice"],
  "irrigation": true
}

Another example:

{
  "role": "traveller",
  "destination": "Manali",
  "trip_start": "2026-09-01",
  "trip_end": "2026-09-05"
}


15. FARMER PROFILE

Table: farmer_profiles

- id: UUID (Primary Key)
- user_id: UUID
- farm_location_id: UUID
- farm_size: DECIMAL
- soil_type: VARCHAR
- irrigation_type: VARCHAR


16. CROPS

Table: crops

- id: UUID (Primary Key)
- farmer_id: UUID
- crop_name: VARCHAR
- variety: VARCHAR
- sowing_date: DATE
- expected_harvest_date: DATE
- farm_location_id: UUID


17. TRIPS

Table: trips

- id: UUID (Primary Key)
- user_id: UUID
- destination_location_id: UUID
- start_date: DATE
- end_date: DATE
- status: ENUM


18. AI TOOL CALLS

Table: ai_tool_calls

- id: UUID (Primary Key)
- message_id: UUID
- tool_name: VARCHAR
- input: JSONB
- output: JSONB
- execution_time_ms: INTEGER
- status: ENUM
- created_at: TIMESTAMP


==================================================
ENTITY RELATIONSHIPS
==================================================

USER
│
├── USER_PROFILE
│
├── USER_CONTEXTS
│
├── USER_LOCATIONS
│        │
│        └── LOCATION
│               │
│               ├── WEATHER_CURRENT
│               ├── WEATHER_FORECASTS
│               └── WEATHER_ALERTS
│
├── NOTIFICATION_PREFERENCES
│
├── NOTIFICATIONS
│
├── CONVERSATIONS
│        │
│        └── MESSAGES
│               │
│               └── AI_TOOL_CALLS
│
├── FARMER_PROFILE
│        │
│        └── CROPS
│
└── TRIPS


DATA_SOURCE
│
├── WEATHER_CURRENT
├── WEATHER_FORECASTS
├── WEATHER_OBSERVATIONS
└── WEATHER_ALERTS


==================================================
RECOMMENDED DATABASE STACK
==================================================

Primary Database:
PostgreSQL

Geospatial Data:
PostGIS

Caching:
Redis

Time-Series Weather Data:
TimescaleDB Extension

AI Semantic Memory:
pgvector

Raw Meteorological Data:
Object Storage

==================================================
IMPORTANT DESIGN PRINCIPLE
==================================================

Do not store all weather data only in JSON.

Store frequently queried data as proper database columns:

- Temperature
- Humidity
- Rainfall
- Wind Speed
- Latitude
- Longitude
- Timestamp
- Alert Severity

Use JSONB only for:

- Raw API responses
- Provider-specific fields
- Flexible metadata
- AI context
- Additional meteorological information


FINAL DATA FLOW

Weather APIs / IMD / Satellite / Radar / WIS2.0
                    │
                    ▼
            Data Ingestion Layer
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
PostgreSQL + PostGIS       Raw Data Storage
         │
         ├── Weather Data
         ├── Forecast Data
         ├── Alert Data
         └── User Data
                    │
                    ▼
                  Redis
                    │
                    ▼
               WeatherGPT AI
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
   Weather      Alert Engine   AI Context
    Tools                         Engine
       │            │            │
       └────────────┼────────────┘
                    ▼
              User Response
                    │
                    ▼
             Notifications