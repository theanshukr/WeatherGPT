import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/user_context.dart';
import '../models/alert_model.dart';
import '../providers/user_context_provider.dart';
import '../providers/weather_provider.dart';
import '../services/alert_service.dart';
import '../widgets/gemini_sparkle_icon.dart';
import 'alerts_screen.dart';

class ProfileContextScreen extends StatefulWidget {
  final bool isStandalone;
  const ProfileContextScreen({super.key, this.isStandalone = false});

  @override
  State<ProfileContextScreen> createState() => _ProfileContextScreenState();
}

class _ProfileContextScreenState extends State<ProfileContextScreen> {
  final AlertService _alertService = AlertService();
  List<WeatherAlert> _recentAlerts = [];
  bool _alertsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentAlerts();
  }

  Future<void> _loadRecentAlerts() async {
    try {
      final weatherProv = context.read<WeatherProvider>();
      final lat = weatherProv.weatherData.location.latitude;
      final lon = weatherProv.weatherData.location.longitude;

      final alerts = await _alertService.getAllAlerts(
        latitude: lat != 0.0 ? lat : 28.6139,
        longitude: lon != 0.0 ? lon : 77.2090,
        country: 'India',
      );

      if (mounted) {
        setState(() {
          _recentAlerts = alerts.take(5).toList();
          _alertsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _alertsLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contextProv = context.watch<UserContextProvider>();
    final userContext = contextProv.userContext;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Responsive without overflow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (widget.isStandalone) ...[
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        size: 28,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const GeminiSparkleIcon(size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Intelligence',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.geminiCyan,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Cloud Synced',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // User Profile Avatar with Gemini Gradient Ring
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.geminiSparkleGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.geminiBlue.withValues(alpha: 0.25),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              child: const Icon(
                                Icons.person_rounded,
                                size: 52,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.geminiBlue,
                            border: Border.all(
                              color: isDark ? AppColors.darkBackground : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // User Name & Tag
                    Text(
                      userContext.userName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI Weather Telemetry Profile',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Active Persona Selector Card (Gemini Style)
                    _buildSectionCard(
                      context,
                      isDark: isDark,
                      title: 'Active Intelligence Persona',
                      subtitle: 'Adapts WeatherGPT responses, risk thresholds, and voice tone.',
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildPersonaTile(
                                context,
                                persona: DetectedPersona.farmer,
                                icon: '🌾',
                                title: 'Farmer',
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildPersonaTile(
                                context,
                                persona: DetectedPersona.traveller,
                                icon: '✈️',
                                title: 'Traveller',
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildPersonaTile(
                                context,
                                persona: DetectedPersona.general,
                                icon: '☀️',
                                title: 'General',
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Inferred Confidence Progress Bar
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131314) : const Color(0xFFF0F4F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.psychology_rounded, size: 18, color: AppColors.geminiPurple),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'AI Behavioral Inference',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            '${(userContext.confidenceScore * 100).toInt()}%',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.geminiBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: userContext.confidenceScore,
                                          minHeight: 5,
                                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                          valueColor: const AlwaysStoppedAnimation(AppColors.geminiBlue),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Saved Meteorological Locations
                    _buildSectionCard(
                      context,
                      isDark: isDark,
                      title: 'Saved Locations & Monitored Basins',
                      subtitle: 'Locations tracked for convective alerts & agricultural timelines.',
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          _buildLocationTile(context, name: 'New Delhi, India', coord: '28.61° N, 77.20° E', isPrimary: true, isDark: isDark),
                          const SizedBox(height: 8),
                          _buildLocationTile(context, name: 'Bengaluru, Karnataka', coord: '12.97° N, 77.59° E', isPrimary: false, isDark: isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Recent Severe Warnings Shortcut Card
                    _buildSectionCard(
                      context,
                      isDark: isDark,
                      title: 'Active NDMA SACHET Warnings',
                      subtitle: 'Official government CAP telemetry feeds.',
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()));
                        },
                        child: const Text('View All', style: TextStyle(fontSize: 12, color: AppColors.geminiBlue)),
                      ),
                      child: _alertsLoading
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.geminiBlue)),
                            )
                          : _recentAlerts.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: AppColors.emeraldNeon, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        'No severe disaster warnings active.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: _recentAlerts.map((alert) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF131314) : const Color(0xFFF0F4F9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.alertCrimson),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                alert.title,
                                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required bool isDark,
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
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
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildPersonaTile(
    BuildContext context, {
    required DetectedPersona persona,
    required String icon,
    required String title,
    required bool isDark,
  }) {
    final contextProv = context.watch<UserContextProvider>();
    final isSelected = contextProv.currentPersona == persona;

    return Expanded(
      child: GestureDetector(
        onTap: () => contextProv.setPersona(persona),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.geminiBlue.withValues(alpha: 0.18) : const Color(0xFFE8F0FE))
                : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.geminiBlue : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.geminiBlue : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationTile(
    BuildContext context, {
    required String name,
    required String coord,
    required bool isPrimary,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131314) : const Color(0xFFF0F4F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_rounded, size: 18, color: AppColors.geminiBlue),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(coord, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                ],
              ),
            ],
          ),
          if (isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.geminiBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Primary', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.geminiBlue)),
            ),
        ],
      ),
    );
  }
}
