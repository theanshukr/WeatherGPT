import 'package:flutter/material.dart';
import '../models/user_context.dart';
import '../core/theme/app_colors.dart';

class ContextBadge extends StatelessWidget {
  final DetectedPersona persona;
  final double confidence;

  const ContextBadge({
    super.key,
    required this.persona,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = _getPersonaInfo(persona);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.emeraldNeon.withValues(alpha: 0.3) : AppColors.emeraldDark.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            info.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(confidence * 100).toInt()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ({String icon, String title}) _getPersonaInfo(DetectedPersona persona) {
    switch (persona) {
      case DetectedPersona.farmer:
        return (icon: '🌾', title: 'Farmer Context');
      case DetectedPersona.traveller:
        return (icon: '✈️', title: 'Traveller Context');
      case DetectedPersona.student:
        return (icon: '🎒', title: 'Student Context');
      case DetectedPersona.commuter:
        return (icon: '🚗', title: 'Commuter Context');
      default:
        return (icon: '☀️', title: 'General Context');
    }
  }
}
