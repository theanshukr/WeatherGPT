enum AlertSeverity {
  advisory,
  watch,
  warning,
  emergency,
}

class WeatherAlert {
  final String id;
  final String title;
  final String description;
  final String instructions;
  final AlertSeverity severity;
  final String area;
  final DateTime startsAt;
  final DateTime expiresAt;

  const WeatherAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.severity,
    required this.area,
    required this.startsAt,
    required this.expiresAt,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      id: json['id'] as String? ?? 'alert_1',
      title: json['title'] as String? ?? 'Severe Thunderstorm Warning',
      description: json['description'] as String? ?? 'Heavy convective rainfall with wind gusts.',
      instructions: json['instructions'] as String? ?? 'Avoid open fields and seek shelter.',
      severity: _parseSeverity(json['severity'] as String?),
      area: json['area'] as String? ?? 'National Capital Region',
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 4)),
    );
  }

  static AlertSeverity _parseSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'emergency':
      case 'severe':
        return AlertSeverity.emergency;
      case 'warning':
        return AlertSeverity.warning;
      case 'watch':
        return AlertSeverity.watch;
      default:
        return AlertSeverity.advisory;
    }
  }

  static List<WeatherAlert> defaultAlerts() {
    final now = DateTime.now();
    return [
      WeatherAlert(
        id: 'alert_rain_01',
        title: '⚠️ Heavy Rainfall & Gusty Winds Expected',
        description: 'Thunderstorm activity expected near New Delhi between 4:00 PM and 8:00 PM today.',
        instructions: 'Avoid waterlogged low-lying areas. Farmers should pause pesticide spraying.',
        severity: AlertSeverity.warning,
        area: 'Delhi NCR & surrounding plains',
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 4)),
      ),
    ];
  }
}
