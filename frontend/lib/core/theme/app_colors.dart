import 'package:flutter/material.dart';

class AppColors {
  // Dark Theme Palette (OLED Black & Glowing Emerald)
  static const Color darkBackground = Color(0xFF060908);
  static const Color darkSurface = Color(0xFF0E1411);
  static const Color darkSurfaceElevated = Color(0xFF141C18);
  static const Color darkCardBorder = Color(0x1A00E676);
  static const Color darkGlassFill = Color(0x0FFFFFFF);

  // Light Theme Palette (Frosted Porcelain & Emerald Accents)
  static const Color lightBackground = Color(0xFFF6F8F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFEFF3F1);
  static const Color lightCardBorder = Color(0x15059669);
  static const Color lightGlassFill = Color(0xF0FFFFFF);

  // Signature Glowing Accents (From Reference Screenshot)
  static const Color emeraldNeon = Color(0xFF00E676);
  static const Color emeraldGlow = Color(0xFF00FF87);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color electricCyan = Color(0xFF00F2FE);
  static const Color tealAccent = Color(0xFF0EA5E9);

  // Dynamic Weather State Accents
  static const Color sunnyGold = Color(0xFFF59E0B);
  static const Color rainyAzure = Color(0xFF3B82F6);
  static const Color stormViolet = Color(0xFF8B5CF6);
  static const Color alertCrimson = Color(0xFFEF4444);

  // Text Colors
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);

  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);

  // Gradient Presets
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF00FF87), Color(0xFF60EFA0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient orbCoreGradient = RadialGradient(
    colors: [
      Color(0xFF00FF87),
      Color(0xFF00E676),
      Color(0x80059669),
      Colors.transparent,
    ],
    stops: [0.0, 0.4, 0.75, 1.0],
  );
}
