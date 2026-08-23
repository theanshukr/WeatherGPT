import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/alert_model.dart';
import '../providers/weather_provider.dart';
import '../services/alert_service.dart';
import 'map_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertService _alertService = AlertService();
  List<WeatherAlert> _alerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final weatherProv = context.read<WeatherProvider>();
      final lat = weatherProv.weatherData.location.latitude;
      final lon = weatherProv.weatherData.location.longitude;

      final list = await _alertService.getAllAlerts(
        latitude: lat != 0.0 ? lat : 28.6139,
        longitude: lon != 0.0 ? lon : 77.2090,
        country: 'India',
      );

      if (mounted) {
        setState(() {
          _alerts = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.emergency:
        return AppColors.alertCrimson;
      case AlertSeverity.warning:
        return AppColors.sunnyGold;
      case AlertSeverity.watch:
        return AppColors.electricCyan;
      case AlertSeverity.advisory:
        return AppColors.emeraldNeon;
    }
  }

  String _severityLabel(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.emergency:
        return '🚨 EMERGENCY';
      case AlertSeverity.warning:
        return '⚠️ WARNING';
      case AlertSeverity.watch:
        return '👁️ WATCH';
      case AlertSeverity.advisory:
        return 'ℹ️ ADVISORY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 32,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Severe Weather Advisories',
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: const Icon(Icons.public_rounded, color: AppColors.emeraldNeon, size: 18),
            ),
            tooltip: 'View on GIS Radar Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldNeon))
          : _error != null
              ? _buildErrorState(isDark)
              : _alerts.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      color: AppColors.emeraldNeon,
                      onRefresh: _loadAlerts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _alerts.length,
                        itemBuilder: (context, index) {
                          final alert = _alerts[index];
                          final sColor = _severityColor(alert.severity);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: sColor.withValues(alpha: 0.35),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: sColor.withValues(alpha: 0.08),
                                  blurRadius: 18,
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: sColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _severityLabel(alert.severity),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: sColor,
                                        ),
                                      ),
                                    ),
                                    if (alert.source != 'threshold')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceElevated,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark ? Colors.white12 : Colors.black12,
                                          ),
                                        ),
                                        child: Text(
                                          alert.source.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                                          ),
                                        ),
                                      ),
                                    Flexible(
                                      child: Text(
                                        alert.area,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  alert.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                if (alert.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    alert.description,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                                if (alert.instructions.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkGlassFill : AppColors.lightSurfaceElevated,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.shield_outlined,
                                          size: 18,
                                          color: AppColors.sunnyGold,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            alert.instructions,
                                            style: GoogleFonts.inter(fontSize: 13, height: 1.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark).withValues(alpha: 0.1),
                border: Border.all(
                  color: (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark).withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Severe Hazards Active',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'No severe convective storms, heatwave, or cyclone warnings for your area right now.\nPull down anytime to refresh live telemetry.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.alertCrimson),
          const SizedBox(height: 16),
          Text(
            'Could not load alerts',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
