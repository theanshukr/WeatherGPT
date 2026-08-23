import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'main_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSigningIn = false;

  final List<({String title, String subtitle, String icon, String tag})> _slides = [
    (
      title: 'Talk to Weather\nNaturally',
      subtitle: 'No complex charts or radar grids needed. Just ask WeatherGPT like a human assistant.',
      icon: '🎙️',
      tag: 'VOICE & CHAT FIRST',
    ),
    (
      title: 'Farmer & Travel\nIntelligence',
      subtitle: 'Get actionable agricultural spray windows, irrigation advice, and destination briefings.',
      icon: '🌾',
      tag: 'DYNAMIC CONTEXT',
    ),
    (
      title: 'Instant Severe\nWeather Warnings',
      subtitle: 'Stay safe with proactive alerts before heavy thunderstorms, convective rain, or heatwaves.',
      icon: '⚡',
      tag: 'REAL-TIME ALERTS',
    ),
  ];

  void _handleGoogleSignIn() {
    setState(() => _isSigningIn = true);

    // Simulated Google OAuth Flow with seamless standalone transition
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _isSigningIn = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 1)),
        );
      }
    });
  }

  void _handleSkipToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen(initialIndex: 1)),
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
            // Top Bar: Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'WeatherGPT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _handleSkipToHome,
                    child: Text(
                      'Skip',
                      style: TextStyle(
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
                      height: 390,
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
                                ? AppColors.emeraldNeon.withValues(alpha: 0.12)
                                : AppColors.emeraldDark.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.emeraldNeon.withValues(alpha: 0.25)
                                  : AppColors.emeraldDark.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            slide.tag,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
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
                            color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                                    .withValues(alpha: 0.2),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              slide.icon,
                              style: const TextStyle(fontSize: 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Headline
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                        ),
                        const SizedBox(height: 14),

                        // Subtitle
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
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
                        ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                        : (isDark ? Colors.white12 : Colors.black12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Authentication Interface: Google Sign-In & Guest Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  // "Continue with Google" Button
                  GestureDetector(
                    onTap: _isSigningIn ? null : _handleGoogleSignIn,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? AppColors.emeraldNeon.withValues(alpha: 0.4)
                              : AppColors.emeraldDark.withValues(alpha: 0.3),
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
                          if (_isSigningIn) ...[
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Signing in with Google...',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ] else ...[
                            // Authentic Google G Icon
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // "Continue as Guest" Button (Solid Emerald)
                  GestureDetector(
                    onTap: _handleSkipToHome,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                                .withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Get Started as Guest',
                          style: TextStyle(
                            color: Colors.black,
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
