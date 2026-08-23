import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/weather_model.dart';
import '../providers/weather_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/user_context_provider.dart';
import '../providers/voice_provider.dart';
import '../widgets/dynamic_weather_orb.dart';
import '../widgets/context_badge.dart';
import '../widgets/error_dialog.dart';
import 'alerts_screen.dart';
import 'map_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VoiceOrbState _orbState = VoiceOrbState.idle;
  String? _liveQueryText;
  String? _liveResponseText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWeatherStatus();
    });
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

  // Live Voice Agent Trigger (Stays directly on HomeScreen)
  Future<void> _handleLiveVoiceTap() async {
    final chatProv = context.read<ChatProvider>();
    final voiceProv = context.read<VoiceProvider>();

    if (_orbState == VoiceOrbState.speaking) {
      // Stop ongoing speech
      await voiceProv.stop();
      setState(() {
        _orbState = VoiceOrbState.idle;
      });
      return;
    }

    if (_orbState == VoiceOrbState.listening) {
      setState(() => _orbState = VoiceOrbState.idle);
      return;
    }

    // 1. Listening State
    setState(() {
      _orbState = VoiceOrbState.listening;
      _liveQueryText = 'बोलिए, मैं सुन रही हूँ... (Listening...)';
      _liveResponseText = null;
    });

    // 2. Query processing (simulated speech capture or trigger)
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted || _orbState != VoiceOrbState.listening) return;

    final query = 'आज शाम को मेरे एरिया में मौसम कैसा रहेगा और क्या बारिश होगी?';
    setState(() {
      _liveQueryText = query;
      _orbState = VoiceOrbState.thinking;
    });

    // 3. Send to Live AI Backend
    try {
      await chatProv.sendUserMessage(query);
      if (!mounted) return;

      final lastMessage = chatProv.messages.isNotEmpty ? chatProv.messages.last : null;
      final replyText = lastMessage?.content ?? 'मौसम सामान्य रहेगा।';

      setState(() {
        _liveResponseText = replyText;
        _orbState = VoiceOrbState.speaking;
      });

      // 4. Speak aloud using VoiceProvider
      await voiceProv.speakMessage('home_live_reply', replyText);
      if (mounted) {
        setState(() {
          _orbState = VoiceOrbState.idle;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _orbState = VoiceOrbState.idle;
          _liveResponseText = 'बैकएंड से कनेक्ट नहीं हो सका। कृपया सर्वर चेक करें।';
        });
        ConnectionErrorDialog.show(
          context,
          message: 'Unable to reach WeatherGPT AI server: $e',
          onRetry: _handleLiveVoiceTap,
        );
      }
    }
  }

  // Open Full Text Chat Screen only on explicit button tap
  void _openTextChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weatherProv = context.watch<WeatherProvider>();
    final contextProv = context.watch<UserContextProvider>();
    final weather = weatherProv.weatherData;

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

            // Main Scrollable Content
            RefreshIndicator(
              onRefresh: () async {
                await weatherProv.loadWeatherData();
                _checkWeatherStatus();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Top Bar: Persona Badge & Map / Alert Action Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ContextBadge(
                          persona: contextProv.currentPersona,
                          confidence: contextProv.userContext.confidenceScore,
                        ),
                        Row(
                          children: [
                            // GIS Radar Map Button
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
                                  Icons.public_rounded,
                                  size: 18,
                                  color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
                                ),
                              ),
                              tooltip: 'GIS Radar & Alert Map',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const MapScreen()),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
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
                                child: const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 18,
                                  color: AppColors.sunnyGold,
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
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Center Live AI Voice Agent Orb
                    Center(
                      child: DynamicWeatherOrb(
                        size: 210,
                        orbState: _orbState,
                        onTap: _handleLiveVoiceTap,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Voice Status Prompt
                    Text(
                      _orbState == VoiceOrbState.listening
                          ? '🎙️ Megha is listening... speak naturally'
                          : _orbState == VoiceOrbState.thinking
                              ? '⚡ Analyzing atmospheric data & advisory...'
                              : _orbState == VoiceOrbState.speaking
                                  ? '🔊 Megha is speaking... (Tap orb to stop)'
                                  : 'Tap Orb to talk with Megha (AI Voice)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _orbState != VoiceOrbState.idle
                            ? AppColors.emeraldNeon
                            : isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),

                    // Live Speech Caption Box
                    if (_liveQueryText != null || _liveResponseText != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_liveQueryText != null)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('👤 ', style: TextStyle(fontSize: 14)),
                                  Expanded(
                                    child: Text(
                                      _liveQueryText!,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            if (_liveResponseText != null) ...[
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('⛅ ', style: TextStyle(fontSize: 14)),
                                  Expanded(
                                    child: Text(
                                      _liveResponseText!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Live Weather Overview Card (Real Data from Open-Meteo)
                    _buildLiveWeatherCard(context, weather: weather, isDark: isDark),

                    const SizedBox(height: 16),

                    // Hourly Forecast Strip
                    if (weather.hourlyForecast.isNotEmpty)
                      _buildHourlyForecastStrip(context, weather: weather, isDark: isDark),

                    const SizedBox(height: 90), // Space for floating buttons
                  ],
                ),
              ),
            ),

            // Floating Keyboard Button (Opens Text Chat only when tapped)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                heroTag: 'fab_chat',
                onPressed: _openTextChat,
                backgroundColor: AppColors.emeraldNeon,
                icon: const Icon(Icons.keyboard_outlined, color: Colors.black, size: 20),
                label: const Text(
                  'Type Query',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWeatherCard(BuildContext context, {required WeatherData weather, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Location & Condition Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: AppColors.emeraldNeon),
                      const SizedBox(width: 4),
                      Text(
                        '${weather.location.name}, ${weather.location.country}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weather.conditionDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                '${weather.temperature.toStringAsFixed(1)}°C',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -1),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // 4 Grid Stats: Rain, Humidity, Wind, UV Index
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Rain Prob', '${weather.rainProbability.toStringAsFixed(0)}%', Icons.water_drop_outlined, isDark),
              _buildStatItem('Humidity', '${weather.humidity.toStringAsFixed(0)}%', Icons.opacity_rounded, isDark),
              _buildStatItem('Wind', '${weather.windSpeed.toStringAsFixed(1)} km/h', Icons.air_rounded, isDark),
              _buildStatItem('UV Index', weather.uvIndex.toStringAsFixed(1), Icons.wb_sunny_outlined, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.emeraldNeon),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyForecastStrip(BuildContext context, {required WeatherData weather, required bool isDark}) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weather.hourlyForecast.length.clamp(0, 12),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final item = weather.hourlyForecast[i];
          final hourStr = '${item.time.hour.toString().padLeft(2, '0')}:00';
          return Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(hourStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                Text('${item.temperature.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${item.rainProbability.toStringAsFixed(0)}% 🌧️', style: TextStyle(fontSize: 9, color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDark)),
              ],
            ),
          );
        },
      ),
    );
  }
}
