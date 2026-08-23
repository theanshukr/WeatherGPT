import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';

class WeatherProvider with ChangeNotifier {
  final WeatherService _weatherService = WeatherService();
  final LocationService _locationService = LocationService();

  WeatherData _weatherData = WeatherData.empty();
  bool _isLoading = false;
  String? _errorMessage;

  WeatherData get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  WeatherProvider() {
    loadWeatherData();
  }

  Future<void> loadWeatherData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loc = await _locationService.getCurrentLocation();
      _weatherData = await _weatherService.getCurrentWeather(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
