import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class LocationService {
  // Resolves current GPS coordinates and requests permissions dynamically
  Future<WeatherLocation> getCurrentLocation() async {
    try {
      // 1. Test if location services are enabled on device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        // 2. Check & request location permissions
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          // Try last known position first for instant response
          Position? position = await Geolocator.getLastKnownPosition();

          // If null or stale, get fresh high accuracy position with timeout
          position ??= await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );

          // Reverse geocode to get city name
          final cityName = await _reverseGeocode(position.latitude, position.longitude);

          return WeatherLocation(
            name: cityName.isNotEmpty ? cityName : 'Live Location',
            state: 'India',
            latitude: position.latitude,
            longitude: position.longitude,
            country: 'India',
          );
        }
      }
    } catch (e) {
      debugPrint('GPS location retrieval error: $e');
    }

    // 3. Fallback: Fast IP Geolocation
    try {
      final ipLoc = await _getIpLocation();
      if (ipLoc != null) {
        return ipLoc;
      }
    } catch (e) {
      debugPrint('IP location fallback error: $e');
    }

    return _defaultLocation();
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final res = await http.get(Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en',
      )).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final city = data['city'] ?? data['locality'] ?? data['principalSubdivision'];
        if (city != null && city.toString().isNotEmpty) {
          return city.toString();
        }
      }
    } catch (_) {}
    return 'Live Location';
  }

  Future<WeatherLocation?> _getIpLocation() async {
    try {
      final res = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();
        final city = data['city'] as String? ?? 'Live Location';
        final region = data['region'] as String? ?? 'India';
        final country = data['country_name'] as String? ?? 'India';

        if (lat != null && lon != null) {
          return WeatherLocation(
            name: city,
            state: region,
            latitude: lat,
            longitude: lon,
            country: country,
          );
        }
      }
    } catch (_) {}
    return null;
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
