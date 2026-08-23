import '../models/alert_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class AlertService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch computed threshold alerts for user's geographical location.
  /// Backend /weather/alerts returns: {active_count, severity_class, triggered: [...]}
  Future<List<WeatherAlert>> getActiveAlerts({required double latitude, required double longitude, String? city}) async {
    final Map<String, dynamic> queryParams = {
      'lat': latitude,
      'lon': longitude,
    };
    if (city != null) {
      queryParams['city'] = city;
    }

    try {
      final response = await _apiClient.get(
        ApiConstants.weatherAlerts,
        queryParams: queryParams,
      );

      if (response == null) return [];

      // Backend returns {active_count, severity_class, triggered: [...]}
      if (response is Map<String, dynamic>) {
        final triggered = response['triggered'] as List<dynamic>?;
        if (triggered != null) {
          return triggered.asMap().entries
              .map((e) => WeatherAlert.fromThresholdAlert(
                    e.value as Map<String, dynamic>,
                    index: e.key,
                  ))
              .toList();
        }
        // Fallback: maybe response has 'alerts' key
        final alerts = response['alerts'] as List<dynamic>?;
        if (alerts != null) {
          return alerts.map((e) => WeatherAlert.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      }

      // Fallback: direct list response
      if (response is List<dynamic>) {
        return response.map((e) => WeatherAlert.fromJson(e as Map<String, dynamic>)).toList();
      }

      return [];
    } catch (e) {
      // Don't crash — return empty list on API failure
      return [];
    }
  }

  /// Fetch official disaster alerts from GDACS / NDMA via /weather/official-alerts.
  Future<List<WeatherAlert>> getOfficialAlerts({String? country}) async {
    final Map<String, dynamic> queryParams = {};
    if (country != null) {
      queryParams['country'] = country;
    }

    try {
      final response = await _apiClient.get(
        ApiConstants.officialAlerts,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );

      if (response != null && response is List<dynamic>) {
        return response
            .map((e) => WeatherAlert.fromOfficialAlert(e as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch all alerts — both threshold and official — merged.
  Future<List<WeatherAlert>> getAllAlerts({
    required double latitude,
    required double longitude,
    String? city,
    String? country,
  }) async {
    final results = await Future.wait([
      getActiveAlerts(latitude: latitude, longitude: longitude, city: city),
      getOfficialAlerts(country: country),
    ]);

    return [...results[0], ...results[1]];
  }
}
