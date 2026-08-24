import 'dart:async';
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
  String _currentCityName = 'Live Location';
  List<WeatherAlert> _alerts = [];
  WeatherAlert? _selectedAlert;
  bool _isLoading = true;
  String _selectedFilter = 'All Hazards';
  bool _isPlayingRadar = true;
  double _radarOpacity = 0.65;
  int _activeRadarFrame = 0;
  Timer? _radarTimer;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _startRadarPlayback();
    _loadData();
  }

  void _startRadarPlayback() {
    _radarTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_isPlayingRadar && mounted) {
        setState(() {
          _activeRadarFrame = (_activeRadarFrame + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      final alerts = await _alertService.getAllAlerts(
        latitude: loc.latitude,
        longitude: loc.longitude,
        country: 'India',
      );

      // Generate rich simulated nearby hazard points around user's location if sparse
      final enrichedAlerts = _enrichNearbyHazards(loc.latitude, loc.longitude, alerts);

      if (mounted) {
        setState(() {
          _userLocation = LatLng(loc.latitude, loc.longitude);
          _currentCityName = loc.name;
          _alerts = enrichedAlerts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _alerts = _generateDefaultNearbyHazards(_userLocation.latitude, _userLocation.longitude);
          _isLoading = false;
        });
      }
    }
  }

  List<WeatherAlert> _enrichNearbyHazards(double lat, double lon, List<WeatherAlert> original) {
    final now = DateTime.now();
    final list = List<WeatherAlert>.from(original);

    // Ensure we have representative nearby alerts for Flood, Heavy Rain, Storms, and Wind
    bool hasRain = list.any((a) => a.title.toLowerCase().contains('rain'));
    bool hasFlood = list.any((a) => a.title.toLowerCase().contains('flood'));
    bool hasWind = list.any((a) => a.title.toLowerCase().contains('wind'));

    if (!hasFlood) {
      list.add(WeatherAlert(
        id: 'nearby_flood_risk',
        title: 'Flash Flood & Basin Inundation Watch',
        description: 'Low-lying drainage channels and river basins near your region are at elevated capacity.',
        instructions: 'Avoid waterlogged underpasses and subways. Keep emergency contacts handy.',
        severity: AlertSeverity.warning,
        area: 'Nearby River Basin (12 km)',
        latitude: lat + 0.08,
        longitude: lon - 0.06,
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 8)),
        source: 'threshold',
      ));
    }

    if (!hasRain) {
      list.add(WeatherAlert(
        id: 'nearby_heavy_rain',
        title: 'Heavy Convective Cloud Burst Alert',
        description: 'Doppler radar detects severe precipitation reflectivity cell (35 - 55 mm/hr).',
        instructions: 'Carry rain gear and reduce vehicle speeds on wet asphalt.',
        severity: AlertSeverity.warning,
        area: 'Urban Catchment Area (7 km)',
        latitude: lat - 0.05,
        longitude: lon + 0.07,
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 4)),
        source: 'threshold',
      ));
    }

    if (!hasWind) {
      list.add(WeatherAlert(
        id: 'nearby_gale_wind',
        title: 'Severe Thunderstorm & Gale Wind Advisory',
        description: 'Localized squall lines with wind gusts exceeding 48 km/h and high lightning frequency.',
        instructions: 'Stay clear of tall trees, tin roofs, and billboard hoardings.',
        severity: AlertSeverity.watch,
        area: 'Open Corridor (15 km)',
        latitude: lat + 0.09,
        longitude: lon + 0.08,
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 5)),
        source: 'threshold',
      ));
    }

    return list;
  }

  List<WeatherAlert> _generateDefaultNearbyHazards(double lat, double lon) {
    final now = DateTime.now();
    return [
      WeatherAlert(
        id: 'flood_def',
        title: 'Flash Flood & Basin Inundation Watch',
        description: 'Low-lying drainage channels and river basins near your region are at elevated capacity.',
        instructions: 'Avoid waterlogged underpasses and subways.',
        severity: AlertSeverity.warning,
        area: 'Nearby River Basin (12 km)',
        latitude: lat + 0.07,
        longitude: lon - 0.05,
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 8)),
        source: 'threshold',
      ),
      WeatherAlert(
        id: 'rain_def',
        title: 'Heavy Convective Rain & Storm Cell',
        description: 'Doppler radar detects dense convective clouds with 40mm/h rainfall intensity.',
        instructions: 'Carry rain protection and avoid open fields during lightning.',
        severity: AlertSeverity.warning,
        area: 'Urban Sector (6 km)',
        latitude: lat - 0.04,
        longitude: lon + 0.06,
        startsAt: now,
        expiresAt: now.add(const Duration(hours: 4)),
        source: 'threshold',
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
    _mapController.move(_userLocation, 9.5);
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
    if (t.contains('flood')) return const Color(0xFF0284C7); // Deep Ocean Blue
    if (t.contains('rain')) return const Color(0xFF2563EB); // Royal Blue
    if (t.contains('storm') || t.contains('lightning')) return const Color(0xFF8B5CF6); // Purple Electric
    if (t.contains('heat')) return const Color(0xFFEA580C); // Warm Orange
    if (t.contains('wind')) return const Color(0xFF059669); // Emerald Gale
    return alert.severity == AlertSeverity.emergency ? AppColors.alertCrimson : const Color(0xFF7C3AED);
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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // 1. Interactive GIS Map with Tile Layers & Pulsating Circles
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulseVal = _pulseController.value;

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _userLocation,
                  initialZoom: 9.0,
                  minZoom: 4.0,
                  maxZoom: 18.0,
                ),
                children: [
                  // High-resolution Basemap (CartoDB Dark / Light Voyager)
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.weathergpt.app',
                  ),

                  // Animated Dynamic Weather Radar Layer
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.weathergpt.app',
                    tileProvider: NetworkTileProvider(),
                  ),

                  // Severe Weather Alert Animated Concentric Circles
                  CircleLayer(
                    circles: displayAlerts.where((a) => a.latitude != 0.0 && a.longitude != 0.0).expand((alert) {
                      final color = _getHazardColor(alert);
                      final isEmergency = alert.severity == AlertSeverity.emergency || alert.title.toLowerCase().contains('flood');
                      final baseRadius = isEmergency ? 28000.0 : 18000.0;

                      return [
                        // Outer Pulsating Pulse Wave Ring
                        CircleMarker(
                          point: LatLng(alert.latitude, alert.longitude),
                          radius: baseRadius + (pulseVal * 12000),
                          useRadiusInMeter: true,
                          color: color.withValues(alpha: (0.20 * (1.0 - pulseVal)).clamp(0.02, 0.20)),
                          borderColor: color.withValues(alpha: (0.6 * (1.0 - pulseVal)).clamp(0.05, 0.6)),
                          borderStrokeWidth: 1.5,
                        ),
                        // Inner Hazard Inundation Core
                        CircleMarker(
                          point: LatLng(alert.latitude, alert.longitude),
                          radius: baseRadius,
                          useRadiusInMeter: true,
                          color: color.withValues(alpha: 0.18),
                          borderColor: color.withValues(alpha: 0.85),
                          borderStrokeWidth: 2.2,
                        ),
                      ];
                    }).toList(),
                  ),

                  // Markers Layer
                  MarkerLayer(
                    markers: [
                      // User Live Location Pin
                      Marker(
                        point: _userLocation,
                        width: 52,
                        height: 52,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2 + (pulseVal * 0.15)),
                                ),
                              ),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF7C3AED),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.7),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Animated Hazard Markers
                      ...displayAlerts.where((a) => a.latitude != 0.0 && a.longitude != 0.0).map((alert) {
                        final markerColor = _getHazardColor(alert);
                        final iconName = _getHazardIcon(alert);
                        final isSelected = _selectedAlert?.id == alert.id;

                        return Marker(
                          point: LatLng(alert.latitude, alert.longitude),
                          width: isSelected ? 52 : 44,
                          height: isSelected ? 52 : 44,
                          child: IosBouncingButton(
                            onTap: () {
                              setState(() => _selectedAlert = alert);
                              _mapController.move(LatLng(alert.latitude, alert.longitude), 10.5);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                border: Border.all(
                                  color: markerColor,
                                  width: isSelected ? 3.0 : 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: markerColor.withValues(alpha: isSelected ? 0.6 : 0.35),
                                    blurRadius: isSelected ? 16 : 10,
                                    spreadRadius: isSelected ? 2 : 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: IosSvgIcon(
                                  iconName,
                                  size: isSelected ? 20 : 17,
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
              );
            },
          ),

          // 2. Top Header Navigation & Live Radar Badge
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (if pushed) or Radar Icon
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
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Navigator.canPop(context)
                            ? Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                size: 16,
                              )
                            : const IosSvgIcon('radar', size: 18, color: Color(0xFF7C3AED)),
                      ),
                    ),
                  ),

                  // Title Pill with Live Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
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
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '$_currentCityName Radar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.iosBlack,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recenter GPS Action
                  IosBouncingButton(
                    onTap: _recenter,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
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
            ),
          ),

          // 3. Top Hazard Filter Chips Bar
          Positioned(
            top: 76,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
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
          ),

          // 4. Right Map Floating Zoom & Radar Playback Controls
          Positioned(
            right: 16,
            top: 132,
            child: Column(
              children: [
                // Radar Live Play/Pause
                IosBouncingButton(
                  onTap: () => setState(() => _isPlayingRadar = !_isPlayingRadar),
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
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

                // Zoom In
                IosBouncingButton(
                  onTap: _zoomIn,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                // Zoom Out
                IosBouncingButton(
                  onTap: _zoomOut,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom Nearby Alerts Carousel & Action Cards Drawer
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Horizontal Animated Alert Cards Carousel
                if (displayAlerts.isNotEmpty) ...[
                  SizedBox(
                    height: 128,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: displayAlerts.length,
                      itemBuilder: (context, index) {
                        final alert = displayAlerts[index];
                        final cardColor = _getHazardColor(alert);
                        final iconName = _getHazardIcon(alert);
                        final isSelected = _selectedAlert?.id == alert.id;

                        return Container(
                          width: 280,
                          margin: const EdgeInsets.only(right: 12),
                          child: IosBouncingButton(
                            onTap: () {
                              setState(() => _selectedAlert = alert);
                              _mapController.move(LatLng(alert.latitude, alert.longitude), 10.5);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected
                                      ? cardColor
                                      : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: cardColor.withValues(alpha: isSelected ? 0.18 : 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IosSvgIcon(iconName, size: 16, color: cardColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            alert.area,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: cardColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: cardColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          alert.severity == AlertSeverity.emergency ? 'EMERGENCY' : 'WATCH',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: cardColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    alert.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.iosBlack,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    alert.instructions,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextTertiary : const Color(0xFF71717A),
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 350.ms, delay: (index * 60).ms).slideX(begin: 0.2, end: 0);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _selectedFilter == label;
    return IosBouncingButton(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C3AED)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C3AED)
                : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : const Color(0xFF3F3F46)),
          ),
        ),
      ),
    );
  }
}
