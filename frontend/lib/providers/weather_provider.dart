import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';

class WeatherProvider with ChangeNotifier {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();

  WeatherData _weatherData = WeatherData.empty();
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasLoaded = false;

  WeatherData get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _hasLoaded;

  WeatherProvider() {
    loadWeatherData();
  }

  /// Load full weather data — tries snapshot endpoint first (has hourly + daily),
  /// falls back to current-only endpoint.
  Future<void> loadWeatherData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loc = await _locationService.getCurrentLocation();

      // Try snapshot endpoint first (gives current + hourly + daily)
      try {
        _weatherData = await _weatherService.getWeatherSnapshot(
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      } catch (_) {
        // Fallback to current-only endpoint
        _weatherData = await _weatherService.getCurrentWeather(
          latitude: loc.latitude,
          longitude: loc.longitude,
        );

        // Try to get hourly data separately
        try {
          final hourly = await _weatherService.getHourlyForecast(
            latitude: loc.latitude,
            longitude: loc.longitude,
          );
          if (hourly.isNotEmpty) {
            _weatherData = _weatherData.copyWith(hourlyForecast: hourly);
          }
        } catch (_) {}
      }

      _errorMessage = null;
      _hasLoaded = true;
    } catch (e) {
      _errorMessage = e.toString();
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
