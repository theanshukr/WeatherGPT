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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // Try last known position first for instantaneous response
        Position? position = await Geolocator.getLastKnownPosition();

        if (position == null && serviceEnabled) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 4),
              ),
            );
          } catch (e) {
            debugPrint('Primary GPS timeout, trying coarse: $e');
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 3),
              ),
            );
          }
        }

        if (position != null) {
          // Reverse geocode to get city name
          final cityName = await _reverseGeocode(position.latitude, position.longitude);

          return WeatherLocation(
            name: cityName.isNotEmpty ? cityName : 'My Location',
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

    // 2. Fallback: Fast Multi-Source IP Geolocation
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
    // 1. Try BigDataCloud
    try {
      final res = await http.get(Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en',
      )).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final city = data['city'] ?? data['locality'] ?? data['principalSubdivision'];
        if (city != null && city.toString().trim().isNotEmpty) {
          return city.toString().trim();
        }
      }
    } catch (_) {}

    // 2. Try Nominatim Reverse Geocoding
    try {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon'),
        headers: {'User-Agent': 'WeatherGPT-App/1.0'},
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'] ?? address['state_district'];
          if (city != null && city.toString().trim().isNotEmpty) {
            return city.toString().trim();
          }
        }
      }
    } catch (_) {}

    return 'My Location';
  }

  Future<WeatherLocation?> _getIpLocation() async {
    // Source 1: ip-api.com (Fastest and most reliable)
    try {
      final res = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          final lat = (data['lat'] as num?)?.toDouble();
          final lon = (data['lon'] as num?)?.toDouble();
          final city = data['city'] as String? ?? 'My Location';
          final region = data['regionName'] as String? ?? 'India';
          final country = data['country'] as String? ?? 'India';

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
      }
    } catch (_) {}

    // Source 2: freeipapi.com
    try {
      final res = await http.get(Uri.parse('https://freeipapi.com/api/json')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();
        final city = data['cityName'] as String? ?? 'My Location';
        final region = data['regionName'] as String? ?? 'India';
        final country = data['countryName'] as String? ?? 'India';

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

    // Source 3: ipapi.co
    try {
      final res = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();
        final city = data['city'] as String? ?? 'My Location';
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
      name: 'Delhi NCR',
      state: 'Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
      country: 'India',
    );
  }
}
