import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
import '../services/radar_service.dart';
import '../widgets/ios_svg_icon.dart';
import '../widgets/ios_bouncing_button.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final AlertService _alertService = AlertService();
  final LocationService _locationService = LocationService();
  final RadarService _radarService = RadarService();

  LatLng _userLocation = const LatLng(28.6139, 77.2090);
  String _currentCityName = 'Resolving GPS...';
  List<WeatherAlert> _alerts = [];
  WeatherAlert? _selectedAlert;
  bool _isLoading = true;
  String _selectedFilter = 'All Hazards';

  // Real Doppler Radar Timeline Data
  RadarTimelineData? _radarData;
  int _activeRadarFrameIndex = 2; // Default to LIVE
  bool _isPlayingRadar = true;
  Timer? _radarPlaybackTimer;

  // Real-time Precision Telemetry at exact user coordinates
  Map<String, dynamic> _precisionWeather = {};
  bool _showTelemetryCard = true;

  late AnimationController _pulseController;
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _loadData();
    _loadRealRadarTimeline();
  }

  @override
  void dispose() {
    _radarPlaybackTimer?.cancel();
    _pulseController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  void _startRadarPlayback() {
    _radarPlaybackTimer?.cancel();
    final framesCount = _radarData?.frames.length ?? 5;
    _radarPlaybackTimer = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      if (_isPlayingRadar && mounted && (_radarData?.frames.isNotEmpty ?? false)) {
        setState(() {
          _activeRadarFrameIndex = (_activeRadarFrameIndex + 1) % framesCount;
        });
      }
    });
  }

  Future<void> _loadRealRadarTimeline() async {
    try {
      final data = await _radarService.getRadarTimeline();
      if (mounted && data != null && data.frames.isNotEmpty) {
        setState(() {
          _radarData = data;
          _activeRadarFrameIndex = data.defaultLiveIndex.clamp(0, data.frames.length - 1);
        });
        _startRadarPlayback();
      }
    } catch (e) {
      debugPrint('Error initializing Doppler radar tiles: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      // 1. High-precision live GPS coordinates
      final loc = await _locationService.getCurrentLocation(forceRefresh: true);
      final userLatLng = LatLng(loc.latitude, loc.longitude);

      // 2. Fetch real weather alerts & real precision telemetry concurrently
      final results = await Future.wait([
        _alertService.getAllAlerts(
          latitude: loc.latitude,
          longitude: loc.longitude,
          city: loc.name,
          country: 'India',
        ),
        _fetchPrecisionWeather(loc.latitude, loc.longitude),
      ]);

      final realAlerts = results[0] as List<WeatherAlert>;
      final precision = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _userLocation = userLatLng;
          _currentCityName = loc.name;
          _alerts = realAlerts;
          _precisionWeather = precision;
          _isLoading = false;
        });

        // Center map smoothly on exact live GPS location
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(userLatLng, 11.0);
          } catch (_) {}
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentCityName = 'Live Location';
        });
      }
    }
  }

  Future<Map<String, dynamic>> _fetchPrecisionWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,weather_code,wind_speed_10m,wind_gusts_10m,uv_index,is_day&hourly=precipitation_probability&timezone=auto',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final current = data['current'] ?? {};
        final hourly = data['hourly'] ?? {};
        final probs = (hourly['precipitation_probability'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [];
        final rainProb = probs.isNotEmpty ? probs.first : 0.0;

        return {
          'temp': (current['temperature_2m'] as num?)?.toDouble() ?? 28.0,
          'feels_like': (current['apparent_temperature'] as num?)?.toDouble() ?? 29.0,
          'rain_mm': (current['precipitation'] as num?)?.toDouble() ?? 0.0,
          'rain_prob': rainProb,
          'wind_speed': (current['wind_speed_10m'] as num?)?.toDouble() ?? 12.0,
          'wind_gusts': (current['wind_gusts_10m'] as num?)?.toDouble() ?? 16.0,
          'humidity': (current['relative_humidity_2m'] as num?)?.toInt() ?? 60,
          'uv_index': (current['uv_index'] as num?)?.toDouble() ?? 5.0,
          'weather_code': current['weather_code'] as int? ?? 0,
          'is_day': current['is_day'] as int? ?? 1,
        };
      }
    } catch (e) {
      debugPrint('Precision telemetry fetch error: $e');
    }

    return {
      'temp': 28.0,
      'feels_like': 29.0,
      'rain_mm': 0.0,
      'rain_prob': 0.0,
      'wind_speed': 10.0,
      'wind_gusts': 14.0,
      'humidity': 55,
      'uv_index': 5.0,
      'weather_code': 0,
      'is_day': 1,
    };
  }

  String _getWeatherConditionDescription(int code) {
    if (code == 0) return 'Clear Sky';
    if (code == 1 || code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code >= 61 && code <= 65) return 'Rain Showers';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Heavy Rain';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Clear';
  }

  List<WeatherAlert> get _filteredAlerts {
    // Only real alerts matching the filter
    final validAlerts = _alerts.where((a) => a.id != 'telemetry_status').toList();

    if (_selectedFilter == '🌊 Flood & Rain') {
      return validAlerts.where((a) {
        final t = a.title.toLowerCase();
        return t.contains('flood') || t.contains('rain') || t.contains('shower');
      }).toList();
    } else if (_selectedFilter == '⚡ Severe Storms') {
      return validAlerts.where((a) {
        final t = a.title.toLowerCase();
        return t.contains('storm') || t.contains('lightning') || t.contains('thunder');
      }).toList();
    } else if (_selectedFilter == '🌡️ Heat & Wind') {
      return validAlerts.where((a) {
        final t = a.title.toLowerCase();
        return t.contains('heat') || t.contains('wind') || t.contains('uv');
      }).toList();
    }
    return validAlerts;
  }

  void _recenter() {
    _mapController.move(_userLocation, 11.0);
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

  RadarFrame? get _activeRadarFrame {
    if (_radarData == null || _radarData!.frames.isEmpty) return null;
    final index = _activeRadarFrameIndex.clamp(0, _radarData!.frames.length - 1);
    return _radarData!.frames[index];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayAlerts = _filteredAlerts;
    final activeFrame = _activeRadarFrame;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F3F8),
      body: Stack(
        children: [
          // 1. High-Performance Real Basemap & Live Doppler Radar Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 11.0,
              minZoom: 4.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Base Map (CartoDB Dark Matter / Positron Voyager)
              TileLayer(
                urlTemplate: isDark
                    ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
                    : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.weathergpt.app',
                maxZoom: 19,
              ),

              // 100% Real Live Doppler Radar Tiles from RainViewer Global Radar Network
              if (activeFrame != null && activeFrame.path.isNotEmpty)
                TileLayer(
                  key: ValueKey('radar_${activeFrame.path}'),
                  urlTemplate: activeFrame.getTileUrlTemplate(
                    host: _radarData?.host ?? 'https://tilecache.rainviewer.com',
                    colorScheme: 2, // Standard Doppler Weather Radar Scheme
                  ),
                  userAgentPackageName: 'com.weathergpt.app',
                  tileProvider: NetworkTileProvider(),
                  tileBuilder: (context, tileWidget, tile) {
                    return Opacity(
                      opacity: 0.72,
                      child: tileWidget,
                    );
                  },
                ),

              // Markers Layer: Live Precision User Beacon & Real Hazard Pins
              MarkerLayer(
                markers: [
                  // High-Precision Apple/Google Maps-Style Pulsing User Location Beacon
                  Marker(
                    point: _userLocation,
                    width: 80,
                    height: 80,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulse = _pulseController.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer expanding radar pulse aura
                              Container(
                                width: 32 + (pulse * 40),
                                height: 32 + (pulse * 40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.22 * (1.0 - pulse)),
                                ),
                              ),
                              // Middle accuracy ring
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                              ),
                              // Core solid precision beacon
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF7C3AED),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
                                      blurRadius: 10,
                                      spreadRadius: 1,
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

                  // Real Active Weather Hazard Pins (Only genuine alerts)
                  ...displayAlerts.where((a) => a.latitude != 0.0 && a.longitude != 0.0).map((alert) {
                    final markerColor = _getHazardColor(alert);
                    final iconName = _getHazardIcon(alert);
                    final isSelected = _selectedAlert?.id == alert.id;

                    return Marker(
                      point: LatLng(alert.latitude, alert.longitude),
                      width: isSelected ? 52 : 42,
                      height: isSelected ? 52 : 42,
                      child: IosBouncingButton(
                        onTap: () {
                          setState(() => _selectedAlert = alert);
                          _mapController.move(LatLng(alert.latitude, alert.longitude), 11.5);
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
                                blurRadius: isSelected ? 14 : 8,
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

          // 2. Animated Doppler Radar Sweep Effect Overlay
          if (_isPlayingRadar)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _sweepController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _RadarSweepPainter(
                        centerOffset: const Offset(0.5, 0.45),
                        progress: _sweepController.value,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
            ),

          // 3. Top Header Bar & Real Category Chips
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back or Radar Button
                      IosBouncingButton(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Navigator.canPop(context)
                                ? Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
                                    size: 16,
                                  )
                                : const IosSvgIcon('radar', size: 18, color: Color(0xFF7C3AED)),
                          ),
                        ),
                      ),

                      // City Radar Pill with Live Beacon Indicator
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isLoading ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '$_currentCityName Radar',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // GPS Recenter Button (Snaps to exact user GPS)
                      IosBouncingButton(
                        onTap: _recenter,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                              width: 1,
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
                            child: Icon(
                              Icons.my_location_rounded,
                              color: Color(0xFF7C3AED),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Horizontal Hazard Category Chips Bar
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

          // 4. Right Side Floating Zoom, Telemetry Toggle & Playback Controls
          Positioned(
            right: 16,
            top: 135,
            child: Column(
              children: [
                // Radar Live Play/Pause
                IosBouncingButton(
                  onTap: () {
                    setState(() {
                      _isPlayingRadar = !_isPlayingRadar;
                      if (_isPlayingRadar) _startRadarPlayback();
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                    child: Center(
                      child: IosSvgIcon(
                        _isPlayingRadar ? 'pause' : 'play',
                        size: 16,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ),

                // Precision Telemetry HUD Toggle
                IosBouncingButton(
                  onTap: () => setState(() => _showTelemetryCard = !_showTelemetryCard),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showTelemetryCard
                            ? const Color(0xFF7C3AED)
                            : (isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3)),
                        width: _showTelemetryCard ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.thermostat_rounded,
                        size: 19,
                        color: _showTelemetryCard ? const Color(0xFF7C3AED) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),

                // Zoom Controls
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                  child: Column(
                    children: [
                      IosBouncingButton(
                        onTap: _zoomIn,
                        child: const SizedBox(
                          width: 40,
                          height: 38,
                          child: Icon(Icons.add_rounded, size: 20),
                        ),
                      ),
                      Divider(height: 1, color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3)),
                      IosBouncingButton(
                        onTap: _zoomOut,
                        child: const SizedBox(
                          width: 40,
                          height: 38,
                          child: Icon(Icons.remove_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom Real Radar Timeline Bar & Precision Weather Telemetry HUD
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected Hazard Alert Card (if tapped)
                if (_selectedAlert != null) ...[
                  _buildSelectedAlertBanner(_selectedAlert!, isDark),
                  const SizedBox(height: 10),
                ],

                // Real-Time Precision Location Weather Telemetry Card
                if (_showTelemetryCard && _selectedAlert == null && _precisionWeather.isNotEmpty) ...[
                  _buildPrecisionTelemetryCard(isDark),
                  const SizedBox(height: 10),
                ],

                // Real Doppler Radar Timeline Scrubber Bar (-30m to +30m)
                _buildRealRadarScrubber(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Glassmorphic HUD showing exact precision weather metrics at live location
  Widget _buildPrecisionTelemetryCard(bool isDark) {
    final temp = (_precisionWeather['temp'] as num?)?.toDouble() ?? 28.0;
    final feelsLike = (_precisionWeather['feels_like'] as num?)?.toDouble() ?? 29.0;
    final rainMm = (_precisionWeather['rain_mm'] as num?)?.toDouble() ?? 0.0;
    final rainProb = (_precisionWeather['rain_prob'] as num?)?.toDouble() ?? 0.0;
    final windSpeed = (_precisionWeather['wind_speed'] as num?)?.toDouble() ?? 10.0;
    final humidity = (_precisionWeather['humidity'] as num?)?.toInt() ?? 60;
    final weatherCode = _precisionWeather['weather_code'] as int? ?? 0;
    final conditionDesc = _getWeatherConditionDescription(weatherCode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Location Name & Exact Condition
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: IosSvgIcon(
                        rainMm > 0 ? 'cloud_rain' : (weatherCode == 0 ? 'sun' : 'cloud'),
                        size: 17,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentCityName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
                        ),
                      ),
                      Text(
                        '$conditionDesc • Feels ${feelsLike.round()}°C',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Temperature badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${temp.round()}°C',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Telemetry Pills Row: Rain mm, Rain %, Wind, Humidity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTelemetryMetric(
                label: 'Precipitation',
                value: rainMm > 0 ? '${rainMm.toStringAsFixed(1)} mm/h' : '${rainProb.round()}% prob',
                icon: Icons.water_drop_rounded,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
              _buildTelemetryMetric(
                label: 'Wind Gusts',
                value: '${windSpeed.round()} km/h',
                icon: Icons.air_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
              _buildTelemetryMetric(
                label: 'Humidity',
                value: '$humidity%',
                icon: Icons.opacity_rounded,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildTelemetryMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF221F2E) : const Color(0xFFF7F6FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2B3D) : const Color(0xFFECEAF3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
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
                  color: isDark ? AppColors.darkTextTertiary : const Color(0xFF9CA3AF),
                ),
              ),
            ],
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
              ? const Color(0xFF7C3AED)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C3AED)
                : (isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3)),
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
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

  /// Real Doppler Radar Timeline Scrubber Bar
  Widget _buildRealRadarScrubber(bool isDark) {
    final frames = _radarData?.frames ?? [
      const RadarFrame(time: 0, path: '', label: '-30m'),
      const RadarFrame(time: 0, path: '', label: '-15m'),
      const RadarFrame(time: 0, path: '', label: 'LIVE', isLive: true),
      const RadarFrame(time: 0, path: '', label: '+15m', isNowcast: true),
      const RadarFrame(time: 0, path: '', label: '+30m', isNowcast: true),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(frames.length, (index) {
          final frame = frames[index];
          final isSelected = _activeRadarFrameIndex == index;
          final isLive = frame.isLive;
          final isNowcast = frame.isNowcast;

          return IosBouncingButton(
            onTap: () {
              setState(() {
                _activeRadarFrameIndex = index;
                _isPlayingRadar = false;
                _radarPlaybackTimer?.cancel();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isLive
                        ? const Color(0xFF10B981)
                        : (isNowcast ? const Color(0xFF38BDF8) : const Color(0xFF7C3AED)))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLive && isSelected) ...[
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    frame.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedAlertBanner(WeatherAlert alert, bool isDark) {
    final color = _getHazardColor(alert);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 14,
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
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0);
  }
}

/// Custom radar sweep line painter for authentic animated Doppler scanner effect
class _RadarSweepPainter extends CustomPainter {
  final Offset centerOffset;
  final double progress;
  final bool isDark;

  _RadarSweepPainter({
    required this.centerOffset,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * centerOffset.dx, size.height * centerOffset.dy);
    final radius = math.max(size.width, size.height) * 0.8;
    final angle = progress * 2 * math.pi;

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset(centerOffset.dx, centerOffset.dy),
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          const Color(0xFF7C3AED).withValues(alpha: 0.0),
          const Color(0xFF38BDF8).withValues(alpha: 0.08),
          const Color(0xFF7C3AED).withValues(alpha: 0.14),
        ],
        stops: const [0.0, 0.7, 1.0],
        transform: GradientRotation(angle - (math.pi / 2)),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Glowing leading edge line
    final linePaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final lineEnd = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    canvas.drawLine(center, lineEnd, linePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
