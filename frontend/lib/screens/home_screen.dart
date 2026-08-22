import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/weather_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/user_context_provider.dart';
import '../widgets/dynamic_weather_orb.dart';
import '../widgets/context_badge.dart';
import 'chat_screen.dart';
import 'alerts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _onOrbTap() {
    final chatProv = context.read<ChatProvider>();
    chatProv.setListening(!chatProv.isListening);
    if (chatProv.isListening) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        chatProv.setListening(false);
        _navigateToChat('Will it rain in my area today?');
      });
    }
  }

  void _navigateToChat([String? query]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(initialQuery: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weatherProv = context.watch<WeatherProvider>();
    final chatProv = context.watch<ChatProvider>();
    final contextProv = context.watch<UserContextProvider>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background Subtle Glowing Aura
            if (isDark)
              Positioned(
                top: -60,
                left: MediaQuery.of(context).size.width * 0.2,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emeraldNeon.withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emeraldNeon.withValues(alpha: 0.15),
                        blurRadius: 130,
                        spreadRadius: 45,
                      ),
                    ],
                  ),
                ),
              ),

            // Main Content
            Column(
              children: [
                const SizedBox(height: 12),

                // Top Header: Active AI Persona Pill & Severe Alert Bell
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Active AI Persona Badge
                      ContextBadge(
                        persona: contextProv.currentPersona,
                        confidence: contextProv.userContext.confidenceScore,
                      ),

                      // Severe Weather Alert Bell
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                            ),
                          ),
                          child: Icon(
                            Icons.notifications_active_outlined,
                            size: 18,
                            color: isDark ? AppColors.sunnyGold : AppColors.alertCrimson,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AlertsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Location & Live Atmosphere Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${weatherProv.weatherData.location.name} • ${weatherProv.weatherData.temperature.toInt()}°C ${weatherProv.weatherData.conditionDescription}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Main Title Headline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'What Can I Do for\nYou Today?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                  ),
                ),

                const SizedBox(height: 10),

                // Status Indicator Prompt
                Text(
                  chatProv.isListening ? '🎙️ Listening to your voice...' : 'Tap the orb to speak or use keyboard below',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: chatProv.isListening
                        ? (isDark ? AppColors.emeraldNeon : AppColors.emeraldDark)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),

                const Spacer(flex: 2),

                // Center Stage: Dynamic Glowing Weather Orb (Interactive)
                DynamicWeatherOrb(
                  size: MediaQuery.of(context).size.width * 0.65,
                  isListening: chatProv.isListening,
                  onTap: _onOrbTap,
                ),

                const Spacer(flex: 2),

                // "Use Keyboard" Action Button (Transitions smoothly to Chat Mode)
                GestureDetector(
                  onTap: () => _navigateToChat(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_alt_outlined,
                          size: 20,
                          color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Use Keyboard',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
