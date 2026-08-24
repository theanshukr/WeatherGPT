import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/weather_provider.dart';
import '../widgets/ios_svg_icon.dart';
import '../widgets/ios_bouncing_button.dart';
import '../widgets/error_dialog.dart';
import 'alerts_screen.dart';
import 'map_screen.dart';
import 'chat_screen.dart';
import 'gemini_live_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWeatherStatus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _checkWeatherStatus() {
    final weatherProv = context.read<WeatherProvider>();
    if (weatherProv.errorMessage != null && mounted) {
      ConnectionErrorDialog.show(
        context,
        message: 'Could not connect to backend server. ${weatherProv.errorMessage}',
        onRetry: () => weatherProv.loadWeatherData(),
      );
    }
  }

  void _openGeminiLive() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GeminiLiveScreen()),
    );
  }

  void _openTextChat({String? query}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(initialQuery: query),
      ),
    );
  }

  void _submitInput() {
    final text = _inputController.text.trim();
    if (text.isNotEmpty) {
      _inputController.clear();
      _openTextChat(query: text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weatherProv = context.watch<WeatherProvider>();
    final weather = weatherProv.weatherData;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Ethereal Lavender Ambient Top-Right Glow
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    isDark
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.18)
                        : const Color(0xFFDDD6FE).withValues(alpha: 0.85),
                    isDark
                        ? const Color(0xFFC084FC).withValues(alpha: 0.08)
                        : const Color(0xFFEDE9FE).withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Header Bar: Menu (≡) & Options (···)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Menu Button
                      IosBouncingButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: IosSvgIcon(
                              'menu',
                              size: 18,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 350.ms).scaleXY(begin: 0.9, end: 1),

                      // Weather Location Center Pill
                      IosBouncingButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MapScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceElevated
                                : Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const IosSvgIcon(
                                'cloud_rain',
                                size: 14,
                                color: Color(0xFF7C3AED),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                weather.location.name.isNotEmpty && weather.location.name != 'Loading...'
                                    ? '${weather.location.name} • ${weather.temperature.round()}°C'
                                    : 'Live Weather',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.2, end: 0),

                      // Right More Options Button
                      IosBouncingButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AlertsScreen()),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: IosSvgIcon(
                              'more_horizontal',
                              size: 18,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 350.ms).scaleXY(begin: 0.9, end: 1),
                    ],
                  ),
                ),

                // Main Scrollable Area
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),

                        // Greeting Section matching Screen 1
                        Text(
                          'Hi, Hendricks',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                            letterSpacing: -0.2,
                          ),
                        ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(begin: -0.05, end: 0),

                        const SizedBox(height: 4),

                        Text(
                          'How can I help today?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.iosBlack,
                            letterSpacing: -0.6,
                            height: 1.2,
                          ),
                        ).animate().fadeIn(duration: 450.ms, delay: 150.ms).slideX(begin: -0.05, end: 0),

                        const SizedBox(height: 8),

                        Text(
                          'I’m here to help — from quick answers to smart recommendations.',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: isDark ? AppColors.darkTextTertiary : const Color(0xFF8E918F),
                            height: 1.4,
                          ),
                        ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                        const SizedBox(height: 24),

                        // 2x2 Feature Action Cards Grid matching Screen 1
                        _buildFeatureGrid(isDark),

                        const SizedBox(height: 20),

                        // Unlock More Features with Pro Banner
                        _buildProBanner(isDark),

                        const SizedBox(height: 16),

                        // Squircle Input Box matching Screen 1
                        _buildInputBox(isDark),

                        const SizedBox(height: 100), // Spacing for floating bottom bar
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                iconName: 'surprise',
                title: 'Surprise me!',
                subtitle: 'Surprise me with a creative idea or story.',
                delayMs: 250,
                isDark: isDark,
                onTap: () => _openTextChat(query: 'Surprise me with a fascinating weather anomaly or creative climate story!'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildFeatureCard(
                iconName: 'image',
                title: 'Create image',
                subtitle: 'Create an image from your idea or prompt.',
                delayMs: 300,
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                iconName: 'document',
                title: 'Summarise',
                subtitle: 'Summarise a document or text in seconds.',
                delayMs: 350,
                isDark: isDark,
                onTap: () => _openTextChat(query: 'Summarise current climate conditions, rain probability, and agriculture safety for today.'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildFeatureCard(
                iconName: 'lightning',
                title: 'Generate ideas',
                subtitle: 'Brainstorm concepts, names, features.',
                delayMs: 400,
                isDark: isDark,
                onTap: () => _openTextChat(query: 'Brainstorm travel recommendations and outdoor activity timing based on the forecast.'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String iconName,
    required String title,
    required String subtitle,
    required int delayMs,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return IosBouncingButton(
      onTap: onTap,
      child: Container(
        height: 146,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : const Color(0xFF7C3AED).withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon
            IosSvgIcon(
              iconName,
              size: 24,
              color: isDark ? Colors.white : AppColors.iosBlack,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.iosBlack,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: isDark ? AppColors.darkTextTertiary : const Color(0xFF737380),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: delayMs.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildProBanner(bool isDark) {
    return IosBouncingButton(
      onTap: _openGeminiLive,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E28)
              : const Color(0xFFF7F3FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFDDD6FE),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const IosSvgIcon(
              'lightning',
              size: 16,
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unlock more features with Pro & Live Voice',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF5B21B6),
                ),
              ),
            ),
            const IosSvgIcon(
              'arrow_right',
              size: 14,
              color: Color(0xFF7C3AED),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 450.ms);
  }

  Widget _buildInputBox(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF936DFF).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _inputController,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Ask me anything ...',
              hintStyle: GoogleFonts.inter(
                fontSize: 14.5,
                color: isDark ? AppColors.darkTextTertiary : const Color(0xFFA1A1AA),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => _submitInput(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left tool shortcuts
              Row(
                children: [
                  IosBouncingButton(
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: IosSvgIcon(
                        'paperclip',
                        size: 20,
                        color: isDark ? AppColors.darkTextTertiary : const Color(0xFF71717A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IosBouncingButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AlertsScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: IosSvgIcon(
                        'sliders',
                        size: 20,
                        color: isDark ? AppColors.darkTextTertiary : const Color(0xFF71717A),
                      ),
                    ),
                  ),
                ],
              ),

              // Right Mic + Black Circular Send Button
              Row(
                children: [
                  IosBouncingButton(
                    onTap: _openGeminiLive,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: IosSvgIcon(
                        'mic',
                        size: 20,
                        color: isDark ? AppColors.darkTextTertiary : const Color(0xFF71717A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IosBouncingButton(
                    onTap: _submitInput,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.iosBlack,
                      ),
                      child: const Center(
                        child: IosSvgIcon(
                          'send',
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }
}
