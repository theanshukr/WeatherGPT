# WeatherGPT

WeatherGPT is a mobile-first, conversational AI weather assistant designed for Android and iOS using Flutter and a FastAPI backend.

## Project Structure

```
WeatherGPT/
│
├── README.md
├── .gitignore
├── .env.example
├── docker-compose.yml
│
├── docs/
│   ├── PRD.md
│   ├── TDD.md
│   ├── DataModels.md
│   ├── engineering.md
│   └── userflow.md
│
├── frontend/
│   ├── pubspec.yaml
│   ├── android/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── theme/
│   │   │   │   ├── app_colors.dart         # OLED Dark & Frosted Light tokens
│   │   │   │   ├── app_typography.dart     # Plus Jakarta Sans & Inter iOS-grade styles
│   │   │   │   └── app_theme.dart          # Dark & Light ThemeData
│   │   │   ├── constants/
│   │   │   │   └── api_constants.dart      # Backend endpoints & headers
│   │   │   └── utils/
│   │   │
│   │   ├── models/
│   │   │   ├── weather_model.dart          # Normalized weather & forecast models
│   │   │   ├── chat_message.dart           # Conversational messages & suggested actions
│   │   │   ├── user_context.dart           # AI-detected personas (Farmer, Traveller, General)
│   │   │   └── alert_model.dart            # Meteorological alerts & warnings
│   │   │
│   │   ├── services/
│   │   │   ├── api_client.dart             # HTTP client base configuration
│   │   │   ├── weather_service.dart        # Real API functions (commented backend integration)
│   │   │   ├── ai_chat_service.dart        # Real AI chat & tool calling (commented)
│   │   │   ├── alert_service.dart          # Alert engine communication (commented)
│   │   │   └── location_service.dart       # Device location resolution
│   │   │
│   │   ├── providers/
│   │   │   ├── theme_provider.dart         # Dark / Light mode state
│   │   │   ├── weather_provider.dart       # Weather state
│   │   │   ├── chat_provider.dart          # Conversation state
│   │   │   └── user_context_provider.dart  # AI-detected persona state
│   │   │
│   │   ├── widgets/
│   │   │   ├── dynamic_weather_orb.dart    # Custom animated glowing particle vortex
│   │   │   ├── glowing_bottom_bar.dart     # Reference floating bottom navigation
│   │   │   ├── chat_message_view.dart      # iOS-style chat bubbles & action pills
│   │   │   ├── weather_snapshot_card.dart  # Glassmorphic weather summary card
│   │   │   └── context_badge.dart          # Detected persona indicator pill
│   │   │
│   │   └── screens/
│   │       ├── home_screen.dart            # Main AI Assistant & Dynamic Orb screen
│   │       ├── chat_screen.dart            # Full-screen conversational AI interface
│   │       ├── profile_context_screen.dart # AI-detected profile & context screen (Ref UI Screen 3)
│   │       ├── weather_detail_screen.dart  # Detailed hourly/daily forecast
│   │       └── alerts_screen.dart          # Severe weather advisories
│   │
│   └── test/
│
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── api/
│   │   ├── core/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   ├── integrations/
│   │   ├── database/
│   │   └── utils/
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
│
├── scripts/
│   ├── setup.sh
│   └── seed_database.py
│
└── .github/
    └── workflows/
        └── ci.yml
```