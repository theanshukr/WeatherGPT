import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GlowingBottomBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback? onOrbTap;

  const GlowingBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onOrbTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      height: 66,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          if (isDark)
            BoxShadow(
              color: AppColors.emeraldNeon.withValues(alpha: 0.12),
              blurRadius: 20,
              spreadRadius: -4,
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Left Tab: Settings
          _buildNavButton(
            context: context,
            icon: Icons.tune_rounded,
            label: 'Settings',
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),

          // 2. Middle Tab: Home / Glowing Dynamic Voice Orb
          GestureDetector(
            onTap: () {
              onItemSelected(1);
              if (onOrbTap != null) onOrbTap!();
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF00FF87),
                    Color(0xFF00E676),
                    Color(0xFF059669),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emeraldNeon.withValues(alpha: selectedIndex == 1 ? 0.65 : 0.35),
                    blurRadius: selectedIndex == 1 ? 18 : 10,
                    spreadRadius: selectedIndex == 1 ? 2 : 0,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: selectedIndex == 1 ? 0.95 : 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // 3. Right Tab: Profile
          _buildNavButton(
            context: context,
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isSelected: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.emeraldNeon : AppColors.emeraldDark;
    final inactiveColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.emeraldNeon.withValues(alpha: 0.12) : AppColors.emeraldDark.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? activeColor : inactiveColor,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
