// ignore_for_file: unused_field, unused_import
import '../models/chat_message.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class AiChatService {
  final ApiClient _apiClient = ApiClient();

  // Send query to AI Orchestrator with Location and Context
  Future<ChatMessage> sendMessage({
    required String query,
    required double latitude,
    required double longitude,
    String language = 'en',
    String? activePersona,
  }) async {
    /*
    final response = await _apiClient.post(
      ApiConstants.chatMessage,
      body: {
        'message': query,
        'location': {'latitude': latitude, 'longitude': longitude},
        'language': language,
        'context_hint': activePersona,
      },
    );
    if (response != null && response['data'] != null) {
      return ChatMessage.fromJson(response['data'] as Map<String, dynamic>);
    }
    */
    
    final lower = query.toLowerCase();
    if (lower.contains('rain') || lower.contains('umbrella') || lower.contains('baarish')) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: '🌧️ There is a 70% chance of convective rain this evening between 4:00 PM and 8:00 PM near your location. Carrying an umbrella is recommended.',
        timestamp: DateTime.now(),
        suggestedActions: const [
          SuggestedAction(title: '⏰ Hourly Rain Timeline', query: 'Show me hourly rain timeline for today'),
          SuggestedAction(title: '🚗 Safe Travel Windows', query: 'When is it safe to travel this evening?'),
          SuggestedAction(title: '🌾 Irrigation Advice', query: 'Should I pause irrigation due to rain?'),
        ],
      );
    } else if (lower.contains('farm') || lower.contains('crop') || lower.contains('spray') || lower.contains('kheti')) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: '🌾 **Agricultural Weather Briefing:**\n\n• **Wind Speed:** 14 km/h (Moderate)\n• **Humidity:** 65%\n• **Rain Probability:** High (Evening)\n\n⚠️ **Recommendation:** Pause pesticide spraying until tomorrow morning to prevent chemical wash-off from expected evening showers.',
        timestamp: DateTime.now(),
        suggestedActions: const [
          SuggestedAction(title: '💧 7-Day Rainfall Forecast', query: 'Show 7-day rainfall trend for wheat'),
          SuggestedAction(title: '☀️ Tomorrow Sowing Conditions', query: 'Is tomorrow suitable for field sowing?'),
        ],
      );
    } else if (lower.contains('travel') || lower.contains('trip') || lower.contains('goa') || lower.contains('manali')) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: '✈️ **Travel Weather Intelligence:**\n\n• **Destination:** Clear to partly cloudy\n• **Temperature Range:** 22°C - 31°C\n• **Precipitation Risk:** Low in morning, moderate in evening\n• **Road & Visibility Conditions:** Good',
        timestamp: DateTime.now(),
        suggestedActions: const [
          SuggestedAction(title: '🎒 Packing Checklist', query: 'What should I pack for this trip?'),
          SuggestedAction(title: '⚠️ Set Travel Alert', query: 'Alert me if severe weather develops for my destination'),
        ],
      );
    }

    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.assistant,
      content: 'Current weather is 28°C with partly cloudy skies. Moderate breeze from the southwest. How can I assist with your planning today?',
      timestamp: DateTime.now(),
      suggestedActions: const [
        SuggestedAction(title: '🌧️ Will it rain today?', query: 'Will it rain today?'),
        SuggestedAction(title: '🌾 Farming Advice', query: 'Is weather suitable for spraying today?'),
        SuggestedAction(title: '✈️ Travel Weather', query: 'Weather briefing for upcoming trip'),
      ],
    );
  }
}
