import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../widgets/gemini_sparkle_icon.dart';
import '../services/supabase_service.dart';
import 'onboarding_screen.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final session = SupabaseService.client.auth.currentSession;
    final targetScreen = session != null
        ? const MainNavigationScreen()
        : const OnboardingScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient Gemini Aurora Glow
          if (isDark)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.28,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.geminiBlue.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.geminiPurple.withValues(alpha: 0.20),
                      blurRadius: 150,
                      spreadRadius: 60,
                    ),
                  ],
                ),
              ),
            ),

          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Radiant Gemini 4-Point Sparkle Icon
                const GeminiSparkleIcon(
                  size: 110,
                  animate: true,
                ),

                const SizedBox(height: 32),

                // Brand Name with Gemini Gradient Shader
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.geminiSparkleGradient.createShader(bounds),
                  child: Text(
                    'WeatherGPT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Tagline
                Text(
                  'AI Weather & Early Warning Intelligence',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    letterSpacing: 0.2,
                  ),
                ),

                const Spacer(flex: 3),

                // Bottom loading indicator
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      isDark ? AppColors.geminiBlue : const Color(0xFF1A73E8),
                    ),
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
