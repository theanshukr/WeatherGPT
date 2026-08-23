import '../models/alert_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class AlertService {
  final ApiClient _apiClient = ApiClient();

  // Fetch active alerts for user's geographical location
  Future<List<WeatherAlert>> getActiveAlerts({required double latitude, required double longitude, String? city}) async {
    final Map<String, dynamic> queryParams = {
      'lat': latitude,
      'lon': longitude,
    };
    if (city != null) {
      queryParams['city'] = city;
    }

    final response = await _apiClient.get(
      ApiConstants.weatherAlerts,
      queryParams: queryParams,
    );

    if (response != null && response is List<dynamic>) {
      return response.map((e) => WeatherAlert.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (response != null && response is Map<String, dynamic> && response['alerts'] is List<dynamic>) {
      final list = response['alerts'] as List<dynamic>;
      return list.map((e) => WeatherAlert.fromJson(e as Map<String, dynamic>)).toList();
    }

    return [];
  }
}
