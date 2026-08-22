class ApiConstants {
  // Base URLs for Local Development and Production
  static const String devBaseUrl = 'http://10.0.2.2:8000/api/v1'; // Android emulator localhost
  static const String webBaseUrl = 'http://localhost:8000/api/v1';
  static const String wsBaseUrl = 'ws://10.0.2.2:8000/ws';

  // Weather Endpoints
  static const String currentWeather = '/weather/current';
  static const String weatherForecast = '/weather/forecast';
  static const String hourlyForecast = '/weather/hourly';

  // AI & Conversational Chat Endpoints
  static const String chatMessage = '/chat/message';
  static const String chatConversations = '/chat/conversations';
  static const String chatStream = '/chat/stream';

  // Alerts & Notifications
  static const String weatherAlerts = '/alerts';
  static const String alertPreferences = '/alerts/preferences';

  // User Profile & AI Context
  static const String userProfile = '/profile';
  static const String userContext = '/user/context';
  static const String savedLocations = '/location';

  // Request Headers
  static Map<String, String> defaultHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
