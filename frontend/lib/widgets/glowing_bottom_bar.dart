import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import 'ios_svg_icon.dart';
import 'ios_bouncing_button.dart';

class GlowingBottomBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const GlowingBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0xFF936DFF).withValues(alpha: 0.09),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Left: Radar
            _buildNavItem(
              index: 0,
              icon: 'radar',
              label: 'Radar',
              isDark: isDark,
            ),
            // Middle: Home / Assistant
            _buildNavItem(
              index: 1,
              icon: 'sparkles',
              label: 'Home',
              isDark: isDark,
            ),
            // Right: Profile
            _buildNavItem(
              index: 2,
              icon: 'user',
              label: 'Profile',
              isDark: isDark,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildNavItem({
    required int index,
    required String icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = selectedIndex == index;
    final inactiveColor = isDark ? AppColors.darkTextTertiary : const Color(0xFF71717A);

    return IosBouncingButton(
      onTap: () => onItemSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 14,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFF3EDFD))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IosSvgIcon(
              icon,
              size: 20,
              color: isSelected ? (isDark ? Colors.white : const Color(0xFF7C3AED)) : inactiveColor,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF7C3AED),
                  letterSpacing: -0.2,
                ),
              ).animate().fadeIn(duration: 180.ms).scaleXY(begin: 0.9, end: 1),
            ],
          ],
        ),
      ),
    );
  }
}
