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
    String? locationName,
  }) async {
    final payload = {
      'message': query,
      'latitude': latitude,
      'longitude': longitude,
      'location': locationName,
      'language': language,
      'persona': activePersona ?? 'general',
    };

    final response = await _apiClient.post(
      ApiConstants.chat,
      body: payload,
    );

    if (response != null && response is Map<String, dynamic>) {
      final replyText = response['response'] as String? ?? 'No response received from AI.';
      final rawSuggestions = response['suggestions'] as List<dynamic>? ?? [];
      final suggestions = rawSuggestions.map((s) => SuggestedAction(
        title: s.toString(),
        query: s.toString(),
      )).toList();

      final weatherData = response['weather_data'] as Map<String, dynamic>?;

      return ChatMessage(
        id: response['session_id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: replyText,
        timestamp: DateTime.now(),
        suggestedActions: suggestions,
        weatherContext: weatherData,
      );
    } else {
      throw Exception('Could not reach backend at ${ApiConstants.baseUrl}${ApiConstants.chat}. Please verify PC and Phone are on the same Wi-Fi and the backend server is running.');
    }
  }
}
