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
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
              color: AppColors.geminiBlue.withValues(alpha: 0.10),
              blurRadius: 20,
              spreadRadius: -2,
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Settings Tab
          _buildNavButton(
            context: context,
            icon: Icons.tune_rounded,
            label: 'Settings',
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),

          // 2. Middle Tab: Gemini Live Sparkle / Voice
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
                gradient: AppColors.geminiSparkleGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.geminiBlue.withValues(alpha: selectedIndex == 1 ? 0.60 : 0.30),
                    blurRadius: selectedIndex == 1 ? 16 : 8,
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
                  child: const Center(
                    child: Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Profile Tab
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
    final activeColor = isDark ? AppColors.geminiBlue : const Color(0xFF1A73E8);
    final inactiveColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.geminiBlue.withValues(alpha: 0.15) : const Color(0xFFE8F0FE))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
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
