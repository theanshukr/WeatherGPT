import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/user_context.dart';
import '../models/alert_model.dart';
import '../providers/user_context_provider.dart';
import '../providers/weather_provider.dart';
import '../services/alert_service.dart';
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

  /// Fetch real alerts from backend instead of hardcoded data
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
          _recentAlerts = alerts.take(5).toList(); // Show up to 5 recent
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
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (widget.isStandalone)
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            size: 30,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      Icon(
                        Icons.person_rounded,
                        size: 26,
                        color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Profile & Memory',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.emeraldNeon.withValues(alpha: 0.12)
                          : AppColors.emeraldDark.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? AppColors.emeraldNeon.withValues(alpha: 0.25)
                            : AppColors.emeraldDark.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI Synced',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
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

                    // User Profile Avatar with Glowing Ring
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 98,
                          height: 98,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                                    .withValues(alpha: 0.25),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              child: Icon(
                                Icons.person_rounded,
                                size: 54,
                                color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDark,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                            border: Border.all(
                              color: isDark ? AppColors.darkBackground : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Profile Name — from actual user context
                    Text(
                      userContext.userName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),

                    // Active Persona Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getPersonaEmoji(contextProv.currentPersona),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Active Persona: ${_getPersonaTitle(contextProv.currentPersona)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SECTION: ALERTS YOU RECEIVED — from real backend data
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 18,
                              color: isDark ? AppColors.sunnyGold : AppColors.alertCrimson,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active Alerts',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AlertsScreen()),
                            );
                          },
                          child: Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Real alerts from backend
                    if (_alertsLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Loading alerts...',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_recentAlerts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 32,
                              color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No active weather alerts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentAlerts.length,
                        itemBuilder: (context, index) {
                          final alert = _recentAlerts[index];
                          final isCritical = alert.severity == AlertSeverity.emergency;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCritical
                                    ? AppColors.alertCrimson.withValues(alpha: 0.4)
                                    : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCritical
                                        ? AppColors.alertCrimson.withValues(alpha: 0.15)
                                        : (isDark ? AppColors.emeraldNeon.withValues(alpha: 0.15) : AppColors.emeraldDark.withValues(alpha: 0.1)),
                                  ),
                                  child: Icon(
                                    isCritical ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                                    size: 18,
                                    color: isCritical
                                        ? AppColors.alertCrimson
                                        : (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alert.title,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      if (alert.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          alert.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 20),

                    // SECTION: AI DETECTED CONTEXT & INTERESTS
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'AI Context & Detected Interests',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        userContext.detectedInterests.isEmpty
                            ? 'Chat with WeatherGPT to build your personalized interest profile.'
                            : 'WeatherGPT remembers your key meteorological topics to customize briefings.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Detected Interests Chips
                    if (userContext.detectedInterests.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: userContext.detectedInterests.map((interest) {
                            return Chip(
                              label: Text(
                                interest,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              side: BorderSide(
                                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                              ),
                              deleteIcon: const Icon(Icons.close_rounded, size: 15),
                              onDeleted: () => contextProv.removeInterest(interest),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Quick Switch Persona Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Switch Persona Mode',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildPersonaChoice(context, persona: DetectedPersona.farmer, label: '🌾 Farmer'),
                              const SizedBox(width: 8),
                              _buildPersonaChoice(context, persona: DetectedPersona.traveller, label: '✈️ Traveller'),
                              const SizedBox(width: 8),
                              _buildPersonaChoice(context, persona: DetectedPersona.general, label: '☀️ General'),
                            ],
                          ),
                        ],
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

  String _getPersonaEmoji(DetectedPersona persona) {
    switch (persona) {
      case DetectedPersona.farmer:
        return '🌾';
      case DetectedPersona.traveller:
        return '✈️';
      case DetectedPersona.student:
        return '📚';
      case DetectedPersona.commuter:
        return '🚗';
      case DetectedPersona.general:
        return '☀️';
    }
  }

  String _getPersonaTitle(DetectedPersona persona) {
    switch (persona) {
      case DetectedPersona.farmer:
        return 'Farmer Intelligence';
      case DetectedPersona.traveller:
        return 'Traveller & Commuter';
      case DetectedPersona.student:
        return 'Student Campus Weather';
      case DetectedPersona.commuter:
        return 'Daily Commuter';
      case DetectedPersona.general:
        return 'General Assistant';
    }
  }

  Widget _buildPersonaChoice(
    BuildContext context, {
    required DetectedPersona persona,
    required String label,
  }) {
    final contextProv = context.watch<UserContextProvider>();
    final isSelected = contextProv.currentPersona == persona;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => contextProv.setPersona(persona),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.emeraldNeon.withValues(alpha: 0.2) : AppColors.emeraldDark.withValues(alpha: 0.15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
