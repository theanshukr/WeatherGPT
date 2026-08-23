import 'package:flutter/foundation.dart';

class ApiConstants {
  // Base URLs for Local Development and Production
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String localhostBaseUrl = 'http://127.0.0.1:8000/api/v1';

  // Custom device override (Physical device IP). LEFT EMPTY ON PURPOSE.
  // A hardcoded LAN IP here breaks silently the moment your PC's IP
  // changes or your phone joins a different Wi-Fi network — every request
  // fails, and the app quietly falls back to mock data with no visible
  // error. Set this at runtime instead, e.g. from the Settings screen
  // (call ApiConstants.setCustomBaseUrl('http://<your-pc-ip>:8000/api/v1'))
  // so it's easy to update without a rebuild, and so you can tell at a
  // glance whether it's actually configured.
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
    // Android emulator default. NOTE: this only reaches a backend running
    // on the SAME machine as the emulator. For a physical Android phone,
    // you MUST call setCustomBaseUrl() with your PC's current LAN IP.
    return androidEmulatorBaseUrl;
  }

  // Weather Endpoints
  static const String currentWeather = '/weather/current';
  static const String weatherForecast = '/weather/forecast';

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
