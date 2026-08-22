// ignore_for_file: unused_field, unused_import
import '../models/weather_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class WeatherService {
  final ApiClient _apiClient = ApiClient();

  // Fetch real-time normalized weather for coordinates
  Future<WeatherData> getCurrentWeather({required double latitude, required double longitude}) async {
    /*
    final response = await _apiClient.get(
      ApiConstants.currentWeather,
      queryParams: {'latitude': latitude, 'longitude': longitude},
    );
    if (response != null && response['data'] != null) {
      return WeatherData.fromJson(response['data'] as Map<String, dynamic>);
    }
    */
    return WeatherData.defaultData();
  }

  // Fetch hourly and 7-day forecast
  Future<List<DailyForecast>> getForecast({required double latitude, required double longitude}) async {
    /*
    final response = await _apiClient.get(
      ApiConstants.weatherForecast,
      queryParams: {'latitude': latitude, 'longitude': longitude},
    );
    if (response != null && response['data'] != null) {
      final list = response['data'] as List<dynamic>;
      return list.map((item) => DailyForecast.fromJson(item as Map<String, dynamic>)).toList();
    }
    */
    return WeatherData.defaultData().dailyForecast;
  }
}
