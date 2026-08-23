import '../models/weather_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class WeatherService {
  final ApiClient _apiClient = ApiClient();

  // Fetch real-time weather from Open-Meteo via backend API
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

  // Fetch forecast data
  Future<List<DailyForecast>> getForecast({
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final weather = await getCurrentWeather(latitude: latitude, longitude: longitude, city: city);
    return weather.dailyForecast;
  }
}
