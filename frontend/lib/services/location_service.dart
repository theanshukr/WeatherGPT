import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/weather_model.dart';

class LocationService {
  // Resolves current GPS coordinates and requests permissions dynamically
  Future<WeatherLocation> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 1. Test if location services are enabled on device
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _defaultLocation();
      }

      // 2. Check location permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _defaultLocation();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _defaultLocation();
      }

      // 3. Obtain current position with 8-second timeout
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return WeatherLocation(
        name: 'Current Location',
        state: 'Local',
        latitude: position.latitude,
        longitude: position.longitude,
        country: 'India',
      );
    } catch (_) {
      // Graceful fallback for simulator / desktop or timeout
      return _defaultLocation();
    }
  }

  WeatherLocation _defaultLocation() {
    return const WeatherLocation(
      name: 'New Delhi',
      state: 'Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
      country: 'India',
    );
  }
}
