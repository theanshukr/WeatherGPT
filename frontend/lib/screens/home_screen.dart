import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/weather_provider.dart';
import '../widgets/svg_icon.dart';
import '../widgets/bouncing_button.dart';
import '../widgets/error_dialog.dart';
import 'alerts_screen.dart';
import 'chat_screen.dart';
import 'gemini_live_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  late AnimationController _orbAnimationController;

  @override
  void initState() {
    super.initState();
    _orbAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWeatherStatus();
    });
  }

  @override
  void dispose() {
    _orbAnimationController.dispose();
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9F8FD),
      body: Stack(
        children: [
          // Ambient soft lilac top-center glow
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isDark
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                          : const Color(0xFFDDD6FE).withValues(alpha: 0.65),
                      isDark
                          ? const Color(0xFFC084FC).withValues(alpha: 0.05)
                          : const Color(0xFFEDE9FE).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top App Bar: [Menu Button] - "Speaking to LIX" - [Document Button]
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Menu Button (≡)
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
                              color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.025),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: IosSvgIcon(
                              'menu',
                              size: 18,
                              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.9, end: 1),

                      // Center Title: Speaking to LIX
                      Text(
                        'Speaking to LIX',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
                          letterSpacing: -0.3,
                        ),
                      ).animate().fadeIn(duration: 300.ms),

                      // Right Document Button
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
                              color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.025),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: IosSvgIcon(
                              'document',
                              size: 19,
                              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.9, end: 1),
                    ],
                  ),
                ),

                // Main Scrollable Area
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 28),

                        // Center 3D Gradient Glowing Orb
                        _buildGlowingOrb(isDark),

                        const SizedBox(height: 28),

                        // Heading: How can I help you today?
                        Text(
                          'How can I help you today?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 10),

                        // Subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Ask about hyper-local forecasts, farming schedules, or live radars.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                              height: 1.45,
                            ),
                          ),
                        ).animate().fadeIn(duration: 450.ms, delay: 150.ms),

                        const SizedBox(height: 32),

                        // Action Prompt Cards
                        _buildActionCards(isDark),

                        const SizedBox(height: 20),

                        // Bottom Floating Message Input Box
                        _buildMessageInput(isDark),

                        const SizedBox(height: 100), // Padding to avoid overlap with bottom navigation bar
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

  /// Glowing Gradient Orb with soft diffused halo and breathing animation
  Widget _buildGlowingOrb(bool isDark) {
    return AnimatedBuilder(
      animation: _orbAnimationController,
      builder: (context, child) {
        final scale = 1.0 + (_orbAnimationController.value * 0.04);
        return IosBouncingButton(
          onTap: _openGeminiLive,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.35 : 0.3),
                    blurRadius: 28,
                    spreadRadius: 6,
                  ),
                  BoxShadow(
                    color: const Color(0xFFEC4899).withValues(alpha: isDark ? 0.25 : 0.2),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF2A85), // Vibrant Pink/Magenta top-left
                      Color(0xFF9333EA), // Purple middle
                      Color(0xFF6366F1), // Indigo
                      Color(0xFF38BDF8), // Light Cyan bottom-right
                    ],
                    stops: [0.0, 0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.85, end: 1, curve: Curves.easeOutBack);
  }

  /// 4 Rounded Action Cards matching screenshot
  Widget _buildActionCards(bool isDark) {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'Crop & Spray Advice',
        'icon': 'chat_bubble',
        'isIconData': false,
        'query': 'Crop & Spray Advice: What is the optimal time for crop spraying based on current weather conditions?',
      },
      {
        'title': 'Rain Timeline',
        'icon': 'cloud_rain',
        'isIconData': false,
        'query': 'Show me today\'s rain timeline and precipitation forecast.',
      },
      {
        'title': 'Travel Safety Risk',
        'icon': 'lightning',
        'isIconData': false,
        'query': 'Analyze travel safety risks and road condition forecasts for current weather.',
      },
      {
        'title': 'Severe Alerts Status',
        'icon': 'bell',
        'isIconData': false,
        'isAlertsScreen': true,
        'query': 'Check active severe weather alerts and warnings.',
      },
    ];

    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IosBouncingButton(
            onTap: () {
              if (item['isAlertsScreen'] == true) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                );
              } else {
                _openTextChat(query: item['query']);
              }
            },
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Purple Icon
                  IosSvgIcon(
                    item['icon'],
                    size: 20,
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 14),

                  // Title
                  Expanded(
                    child: Text(
                      item['title'],
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1F2937),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),

                  // Trailing Chevron
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(
                duration: 350.ms,
                delay: (200 + index * 60).ms,
              ).slideY(begin: 0.1, end: 0),
        );
      }),
    );
  }

  /// Bottom Message Input Bar matching screenshot
  Widget _buildMessageInput(bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : const Color(0xFFECEAF3),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Plus Button
          IosBouncingButton(
            onTap: () {
              _openTextChat();
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F8),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Message Text Input
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitInput(),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF111114),
              ),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppColors.darkTextTertiary : const Color(0xFF9CA3AF),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // Microphone Button
          IosBouncingButton(
            onTap: _openGeminiLive,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: IosSvgIcon(
                'mic',
                size: 20,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Black circular send button with right arrow
          IosBouncingButton(
            onTap: _submitInput,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : const Color(0xFF111114),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF111114) : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.15, end: 0);
  }
}
