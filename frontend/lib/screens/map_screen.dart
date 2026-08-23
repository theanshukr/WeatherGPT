import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme/app_colors.dart';
import '../models/alert_model.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final AlertService _alertService = AlertService();
  final LocationService _locationService = LocationService();

  LatLng _userLocation = const LatLng(28.6139, 77.2090);
  List<WeatherAlert> _alerts = [];
  WeatherAlert? _selectedAlert;
  bool _isLoading = true;
  String _selectedLayer = 'Alerts & Radar';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      final alerts = await _alertService.getActiveAlerts(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(loc.latitude, loc.longitude);
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _alerts = WeatherAlert.defaultAlerts();
          _isLoading = false;
        });
      }
    }
  }

  void _recenter() {
    _mapController.move(_userLocation, 10.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive GIS Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 7.0,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              // OpenStreetMap CartoDB / Standard Tile Layer
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.weathergpt.app',
              ),

              // Severe Weather Alert Circles / Radiation Area
              CircleLayer(
                circles: _alerts.map((alert) {
                  final isEmergency = alert.severity == AlertSeverity.emergency;
                  final color = isEmergency
                      ? AppColors.alertCrimson
                      : (alert.severity == AlertSeverity.warning
                          ? AppColors.sunnyGold
                          : AppColors.electricCyan);
                  return CircleMarker(
                    point: LatLng(alert.latitude, alert.longitude),
                    radius: isEmergency ? 45000 : 30000,
                    useRadiusInMeter: true,
                    color: color.withValues(alpha: 0.15),
                    borderColor: color.withValues(alpha: 0.8),
                    borderStrokeWidth: 2,
                  );
                }).toList(),
              ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // User Location Pin
                  Marker(
                    point: _userLocation,
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📍 Current GPS Location (New Delhi)'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.emeraldNeon.withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.emeraldNeon,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emeraldNeon.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Alert Hazard Markers
                  ..._alerts.map((alert) {
                    final isEmergency = alert.severity == AlertSeverity.emergency;
                    final markerColor = isEmergency
                        ? AppColors.alertCrimson
                        : (alert.severity == AlertSeverity.warning
                            ? AppColors.sunnyGold
                            : AppColors.tealAccent);

                    return Marker(
                      point: LatLng(alert.latitude, alert.longitude),
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAlert = alert;
                          });
                          _mapController.move(
                            LatLng(alert.latitude, alert.longitude),
                            9.0,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                            border: Border.all(color: markerColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: markerColor.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            isEmergency
                                ? Icons.warning_amber_rounded
                                : Icons.thunderstorm_outlined,
                            color: markerColor,
                            size: 24,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Top Header Navigation Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceElevated.withValues(alpha: 0.85)
                            : AppColors.lightSurface.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        size: 22,
                      ),
                    ),
                  ),

                  // Map Title Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated.withValues(alpha: 0.85)
                          : AppColors.lightSurface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.public_rounded, color: AppColors.emeraldNeon, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'GIS Weather Radar & Alerts',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recenter Action
                  GestureDetector(
                    onTap: _recenter,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceElevated.withValues(alpha: 0.85)
                            : AppColors.lightSurface.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: AppColors.emeraldNeon,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Layer Chips (Top Sub-bar)
          Positioned(
            top: 74,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLayerChip('Alerts & Radar', Icons.radar_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildLayerChip('Precipitation', Icons.water_drop_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildLayerChip('Heat Stress', Icons.thermostat_rounded, isDark),
                  const SizedBox(width: 8),
                  _buildLayerChip('Wind Speeds', Icons.air_rounded, isDark),
                ],
              ),
            ),
          ),

          // 4. Selected Alert Detail Bottom Card
          if (_selectedAlert != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _selectedAlert!.severity == AlertSeverity.emergency
                        ? AppColors.alertCrimson.withValues(alpha: 0.5)
                        : AppColors.emeraldNeon.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _selectedAlert!.severity == AlertSeverity.emergency
                                ? AppColors.alertCrimson.withValues(alpha: 0.15)
                                : AppColors.sunnyGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _selectedAlert!.severity == AlertSeverity.emergency
                                ? '🚨 SEVERE EMERGENCY'
                                : '⚠️ ADVISORY WARNING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _selectedAlert!.severity == AlertSeverity.emergency
                                  ? AppColors.alertCrimson
                                  : AppColors.sunnyGold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _selectedAlert = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedAlert!.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedAlert!.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkGlassFill : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 16, color: AppColors.emeraldNeon),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedAlert!.instructions,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.emeraldNeon),
            ),
        ],
      ),
    );
  }

  Widget _buildLayerChip(String label, IconData icon, bool isDark) {
    final isSelected = _selectedLayer == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLayer = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.emeraldNeon
              : (isDark
                  ? AppColors.darkSurfaceElevated.withValues(alpha: 0.85)
                  : AppColors.lightSurface.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.emeraldNeon
                : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.black
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.black
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
