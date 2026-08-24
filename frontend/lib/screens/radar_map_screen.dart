import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../core/theme/app_colors.dart';
import '../models/alert_model.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';
import '../widgets/svg_icon.dart';
import '../widgets/bouncing_button.dart';

class RadarMapScreen extends StatefulWidget {
  const RadarMapScreen({super.key});

  @override
  State<RadarMapScreen> createState() => _RadarMapScreenState();
}

// Backward-compatible alias
typedef MapScreen = RadarMapScreen;

class _RadarMapScreenState extends State<RadarMapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final AlertService _alertService = AlertService();
  final LocationService _locationService = LocationService();

  LatLng _userLocation = const LatLng(28.6139, 77.2090);
  String _currentCityName = 'Locating GPS...';
  List<WeatherAlert> _alerts = [];
  WeatherAlert? _selectedAlert;
  bool _isLoadingGps = true;
  String _selectedFilter = 'All Hazards';

  // Precise Live Meteorological Data for User Coordinates
  Map<String, dynamic>? _precisionWeather;
  bool _isTelemetryExpanded = true;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _initInstantLocationAndData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// 1. Instant Hardware GPS → IP Fallback → Full Resolution
  Future<void> _initInstantLocationAndData() async {
    try {
      // Attempt cached location first for absolute instant snap
      final cachedLoc = LocationService.currentCachedLocation;
      if (cachedLoc != null && mounted) {
        final cachedLatLng = LatLng(cachedLoc.latitude, cachedLoc.longitude);
        setState(() {
          _userLocation = cachedLatLng;
          _currentCityName = cachedLoc.name;
          _isLoadingGps = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try { _mapController.move(cachedLatLng, 14.0); } catch (_) {}
        });
        _fetchPrecisionMeteorology(cachedLatLng.latitude, cachedLatLng.longitude);
      }

      // Hardware GPS resolution
      final rawPosition = await _locationService.getRawDevicePosition();
      if (rawPosition != null && mounted) {
        final fastLatLng = LatLng(rawPosition.latitude, rawPosition.longitude);
        setState(() {
          _userLocation = fastLatLng;
          _isLoadingGps = false;
        });

        // Snap map camera immediately to exact user position (Google Maps style)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try { _mapController.move(fastLatLng, 14.0); } catch (_) {}
        });

        // Fetch precision meteorological data asynchronously
        _fetchPrecisionMeteorology(fastLatLng.latitude, fastLatLng.longitude);
      }

      // Detailed location resolution & alerts in background
      final detailedLoc = await _locationService.getCurrentLocation();
      if (mounted) {
        final detailedLatLng = LatLng(detailedLoc.latitude, detailedLoc.longitude);
        setState(() {
          _userLocation = detailedLatLng;
          _currentCityName = detailedLoc.name;
          _isLoadingGps = false;
        });

        // Move map if GPS was null earlier (IP fallback resolved)
        if (rawPosition == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try { _mapController.move(detailedLatLng, 14.0); } catch (_) {}
          });
          _fetchPrecisionMeteorology(detailedLatLng.latitude, detailedLatLng.longitude);
        }

        _loadAlerts(detailedLoc.latitude, detailedLoc.longitude, detailedLoc.name);
      }
    } catch (e) {
      debugPrint('Location initialization error: $e');
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  /// 2. Real-Time High-Precision Meteorological Telemetry from Open-Meteo
  Future<void> _fetchPrecisionMeteorology(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,weather_code,surface_pressure,wind_speed_10m,wind_gusts_10m,uv_index,cloud_cover'
        '&hourly=precipitation_probability,dew_point_2m,visibility'
        '&timezone=auto',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final current = data['current'] ?? {};
        final hourly = data['hourly'] ?? {};

        final probs = (hourly['precipitation_probability'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [];
        final visibilities = (hourly['visibility'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [];
        final dewPoints = (hourly['dew_point_2m'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [];

        final rainProb = probs.isNotEmpty ? probs.first : 0.0;
        final visibilityKm = visibilities.isNotEmpty ? (visibilities.first / 1000.0) : 10.0;
        final dewPoint = dewPoints.isNotEmpty ? dewPoints.first : 18.0;

        if (mounted) {
          setState(() {
            _precisionWeather = {
              'temp': (current['temperature_2m'] as num?)?.toDouble() ?? 28.0,
              'feels_like': (current['apparent_temperature'] as num?)?.toDouble() ?? 29.0,
              'rain_mm': (current['precipitation'] as num?)?.toDouble() ?? 0.0,
              'rain_prob': rainProb,
              'wind_speed': (current['wind_speed_10m'] as num?)?.toDouble() ?? 10.0,
              'wind_gusts': (current['wind_gusts_10m'] as num?)?.toDouble() ?? 14.0,
              'humidity': (current['relative_humidity_2m'] as num?)?.toInt() ?? 55,
              'pressure': (current['surface_pressure'] as num?)?.toDouble() ?? 1012.0,
              'uv_index': (current['uv_index'] as num?)?.toDouble() ?? 5.0,
              'cloud_cover': (current['cloud_cover'] as num?)?.toInt() ?? 20,
              'dew_point': dewPoint,
              'visibility_km': visibilityKm,
              'weather_code': current['weather_code'] as int? ?? 0,
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching precision meteorology: $e');
    }
  }

  Future<void> _loadAlerts(double lat, double lon, String city) async {
    try {
      final realAlerts = await _alertService.getAllAlerts(
        latitude: lat,
        longitude: lon,
        city: city,
        country: 'India',
      );

      if (mounted) {
        setState(() {
          _alerts = realAlerts;
        });
      }
    } catch (e) {
      debugPrint('Alerts load error: $e');
    }
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'Clear Sky';
    if (code == 1 || code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code >= 45 && code <= 48) return 'Fog & Mist';
    if (code >= 51 && code <= 55) return 'Light Drizzle';
    if (code >= 61 && code <= 65) return 'Rain Showers';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Heavy Rainfall';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Clear';
  }

  List<WeatherAlert> get _filteredAlerts {
    final valid = _alerts.where((a) => a.id != 'telemetry_status').toList();

    if (_selectedFilter == '🌊 Flood & Rain') {
      return valid.where((a) {
        final t = a.title.toLowerCase();
        return t.contains('flood') || t.contains('rain') || t.contains('shower');
      }).toList();
    } else if (_selectedFilter == '⚡ Severe Storms') {
      return valid.where((a) {
        final t = a.title.toLowerCase();
        return t.contains('storm') || t.contains('lightning') || t.contains('thunder');
      }).toList();
    } else if (_selectedFilter == '🌡️ Heat & Wind') {
      return valid.where((a) {
        final t = a.title.toLowerCase();
        return t.contains('heat') || t.contains('wind') || t.contains('uv');
      }).toList();
    }
    return valid;
  }

  void _recenterToUser() {
    _mapController.move(_userLocation, 14.0);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom + 1).clamp(3.0, 18.0));
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom - 1).clamp(3.0, 18.0));
  }

  Color _getHazardColor(WeatherAlert alert) {
    final t = alert.title.toLowerCase();
    if (t.contains('flood')) return const Color(0xFF0284C7);
    if (t.contains('rain')) return const Color(0xFF3B82F6);
    if (t.contains('storm') || t.contains('lightning')) return const Color(0xFF8B5CF6);
    if (t.contains('heat')) return const Color(0xFFEA580C);
    if (t.contains('wind')) return const Color(0xFF10B981);
    return const Color(0xFF7C3AED);
  }

  String _getHazardIcon(WeatherAlert alert) {
    final t = alert.title.toLowerCase();
    if (t.contains('flood') || t.contains('rain')) return 'cloud_rain';
    if (t.contains('storm') || t.contains('lightning')) return 'lightning';
    if (t.contains('heat')) return 'sun';
    return 'bell';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayAlerts = _filteredAlerts;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF3F2F8),
      body: Stack(
        children: [
          // 1. Rock-Solid, High-Res Basemap (Zero "Zoom Level Not Supported" errors)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 14.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Clean Standard OpenStreetMap / Carto Basemap Tiles
              TileLayer(
                urlTemplate: isDark
                    ? 'https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.weathergpt.app',
                maxZoom: 19,
                maxNativeZoom: 18,
              ),

              // Markers: Google Maps-Style Blue Location Puck & Active Hazard Badges
              MarkerLayer(
                markers: [
                  // Authentic Google Maps Blue Dot GPS Indicator
                  Marker(
                    point: _userLocation,
                    width: 76,
                    height: 76,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulse = _pulseController.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Translucent Accuracy Halo
                              Container(
                                width: 28 + (pulse * 36),
                                height: 28 + (pulse * 36),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF4285F4).withValues(alpha: 0.22 * (1.0 - pulse)),
                                ),
                              ),
                              // Soft Middle Aura
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                                ),
                              ),
                              // Core Google Maps Solid Blue Beacon
                              Container(
                                width: 17,
                                height: 17,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1A73E8),
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x661A73E8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // Real Active Weather Hazard Pins (Only shown when genuine warnings exist)
                  ...displayAlerts.where((a) => a.latitude != 0.0 && a.longitude != 0.0).map((alert) {
                    final markerColor = _getHazardColor(alert);
                    final iconName = _getHazardIcon(alert);
                    final isSelected = _selectedAlert?.id == alert.id;

                    return Marker(
                      point: LatLng(alert.latitude, alert.longitude),
                      width: isSelected ? 50 : 40,
                      height: isSelected ? 50 : 40,
                      child: IosBouncingButton(
                        onTap: () {
                          setState(() => _selectedAlert = alert);
                          _mapController.move(LatLng(alert.latitude, alert.longitude), 13.0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                            border: Border.all(
                              color: isSelected ? markerColor : markerColor.withValues(alpha: 0.8),
                              width: isSelected ? 2.5 : 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: markerColor.withValues(alpha: isSelected ? 0.5 : 0.25),
                                blurRadius: isSelected ? 12 : 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: IosSvgIcon(
                              iconName,
                              size: isSelected ? 20 : 16,
                              color: markerColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Top Header Bar & Category Chips
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Row: Location Pill & Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button if pushed
                      if (Navigator.canPop(context))
                        IosBouncingButton(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                            ),
                          ),
                        ),

                      // Location Title Pill with Live Status Beacon
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isLoadingGps ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isLoadingGps ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentCityName,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
                                  ),
                                ),
                              ),
                              if (_precisionWeather != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${(_precisionWeather!['temp'] as double).round()}°C',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF4285F4),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // GPS Recenter Button (Google Maps-Style Target)
                      IosBouncingButton(
                        onTap: _recenterToUser,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.my_location_rounded,
                              color: Color(0xFF1A73E8),
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Horizontal Hazard Filter Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip('All Hazards', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('🌊 Flood & Rain', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('⚡ Severe Storms', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('🌡️ Heat & Wind', isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Right Side Floating Zoom Controls
          Positioned(
            right: 16,
            top: 135,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  IosBouncingButton(
                    onTap: _zoomIn,
                    child: const SizedBox(
                      width: 42,
                      height: 40,
                      child: Icon(Icons.add_rounded, size: 20),
                    ),
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3)),
                  IosBouncingButton(
                    onTap: _zoomOut,
                    child: const SizedBox(
                      width: 42,
                      height: 40,
                      child: Icon(Icons.remove_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Floating Precision Weather & Alerts HUD
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected Hazard Banner (if a pin is clicked)
                if (_selectedAlert != null) ...[
                  _buildSelectedAlertBanner(_selectedAlert!, isDark),
                  const SizedBox(height: 10),
                ],

                // Real Meteorological Telemetry Card at exact location
                if (_precisionWeather != null && _selectedAlert == null)
                  _buildPrecisionTelemetryHUD(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Google Weather / Apple Weather Style Live Telemetry HUD
  Widget _buildPrecisionTelemetryHUD(bool isDark) {
    final w = _precisionWeather!;
    final temp = (w['temp'] as num).toDouble();
    final feelsLike = (w['feels_like'] as num).toDouble();
    final rainMm = (w['rain_mm'] as num).toDouble();
    final rainProb = (w['rain_prob'] as num).toDouble();
    final windSpeed = (w['wind_speed'] as num).toDouble();
    final windGusts = (w['wind_gusts'] as num).toDouble();
    final humidity = (w['humidity'] as num).toInt();
    final pressure = (w['pressure'] as num).toDouble();
    final uvIndex = (w['uv_index'] as num).toDouble();
    final cloudCover = (w['cloud_cover'] as num).toInt();
    final visibilityKm = (w['visibility_km'] as num).toDouble();
    final weatherCode = (w['weather_code'] as num).toInt();
    final desc = _getWeatherDescription(weatherCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface.withValues(alpha: 0.96) : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : const Color(0xFFE5E2EE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main Headline Row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: IosSvgIcon(
                    rainMm > 0 ? 'cloud_rain' : (weatherCode == 0 ? 'sun' : 'cloud'),
                    size: 24,
                    color: const Color(0xFF1A73E8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${temp.round()}°C',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            desc,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Feels like ${feelsLike.round()}°C • Cloud Cover $cloudCover%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              // Expand / Collapse Toggle
              IosBouncingButton(
                onTap: () => setState(() => _isTelemetryExpanded = !_isTelemetryExpanded),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF232030) : const Color(0xFFF3F2F8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isTelemetryExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),

          if (_isTelemetryExpanded) ...[
            const SizedBox(height: 14),
            // Precision Meteorological Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Precipitation',
                    value: rainMm > 0 ? '${rainMm.toStringAsFixed(1)} mm/h' : '${rainProb.round()}% prob',
                    icon: Icons.water_drop_rounded,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Wind Speed',
                    value: '${windSpeed.round()} km/h (G ${windGusts.round()})',
                    icon: Icons.air_rounded,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Humidity / UV',
                    value: '$humidity% • UV ${uvIndex.toStringAsFixed(1)}',
                    icon: Icons.opacity_rounded,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Pressure / Visibility',
                    value: '${pressure.round()} hPa • ${visibilityKm.toStringAsFixed(1)} km',
                    icon: Icons.speed_rounded,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1B28) : const Color(0xFFF7F6FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2B283A) : const Color(0xFFECEAF3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: isDark ? AppColors.darkTextTertiary : const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _selectedFilter == label;
    return IosBouncingButton(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _selectedAlert = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A73E8)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A73E8)
                : (isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3)),
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF1A73E8).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : const Color(0xFF1F2937)),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedAlertBanner(WeatherAlert alert, bool isDark) {
    final color = _getHazardColor(alert);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IosSvgIcon(_getHazardIcon(alert), size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alert.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF)),
                onPressed: () => setState(() => _selectedAlert = null),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alert.description,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
              height: 1.35,
            ),
          ),
          if (alert.instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '⚠️ ${alert.instructions}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.08, end: 0);
  }
}
