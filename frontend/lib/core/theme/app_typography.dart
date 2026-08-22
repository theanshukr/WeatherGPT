import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  // iOS-style Typography for Dark Theme
  static TextTheme darkTextTheme = TextTheme(
    displayLarge: GoogleFonts.plusJakartaSans(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppColors.darkTextPrimary,
      height: 1.2,
    ),
    displayMedium: GoogleFonts.plusJakartaSans(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      color: AppColors.darkTextPrimary,
      height: 1.25,
    ),
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: AppColors.darkTextPrimary,
      height: 1.3,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.darkTextPrimary,
      height: 1.3,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: AppColors.darkTextPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.1,
      color: AppColors.darkTextPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.1,
      color: AppColors.darkTextPrimary,
      height: 1.45,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: AppColors.darkTextSecondary,
      height: 1.4,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: AppColors.darkTextPrimary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: AppColors.darkTextTertiary,
    ),
  );

  // iOS-style Typography for Light Theme
  static TextTheme lightTextTheme = TextTheme(
    displayLarge: GoogleFonts.plusJakartaSans(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppColors.lightTextPrimary,
      height: 1.2,
    ),
    displayMedium: GoogleFonts.plusJakartaSans(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      color: AppColors.lightTextPrimary,
      height: 1.25,
    ),
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: AppColors.lightTextPrimary,
      height: 1.3,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.lightTextPrimary,
      height: 1.3,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: AppColors.lightTextPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.1,
      color: AppColors.lightTextPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.1,
      color: AppColors.lightTextPrimary,
      height: 1.45,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: AppColors.lightTextSecondary,
      height: 1.4,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: AppColors.lightTextPrimary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: AppColors.lightTextTertiary,
    ),
  );
}
