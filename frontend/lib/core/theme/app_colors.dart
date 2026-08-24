import 'package:flutter/material.dart';

class AppColors {
  // ---------------------------------------------------------------------------
  // Google Gemini Signature Dark Palette (Charcoal, Obsidian & Radiant Aurora)
  // ---------------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF131314); // Official Gemini Canvas
  static const Color darkSurface = Color(0xFF1E1F20); // Gemini Card Surface
  static const Color darkSurfaceElevated = Color(0xFF282A2C); // Input pill & chips
  static const Color darkSurfaceHover = Color(0xFF333537); // Hover / Highlighted card
  static const Color darkCardBorder = Color(0xFF37393B); // Subtle refined stroke
  static const Color darkGlassFill = Color(0x1AFFFFFF);

  // ---------------------------------------------------------------------------
  // Google Gemini Signature Light Palette (Frosted Cloud & Soft Slate)
  // ---------------------------------------------------------------------------
  static const Color lightBackground = Color(0xFFF0F4F9); // Gemini Web / Mobile light canvas
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFE3E8EF);
  static const Color lightSurfaceHover = Color(0xFFD8DFEB);
  static const Color lightCardBorder = Color(0xFFE1E5EA);
  static const Color lightGlassFill = Color(0xF0FFFFFF);

  // ---------------------------------------------------------------------------
  // Google Gemini Aurora Multi-Color Accent Palette
  // ---------------------------------------------------------------------------
  static const Color geminiBlue = Color(0xFF4285F4); // Google Blue
  static const Color geminiPurple = Color(0xFF9B72CF); // Gemini Violet
  static const Color geminiCoral = Color(0xFFFF758C); // Soft Magenta Glow
  static const Color geminiCyan = Color(0xFF00E5FF); // Cyber Cyan
  static const Color emeraldNeon = Color(0xFF00E676); // High-vitality Emerald
  static const Color emeraldGlow = Color(0xFF00FF87);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color electricCyan = Color(0xFF00F2FE);
  static const Color tealAccent = Color(0xFF0EA5E9);

  // ---------------------------------------------------------------------------
  // Dynamic Weather State Accents
  // ---------------------------------------------------------------------------
  static const Color sunnyGold = Color(0xFFF59E0B);
  static const Color rainyAzure = Color(0xFF3B82F6);
  static const Color stormViolet = Color(0xFF8B5CF6);
  static const Color alertCrimson = Color(0xFFEF4444);

  // ---------------------------------------------------------------------------
  // Typography Colors
  // ---------------------------------------------------------------------------
  static const Color darkTextPrimary = Color(0xFFE3E3E3);
  static const Color darkTextSecondary = Color(0xFFC4C7C5);
  static const Color darkTextTertiary = Color(0xFF8E918F);

  static const Color lightTextPrimary = Color(0xFF1F1F1F);
  static const Color lightTextSecondary = Color(0xFF444746);
  static const Color lightTextTertiary = Color(0xFF747775);

  // ---------------------------------------------------------------------------
  // Gemini Multi-Color Gradients
  // ---------------------------------------------------------------------------
  /// Signature Gemini 4-color Sparkle gradient (Blue -> Purple -> Coral -> Cyan)
  static const LinearGradient geminiSparkleGradient = LinearGradient(
    colors: [
      Color(0xFF4E80EE),
      Color(0xFF9B72CF),
      Color(0xFFFF758C),
      Color(0xFF00E5FF),
    ],
    stops: [0.0, 0.35, 0.70, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gemini Live Glowing Aurora gradient for interactive voice waves
  static const LinearGradient geminiLiveGradient = LinearGradient(
    colors: [
      Color(0xFF4E80EE),
      Color(0xFF9B72CF),
      Color(0xFF00FF87),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Emerald Intelligence Gradient (Weather theme integration)
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF00FF87), Color(0xFF60EFA0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Radial glow for background ambiance and Gemini Live center
  static const RadialGradient orbCoreGradient = RadialGradient(
    colors: [
      Color(0xFF4E80EE),
      Color(0xFF9B72CF),
      Color(0x6600E5FF),
      Colors.transparent,
    ],
    stops: [0.0, 0.45, 0.75, 1.0],
  );
}
