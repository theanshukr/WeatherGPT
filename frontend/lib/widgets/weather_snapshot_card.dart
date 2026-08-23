import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/weather_model.dart';
import '../core/theme/app_colors.dart';

class WeatherSnapshotCard extends StatelessWidget {
  final WeatherData weatherData;
  final VoidCallback? onTap;

  const WeatherSnapshotCard({
    super.key,
    required this.weatherData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Header & Live Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: AppColors.emeraldNeon,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      weatherData.location.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.emeraldNeon.withValues(alpha: 0.15)
                        : AppColors.emeraldDark.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
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
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main Temp & Condition Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${weatherData.temperature.toStringAsFixed(1)}°C',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Feels like ${weatherData.feelsLike.toStringAsFixed(1)}°C • ${weatherData.conditionDescription}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _getWeatherIcon(weatherData.condition),
                  size: 48,
                  color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Key Weather Metrics Grid (Precip, Humidity, Wind, UV)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkGlassFill : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetric(
                    context,
                    icon: Icons.water_drop_outlined,
                    label: 'Precip',
                    value: '${weatherData.rainfallAmount.toStringAsFixed(1)} mm',
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildMetric(
                    context,
                    icon: Icons.opacity_rounded,
                    label: 'Humidity',
                    value: '${weatherData.humidity.toInt()}%',
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildMetric(
                    context,
                    icon: Icons.air_rounded,
                    label: 'Wind',
                    value: '${weatherData.windSpeed.toStringAsFixed(1)} km/h',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getWeatherIcon(WeatherConditionType condition) {
    switch (condition) {
      case WeatherConditionType.clear:
        return Icons.wb_sunny_rounded;
      case WeatherConditionType.partlyCloudy:
        return Icons.cloud_queue_rounded;
      case WeatherConditionType.cloudy:
        return Icons.cloud_rounded;
      case WeatherConditionType.rain:
        return Icons.grain_rounded;
      case WeatherConditionType.heavyRain:
        return Icons.water_drop_rounded;
      case WeatherConditionType.thunderstorm:
        return Icons.thunderstorm_rounded;
      case WeatherConditionType.fog:
        return Icons.foggy;
      case WeatherConditionType.windy:
        return Icons.air_rounded;
      case WeatherConditionType.snow:
        return Icons.ac_unit_rounded;
    }
  }

  Widget _buildMetric(BuildContext context, {required IconData icon, required String label, required String value, required bool isDark}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }
}
