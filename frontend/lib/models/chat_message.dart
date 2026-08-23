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

/// Structured advisory data returned by the backend when
/// Gemini tool-calling resolves travel/farming/urban advisories.
class AdvisoryData {
  final String type; // 'travel', 'farming', 'urban'
  final String headline;
  final String verdict;
  final String riskLevel;
  final List<String> reasons;
  final List<String> actionableSteps;
  final Map<String, dynamic> weatherFacts;

  const AdvisoryData({
    required this.type,
    required this.headline,
    required this.verdict,
    required this.riskLevel,
    this.reasons = const [],
    this.actionableSteps = const [],
    this.weatherFacts = const {},
  });

  factory AdvisoryData.fromTravelJson(Map<String, dynamic> json) {
    return AdvisoryData(
      type: 'travel',
      headline: '${json['destination'] ?? 'Travel'} — ${json['time_frame'] ?? ''}',
      verdict: json['verdict'] as String? ?? '',
      riskLevel: json['travel_risk'] as String? ?? 'LOW',
      reasons: (json['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      actionableSteps: (json['guidelines'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      weatherFacts: json['weather_facts'] as Map<String, dynamic>? ?? {},
    );
  }

  factory AdvisoryData.fromFarmingJson(Map<String, dynamic> json) {
    return AdvisoryData(
      type: 'farming',
      headline: json['advisory_headline'] as String? ?? 'Farming Advisory',
      verdict: json['recommendation'] as String? ?? '',
      riskLevel: json['recommendation'] as String? ?? 'NORMAL',
      reasons: (json['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      actionableSteps: (json['actionable_steps'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      weatherFacts: json['weather_facts'] as Map<String, dynamic>? ?? {},
    );
  }

  factory AdvisoryData.fromUrbanJson(Map<String, dynamic> json) {
    return AdvisoryData(
      type: 'urban',
      headline: json['advisory_headline'] as String? ?? 'Urban Advisory',
      verdict: json['verdict'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ?? 'LOW',
      reasons: (json['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      actionableSteps: (json['actionable_steps'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      weatherFacts: json['weather_facts'] as Map<String, dynamic>? ?? {},
    );
  }
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<SuggestedAction> suggestedActions;
  final Map<String, dynamic>? weatherContext;
  final bool isStreaming;

  // Rich structured data from backend ChatMessageResponse
  final String? riskLevel;
  final List<String> toolsCalled;
  final String? personaApplied;
  final AdvisoryData? advisory; // travel / farming / urban advisory
  final String? primaryIntent;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedActions = const [],
    this.weatherContext,
    this.isStreaming = false,
    this.riskLevel,
    this.toolsCalled = const [],
    this.personaApplied,
    this.advisory,
    this.primaryIntent,
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
    Map<String, dynamic>? weatherContext,
    String? riskLevel,
    List<String>? toolsCalled,
    String? personaApplied,
    AdvisoryData? advisory,
    String? primaryIntent,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      weatherContext: weatherContext ?? this.weatherContext,
      isStreaming: isStreaming ?? this.isStreaming,
      riskLevel: riskLevel ?? this.riskLevel,
      toolsCalled: toolsCalled ?? this.toolsCalled,
      personaApplied: personaApplied ?? this.personaApplied,
      advisory: advisory ?? this.advisory,
      primaryIntent: primaryIntent ?? this.primaryIntent,
    );
  }
}
