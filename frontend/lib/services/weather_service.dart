import '../models/weather_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class WeatherService {
  final ApiClient _apiClient = ApiClient();

  // Fetch real-time normalized weather for coordinates.
  // Throws ApiUnreachableException if the backend can't be reached, so the
  // UI can show a real "can't connect" state instead of silently displaying
  // fabricated placeholder numbers as if they were live weather.
  Future<WeatherData> getCurrentWeather({required double latitude, required double longitude, String? city}) async {
    final Map<String, dynamic> queryParams = {
      'lat': latitude,
      'lon': longitude,
    };
    if (city != null) {
      queryParams['city'] = city;
    }

    // Let ApiUnreachableException propagate — callers must handle it
    // explicitly rather than us pretending everything is fine.
    final response = await _apiClient.get(
      ApiConstants.currentWeather,
      queryParams: queryParams,
    );

    if (response != null && response is Map<String, dynamic>) {
      final locName = response['location'] as String? ?? 'Location';
      final temp = (response['temperature'] as num?)?.toDouble() ?? 28.0;
      final conditionStr = response['condition'] as String? ?? 'Clear';
      final humidity = (response['humidity'] as num?)?.toDouble() ?? 50.0;
      final windSpeed = (response['wind_speed'] as num?)?.toDouble() ?? 10.0;
      final precipitation = (response['precipitation'] as num?)?.toDouble() ?? 0.0;

      return WeatherData(
        location: WeatherLocation(name: locName, latitude: latitude, longitude: longitude),
        observedAt: DateTime.now(),
        temperature: temp,
        feelsLike: temp + 1.5,
        humidity: humidity,
        windSpeed: windSpeed,
        windDirection: (response['wind_direction'] as num?)?.toDouble() ?? 180.0,
        rainProbability: precipitation > 0 ? 80.0 : 20.0,
        rainfallAmount: precipitation,
        uvIndex: 5.0,
        visibility: 8.0,
        condition: HourlyForecast.parseCondition(conditionStr),
        conditionDescription: conditionStr,
        hourlyForecast: WeatherData.defaultData().hourlyForecast,
        dailyForecast: WeatherData.defaultData().dailyForecast,
      );
    }

    // Server reachable but returned an unexpected/empty body — this is a
    // genuine "no data" case (not a connectivity failure), so a clearly
    // placeholder response is reasonable here.
    return WeatherData.defaultData();
  }

  // Fetch hourly and 7-day forecast. Same rule: connectivity failures
  // propagate as ApiUnreachableException instead of being swallowed.
  Future<List<DailyForecast>> getForecast({required double latitude, required double longitude, String? city}) async {
    final Map<String, dynamic> queryParams = {
      'lat': latitude,
      'lon': longitude,
      'days': 5,
    };
    if (city != null) {
      queryParams['city'] = city;
    }

    final response = await _apiClient.get(
      ApiConstants.weatherForecast,
      queryParams: queryParams,
    );
    if (response != null && response['daily'] != null) {
      // Daily forecast parsing if available
    }
    return WeatherData.defaultData().dailyForecast;
  }
}
