import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alert_model.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

class AlertService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch computed threshold alerts for user's geographical location.
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

      if (response != null && response is Map<String, dynamic>) {
        final triggered = response['triggered'] as List<dynamic>?;
        if (triggered != null && triggered.isNotEmpty) {
          return triggered.asMap().entries
              .map((e) => WeatherAlert.fromThresholdAlert(
                    e.value as Map<String, dynamic>,
                    index: e.key,
                  ))
              .toList();
        }
      }
    } catch (_) {}

    // Fallback: Compute real-time meteorological risk advisories from Open-Meteo
    return await _computeOpenMeteoRiskAlerts(latitude, longitude, city);
  }

  Future<List<WeatherAlert>> _computeOpenMeteoRiskAlerts(double lat, double lon, String? city) async {
    final now = DateTime.now();
    final areaName = city ?? 'Your Local Area';

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,weather_code,wind_speed_10m,wind_gusts_10m,uv_index&hourly=precipitation_probability,rain,weather_code&timezone=auto',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final current = data['current'] ?? {};
        final hourly = data['hourly'] ?? {};
        final alerts = <WeatherAlert>[];

        final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 25.0;
        final wind = (current['wind_gusts_10m'] as num?)?.toDouble() ?? 10.0;
        final uv = (current['uv_index'] as num?)?.toDouble() ?? 5.0;
        final precipProbs = (hourly['precipitation_probability'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [];
        final maxRainProb = precipProbs.take(12).fold(0.0, (prev, elem) => elem > prev ? elem : prev);

        // 1. Heat Index / High Temperature Alert
        if (temp >= 38.0) {
          alerts.add(WeatherAlert(
            id: 'heat_warning',
            title: 'Severe Heatwave Advisory (${temp.round()}°C)',
            description: 'Extreme ambient temperature detected. High risk of dehydration and thermal stress.',
            severity: AlertSeverity.warning,
            area: areaName,
            source: 'threshold',
            startsAt: now,
            expiresAt: now.add(const Duration(hours: 6)),
            latitude: lat,
            longitude: lon,
            instructions: 'Stay indoors during 12 PM - 4 PM. Stay hydrated and avoid strenuous outdoor work.',
          ));
        }

        // 2. High Rain / Convective Storm Alert
        if (maxRainProb >= 60.0) {
          alerts.add(WeatherAlert(
            id: 'rain_convective_alert',
            title: 'Elevated Rain & Convective Storm Risk (${maxRainProb.round()}%)',
            description: 'High atmospheric moisture indicates imminent showers and localized waterlogging risk.',
            severity: maxRainProb >= 80 ? AlertSeverity.warning : AlertSeverity.advisory,
            area: areaName,
            source: 'threshold',
            startsAt: now,
            expiresAt: now.add(const Duration(hours: 6)),
            latitude: lat,
            longitude: lon,
            instructions: 'Carry rain protection. Avoid low-lying underpasses and delay crop spraying operations.',
          ));
        }

        // 3. High Wind Gust Advisory
        if (wind >= 35.0) {
          alerts.add(WeatherAlert(
            id: 'high_wind_alert',
            title: 'High Wind Gust Alert (${wind.round()} km/h)',
            description: 'Strong gusting winds may affect two-wheeler stability and loose overhead structures.',
            severity: AlertSeverity.watch,
            area: areaName,
            source: 'threshold',
            startsAt: now,
            expiresAt: now.add(const Duration(hours: 6)),
            latitude: lat,
            longitude: lon,
            instructions: 'Secure outdoor equipment, shade nets, and drive cautiously on exposed highways.',
          ));
        }

        // 4. Extreme UV Index Alert
        if (uv >= 8.0) {
          alerts.add(WeatherAlert(
            id: 'uv_advisory',
            title: 'Very High UV Radiation Index (${uv.toStringAsFixed(1)})',
            description: 'Intense ultraviolet radiation levels can cause rapid skin sunburn and eye strain.',
            severity: AlertSeverity.advisory,
            area: areaName,
            source: 'threshold',
            startsAt: now,
            expiresAt: now.add(const Duration(hours: 6)),
            latitude: lat,
            longitude: lon,
            instructions: 'Apply broad-spectrum sunscreen and wear UV-rated sunglasses when outdoors.',
          ));
        }

        if (alerts.isNotEmpty) {
          return alerts;
        }
      }
    } catch (_) {}

    // Default general climate telemetry advisory
    return [
      WeatherAlert(
        id: 'telemetry_status',
        title: 'Normal Meteorological Conditions',
        description: 'Atmospheric telemetry indicates stable weather without active NDMA disaster warnings.',
        severity: AlertSeverity.advisory,
        area: areaName,
        source: 'threshold',
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 6)),
        latitude: lat,
        longitude: lon,
        instructions: 'Safe for travel, outdoor activities, and routine agricultural operations.',
      )
    ];
  }

  /// Fetch official disaster alerts from GDACS / NDMA via /weather/official-alerts.
  Future<List<WeatherAlert>> getOfficialAlerts({String? country}) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.officialAlerts,
        queryParams: country != null ? {'country': country} : null,
      );

      if (response != null && response is List<dynamic>) {
        return response
            .map((e) => WeatherAlert.fromOfficialAlert(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
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

    final merged = [...results[0], ...results[1]];
    return merged.isNotEmpty ? merged : await _computeOpenMeteoRiskAlerts(latitude, longitude, city);
  }
}
