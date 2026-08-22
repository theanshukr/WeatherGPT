WeatherGPT — Technical Design Document (TDD)

Version: 1.0
Project: WeatherGPT
Date: August 2026

1. Purpose and Scope

WeatherGPT is a mobile-first, AI-powered conversational weather intelligence platform.

The system combines:

Real-time weather data
Weather forecasting
Meteorological datasets
Severe weather and disaster warnings
AI/LLM-based natural language understanding
Location-aware intelligence
Personalized alerts
Farmer-focused assistance
Traveller-focused assistance
Multilingual support for Indian languages

The purpose of this TDD is to define the technical architecture, components, data flow, APIs, database design, AI integration, alert system, security, and deployment strategy for WeatherGPT.

2. System Goals

The WeatherGPT platform should:

Provide real-time and forecast weather information.
Allow users to ask weather questions in natural language.
Support multiple languages, including Indian languages.
Provide personalized weather intelligence.
Detect weather-related user contexts such as farming and travelling.
Deliver location-based weather and disaster alerts.
Integrate multiple weather and meteorological data sources.
Avoid hallucinating live weather information.
Support scalable real-time data ingestion.
Provide an architecture suitable for both an MVP and future production scaling.


# High Level Architecture


                         ┌─────────────────────┐
                         │    Mobile App       │
                         │ Flutter / Android   │
                         └──────────┬──────────┘
                                    │
                              HTTPS/WebSocket
                                    │
                         ┌──────────▼──────────┐
                         │    API Gateway      │
                         │ Auth / Rate Limit   │
                         └──────────┬──────────┘
                                    │
             ┌──────────────────────┼──────────────────────┐
             │                      │                      │
      ┌──────▼──────┐       ┌──────▼──────┐       ┌──────▼──────┐
      │Conversation │       │   Weather   │       │    Alert     │
      │  Service    │       │   Service   │       │    Engine    │
      └──────┬──────┘       └──────┬──────┘       └──────┬──────┘
             │                      │                      │
             └──────────────────────┼──────────────────────┘
                                    │
                         ┌──────────▼──────────┐
                         │   AI Orchestrator   │
                         │ Intent + Context    │
                         │ Tool Selection      │
                         └──────────┬──────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
       ┌──────▼──────┐      ┌──────▼──────┐      ┌──────▼──────┐
       │ Weather APIs│      │ Alert/Warning│      │ LLM Service │
       │ Data Sources│      │   Sources    │      │              │
       └──────┬──────┘      └──────┬──────┘      └─────────────┘
              │                     │
              └──────────┬──────────┘
                         │
                ┌────────▼────────┐
                │ Data Processing │
                │ Queue / Workers │
                └────────┬────────┘
                         │
            ┌────────────┼─────────────┐
            │            │             │
     ┌──────▼─────┐ ┌───▼────┐ ┌──────▼──────┐
     │ PostgreSQL │ │ Redis  │ │ Vector DB   │
     └────────────┘ └────────┘ └─────────────┘

4. Mobile Application
Recommended Technology

Flutter

Flutter is recommended because it provides:

Single codebase for Android and iOS
Faster development
Good performance
Strong multilingual support
Push notification support
Suitable for MVP and production
Mobile App Features

The application will include:

User authentication
Location permission
Current weather
Hourly forecast
Daily forecast
WeatherGPT chat
Voice input support in future versions
Weather alerts
Push notifications
Saved locations
Language selection
Farmer assistance
Traveller assistance
User preferences
5. Backend Architecture

The backend will use a modular service architecture.

Service	Responsibility
API Gateway	Authentication, validation, routing, rate limiting
Conversation Service	Chat sessions and history
AI Orchestrator	Intent detection and tool selection
Weather Service	Weather data retrieval and normalization
Alert Engine	Weather warning processing
Notification Service	Push notifications
User Service	User profile and preferences
Personalization Service	Context and user intelligence
Knowledge Service	RAG and weather knowledge retrieval
6. AI Orchestrator

The AI Orchestrator acts as the central intelligence layer.

It performs:

Intent detection
Entity extraction
Location detection
Date and time understanding
User context retrieval
Tool selection
Weather API calls
Alert lookup
RAG retrieval
Response generation
Example Flow

User asks:

Will it rain tomorrow?
User Message
      ↓
Intent Detection
      ↓
Intent = RAIN_FORECAST
      ↓
Extract Location
      ↓
Extract Date = Tomorrow
      ↓
Call Weather Tool
      ↓
Get Forecast Data
      ↓
LLM Generates Natural Response
      ↓
User

7. Intent Classification

WeatherGPT should classify user queries into intents.

WEATHER_CURRENT

WEATHER_FORECAST

RAIN_QUERY

TEMPERATURE_QUERY

WIND_QUERY

