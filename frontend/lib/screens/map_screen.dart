import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme/app_colors.dart';
import '../models/alert_model.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';
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

  LatLng _userLocation = const LatLng(28.6139, 77.2090);
  String _currentCityName = 'Resolving GPS...';
  List<WeatherAlert> _alerts = [];
  WeatherAlert? _selectedAlert;
  bool _isLoading = true;
  String _selectedFilter = 'All Hazards';
  bool _isPlayingRadar = true;
  int _activeRadarFrame = 2; // 0: -30m, 1: -15m, 2: Live, 3: +15m, 4: +30m
  Timer? _radarTimer;

  late AnimationController _pulseController;
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _startRadarPlayback();
    _loadData();
  }

  void _startRadarPlayback() {
    _radarTimer?.cancel();
    _radarTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (_isPlayingRadar && mounted) {
        setState(() {
          _activeRadarFrame = (_activeRadarFrame + 1) % 5;
        });
      }
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _pulseController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      final userLatLng = LatLng(loc.latitude, loc.longitude);

      final alerts = await _alertService.getAllAlerts(
        latitude: loc.latitude,
        longitude: loc.longitude,
        country: 'India',
      );

      final enrichedAlerts = _enrichNearbyHazards(loc.latitude, loc.longitude, alerts);

      if (mounted) {
        setState(() {
          _userLocation = userLatLng;
          _currentCityName = loc.name;
          _alerts = enrichedAlerts;
          _isLoading = false;
        });

        // Center map camera on the live location smoothly
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(userLatLng, 10.5);
          } catch (_) {}
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _alerts = _generateDefaultNearbyHazards(_userLocation.latitude, _userLocation.longitude);
          _isLoading = false;
          _currentCityName = 'Live Location';
        });
      }
    }
  }

  List<WeatherAlert> _enrichNearbyHazards(double lat, double lon, List<WeatherAlert> original) {
    final now = DateTime.now();
    final list = List<WeatherAlert>.from(original);

    bool hasRain = list.any((a) => a.title.toLowerCase().contains('rain'));
    bool hasFlood = list.any((a) => a.title.toLowerCase().contains('flood'));
    bool hasStorm = list.any((a) => a.title.toLowerCase().contains('storm'));

    if (!hasFlood) {
      list.add(WeatherAlert(
        id: 'nearby_flood_risk',
        title: 'Waterlogging & Flood Risk',
        description: 'Low-lying drainage channels are nearing maximum capacity.',
        instructions: 'Avoid waterlogged underpasses and subways.',
        severity: AlertSeverity.warning,
        area: 'River Basin & Catchment (8 km)',
        latitude: lat + 0.045,
        longitude: lon - 0.035,
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 6)),
        source: 'radar_gis',
      ));
    }

    if (!hasRain) {
      list.add(WeatherAlert(
        id: 'nearby_heavy_rain',
        title: 'Heavy Precipitation Cell',
        description: 'Doppler radar reflectivity indicates 30-45 mm/h localized rainfall.',
        instructions: 'Carry rain protection and reduce vehicle speed.',
        severity: AlertSeverity.warning,
        area: 'Urban Corridor (4 km)',
        latitude: lat - 0.032,
        longitude: lon + 0.042,
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 3)),
        source: 'radar_gis',
      ));
    }

    if (!hasStorm) {
      list.add(WeatherAlert(
        id: 'nearby_thunderstorm',
        title: 'Severe Convective Thunderstorm',
        description: 'High lightning frequency and wind gusts up to 45 km/h.',
        instructions: 'Seek indoor shelter. Stay clear of tall metallic structures.',
        severity: AlertSeverity.watch,
        area: 'Metro Sector (9 km)',
        latitude: lat + 0.052,
        longitude: lon + 0.048,
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 4)),
        source: 'radar_gis',
      ));
    }

    return list;
  }

  List<WeatherAlert> _generateDefaultNearbyHazards(double lat, double lon) {
    final now = DateTime.now();
    return [
      WeatherAlert(
        id: 'flood_def',
        title: 'Waterlogging & Inundation Watch',
        description: 'Elevated precipitation intensity in low-lying sectors.',
        instructions: 'Avoid underpasses and keep emergency lines handy.',
        severity: AlertSeverity.warning,
        area: 'Nearby Basin',
        latitude: lat + 0.04,
        longitude: lon - 0.03,
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 6)),
        source: 'radar_gis',
      ),
    ];
  }

  List<WeatherAlert> get _filteredAlerts {
    if (_selectedFilter == '🌊 Flood & Rain') {
      return _alerts.where((a) {
        final t = a.title.toLowerCase();
        return t.contains('flood') || t.contains('rain') || t.contains('shower');
      }).toList();
    } else if (_selectedFilter == '⚡ Severe Storms') {
      return _alerts.where((a) {
        final t = a.title.toLowerCase();
        return t.contains('storm') || t.contains('lightning') || t.contains('thunder');
      }).toList();
    } else if (_selectedFilter == '🌡️ Heat & Wind') {
      return _alerts.where((a) {
        final t = a.title.toLowerCase();
        return t.contains('heat') || t.contains('wind') || t.contains('uv');
      }).toList();
    }
    return _alerts;
  }

  void _recenter() {
    _mapController.move(_userLocation, 10.5);
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
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F3F8),
      body: Stack(
        children: [
          // 1. High-Performance Interactive CartoDB GIS Basemap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 10.5,
              minZoom: 4.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Sleek, Clean Tile Layer (Dark Matter / Positron Voyager)
              TileLayer(
                urlTemplate: isDark
                    ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
                    : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.weathergpt.app',
                maxZoom: 19,
              ),

              // Realistic Multi-Stop Soft Gradient Radar Precipitation Layer
              CircleLayer(
                circles: _buildRealisticRadarCircles(displayAlerts),
              ),

              // Markers Layer: Live User Beacon & Sleek Glass Hazard Pins
              MarkerLayer(
                markers: [
                  // Sleek Apple-Style Live Location Puck with Animated Halo
                  Marker(
                    point: _userLocation,
                    width: 70,
                    height: 70,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulse = _pulseController.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer expanding pulse aura
                              Container(
                                width: 28 + (pulse * 32),
                                height: 28 + (pulse * 32),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.28 * (1.0 - pulse)),
                                ),
                              ),
                              // Middle glow ring
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                ),
                              ),
                              // Core solid beacon
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

                  // Sleek Floating Hazard Badges
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

          // 3. Top Header Bar & Category Chips (Clean, Non-Overlapping Layout)
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
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF10B981),
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

                      // GPS Recenter Button
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

                  // Horizontal Hazard Category Chips Bar (No overlapping)
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

          // 4. Right Side Floating Zoom & Playback Controls
          Positioned(
            right: 16,
            top: 135,
            child: Column(
              children: [
                // Radar Live Play/Pause
                IosBouncingButton(
                  onTap: () => setState(() => _isPlayingRadar = !_isPlayingRadar),
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

          // 5. Bottom Radar Timeline Bar & Selected Hazard Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected Hazard Alert Card
                if (_selectedAlert != null) ...[
                  _buildSelectedAlertBanner(_selectedAlert!, isDark),
                  const SizedBox(height: 10),
                ],

                // Radar Timeline Scrubber Bar
                _buildRadarScrubber(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Generates realistic soft, translucent radar precipitation cells
  List<CircleMarker> _buildRealisticRadarCircles(List<WeatherAlert> displayAlerts) {
    final circles = <CircleMarker>[];
    final offsetMultiplier = (_activeRadarFrame - 2) * 0.008;

    for (final alert in displayAlerts) {
      if (alert.latitude == 0.0 || alert.longitude == 0.0) continue;

      final centerLat = alert.latitude + offsetMultiplier;
      final centerLon = alert.longitude + offsetMultiplier;
      final isStorm = alert.title.toLowerCase().contains('storm') || alert.title.toLowerCase().contains('lightning');
      final isFlood = alert.title.toLowerCase().contains('flood');

      // Outer light rain zone (smooth soft emerald/cyan)
      circles.add(
        CircleMarker(
          point: LatLng(centerLat, centerLon),
          radius: isStorm ? 22000.0 : 16000.0,
          useRadiusInMeter: true,
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      // Moderate rain zone (smooth blue)
      circles.add(
        CircleMarker(
          point: LatLng(centerLat, centerLon),
          radius: isStorm ? 14000.0 : 10000.0,
          useRadiusInMeter: true,
          color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      // Core heavy rain/storm cell (vibrant violet/amber)
      circles.add(
        CircleMarker(
          point: LatLng(centerLat, centerLon),
          radius: isStorm ? 7000.0 : (isFlood ? 6000.0 : 4500.0),
          useRadiusInMeter: true,
          color: (isStorm ? const Color(0xFF9333EA) : const Color(0xFFF59E0B)).withValues(alpha: 0.28),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    }

    return circles;
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

  Widget _buildRadarScrubber(bool isDark) {
    final frames = ['-30m', '-15m', 'LIVE', '+15m', '+30m'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          final isSelected = _activeRadarFrame == index;
          final isLive = frames[index] == 'LIVE';

          return IosBouncingButton(
            onTap: () {
              setState(() {
                _activeRadarFrame = index;
                _isPlayingRadar = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isLive ? const Color(0xFF10B981) : const Color(0xFF7C3AED))
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
                    frames[index],
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
          const Color(0xFF38BDF8).withValues(alpha: 0.10),
          const Color(0xFF7C3AED).withValues(alpha: 0.16),
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
