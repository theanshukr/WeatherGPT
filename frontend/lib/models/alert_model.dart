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
  final double latitude;
  final double longitude;
  final DateTime startsAt;
  final DateTime expiresAt;
  final String source; // 'threshold', 'gdacs', 'ndma'

  const WeatherAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.severity,
    required this.area,
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.startsAt,
    required this.expiresAt,
    this.source = 'threshold',
  });

  /// Parse from backend /weather/alerts threshold alert format
  /// Backend returns: {active_count, severity_class, triggered: [{type, headline, description, ...}]}
  factory WeatherAlert.fromThresholdAlert(Map<String, dynamic> json, {int index = 0}) {
    return WeatherAlert(
      id: 'threshold_$index',
      title: json['headline'] as String? ?? json['type'] as String? ?? 'Weather Alert',
      description: json['description'] as String? ?? '',
      instructions: json['safety_advice'] as String? ?? json['action'] as String? ?? 'Stay safe and monitor conditions.',
      severity: _parseSeverity(json['severity'] as String? ?? json['level'] as String?),
      area: json['area'] as String? ?? json['region'] as String? ?? 'Your Area',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 6)),
      source: 'threshold',
    );
  }

  /// Parse from backend /weather/official-alerts (GDACS format)
  factory WeatherAlert.fromOfficialAlert(Map<String, dynamic> json) {
    return WeatherAlert(
      id: json['id'] as String? ?? json['gdacs_id'] as String? ?? 'official_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? json['event_name'] as String? ?? 'Official Alert',
      description: json['description'] as String? ?? '',
      instructions: json['instructions'] as String? ?? json['safety_advice'] as String? ?? 'Follow official guidance.',
      severity: _parseSeverity(json['severity'] as String? ?? json['alert_level'] as String?),
      area: json['area'] as String? ?? json['country'] as String? ?? json['affected_area'] as String? ?? 'Region',
      latitude: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? (json['lon'] as num?)?.toDouble() ?? 0.0,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? json['from_date'] as String? ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? json['to_date'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
      source: json['source'] as String? ?? 'gdacs',
    );
  }

  /// Generic fromJson fallback — tries both formats
  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      id: json['id'] as String? ?? 'alert_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? json['headline'] as String? ?? json['event_name'] as String? ?? 'Alert',
      description: json['description'] as String? ?? '',
      instructions: json['instructions'] as String? ?? json['safety_advice'] as String? ?? 'Stay informed.',
      severity: _parseSeverity(json['severity'] as String? ?? json['alert_level'] as String?),
      area: json['area'] as String? ?? json['affected_area'] as String? ?? json['country'] as String? ?? 'Area',
      latitude: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? (json['lon'] as num?)?.toDouble() ?? 0.0,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? json['from_date'] as String? ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? json['to_date'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 4)),
      source: json['source'] as String? ?? 'unknown',
    );
  }

  static AlertSeverity _parseSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'emergency':
      case 'severe':
      case 'extreme':
      case 'red':
        return AlertSeverity.emergency;
      case 'warning':
      case 'orange':
        return AlertSeverity.warning;
      case 'watch':
      case 'yellow':
        return AlertSeverity.watch;
      default:
        return AlertSeverity.advisory;
    }
  }
}
