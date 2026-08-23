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
      temperature: (json['temperature'] as num?)?.toDouble() ?? 26.0,
      rainProbability: (json['rain_probability'] as num?)?.toDouble() ?? 0.0,
      condition: parseCondition(json['condition'] as String?),
      iconCode: json['icon'] as String? ?? 'cloud-sun',
    );
  }

  static WeatherConditionType parseCondition(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'rain':
        return WeatherConditionType.rain;
      case 'heavy_rain':
        return WeatherConditionType.heavyRain;
      case 'thunderstorm':
        return WeatherConditionType.thunderstorm;
      case 'cloudy':
        return WeatherConditionType.cloudy;
      case 'partly_cloudy':
      case 'partly cloudy':
        return WeatherConditionType.partlyCloudy;
      case 'fog':
        return WeatherConditionType.fog;
      case 'snow':
        return WeatherConditionType.snow;
      default:
        return WeatherConditionType.clear;
    }
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
      tempMin: (json['temp_min'] as num?)?.toDouble() ?? 22.0,
      tempMax: (json['temp_max'] as num?)?.toDouble() ?? 32.0,
      rainProbability: (json['rain_probability'] as num?)?.toDouble() ?? 10.0,
      condition: HourlyForecast.parseCondition(json['condition'] as String?),
      summary: json['summary'] as String? ?? 'Partly cloudy with pleasant evening.',
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
    this.hourlyForecast = const [],
    this.dailyForecast = const [],
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      location: WeatherLocation.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
      observedAt: DateTime.tryParse(json['observed_at'] as String? ?? '') ?? DateTime.now(),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 28.0,
      feelsLike: (json['feels_like'] as num?)?.toDouble() ?? 30.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 65.0,
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 12.0,
      windDirection: (json['wind_direction'] as num?)?.toDouble() ?? 180.0,
      rainProbability: (json['rain_probability'] as num?)?.toDouble() ?? 40.0,
      rainfallAmount: (json['rainfall_amount'] as num?)?.toDouble() ?? 2.5,
      uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 5.0,
      visibility: (json['visibility'] as num?)?.toDouble() ?? 8.0,
      condition: HourlyForecast.parseCondition(json['weather_condition'] as String?),
      conditionDescription: json['weather_condition'] as String? ?? 'Partly Cloudy',
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

  // Pre-configured default representation
  static WeatherData empty() {
    final now = DateTime.now();
    return WeatherData(
      location: const WeatherLocation(name: 'Locating...', latitude: 28.6139, longitude: 77.2090),
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
      condition: WeatherConditionType.partlyCloudy,
      conditionDescription: 'Connecting to atmospheric data...',
      hourlyForecast: const [],
      dailyForecast: const [],
    );
  }
}
