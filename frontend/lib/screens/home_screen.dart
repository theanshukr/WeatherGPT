import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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

  // Real speech recognition
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechAvailable = false;
  String _recognizedWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWeatherStatus();
    });
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (error) {
          if (mounted) {
            setState(() {
              _orbState = VoiceOrbState.idle;
              _liveQueryText = 'Speech error: ${error.errorMsg}';
            });
          }
        },
        onStatus: (status) {
          if (status == 'done' && mounted && _orbState == VoiceOrbState.listening) {
            _processRecognizedSpeech();
          }
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
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

  Future<void> _handleLiveVoiceTap() async {
    final voiceProv = context.read<VoiceProvider>();

    if (_orbState == VoiceOrbState.speaking) {
      await voiceProv.stop();
      setState(() {
        _orbState = VoiceOrbState.idle;
      });
      return;
    }

    if (_orbState == VoiceOrbState.listening) {
      await _speechToText.stop();
      setState(() => _orbState = VoiceOrbState.idle);
      return;
    }

    if (!_speechAvailable) {
      setState(() {
        _liveQueryText = 'Voice input not available on this device. Tap "Type Query" to chat.';
        _liveResponseText = null;
      });
      return;
    }

    setState(() {
      _orbState = VoiceOrbState.listening;
      _liveQueryText = '🎙️ Listening... speak now';
      _liveResponseText = null;
      _recognizedWords = '';
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _recognizedWords = result.recognizedWords;
              _liveQueryText = _recognizedWords.isEmpty
                  ? '🎙️ Listening... speak now'
                  : _recognizedWords;
            });

            if (result.finalResult && _recognizedWords.isNotEmpty) {
              _processRecognizedSpeech();
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _orbState = VoiceOrbState.idle;
          _liveQueryText = 'Could not start voice input: $e';
        });
      }
    }
  }

  Future<void> _processRecognizedSpeech() async {
    if (_recognizedWords.trim().isEmpty) {
      setState(() {
        _orbState = VoiceOrbState.idle;
        _liveQueryText = 'No speech detected. Tap the orb and try again.';
      });
      return;
    }

    final chatProv = context.read<ChatProvider>();
    final voiceProv = context.read<VoiceProvider>();

    setState(() {
      _orbState = VoiceOrbState.thinking;
      _liveQueryText = _recognizedWords;
    });

    try {
      await chatProv.sendUserMessage(_recognizedWords);
      if (!mounted) return;

      final lastMessage = chatProv.messages.isNotEmpty ? chatProv.messages.last : null;
      final replyText = lastMessage?.content ?? 'No response received.';

      setState(() {
        _liveResponseText = replyText;
        _orbState = VoiceOrbState.speaking;
      });

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
          _liveResponseText = 'Could not connect to AI server. Please check your connection.';
        });
        ConnectionErrorDialog.show(
          context,
          message: 'Unable to reach WeatherGPT AI server: $e',
          onRetry: _handleLiveVoiceTap,
        );
      }
    }
  }

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
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emeraldNeon.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emeraldNeon.withValues(alpha: 0.18),
                        blurRadius: 140,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              ),

            // Main Scrollable Content
            RefreshIndicator(
              color: AppColors.emeraldNeon,
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
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Icon(
                                  Icons.public_rounded,
                                  size: 19,
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
                            const SizedBox(width: 6),
                            // Severe Weather Alert Bell
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 19,
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
                      style: GoogleFonts.inter(
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            if (_liveResponseText != null) ...[
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('⛅ ', style: TextStyle(fontSize: 14)),
                                  Expanded(
                                    child: Text(
                                      _liveResponseText!,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        height: 1.45,
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

                    // Live Weather Overview Card (Real Data from Backend)
                    _buildLiveWeatherCard(context, weatherProv: weatherProv, weather: weather, isDark: isDark),

                    const SizedBox(height: 16),

                    // Hourly Forecast Strip
                    if (weather.hourlyForecast.isNotEmpty)
                      _buildHourlyForecastStrip(context, weather: weather, isDark: isDark),

                    const SizedBox(height: 90), // Space for floating buttons
                  ],
                ),
              ),
            ),

            // Floating Keyboard Button
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                heroTag: 'fab_chat',
                onPressed: _openTextChat,
                backgroundColor: AppColors.emeraldNeon,
                elevation: 4,
                icon: const Icon(Icons.keyboard_outlined, color: Colors.black, size: 20),
                label: Text(
                  'Type Query',
                  style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWeatherCard(BuildContext context, {required WeatherProvider weatherProv, required WeatherData weather, required bool isDark}) {
    if (weatherProv.isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.emeraldNeon),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Connecting to atmospheric telemetry...',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (weatherProv.errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.alertCrimson.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 34, color: AppColors.alertCrimson),
            const SizedBox(height: 8),
            Text(
              'Could not reach weather server',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Check your connection and verify the backend is running.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => weatherProv.loadWeatherData(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 17, color: AppColors.emeraldNeon),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            weather.location.name,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weather.conditionDescription,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${weather.temperature.toStringAsFixed(1)}°C',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 4 Grid Stats: Rain, Humidity, Wind, Condition
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Precip',
                '${weather.rainfallAmount.toStringAsFixed(1)} mm',
                Icons.water_drop_outlined,
                isDark,
              ),
              _buildStatItem('Humidity', '${weather.humidity.toStringAsFixed(0)}%', Icons.opacity_rounded, isDark),
              _buildStatItem('Wind', '${weather.windSpeed.toStringAsFixed(1)} km/h', Icons.air_rounded, isDark),
              _buildStatItem(
                'Wind Dir',
                '${weather.windDirection.toInt()}°',
                Icons.explore_outlined,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 19, color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'HOURLY RAIN & TEMPERATURE TIMELINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? AppColors.emeraldNeon : AppColors.emeraldDark,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: weather.hourlyForecast.length.clamp(0, 16),
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final item = weather.hourlyForecast[i];
              final hourStr = '${item.time.hour.toString().padLeft(2, '0')}:00';
              return Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(hourStr, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('${item.temperature.toStringAsFixed(0)}°', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('${item.rainProbability.toStringAsFixed(0)}% 🌧️', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDark)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
