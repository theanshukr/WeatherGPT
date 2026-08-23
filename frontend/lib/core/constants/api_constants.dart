import 'package:flutter/foundation.dart';

class ApiConstants {
  // Base URLs for Local Development and Production
  static const String liveCloudBaseUrl = 'https://weathergpt-backend-3n4b.onrender.com/api/v1';
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String localhostBaseUrl = 'http://127.0.0.1:8000/api/v1';

  // Custom device override (Physical device IP / Cloud URL).
  static String? customBaseUrl;

  static void setCustomBaseUrl(String? url) {
    customBaseUrl = (url == null || url.trim().isEmpty) ? null : url.trim();
  }

  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS) {
      return localhostBaseUrl;
    }
    // Physical Android & iOS phones automatically point to live Render Cloud backend!
    return liveCloudBaseUrl;
  }

  // Weather Endpoints
  static const String currentWeather = '/weather/current';
  static const String weatherForecast = '/weather/forecast';
  static const String weatherAlerts = '/weather/alerts';

  // AI & Conversational Chat Endpoints
  static const String chat = '/chat';

  // Voice Endpoints
  static const String voiceTts = '/voice/tts';

  // System
  static const String health = '/health';

  // Request Headers
  static Map<String, String> defaultHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
