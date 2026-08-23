enum WeatherConditionType {
  clear,
  partlyCloudy,
  cloudy,
  rain,
  heavyRain,
  thunderstorm,
  fog,
  windy,
  snow,
}

class WeatherLocation {
  final String name;
  final double latitude;
  final double longitude;
  final String? state;
  final String country;

  const WeatherLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.state,
    this.country = 'India',
  });

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    return WeatherLocation(
      name: json['name'] as String? ?? 'Current Location',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 28.6139,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 77.2090,
      state: json['state'] as String?,
      country: json['country'] as String? ?? 'India',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'state': state,
    'country': country,
  };
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final double rainProbability;
  final WeatherConditionType condition;
  final String iconCode;

  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.rainProbability,
    required this.condition,
    this.iconCode = 'cloud-sun',
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      rainProbability: (json['rain_probability'] as num?)?.toDouble() ?? 0.0,
      condition: parseCondition(json['condition'] as String?),
      iconCode: json['icon'] as String? ?? 'cloud-sun',
    );
  }

  /// Parse from the backend /weather/hourly rain_timeline format
  factory HourlyForecast.fromRainTimeline(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      temperature: (json['temp_c'] as num?)?.toDouble() ?? 0.0,
      rainProbability: (json['rain_probability_pct'] as num?)?.toDouble() ?? 0.0,
      condition: parseCondition(json['condition'] as String?),
      iconCode: json['icon'] as String? ?? 'cloud-sun',
    );
  }

  static WeatherConditionType parseCondition(String? condition) {
    if (condition == null) return WeatherConditionType.clear;
    final lower = condition.toLowerCase();
    if (lower.contains('thunder')) return WeatherConditionType.thunderstorm;
    if (lower.contains('heavy rain') || lower.contains('violent rain')) {
      return WeatherConditionType.heavyRain;
    }
    if (lower.contains('rain') || lower.contains('drizzle') || lower.contains('shower')) {
      return WeatherConditionType.rain;
    }
    if (lower.contains('snow')) return WeatherConditionType.snow;
    if (lower.contains('fog')) return WeatherConditionType.fog;
    if (lower.contains('overcast') || lower == 'cloudy') return WeatherConditionType.cloudy;
    if (lower.contains('partly cloudy') || lower.contains('mainly clear')) {
      return WeatherConditionType.partlyCloudy;
    }
    if (lower.contains('wind')) return WeatherConditionType.windy;
    return WeatherConditionType.clear;
  }
}

class DailyForecast {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final double rainProbability;
  final WeatherConditionType condition;
  final String summary;

  const DailyForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.rainProbability,
    required this.condition,
    required this.summary,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      tempMin: (json['temp_min'] as num?)?.toDouble() ?? 0.0,
      tempMax: (json['temp_max'] as num?)?.toDouble() ?? 0.0,
      rainProbability: (json['rain_probability'] as num?)?.toDouble() ??
          (json['rain_probability_pct'] as num?)?.toDouble() ?? 0.0,
      condition: HourlyForecast.parseCondition(json['condition'] as String?),
      summary: json['summary'] as String? ?? json['condition'] as String? ?? '',
    );
  }
}

class WeatherData {
  final WeatherLocation location;
  final DateTime observedAt;
  final double temperature;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final double windDirection;
  final double rainProbability;
  final double rainfallAmount;
  final double uvIndex;
  final double visibility;
  final WeatherConditionType condition;
  final String conditionDescription;
  final int weatherCode;
  final List<HourlyForecast> hourlyForecast;
  final List<DailyForecast> dailyForecast;

  const WeatherData({
    required this.location,
    required this.observedAt,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.rainProbability,
    required this.rainfallAmount,
    required this.uvIndex,
    required this.visibility,
    required this.condition,
    required this.conditionDescription,
    this.weatherCode = 0,
    this.hourlyForecast = const [],
    this.dailyForecast = const [],
  });

  /// Parse the backend /weather/current response (flat CurrentWeatherResponse).
  /// Backend schema: {location: str, latitude, longitude, temperature, wind_speed,
  ///   wind_direction, weather_code, condition, is_day, humidity, precipitation, time}
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    // Backend sends 'location' as a plain string, not a nested object
    final locationValue = json['location'];
    WeatherLocation loc;
    if (locationValue is Map<String, dynamic>) {
      // Legacy nested format (future-proof)
      loc = WeatherLocation.fromJson(locationValue);
    } else {
      // Actual backend format: flat string + top-level lat/lon
      loc = WeatherLocation(
        name: (locationValue as String?) ?? 'Unknown',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      );
    }