AIR_QUALITY_QUERY

SEVERE_WEATHER

DISASTER_ALERT

TRAVEL_WEATHER

FARMING_WEATHER

WEATHER_EXPLANATION

WEATHER_COMPARISON

LOCATION_CHANGE

ALERT_CONFIGURATION

GENERAL_CONVERSATION

Example:

"Should I carry an umbrella tomorrow?"

Can be interpreted as:

Intent: TRAVEL_WEATHER
Weather Need: RAIN_FORECAST
Date: Tomorrow
8. Weather Data Integration Layer

WeatherGPT should not depend directly on only one weather API.

Instead, use a provider abstraction layer.

Weather Provider A
        │
Weather Provider B
        │
Meteorological Data Source
        │
        ▼
Provider Adapter Layer
        │
        ▼
Validation
        │
        ▼
Normalization
        │
        ▼
WeatherGPT Internal Schema

This makes it possible to change or add providers without changing the rest of the application.

9. Normalized Weather Data Schema

Example:

{
  "location": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "name": "New Delhi"
  },
  "timestamp": "2026-08-23T10:00:00Z",
  "temperature": 31,
  "feels_like": 34,
  "humidity": 72,
  "wind_speed": 14,
  "precipitation_probability": 65,
  "weather_condition": "Rain",
  "visibility": 7,
  "uv_index": 6,
  "source": "weather_provider"
}

All providers should be converted into this internal format.

10. Weather Data Flow
On-Demand Request

When a user asks for weather information:

User
  ↓
WeatherGPT App
  ↓
API Gateway
  ↓
Weather Service
  ↓
Check Redis Cache
  ↓
Cache Available?
  ├── Yes → Return Data
  │
  └── No
       ↓
   Weather Provider
       ↓
   Normalize Data
       ↓
   Save in Cache
       ↓
   Return Data
11. Real-Time Data Ingestion

For continuous weather and alert processing:

Weather APIs
Meteorological Feeds
Warning Systems
        ↓
Data Ingestion Service
        ↓
Message Queue
        ↓
Data Processing Workers
        ↓
Database / Cache
        ↓
Alert Engine
        ↓
Notification Service

For MVP:

Redis Streams

For production:

Apache Kafka

MQTT or WIS2.0-compatible ingestion can be introduced if required by selected meteorological data sources.

12. LLM Tool Calling

The LLM should not directly invent weather information.

Instead:

                  User
                    ↓
                   LLM
                    ↓
             Tool Selection
                    ↓
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
 Weather Tool   Alert Tool   Location Tool
        │           │           │
        └───────────┼───────────┘
                    ↓
              Verified Data
                    ↓
                   LLM
                    ↓
             Final Response
Available Tools
get_current_weather()

get_forecast()

get_weather_alerts()

get_air_quality()

get_location_weather()

get_travel_weather()

get_farming_weather()

get_saved_locations()

create_alert()
13. Farmer Intelligence

WeatherGPT can identify farming-related context.

Example:

"Can I spray pesticide tomorrow?"

The system can detect:

User Context = Farmer

Activity = Crop Spraying

Weather Variables Required:
- Rain probability
- Wind speed
- Temperature
- Humidity
- Forecast window

Then the system retrieves weather information and provides contextual assistance.

Important principle:

Weather Data
      +
User Context
      =
Personalized Weather Intelligence

The application should clearly distinguish verified weather information from recommendations.

14. Traveller Intelligence

Example:

"I am travelling to Manali this weekend."

The system extracts:

User Type: Traveller

Destination: Manali

Travel Date: Weekend

Then WeatherGPT can retrieve:

Temperature
Rain probability
Snow conditions
Wind
Visibility
Weather warnings
Sunrise/sunset
Relevant travel weather risks

It can also proactively ask:

Would you like a weather-based travel packing checklist?

15. Personalization Engine

WeatherGPT maintains user context.

Example:

{
  "user_id": "123",
  "language": "hi",
  "home_location": {
    "lat": 26.8467,
    "lon": 80.9462
  },
  "interests": [
    "farming",
    "weather_alerts"
  ],
  "occupation_context": "farmer",
  "alert_preferences": {
    "heavy_rain": true,
    "heatwave": true,
    "storm": true
  }
}

Personalization can use:

User-selected preferences
Saved locations
Conversation context
Explicitly provided activity information
Weather interests
16. Multilingual Architecture

WeatherGPT should support multiple Indian languages without duplicating backend logic.

User Language
      ↓
Language Detection
      ↓
Intent and Entity Extraction
      ↓
Language-Neutral Internal Request
      ↓
Weather API / Tools
      ↓
Verified Data
      ↓
LLM Response Generation
      ↓
Response in User Language

Example:

Hindi Input

"कल बारिश होगी क्या?"

        ↓

