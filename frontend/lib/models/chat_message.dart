enum MessageRole {
  user,
  assistant,
  system,
}

class SuggestedAction {
  final String title;
  final String query;
  final String? icon;

  const SuggestedAction({
    required this.title,
    required this.query,
    this.icon,
  });

  factory SuggestedAction.fromJson(Map<String, dynamic> json) {
    return SuggestedAction(
      title: json['title'] as String? ?? '',
      query: json['query'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'query': query,
    'icon': icon,
  };
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<SuggestedAction> suggestedActions;
  final Map<String, dynamic>? weatherContext;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedActions = const [],
    this.weatherContext,
    this.isStreaming = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      role: _parseRole(json['role'] as String?),
      content: json['content'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      suggestedActions: (json['suggested_actions'] as List<dynamic>?)
              ?.map((e) => SuggestedAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      weatherContext: json['weather_context'] as Map<String, dynamic>?,
      isStreaming: json['is_streaming'] as bool? ?? false,
    );
  }

  static MessageRole _parseRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'system':
        return MessageRole.system;
      default:
        return MessageRole.assistant;
    }
  }

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    List<SuggestedAction>? suggestedActions,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      weatherContext: weatherContext,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
