import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

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
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          if (isDark)
            BoxShadow(
              color: AppColors.geminiBlue.withValues(alpha: 0.08),
              blurRadius: 18,
              spreadRadius: -2,
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Dashboard / Home Tab
          _buildNavButton(
            context: context,
            icon: Icons.dashboard_rounded,
            label: 'Home',
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),

          // 2. Gemini Chat Tab
          _buildNavButton(
            context: context,
            icon: Icons.chat_bubble_rounded,
            label: 'Chat',
            isSelected: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),

          // 3. GIS Radar Map Tab
          _buildNavButton(
            context: context,
            icon: Icons.public_rounded,
            label: 'Radar',
            isSelected: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),

          // 4. Intelligence / Profile Tab
          _buildNavButton(
            context: context,
            icon: Icons.psychology_rounded,
            label: 'Profile',
            isSelected: selectedIndex == 3,
            onTap: () => onItemSelected(3),
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
    final activeColor = isDark ? AppColors.geminiCyan : AppColors.geminiBlue;
    final inactiveColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.geminiBlue.withValues(alpha: 0.16) : const Color(0xFFE8F0FE))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
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