    final conditionStr = json['condition'] as String? ??
        json['weather_condition'] as String? ?? '';

    return WeatherData(
      location: loc,
      observedAt: DateTime.tryParse(
          json['time'] as String? ?? json['observed_at'] as String? ?? '') ??
          DateTime.now(),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (json['feels_like'] as num?)?.toDouble() ??
          (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0.0,
      windDirection: (json['wind_direction'] as num?)?.toDouble() ?? 0.0,
      rainProbability: (json['rain_probability'] as num?)?.toDouble() ?? 0.0,
      rainfallAmount: (json['precipitation'] as num?)?.toDouble() ??
          (json['rainfall_amount'] as num?)?.toDouble() ?? 0.0,
      uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 0.0,
      visibility: (json['visibility'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      condition: HourlyForecast.parseCondition(conditionStr),
      conditionDescription: conditionStr.isNotEmpty ? conditionStr : 'Clear sky',
      hourlyForecast: (json['hourly'] as List<dynamic>?)
              ?.map((e) => HourlyForecast.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dailyForecast: ((json['forecast_daily'] ?? json['daily']) as List<dynamic>?)
              ?.map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Parse the full /weather/snapshot response which contains everything
  factory WeatherData.fromSnapshot(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final locationName = json['location'] as String? ?? current['location'] as String? ?? 'Unknown';

    // Parse hourly from rain_timeline
    final rainTimeline = json['rain_timeline'] as List<dynamic>? ?? [];
    final hourly = rainTimeline
        .map((e) => HourlyForecast.fromRainTimeline(e as Map<String, dynamic>))
        .toList();

    // Parse daily from daily_7_day_forecast
    final dailyList = json['daily_7_day_forecast'] as List<dynamic>? ?? [];
    final daily = dailyList
        .map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
        .toList();

    final conditionStr = current['condition'] as String? ?? '';

    return WeatherData(
      location: WeatherLocation(
        name: locationName,
        latitude: (current['latitude'] as num?)?.toDouble() ??
            (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (current['longitude'] as num?)?.toDouble() ??
            (json['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      observedAt: DateTime.tryParse(current['time'] as String? ?? '') ?? DateTime.now(),
      temperature: (current['temperature'] as num?)?.toDouble() ??
          (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (current['feels_like'] as num?)?.toDouble() ??
          (current['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (current['humidity'] as num?)?.toDouble() ??
          (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (current['wind_speed'] as num?)?.toDouble() ??
          (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
      windDirection: (current['wind_direction'] as num?)?.toDouble() ?? 0.0,
      rainProbability: (current['rain_probability'] as num?)?.toDouble() ?? 0.0,
      rainfallAmount: (current['precipitation'] as num?)?.toDouble() ?? 0.0,
      uvIndex: (current['uv_index'] as num?)?.toDouble() ?? 0.0,
      visibility: (current['visibility'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      condition: HourlyForecast.parseCondition(conditionStr),
      conditionDescription: conditionStr.isNotEmpty ? conditionStr : 'Clear sky',
      hourlyForecast: hourly,
      dailyForecast: daily,
    );
  }

  /// Copy with updated hourly/daily forecasts
  WeatherData copyWith({
    List<HourlyForecast>? hourlyForecast,
    List<DailyForecast>? dailyForecast,
  }) {
    return WeatherData(
      location: location,
      observedAt: observedAt,
      temperature: temperature,
      feelsLike: feelsLike,
      humidity: humidity,
      windSpeed: windSpeed,
      windDirection: windDirection,
      rainProbability: rainProbability,
      rainfallAmount: rainfallAmount,
      uvIndex: uvIndex,
      visibility: visibility,
      condition: condition,
      conditionDescription: conditionDescription,
      weatherCode: weatherCode,
      hourlyForecast: hourlyForecast ?? this.hourlyForecast,
      dailyForecast: dailyForecast ?? this.dailyForecast,
    );
  }

  // Loading placeholder — clearly shows "Loading..." not fake data
  static WeatherData empty() {
    final now = DateTime.now();
    return WeatherData(
      location: const WeatherLocation(name: 'Loading...', latitude: 0, longitude: 0),
      observedAt: now,
      temperature: 0.0,
      feelsLike: 0.0,
      humidity: 0.0,
      windSpeed: 0.0,
      windDirection: 0.0,
      rainProbability: 0.0,
      rainfallAmount: 0.0,
      uvIndex: 0.0,
      visibility: 0.0,
      condition: WeatherConditionType.clear,
      conditionDescription: 'Loading...',
      hourlyForecast: const [],
      dailyForecast: const [],
    );
  }

  bool get isEmpty => location.name == 'Loading...' && temperature == 0.0;
}
