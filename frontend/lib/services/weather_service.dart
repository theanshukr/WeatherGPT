import '../models/weather_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class WeatherService {
  final ApiClient _apiClient = ApiClient();

  // Fetch real-time normalized weather for coordinates
  Future<WeatherData> getCurrentWeather({required double latitude, required double longitude}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.currentWeather,
        queryParams: {'latitude': latitude, 'longitude': longitude},
      );
      if (response != null) {
        final Map<String, dynamic> data = response is Map<String, dynamic> && response.containsKey('data')
            ? response['data'] as Map<String, dynamic>
            : response as Map<String, dynamic>;
        return WeatherData.fromJson(data);
      }
    } catch (_) {}
    return WeatherData.defaultData();
  }

  // Fetch hourly and 7-day forecast
  Future<List<DailyForecast>> getForecast({required double latitude, required double longitude}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.weatherForecast,
        queryParams: {'latitude': latitude, 'longitude': longitude},
      );
      if (response != null) {
        if (response is Map<String, dynamic> && response.containsKey('forecast_daily')) {
          final list = response['forecast_daily'] as List<dynamic>;
          return list.map((item) => DailyForecast.fromJson(item as Map<String, dynamic>)).toList();
        } else if (response is Map<String, dynamic> && response.containsKey('data')) {
          final list = response['data'] as List<dynamic>;
          return list.map((item) => DailyForecast.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {}
    return WeatherData.defaultData().dailyForecast;
  }
}
