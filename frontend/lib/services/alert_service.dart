// ignore_for_file: unused_field, unused_import
import '../models/alert_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class AlertService {
  final ApiClient _apiClient = ApiClient();

  // Fetch active alerts for user's geographical bounding box
  Future<List<WeatherAlert>> getActiveAlerts({required double latitude, required double longitude}) async {
    /*
    final response = await _apiClient.get(
      ApiConstants.weatherAlerts,
      queryParams: {'latitude': latitude, 'longitude': longitude},
    );
    if (response != null && response['data'] != null) {
      final list = response['data'] as List<dynamic>;
      return list.map((e) => WeatherAlert.fromJson(e as Map<String, dynamic>)).toList();
    }
    */
    return WeatherAlert.defaultAlerts();
  }
}
