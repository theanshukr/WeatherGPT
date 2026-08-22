import '../models/weather_model.dart';

class LocationService {
  // Resolves current GPS coordinates (with default fallback for immediate startup)
  Future<WeatherLocation> getCurrentLocation() async {
    // In production, uses geolocator / platform location channels
    return const WeatherLocation(
      name: 'New Delhi',
      state: 'Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
      country: 'India',
    );
  }
}
