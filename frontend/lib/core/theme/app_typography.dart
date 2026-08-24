import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  // ---------------------------------------------------------------------------
  // iOS SF Pro Styled Dark Text Theme
  // ---------------------------------------------------------------------------
  static TextTheme darkTextTheme = TextTheme(
    displayLarge: GoogleFonts.plusJakartaSans(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppColors.darkTextPrimary,
      height: 1.18,
    ),
    displayMedium: GoogleFonts.plusJakartaSans(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColors.darkTextPrimary,
      height: 1.22,
    ),
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppColors.darkTextPrimary,
      height: 1.25,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.darkTextPrimary,
      height: 1.3,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.darkTextPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: AppColors.darkTextPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.1,
      color: AppColors.darkTextPrimary,
      height: 1.4,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.05,
      color: AppColors.darkTextSecondary,
      height: 1.38,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: AppColors.darkTextPrimary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: AppColors.darkTextTertiary,
    ),
  );

  // ---------------------------------------------------------------------------
  // iOS SF Pro Styled Light Text Theme
  // ---------------------------------------------------------------------------
  static TextTheme lightTextTheme = TextTheme(
    displayLarge: GoogleFonts.plusJakartaSans(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppColors.lightTextPrimary,
      height: 1.18,
    ),
    displayMedium: GoogleFonts.plusJakartaSans(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColors.lightTextPrimary,
      height: 1.22,
    ),
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: AppColors.lightTextPrimary,
      height: 1.25,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.lightTextPrimary,
      height: 1.3,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: AppColors.lightTextPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: AppColors.lightTextPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.1,
      color: AppColors.lightTextPrimary,
      height: 1.4,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.05,
      color: AppColors.lightTextSecondary,
      height: 1.38,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: AppColors.lightTextPrimary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: AppColors.lightTextTertiary,
    ),
  );
}
