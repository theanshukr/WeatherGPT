import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class LocationService {
  static WeatherLocation? _cachedLocation;
  static DateTime? _lastFetchedTime;

  /// Instant access to the last resolved high-precision location
  static WeatherLocation? get currentCachedLocation => _cachedLocation;

  /// Instant hardware GPS position query (zero network blocking)
  /// Uses tiered fallback: cached → low-accuracy (fast) → high-accuracy
  Future<Position?> getRawDevicePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return null;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // 1. Try last known position for instant 0ms response
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          debugPrint('GPS: instant cached position (${lastKnown.latitude}, ${lastKnown.longitude})');
          return lastKnown;
        }

        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('GPS: Location services disabled');
          return null;
        }

        // 2. Quick low-accuracy fix first (1-2 seconds, uses cell towers / WiFi)
        try {
          final quickPos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 3),
            ),
          );
          debugPrint('GPS: quick low-accuracy fix (${quickPos.latitude}, ${quickPos.longitude})');
          return quickPos;
        } catch (e) {
          debugPrint('GPS: low-accuracy timeout, trying high-accuracy...');
        }

        // 3. Full high-accuracy GPS fix (takes longer but most precise)
        try {
          final precisePos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          );
          debugPrint('GPS: high-accuracy fix (${precisePos.latitude}, ${precisePos.longitude})');
          return precisePos;
        } catch (e) {
          debugPrint('GPS: high-accuracy also timed out: $e');
        }
      }
    } catch (e) {
      debugPrint('Direct GPS retrieval error: $e');
    }
    return null;
  }

  // Resolves exact, high-precision GPS coordinates
  Future<WeatherLocation> getCurrentLocation({bool forceRefresh = false}) async {
    // Return cached if fresh (under 3 minutes) unless forced
    if (!forceRefresh &&
        _cachedLocation != null &&
        _lastFetchedTime != null &&
        DateTime.now().difference(_lastFetchedTime!).inMinutes < 3) {
      return _cachedLocation!;
    }

    try {
      final position = await getRawDevicePosition();

      if (position != null) {
        // Reverse geocode to get exact city/neighborhood name
        final cityName = await _reverseGeocode(position.latitude, position.longitude);

        final resolved = WeatherLocation(
          name: cityName.isNotEmpty ? cityName : 'My Location',
          state: 'India',
          latitude: position.latitude,
          longitude: position.longitude,
          country: 'India',
        );

        _cachedLocation = resolved;
        _lastFetchedTime = DateTime.now();
        return resolved;
      }
    } catch (e) {
      debugPrint('GPS location retrieval error: $e');
    }

    // 2. Fallback: Fast Multi-Source IP Geolocation
    try {
      final ipLoc = await _getIpLocation();
      if (ipLoc != null) {
        _cachedLocation = ipLoc;
        _lastFetchedTime = DateTime.now();
        return ipLoc;
      }
    } catch (e) {
      debugPrint('IP location fallback error: $e');
    }

    final fallback = _defaultLocation();
    _cachedLocation ??= fallback;
    return _cachedLocation!;
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    // 1. Try BigDataCloud with high precision locality
    try {
      final res = await http.get(Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en',
      )).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final locality = data['locality'] ?? data['subLocality'];
        final city = data['city'] ?? data['principalSubdivision'];

        if (locality != null && locality.toString().trim().isNotEmpty) {
          final locStr = locality.toString().trim();
          if (city != null && city.toString().trim().isNotEmpty && city.toString() != locStr) {
            return '$locStr, ${city.toString().trim()}';
          }
          return locStr;
        }

        if (city != null && city.toString().trim().isNotEmpty) {
          return city.toString().trim();
        }
      }
    } catch (_) {}

    // 2. Try Nominatim Reverse Geocoding
    try {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=16&addressdetails=1'),
        headers: {'User-Agent': 'WeatherGPT-App/2.0'},
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final sub = address['suburb'] ?? address['neighbourhood'] ?? address['residential'] ?? address['quarter'];
          final city = address['city'] ?? address['town'] ?? address['county'] ?? address['state_district'];

          if (sub != null && sub.toString().trim().isNotEmpty) {
            final subStr = sub.toString().trim();
            if (city != null && city.toString().trim().isNotEmpty && city.toString() != subStr) {
              return '$subStr, ${city.toString().trim()}';
            }
            return subStr;
          }

          if (city != null && city.toString().trim().isNotEmpty) {
            return city.toString().trim();
          }
        }
      }
    } catch (_) {}

    return 'My Location';
  }

  Future<WeatherLocation?> _getIpLocation() async {
    // Source 1: ip-api.com
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
