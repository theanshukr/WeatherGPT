import '../models/chat_message_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class AiChatService {
  final ApiClient _apiClient = ApiClient();

  /// Send query to AI Orchestrator with Location and Context.
  /// Parses the FULL ChatMessageResponse from backend including
  /// structured advisory data, risk level, tools called, etc.
  Future<ChatMessage> sendMessage({
    required String query,
    required double latitude,
    required double longitude,
    String language = 'en',
    String? activePersona,
    String? locationName,
    String? sessionId,
    String? userId,
  }) async {
    final payload = {
      'message': query,
      'latitude': latitude,
      'longitude': longitude,
      'location': locationName,
      'language': language,
      'persona': activePersona ?? 'general',
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
    };

    final response = await _apiClient.post(
      ApiConstants.chat,
      body: payload,
    );

    if (response != null && response is Map<String, dynamic>) {
      final replyText = response['response'] as String? ?? 'No response received from AI.';

      // Parse suggestions
      final rawSuggestions = response['suggestions'] as List<dynamic>? ?? [];
      final suggestions = rawSuggestions.map((s) => SuggestedAction(
        title: s.toString(),
        query: s.toString(),
      )).toList();

      // Parse weather card data
      final weatherData = response['weather_data'] as Map<String, dynamic>?;

      // Parse risk level
      final riskLevel = response['risk_level'] as String? ?? 'LOW';

      // Parse tools called
      final toolsCalled = (response['tools_called'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [];

      // Parse persona applied
      final personaApplied = response['persona_applied'] as String?;

      // Parse primary intent
      final primaryIntent = response['primary_intent'] as String?;

      // Parse structured advisory data
      AdvisoryData? advisory;
      final travelData = response['travel_assessment'] as Map<String, dynamic>?;
      final farmingData = response['farming_advisory'] as Map<String, dynamic>?;
      final urbanData = response['urban_advisory'] as Map<String, dynamic>?;

      if (travelData != null) {
        advisory = AdvisoryData.fromTravelJson(travelData);
      } else if (farmingData != null) {
        advisory = AdvisoryData.fromFarmingJson(farmingData);
      } else if (urbanData != null) {
        advisory = AdvisoryData.fromUrbanJson(urbanData);
      }

      return ChatMessage(
        id: response['session_id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        role: MessageRole.assistant,
        content: replyText,
        timestamp: DateTime.now(),
        suggestedActions: suggestions,
        weatherContext: weatherData,
        riskLevel: riskLevel,
        toolsCalled: toolsCalled,
        personaApplied: personaApplied,
        advisory: advisory,
        primaryIntent: primaryIntent,
      );
    } else {
      throw Exception('Could not reach backend at ${ApiConstants.baseUrl}${ApiConstants.chat}. Please verify PC and Phone are on the same Wi-Fi and the backend server is running.');
    }
  }
}
