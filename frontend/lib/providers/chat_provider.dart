import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';

class ChatProvider with ChangeNotifier {
  final AiChatService _aiChatService = AiChatService();

  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isListening = false;

  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;
  bool get isListening => _isListening;

  ChatProvider() {
    _initWelcomeMessage();
  }

  void _initWelcomeMessage() {
    _messages.add(
      ChatMessage(
        id: 'welcome_msg',
        role: MessageRole.assistant,
        content: "Hi! I'm **WeatherGPT**, your AI Weather Intelligence Assistant.\n\nAsk me anything about today's forecast, rain probability, agricultural spraying advice, or travel conditions.",
        timestamp: DateTime.now(),
        suggestedActions: const [
          SuggestedAction(title: '🌧️ Will it rain today?', query: 'Will it rain today?'),
          SuggestedAction(title: '🌾 Farming & Spray Advice', query: 'Is weather suitable for pesticide spraying today?'),
          SuggestedAction(title: '✈️ Travel Weather Briefing', query: 'Travel weather briefing for tomorrow'),
        ],
      ),
    );
  }

  void setListening(bool listening) {
    _isListening = listening;
    notifyListeners();
  }

  Future<void> sendUserMessage(String text, {double lat = 28.6139, double lon = 77.2090, String? activePersona}) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    _messages.add(userMsg);
    _isTyping = true;
    notifyListeners();

    try {
      final aiResponse = await _aiChatService.sendMessage(
        query: text.trim(),
        latitude: lat,
        longitude: lon,
        activePersona: activePersona,
      );
      _messages.add(aiResponse);
    } catch (e) {
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: MessageRole.assistant,
          content: 'Unable to connect to WeatherGPT AI server. Please try again.',
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
    _initWelcomeMessage();
    notifyListeners();
  }
}
