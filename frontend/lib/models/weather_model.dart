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
      time: DateTime.tryParse((json['timestamp'] ?? json['time']) as String? ?? '') ?? DateTime.now(),
      temperature: ((json['temperature_c'] ?? json['temperature']) as num?)?.toDouble() ?? 26.0,
      rainProbability: ((json['precipitation_probability_percent'] ?? json['rain_probability']) as num?)?.toDouble() ?? 0.0,
      condition: _parseCondition((json['weather_description'] ?? json['condition']) as String?),
      iconCode: json['icon'] as String? ?? 'cloud-sun',
    );
  }

  static WeatherConditionType _parseCondition(String? condition) {
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
      tempMin: ((json['temp_min_c'] ?? json['temp_min']) as num?)?.toDouble() ?? 22.0,
      tempMax: ((json['temp_max_c'] ?? json['temp_max']) as num?)?.toDouble() ?? 32.0,
      rainProbability: ((json['precipitation_probability_max_percent'] ?? json['rain_probability']) as num?)?.toDouble() ?? 10.0,
      condition: HourlyForecast._parseCondition((json['weather_description'] ?? json['condition']) as String?),
      summary: (json['weather_description'] ?? json['summary']) as String? ?? 'Partly cloudy with pleasant evening.',
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
    final current = json['current'] as Map<String, dynamic>?;
    return WeatherData(
      location: WeatherLocation.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
      observedAt: DateTime.tryParse((current?['timestamp'] ?? json['observed_at']) as String? ?? '') ?? DateTime.now(),
      temperature: ((current?['temperature_c'] ?? json['temperature']) as num?)?.toDouble() ?? 28.0,
      feelsLike: ((current?['apparent_temperature_c'] ?? json['feels_like']) as num?)?.toDouble() ?? 30.0,
      humidity: ((current?['humidity_percent'] ?? json['humidity']) as num?)?.toDouble() ?? 65.0,
      windSpeed: ((current?['wind_speed_kmh'] ?? json['wind_speed']) as num?)?.toDouble() ?? 12.0,
      windDirection: ((current?['wind_direction_deg'] ?? json['wind_direction']) as num?)?.toDouble() ?? 180.0,
      rainProbability: ((current?['precipitation_probability_percent'] ?? json['rain_probability']) as num?)?.toDouble() ?? 40.0,
      rainfallAmount: ((current?['precipitation_mm'] ?? json['rainfall_amount']) as num?)?.toDouble() ?? 2.5,
      uvIndex: ((current?['uv_index'] ?? json['uv_index']) as num?)?.toDouble() ?? 5.0,
      visibility: ((current?['visibility_m'] != null ? (current!['visibility_m'] as num) / 1000.0 : json['visibility']) as num?)?.toDouble() ?? 8.0,
      condition: HourlyForecast._parseCondition((current?['weather_description'] ?? json['weather_condition']) as String?),
      conditionDescription: (current?['weather_description'] ?? json['weather_condition']) as String? ?? 'Partly Cloudy',
      hourlyForecast: ((json['forecast_hourly'] ?? json['hourly']) as List<dynamic>?)
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
  static WeatherData defaultData() {
    final now = DateTime.now();
    return WeatherData(
      location: const WeatherLocation(name: 'New Delhi', latitude: 28.6139, longitude: 77.2090, state: 'Delhi'),
      observedAt: now,
      temperature: 28.0,
      feelsLike: 30.0,
      humidity: 62.0,
      windSpeed: 14.0,
      windDirection: 210.0,
      rainProbability: 65.0,
      rainfallAmount: 4.2,
      uvIndex: 6.0,
      visibility: 7.5,
      condition: WeatherConditionType.partlyCloudy,
      conditionDescription: 'Partly Cloudy • Rain Expected Evening',
      hourlyForecast: List.generate(
        8,
        (i) => HourlyForecast(
          time: now.add(Duration(hours: i * 2)),
          temperature: 28.0 - (i > 3 ? (i - 3) * 1.5 : -i * 0.8),
          rainProbability: i >= 3 ? 75.0 : 20.0,
          condition: i >= 3 ? WeatherConditionType.rain : WeatherConditionType.partlyCloudy,
        ),
      ),
      dailyForecast: List.generate(
        5,
        (i) => DailyForecast(
          date: now.add(Duration(days: i)),
          tempMin: 22.0 + (i % 2),
          tempMax: 32.0 - (i % 3),
          rainProbability: (i == 1 || i == 3) ? 70.0 : 15.0,
          condition: (i == 1 || i == 3) ? WeatherConditionType.rain : WeatherConditionType.clear,
          summary: i == 1 ? 'High chance of evening rainfall' : 'Clear skies and warm breeze',
        ),
      ),
    );
  }
}
