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
      userId: json['user_id'] as String? ?? 'user_1',
      userName: json['user_name'] as String? ?? 'Sarah Logan',
      primaryPersona: _parsePersona(json['primary_persona'] as String?),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.85,
      detectedInterests: (json['detected_interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['🌾 Agriculture', '✈️ Travel', '🌧️ Rain & Storm Alerts'],
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

  static UserContext defaultContext() {
    return UserContext(
      userId: 'user_dev',
      userName: 'Sarah Logan',
      primaryPersona: DetectedPersona.farmer,
      confidenceScore: 0.88,
      detectedInterests: const [
        '🌾 Agriculture & Sowing',
        '✈️ Travel Advisories',
        '🌧️ Severe Rain & Storm Alerts',
        '💧 Irrigation Optimization',
      ],
      activeContextData: const {
        'crop': 'Wheat',
        'irrigation_window': 'Morning preferred',
        'upcoming_trip': 'Manali (Sep 01 - Sep 05)',
      },
      lastUpdated: DateTime.now().subtract(const Duration(hours: 3)),
    );
  }
}
