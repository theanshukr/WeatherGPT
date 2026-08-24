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
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 62,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(31),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0xFF936DFF).withValues(alpha: 0.08),
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
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              index: 0,
              icon: 'surprise',
              label: 'Explore',
              isDark: isDark,
            ),
            _buildNavItem(
              index: 1,
              icon: 'chat_bubble',
              label: 'Chat',
              isDark: isDark,
            ),
            _buildNavItem(
              index: 2,
              icon: 'radar',
              label: 'Radar',
              isDark: isDark,
            ),
            _buildNavItem(
              index: 3,
              icon: 'user',
              label: 'Context',
              isDark: isDark,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildNavItem({
    required int index,
    required String icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = selectedIndex == index;
    final inactiveColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return IosBouncingButton(
      onTap: () => onItemSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFF3EDFD))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
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
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
