import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/dynamic_weather_orb.dart';
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
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient emerald aura
          if (isDark)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emeraldNeon.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldNeon.withValues(alpha: 0.2),
                      blurRadius: 130,
                      spreadRadius: 50,
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

                // Center Dynamic Orb
                const DynamicWeatherOrb(
                  size: 160,
                  orbState: VoiceOrbState.idle,
                ),

                const SizedBox(height: 36),

                // Brand Name
                Text(
                  'WeatherGPT',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 8),

                // Tagline
                Text(
                  'AI Weather & Disaster Intelligence',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDark,
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
                      isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
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
