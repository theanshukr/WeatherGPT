import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';

class ChatProvider with ChangeNotifier {
  final AiChatService _aiChatService = AiChatService();
  final LocationService _locationService = LocationService();

  final List<ChatMessage> _messages = [];
  String? _sessionId;
  bool _isTyping = false;
  bool _isListening = false;

  List<ChatMessage> get messages => _messages;
  String? get sessionId => _sessionId;
  bool get isTyping => _isTyping;
  bool get isListening => _isListening;

  void setListening(bool listening) {
    _isListening = listening;
    notifyListeners();
  }

  Future<void> sendUserMessage(
    String text, {
    double? lat,
    double? lon,
    String? activePersona,
  }) async {
    final queryText = text.trim();
    if (queryText.isEmpty) return;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: queryText,
      timestamp: DateTime.now(),
    );

    _messages.add(userMsg);
    _isTyping = true;
    notifyListeners();

    try {
      double targetLat = lat ?? 28.6139;
      double targetLon = lon ?? 77.2090;

      if (lat == null || lon == null) {
        try {
          final loc = await _locationService.getCurrentLocation();
          targetLat = loc.latitude;
          targetLon = loc.longitude;
        } catch (_) {}
      }

      ChatMessage? aiResponse;
      // Up to 2 attempts with short delay for network resilience
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          aiResponse = await _aiChatService.sendMessage(
            query: queryText,
            latitude: targetLat,
            longitude: targetLon,
            activePersona: activePersona,
            sessionId: _sessionId,
            userId: SupabaseService.currentUserId,
          );
          break;
        } catch (e) {
          if (attempt == 0) {
            await Future.delayed(const Duration(milliseconds: 600));
          } else {
            rethrow;
          }
        }
      }

      if (aiResponse != null) {
        // Persist session ID returned by backend so subsequent queries maintain full conversational context
        if (aiResponse.id.isNotEmpty) {
          _sessionId = aiResponse.id;
        }
        _messages.add(aiResponse);
      }
    } catch (e) {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: MessageRole.assistant,
          content: 'Unable to reach WeatherGPT AI server. Please check your internet connection and try again.',
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  void clearConversation() {
    _messages.clear();
    _sessionId = null;
    notifyListeners();
  }
}
