import '../models/weather_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class WeatherService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch real-time weather from backend /weather/current.
  /// Backend returns flat CurrentWeatherResponse (location as string, not object).
  Future<WeatherData> getCurrentWeather({
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final Map<String, dynamic> queryParams = {
      'lat': latitude,
      'lon': longitude,
    };
    if (city != null) {
      queryParams['city'] = city;
    }

    final response = await _apiClient.get(
      ApiConstants.currentWeather,
      queryParams: queryParams,
    );

    if (response != null && response is Map<String, dynamic>) {
      return WeatherData.fromJson(response);
    }

    throw ApiUnreachableException('No response received from weather server.');
  }

  /// Fetch the full weather snapshot (current + hourly rain timeline + 7-day forecast + alerts).
  /// Returns a WeatherData with hourly and daily forecasts populated.
  Future<WeatherData> getWeatherSnapshot({
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final Map<String, dynamic> queryParams = {
      'lat': latitude,
      'lon': longitude,
    };
    if (city != null) {
      queryParams['city'] = city;
    }

    final response = await _apiClient.get(
      ApiConstants.weatherSnapshot,
      queryParams: queryParams,
    );

    if (response != null && response is Map<String, dynamic>) {
      return WeatherData.fromSnapshot(response);
    }

    throw ApiUnreachableException('No response received from weather snapshot endpoint.');
  }

  /// Fetch hourly rain timeline from /weather/hourly.
  Future<List<HourlyForecast>> getHourlyForecast({
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final Map<String, dynamic> queryParams = {
      'lat': latitude,
      'lon': longitude,
    };
    if (city != null) {
      queryParams['city'] = city;
    }

    final response = await _apiClient.get(
      ApiConstants.weatherHourly,
      queryParams: queryParams,
    );

    if (response != null && response is List<dynamic>) {
      return response
          .map((e) => HourlyForecast.fromRainTimeline(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// Fetch 7-day daily forecast from /weather/forecast.
  Future<List<DailyForecast>> getDailyForecast({
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final Map<String, dynamic> queryParams = {
      'lat': latitude,
      'lon': longitude,
    };
    if (city != null) {
      queryParams['city'] = city;
    }

    final response = await _apiClient.get(
      ApiConstants.weatherForecast,
      queryParams: queryParams,
    );

    if (response != null && response is List<dynamic>) {
      return response
          .map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }
}
