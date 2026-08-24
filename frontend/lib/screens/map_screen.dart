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

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final AlertService _alertService = AlertService();
  final LocationService _locationService = LocationService();

  LatLng _userLocation = const LatLng(28.6139, 77.2090);
  List<WeatherAlert> _alerts = [];
  WeatherAlert? _selectedAlert;
  bool _isLoading = true;
  String _selectedLayer = 'Radar';
  bool _showLegend = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      final alerts = await _alertService.getAllAlerts(
        latitude: loc.latitude,
        longitude: loc.longitude,
        country: 'India',
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
          _alerts = [];
          _isLoading = false;
        });
      }
    }
  }

  void _recenter() {
    _mapController.move(_userLocation, 9.0);
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom + 1).clamp(3.0, 18.0));
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (currentZoom - 1).clamp(3.0, 18.0));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // 1. Interactive GIS Map with Tile Layers
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 8.0,
              minZoom: 3.0,
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

              // Weather Radar / Precipitation Tile Layer
              if (_selectedLayer == 'Radar' || _selectedLayer == 'Precipitation')
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.weathergpt.app',
                  tileProvider: NetworkTileProvider(),
                ),

              // Severe Weather Alert Circles
              CircleLayer(
                circles: _alerts.where((a) => a.latitude != 0.0 && a.longitude != 0.0).map((alert) {
                  final isEmergency = alert.severity == AlertSeverity.emergency;
                  final color = isEmergency
                      ? AppColors.alertCrimson
                      : (alert.severity == AlertSeverity.warning
                          ? AppColors.sunnyGold
                          : const Color(0xFF7C3AED));
                  return CircleMarker(
                    point: LatLng(alert.latitude, alert.longitude),
                    radius: isEmergency ? 45000 : 25000,
                    useRadiusInMeter: true,
                    color: color.withValues(alpha: 0.16),
                    borderColor: color.withValues(alpha: 0.8),
                    borderStrokeWidth: 2,
                  );
                }).toList(),
              ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // User Live Location Pin
                  Marker(
                    point: _userLocation,
                    width: 50,
                    height: 50,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                            ),
                          ),
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
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Alert Hazard Markers
                  ..._alerts.where((a) => a.latitude != 0.0 && a.longitude != 0.0).map((alert) {
                    final isEmergency = alert.severity == AlertSeverity.emergency;
                    final markerColor = isEmergency
                        ? AppColors.alertCrimson
                        : (alert.severity == AlertSeverity.warning
                            ? AppColors.sunnyGold
                            : const Color(0xFF7C3AED));

                    return Marker(
                      point: LatLng(alert.latitude, alert.longitude),
                      width: 44,
                      height: 44,
                      child: IosBouncingButton(
                        onTap: () {
                          setState(() => _selectedAlert = alert);
                          _mapController.move(LatLng(alert.latitude, alert.longitude), 9.5);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            border: Border.all(color: markerColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: markerColor.withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: IosSvgIcon(
                              isEmergency ? 'bell' : 'cloud_rain',
                              size: 18,
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

          // 2. Top Header Navigation Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  IosBouncingButton(
                    onTap: () => Navigator.pop(context),
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
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),

                  // Title Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        const IosSvgIcon('radar', size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 8),
                        Text(
                          'Live GIS Radar & Satellite',
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

          // 3. Right Map Floating Zoom Controls
          Positioned(
            right: 16,
            top: 130,
            child: Column(
              children: [
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
                const SizedBox(height: 8),
                IosBouncingButton(
                  onTap: () => setState(() => _showLegend = !_showLegend),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _showLegend
                          ? const Color(0xFF7C3AED)
                          : (isDark ? AppColors.darkSurface : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.layers_rounded,
                        size: 18,
                        color: _showLegend
                            ? Colors.white
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Expanded Floating Radar Options & Layer Dock (Bottom)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected Alert Detail Card (if open)
                if (_selectedAlert != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedAlert!.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IosBouncingButton(
                              onTap: () => setState(() => _selectedAlert = null),
                              child: const IosSvgIcon('close', size: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedAlert!.description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0),
                ],

                // Radar Legend Bar (when toggled on)
                if (_showLegend) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rain Intensity (mm/h):', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            _buildLegendPill('Light', const Color(0xFF60A5FA)),
                            const SizedBox(width: 4),
                            _buildLegendPill('Moderate', const Color(0xFF34D399)),
                            const SizedBox(width: 4),
                            _buildLegendPill('Heavy', const Color(0xFFFBBF24)),
                            const SizedBox(width: 4),
                            _buildLegendPill('Extreme', const Color(0xFFEF4444)),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 200.ms),
                ],

                // Expanded Layer Selector Dock
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLayerButton('Radar', 'radar', isDark),
                      _buildLayerButton('Precipitation', 'cloud_rain', isDark),
                      _buildLayerButton('Storm Alerts', 'bell', isDark),
                      _buildLayerButton('Temperature', 'sun', isDark),
                    ],
                  ),
                ),
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

  Widget _buildLegendPill(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 2),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLayerButton(String label, String iconName, bool isDark) {
    final isSelected = _selectedLayer == label;
    return IosBouncingButton(
      onTap: () => setState(() => _selectedLayer = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF3EDFD))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IosSvgIcon(
              iconName,
              size: 16,
              color: isSelected ? const Color(0xFF7C3AED) : (isDark ? AppColors.darkTextTertiary : const Color(0xFF71717A)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF7C3AED) : (isDark ? AppColors.darkTextTertiary : const Color(0xFF71717A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
