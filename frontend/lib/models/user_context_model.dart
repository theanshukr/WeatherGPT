enum DetectedPersona {
  general,
  farmer,
  traveller,
  student,
  commuter,
}

class UserContext {
  final String userId;
  final String userName;
  final DetectedPersona primaryPersona;
  final double confidenceScore;
  final List<String> detectedInterests;
  final Map<String, dynamic> activeContextData;
  final DateTime lastUpdated;

  const UserContext({
    required this.userId,
    required this.userName,
    required this.primaryPersona,
    required this.confidenceScore,
    required this.detectedInterests,
    this.activeContextData = const {},
    required this.lastUpdated,
  });

  factory UserContext.fromJson(Map<String, dynamic> json) {
    return UserContext(
      userId: json['user_id'] as String? ?? 'guest',
      userName: json['user_name'] as String? ?? 'Guest User',
      primaryPersona: _parsePersona(json['primary_persona'] as String?),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      detectedInterests: (json['detected_interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      activeContextData: json['active_context_data'] as Map<String, dynamic>? ?? {},
      lastUpdated: DateTime.tryParse(json['last_updated'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static DetectedPersona _parsePersona(String? persona) {
    switch (persona?.toLowerCase()) {
      case 'farmer':
        return DetectedPersona.farmer;
      case 'traveller':
        return DetectedPersona.traveller;
      case 'student':
        return DetectedPersona.student;
      case 'commuter':
        return DetectedPersona.commuter;
      default:
        return DetectedPersona.general;
    }
  }

  /// Honest default — no fake names, no fake interests
  static UserContext defaultContext() {
    return UserContext(
      userId: 'guest',
      userName: 'Guest User',
      primaryPersona: DetectedPersona.general,
      confidenceScore: 0.0,
      detectedInterests: const [],
      activeContextData: const {},
      lastUpdated: DateTime.now(),
    );
  }
}
