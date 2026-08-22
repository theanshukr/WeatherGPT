import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../widgets/dynamic_weather_orb.dart';
import 'onboarding_screen.dart';

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
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    // Navigate to Onboarding after 2.4s
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
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

                // Center Mini Glowing Dynamic Orb
                const DynamicWeatherOrb(
                  size: 160,
                  isListening: false,
                ),

                const SizedBox(height: 36),

                // Brand Name
                Text(
                  'WeatherGPT',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 8),

                // Tagline
                Text(
                  'AI Weather Intelligence',
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