Intent = RAIN_FORECAST

Date = Tomorrow

        ↓

Weather Tool

        ↓

Hindi Response

Initially, the MVP can support:

English
Hindi

Then expand to additional Indian languages.

17. RAG Knowledge Architecture

RAG should be used for stable knowledge, not live weather data.

Examples:

Weather terminology
Disaster preparedness
Safety guidance
Agricultural weather knowledge
Government guidance
Frequently asked questions

Architecture:

Documents
    ↓
Chunking
    ↓
Embeddings
    ↓
Vector Database
    ↓
Semantic Search
    ↓
Relevant Context
    ↓
LLM
    ↓
Answer
Important Rule
Current Weather → Weather API

Forecast → Weather API

Severe Alerts → Warning Sources

Weather Knowledge → RAG
18. Alert Engine

The Alert Engine continuously processes weather events.

Weather Event
      ↓
Check Affected Location
      ↓
Find Relevant Users
      ↓
Check User Preferences
      ↓
Determine Severity
      ↓
Generate Alert
      ↓
Push Notification
Alert Types
Heavy rain
Thunderstorm
Lightning
Flood
Cyclone
Heatwave
Cold wave
Strong wind
Dense fog
Poor visibility
Hailstorm
Air quality alerts
Official disaster warnings

For severe weather, authoritative warning sources should be prioritized.

19. Notification Architecture
Weather Source
      ↓
Alert Engine
      ↓
Notification Service
      ↓
Firebase Cloud Messaging
      ↓
Mobile Device

Example:

⚠ Heavy Rain Alert

Heavy rainfall is expected near your location
within the next 2 hours.
20. Database Architecture
PostgreSQL

Used for persistent application data.

Main tables:

users

user_preferences

user_locations

user_alert_preferences

conversations

messages

weather_observations

weather_forecasts

weather_alerts

notifications

farmer_profiles

traveller_profiles
21. Redis

Redis will be used for:

Weather caching
Forecast caching
Session data
Temporary conversation context
Rate limiting
Frequently accessed locations

Example cache key:

weather:{latitude}:{longitude}:current

Example:

weather:26.8467:80.9462:current

Cache duration depends on data type and provider freshness.

22. Vector Database

Recommended options:

pgvector

or

Qdrant

The vector database stores semantic embeddings for:

Weather documentation
Preparedness guides
FAQs
Safety information
Agricultural knowledge
23. API Design
Authentication
POST /api/v1/auth/register

POST /api/v1/auth/login
Weather
GET /api/v1/weather/current

GET /api/v1/weather/forecast
Chat
POST /api/v1/chat

GET /api/v1/chat/history
Alerts
GET /api/v1/alerts

POST /api/v1/alerts/preferences
User
GET /api/v1/user/profile

PUT /api/v1/user/preferences
Location
POST /api/v1/location
24. Chat Request Flow
User Message
      ↓
API Gateway
      ↓
Authentication
      ↓
Conversation Service
      ↓
AI Orchestrator
      ↓
Intent Detection
      ↓
Entity Extraction
      ↓
Retrieve User Context
      ↓
Select Tool
      ↓
Weather / Alert / RAG Tool
      ↓
Verified Context
      ↓
LLM Response Generation
      ↓
Response Validation
      ↓
User
25. WebSocket Usage

WebSockets can be used for:

Streaming AI responses
Live weather updates
Alert updates
Real-time notification status

Example:

User
  ↓
WebSocket
  ↓
AI Orchestrator
  ↓
LLM Streaming
  ↓
WebSocket
  ↓
User receives response progressively
26. Security

WeatherGPT should implement:

HTTPS/TLS
JWT authentication
OAuth or phone OTP
Input validation
Rate limiting
API key protection
Server-side secrets storage
Database access control
Role-based access
Audit logging
Encryption where required
Important Rule

Weather provider API keys must never be exposed directly inside the mobile application.

27. Error Handling

If a weather provider fails:

Weather API Request
       ↓
     Failure
       ↓
      Retry
       ↓
Fallback Provider
       ↓
If unavailable
       ↓
Use Recent Cached Data
       ↓
If no valid data
       ↓
Inform User

Example:

Live weather data is temporarily unavailable. Please try again shortly.

WeatherGPT must never invent a temperature, forecast, or weather warning when live data is unavailable.

28. Reliability Strategy

For critical weather events:

Weather Provider A
        +
Weather Provider B
        +
Official Warning Source
        ↓
Validation
        ↓
Deduplication
        ↓
Alert Engine

The system should track:

Source
Timestamp
Freshness
Validity period
Severity
29. Monitoring and Observability

Monitor:

API latency

API failures

Weather provider failures

Cache hit rate

LLM response latency

LLM errors

Token usage

Alert generation rate

Notification delivery rate

