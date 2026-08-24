import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../widgets/gemini_sparkle_icon.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<({String title, String subtitle, IconData icon, Color iconColor, String tag})> _slides = [
    (
      title: 'Talk to Weather\nNaturally',
      subtitle: 'No complex charts or radar grids needed. Just ask WeatherGPT like a human AI companion.',
      icon: Icons.auto_awesome_rounded,
      iconColor: AppColors.geminiCyan,
      tag: 'GEMINI LIVE & VOICE FIRST',
    ),
    (
      title: 'Agricultural & Travel\nIntelligence',
      subtitle: 'Get actionable spray windows, irrigation timing, and destination highway risk briefings.',
      icon: Icons.agriculture_rounded,
      iconColor: Color(0xFF00FF87),
      tag: 'METEOROLOGICAL GROUNDING',
    ),
    (
      title: 'Instant Early\nWarning Alerts',
      subtitle: 'Stay safe with proactive NDMA SACHET disaster advisories before convective storms or heatwaves.',
      icon: Icons.warning_amber_rounded,
      iconColor: Color(0xFFFF758C),
      tag: 'REAL-TIME TELEMETRY',
    ),
  ];

  void _navigateToAuth() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  void _handleSkipToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    // Top Bar: Gemini Sparkle + Skip Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const GeminiSparkleIcon(size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'WeatherGPT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _handleSkipToHome,
                            child: Text(
                              'Skip',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // PageView Slides
                    SizedBox(
                      height: 410,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _slides.length,
                        onPageChanged: (index) => setState(() => _currentPage = index),
                        itemBuilder: (context, index) {
                          final slide = _slides[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Tag Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurfaceElevated
                                        : AppColors.lightSurfaceElevated,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                    ),
                                  ),
                                  child: Text(
                                    slide.tag,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: AppColors.geminiBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Center Icon Visual Card
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                    border: Border.all(
                                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: slide.iconColor.withValues(alpha: 0.2),
                                        blurRadius: 30,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      slide.icon,
                                      size: 46,
                                      color: slide.iconColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Headline
                                Text(
                                  slide.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Subtitle
                                Text(
                                  slide.subtitle,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Animated Page Dots Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (index) {
                        final isSelected = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isSelected ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.geminiBlue
                                : (isDark ? Colors.white12 : Colors.black12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 36),

                    // Authentication Interface: Google Sign-In & Guest Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          // "Sign In / Register" Button
                          GestureDetector(
                            onTap: _navigateToAuth,
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Sign In or Create Account',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // "Continue as Guest" Button (Gemini Gradient CTA)
                          GestureDetector(
                            onTap: _handleSkipToHome,
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: AppColors.geminiSparkleGradient,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.geminiBlue.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Get Started as Guest',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
