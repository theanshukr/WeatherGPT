import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/theme/app_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/voice_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/user_context_provider.dart';
import '../widgets/ios_svg_icon.dart';
import '../widgets/ios_bouncing_button.dart';
import '../widgets/ios_voice_orb_3d.dart';
import 'chat_screen.dart';

enum GeminiLiveState {
  connecting,
  listening,
  thinking,
  speaking,
  paused,
}

class GeminiLiveScreen extends StatefulWidget {
  const GeminiLiveScreen({super.key});

  @override
  State<GeminiLiveScreen> createState() => _GeminiLiveScreenState();
}

class _GeminiLiveScreenState extends State<GeminiLiveScreen>
    with TickerProviderStateMixin {
  late stt.SpeechToText _speechToText;
  late AnimationController _rippleController;

  GeminiLiveState _liveState = GeminiLiveState.connecting;
  String _userTranscription = '';
  String _aiSpeechReply = '';
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _speechToText = stt.SpeechToText();
    _initLiveVoiceSession();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _speechToText.stop();
    context.read<VoiceProvider>().stop();
    super.dispose();
  }

  Future<void> _initLiveVoiceSession() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (error) {
          if (mounted && _liveState == GeminiLiveState.listening) {
            setState(() {
              _userTranscription = 'Listening paused. Tap mic to speak.';
              _liveState = GeminiLiveState.paused;
            });
          }
        },
        onStatus: (status) {
          if (status == 'done' && mounted && _liveState == GeminiLiveState.listening) {
            if (_userTranscription.isNotEmpty) {
              _processVoiceTurn();
            }
          }
        },
      );

      if (_speechAvailable && mounted) {
        setState(() {
          _liveState = GeminiLiveState.listening;
          _userTranscription = 'Say it — I’ll take notes';
        });
        _startListening();
      } else if (mounted) {
        setState(() {
          _liveState = GeminiLiveState.paused;
          _userTranscription = 'Voice input not ready. Check microphone permissions.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liveState = GeminiLiveState.paused;
          _userTranscription = 'Could not access microphone.';
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _userTranscription = result.recognizedWords;
            });

            if (result.finalResult && _userTranscription.trim().isNotEmpty) {
              _processVoiceTurn();
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (_) {}
  }

  Future<void> _processVoiceTurn() async {
    final query = _userTranscription.trim();
    if (query.isEmpty) {
      _startListening();
      return;
    }

    final chatProv = context.read<ChatProvider>();
    final voiceProv = context.read<VoiceProvider>();
    final weatherProv = context.read<WeatherProvider>();
    final contextProv = context.read<UserContextProvider>();

    setState(() {
      _liveState = GeminiLiveState.thinking;
    });

    try {
      await chatProv.sendUserMessage(
        query,
        lat: weatherProv.weatherData.location.latitude,
        lon: weatherProv.weatherData.location.longitude,
        activePersona: contextProv.currentPersona.name,
      );

      if (chatProv.messages.isNotEmpty) {
        final lastMsg = chatProv.messages.last;
        if (mounted) {
          setState(() {
            _aiSpeechReply = lastMsg.content;
            _liveState = GeminiLiveState.speaking;
          });

          await voiceProv.speakMessage('live_session', _aiSpeechReply);

          if (mounted) {
            setState(() {
              _liveState = GeminiLiveState.listening;
              _userTranscription = '';
            });
            _startListening();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _liveState = GeminiLiveState.paused;
          _userTranscription = 'Error processing request.';
        });
      }
    }
  }

  IosVoiceOrbState _getOrbState() {
    switch (_liveState) {
      case GeminiLiveState.connecting:
      case GeminiLiveState.paused:
        return IosVoiceOrbState.idle;
      case GeminiLiveState.listening:
        return IosVoiceOrbState.listening;
      case GeminiLiveState.thinking:
        return IosVoiceOrbState.thinking;
      case GeminiLiveState.speaking:
        return IosVoiceOrbState.speaking;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Ethereal Ambient Lavender Glow (Center-Top)
          Positioned(
            top: 40,
            left: MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    isDark
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.16)
                        : const Color(0xFFE0D4F7).withValues(alpha: 0.7),
                    isDark
                        ? const Color(0xFFC084FC).withValues(alpha: 0.06)
                        : const Color(0xFFEDE9FE).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  // Top Navigation Bar matching Screen 2
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Menu
                      IosBouncingButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                            ),
                          ),
                          child: Center(
                            child: IosSvgIcon(
                              'menu',
                              size: 18,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ),

                      // Center Title & Subtitle
                      Column(
                        children: [
                          Text(
                            'Speaking to LIX',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.iosBlack,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Say it — I’ll take notes',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextTertiary : const Color(0xFF8E918F),
                            ),
                          ),
                        ],
                      ),

                      // Right Chat Bubble Button (Transition to text chat)
                      IosBouncingButton(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const ChatScreen()),
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
                            ),
                          ),
                          child: Center(
                            child: IosSvgIcon(
                              'chat_bubble',
                              size: 18,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1, end: 0),

                  const Spacer(flex: 2),

                  // Center Layered 3D Translucent Petal Orb matching Screen 2
                  Center(
                    child: IosVoiceOrb3D(
                      size: 260,
                      state: _getOrbState(),
                      onTap: () {
                        if (_liveState == GeminiLiveState.listening) {
                          _speechToText.stop();
                          setState(() => _liveState = GeminiLiveState.paused);
                        } else {
                          setState(() => _liveState = GeminiLiveState.listening);
                          _startListening();
                        }
                      },
                    ),
                  ).animate().fadeIn(duration: 600.ms).scaleXY(begin: 0.85, end: 1, curve: Curves.easeOutBack),

                  const Spacer(flex: 2),

                  // Spoken Transcription Card matching Screen 2
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.2)
                              : const Color(0xFF7C3AED).withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _userTranscription.isNotEmpty
                          ? _userTranscription
                          : 'Hey, what will the weather be like today? Any rainfall or storm alerts I should know about?',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(duration: 450.ms, delay: 200.ms).slideY(begin: 0.1, end: 0),

                  // Bottom Action Controls (Giant ripple microphone + Close button)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Center Giant Glowing Ripple Microphone Button
                        _buildMicCenterButton(isDark),

                        // Right Close Button
                        Positioned(
                          right: 16,
                          child: IosBouncingButton(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                border: Border.all(
                                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: IosSvgIcon(
                                  'close',
                                  size: 16,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicCenterButton(bool isDark) {
    final isListening = _liveState == GeminiLiveState.listening;

    return IosBouncingButton(
      onTap: () {
        if (isListening) {
          _speechToText.stop();
          setState(() => _liveState = GeminiLiveState.paused);
        } else {
          setState(() => _liveState = GeminiLiveState.listening);
          _startListening();
        }
      },
      child: AnimatedBuilder(
        animation: _rippleController,
        builder: (context, child) {
          final rippleVal = _rippleController.value;

          return SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer animated ripple ring
                if (isListening)
                  Container(
                    width: 68 + (rippleVal * 18),
                    height: 68 + (rippleVal * 18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: (1.0 - rippleVal) * 0.4),
                        width: 2,
                      ),
                    ),
                  ),

                // Concentric inner ring
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? const Color(0xFF262630)
                        : const Color(0xFFEDE9FE),
                  ),
                ),

                // Main Center Black Pill Button
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.iosBlack,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: IosSvgIcon(
                      'mic_fill',
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
