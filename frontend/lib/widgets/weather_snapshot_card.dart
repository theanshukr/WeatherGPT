import 'package:flutter/material.dart';
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
              blurRadius: 16,
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
                    Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      weatherData.location.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.emeraldNeon.withValues(alpha: 0.15) : AppColors.emeraldDark.withValues(alpha: 0.1),
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
                          fontWeight: FontWeight.w700,
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
                      '${weatherData.temperature.toInt()}°C',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Feels like ${weatherData.feelsLike.toInt()}°C • ${weatherData.conditionDescription}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Icon(
                  Icons.cloud_queue_rounded,
                  size: 52,
                  color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Key Weather Metrics (Rain, Humidity, Wind)
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
                    label: 'Rain Risk',
                    value: '${weatherData.rainProbability.toInt()}%',
                  ),
                  _buildDivider(isDark),
                  _buildMetric(
                    context,
                    icon: Icons.air_rounded,
                    label: 'Wind',
                    value: '${weatherData.windSpeed.toInt()} km/h',
                  ),
                  _buildDivider(isDark),
                  _buildMetric(
                    context,
                    icon: Icons.wb_sunny_outlined,
                    label: 'UV Index',
                    value: '${weatherData.uvIndex.toInt()}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(BuildContext context, {required IconData icon, required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, size: 18, color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
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
