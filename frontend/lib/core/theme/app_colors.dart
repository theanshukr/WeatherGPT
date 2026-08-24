import 'package:flutter/material.dart';

class AppColors {
  // ---------------------------------------------------------------------------
  // iOS Ethereal Light Canvas & Surfaces (Matching Reference UI)
  // ---------------------------------------------------------------------------
  static const Color lightBackground = Color(0xFFF8F6FD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1EEF9);
  static const Color lightCardBorder = Color(0xFFEBE6F5);
  static const Color lightCardBorderSubtle = Color(0x0D000000);
  static const Color lightGlassFill = Color(0xD9FFFFFF);
  static const Color lightAmbientGlow = Color(0xFFDFD4F6);

  // ---------------------------------------------------------------------------
  // iOS Obsidian Dark Canvas & Surfaces
  // ---------------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF0F0F12);
  static const Color darkSurface = Color(0xFF1A1A20);
  static const Color darkSurfaceElevated = Color(0xFF24242C);
  static const Color darkCardBorder = Color(0xFF2E2E38);
  static const Color darkGlassFill = Color(0x1AFFFFFF);

  // ---------------------------------------------------------------------------
  // iOS Core Accent & Action Colors
  // ---------------------------------------------------------------------------
  static const Color iosBlack = Color(0xFF111114);
  static const Color iosDarkPill = Color(0xFF18181B);
  static const Color iosViolet = Color(0xFF8B5CF6);
  static const Color iosIndigo = Color(0xFF6366F1);
  static const Color iosMagenta = Color(0xFFEC4899);
  static const Color iosCyan = Color(0xFF38BDF8);
  static const Color iosLilac = Color(0xFFC4B5FD);

  // Aliases for compatibility
  static const Color geminiPurple = iosViolet;
  static const Color geminiBlue = iosIndigo;
  static const Color geminiCoral = iosMagenta;
  static const Color geminiCyan = iosCyan;

  static const Color emeraldNeon = Color(0xFF10B981);
  static const Color emeraldGlow = Color(0xFF34D399);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color sunnyGold = Color(0xFFF59E0B);
  static const Color alertCrimson = Color(0xFFEF4444);
  static const Color tealAccent = Color(0xFF0EA5E9);

  // ---------------------------------------------------------------------------
  // Typography Colors
  // ---------------------------------------------------------------------------
  static const Color lightTextPrimary = Color(0xFF111114);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);

  static const Color darkTextPrimary = Color(0xFFF4F4F5);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkTextTertiary = Color(0xFF71717A);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------
  /// Signature Ambient Lilac Aura for Light Background top-right
  static const RadialGradient iosAmbientTopGlow = RadialGradient(
    center: Alignment(0.85, -0.85),
    radius: 1.1,
    colors: [
      Color(0xFFE2D6F8),
      Color(0xFFF0E8FC),
      Color(0x00F8F6FD),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  /// 3D Orb & Signature Gradient (Violet -> Magenta -> Lilac)
  static const LinearGradient iosOrbGradient = LinearGradient(
    colors: [
      Color(0xFF7C3AED),
      Color(0xFFA855F7),
      Color(0xFFEC4899),
      Color(0xFF38BDF8),
    ],
    stops: [0.0, 0.35, 0.70, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient geminiSparkleGradient = iosOrbGradient;

  static const LinearGradient iosLiveWaveGradient = LinearGradient(
    colors: [
      Color(0xFF7C3AED),
      Color(0xFFEC4899),
      Color(0xFF38BDF8),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient geminiLiveGradient = iosLiveWaveGradient;

  static const LinearGradient proBadgeGradient = LinearGradient(
    colors: [
      Color(0xFF8B5CF6),
      Color(0xFFD946EF),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient orbCoreGradient = RadialGradient(
    colors: [
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0x6638BDF8),
      Colors.transparent,
    ],
    stops: [0.0, 0.45, 0.75, 1.0],
  );
}