Queue processing lag

Worker health

Intent accuracy

Recommended monitoring stack:

OpenTelemetry
       +
Prometheus
       +
Grafana
30. Recommended Technology Stack
Layer	Technology
Mobile	Flutter
Backend	Python + FastAPI
AI	LLM with tool/function calling
Database	PostgreSQL
Cache	Redis
Message Queue	Redis Streams / Kafka
Vector Database	pgvector / Qdrant
Real-time	WebSocket
Notifications	Firebase Cloud Messaging
Authentication	JWT + OAuth/OTP
Containerization	Docker
Cloud	AWS / GCP / Azure
Monitoring	Prometheus + Grafana
Tracing	OpenTelemetry
31. Recommended Backend Folder Structure
backend/
│
├── app/
│   │
│   ├── main.py
│   │
│   ├── api/
│   │   ├── auth.py
│   │   ├── weather.py
│   │   ├── chat.py
│   │   ├── alerts.py
│   │   ├── users.py
│   │   └── locations.py
│   │
│   ├── services/
│   │   ├── weather_service.py
│   │   ├── ai_service.py
│   │   ├── alert_service.py
│   │   ├── notification_service.py
│   │   └── personalization_service.py
│   │
│   ├── integrations/
│   │   ├── weather_provider.py
│   │   ├── meteorological_provider.py
│   │   └── notification_provider.py
│   │
│   ├── ai/
│   │   ├── orchestrator.py
│   │   ├── intent.py
│   │   ├── tools.py
│   │   └── prompts.py
│   │
│   ├── models/
│   │
│   ├── schemas/
│   │
│   ├── repositories/
│   │
│   ├── workers/
│   │
│   └── core/
│
├── tests/
│
├── Dockerfile
│
└── requirements.txt
32. MVP Architecture

For the first version, avoid unnecessary complexity.

Flutter App
      ↓
FastAPI Backend
      ↓
AI Orchestrator
      ↓
Weather API
      ↓
PostgreSQL
      +
Redis
      ↓
LLM
      ↓
Firebase Notifications
MVP Features
User authentication
Location detection
Current weather
Forecast
Weather chat
AI tool calling
English and Hindi
Basic weather alerts
Push notifications
Traveller assistance
Farmer-focused weather assistance
PostgreSQL database
Redis caching
33. Production Architecture

As the platform grows:

                    Internet
                        │
                 Load Balancer
                        │
                   API Gateway
                        │
       ┌────────────────┼────────────────┐
       │                │                │
       ▼                ▼                ▼
 Chat Service    Weather Service    User Service
       │                │                │
       └────────────────┼────────────────┘
                        │
                      Kafka
                        │
       ┌────────────────┼────────────────┐
       │                │                │
       ▼                ▼                ▼
 Alert Engine      Data Workers      Analytics
       │
       ▼
Notification Service
       │
   FCM / APNs
34. Development Phases
Phase 1 — Foundation
Create Flutter application
Setup FastAPI backend
Setup PostgreSQL
Setup Redis
Implement authentication
Implement location handling
Phase 2 — Weather Integration
Integrate weather APIs
Create provider adapter layer
Normalize weather data
Implement caching
Phase 3 — AI
Implement AI Orchestrator
Add intent detection
Add entity extraction
Add tool calling
Implement conversational weather queries
Phase 4 — Alerts
Implement alert ingestion
Create alert rules
Add location matching
Integrate push notifications
Phase 5 — Personalization
User preferences
Saved locations
Farmer context
Traveller context
Personalized follow-up suggestions
Phase 6 — Advanced Intelligence
Multilingual expansion
RAG knowledge system
Voice support
More meteorological data sources
Phase 7 — Scale
Kafka
Distributed workers
Advanced monitoring
High availability
Admin panel
Analytics
35. Key Architectural Principle

WeatherGPT should not work like this:

User
 ↓
LLM
 ↓
Answer

Instead:

                    User
                      ↓
               AI Orchestrator
                      ↓
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
     Weather API   Alert Data   RAG Knowledge
          │           │           │
          └───────────┼───────────┘
                      ↓
               Verified Context
                      ↓
                     LLM
                      ↓
           Personalized Response
                      ↓
                    User
36. Final Technical Summary

WeatherGPT will be built as a tool-driven AI weather intelligence platform.

The architecture separates:

AI reasoning and conversation
Live weather retrieval
Meteorological data processing
Weather alert processing
Personalization
Knowledge retrieval
The LLM is responsible for understanding the user and generating natural-language responses, while verified weather services and warning sources provide the actual data.

This architecture allows WeatherGPT to evolve from a simple hackathon MVP into a scalable platform supporting real-time weather intelligence, multilingual conversations, proactive alerts, farmer assistance, traveller assistance, and personalized AI weather experiences.