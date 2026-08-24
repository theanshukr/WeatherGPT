import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/theme/app_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/voice_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/user_context_provider.dart';
import '../widgets/gemini_sparkle_icon.dart';

enum GeminiLiveState {
  connecting,
  listening,
  thinking,
  speaking,
  paused,
}

/// Full-screen Gemini Live interactive voice interface.
/// Features glowing dynamic fluid aurora waveform, real-time speech interaction,
/// natural multilingual voice responses, and seamless Gemini aesthetic.
class GeminiLiveScreen extends StatefulWidget {
  const GeminiLiveScreen({super.key});

  @override
  State<GeminiLiveScreen> createState() => _GeminiLiveScreenState();
}

class _GeminiLiveScreenState extends State<GeminiLiveScreen>
    with TickerProviderStateMixin {
  late AnimationController _auroraController;
  late AnimationController _pulseController;
  late stt.SpeechToText _speechToText;

  GeminiLiveState _liveState = GeminiLiveState.connecting;
  String _userTranscription = '';
  String _aiSpeechReply = '';
  bool _speechAvailable = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();

    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      lowerBound: 0.85,
      upperBound: 1.15,
    )..repeat(reverse: true);

    _speechToText = stt.SpeechToText();
    _initLiveVoiceSession();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _pulseController.dispose();
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
          _userTranscription = 'Listening... Speak in Hindi or English';
        });
        _startListening();
      } else if (mounted) {
        setState(() {
          _liveState = GeminiLiveState.paused;
          _userTranscription = 'Voice input not ready. Check microphone permission.';
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
    if (!_speechAvailable || _isMuted) return;

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

      if (!mounted) return;

      final lastMsg = chatProv.messages.isNotEmpty ? chatProv.messages.last : null;
      final replyText = lastMsg?.content ?? 'Sorry, could not process weather information.';

      setState(() {
        _liveState = GeminiLiveState.speaking;
        _aiSpeechReply = replyText;
      });

      await voiceProv.speakMessage('gemini_live_utterance', replyText);

      if (mounted) {
        setState(() {
          _liveState = GeminiLiveState.listening;
          _userTranscription = '';
        });
        _startListening();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _liveState = GeminiLiveState.paused;
          _aiSpeechReply = 'Could not connect to AI server. Tap mic to retry.';
        });
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _speechToText.stop();
        _liveState = GeminiLiveState.paused;
      } else {
        _liveState = GeminiLiveState.listening;
        _startListening();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: SafeArea(
        child: Stack(
          children: [
            // Top Header: Gemini Live Brand & Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const GeminiSparkleIcon(size: 26),
                      const SizedBox(width: 10),
                      Text(
                        'Gemini Live',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF333537)),
                        ),
                        child: Text(
                          'Megha AI',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.geminiCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1E1F20),
                      ),
                      child: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Center Content: Pulsing Fluid Aurora Wave Visualizer + Live Text
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Gemini Aurora Orb
                    AnimatedBuilder(
                      animation: Listenable.merge([_auroraController, _pulseController]),
                      builder: (context, child) {
                        final scale = _liveState == GeminiLiveState.speaking ||
                                _liveState == GeminiLiveState.listening
                            ? _pulseController.value
                            : 1.0;

                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _getStatePrimaryColor().withValues(alpha: 0.95),
                                  _getStateSecondaryColor().withValues(alpha: 0.60),
                                  const Color(0xFF4285F4).withValues(alpha: 0.20),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.45, 0.75, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatePrimaryColor().withValues(alpha: 0.35),
                                  blurRadius: 70,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                            child: Center(
                              child: GeminiSparkleIcon(
                                size: 52,
                                gradient: _getStateGradient(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 38),

                    // State Indicator Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatePrimaryColor().withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getStatePrimaryColor(),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatePrimaryColor(),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getStateLabel(),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Live Speech Transcription / AI Response Text Box
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Text(
                          _liveState == GeminiLiveState.speaking
                              ? _aiSpeechReply
                              : (_userTranscription.isNotEmpty
                                  ? _userTranscription
                                  : 'Start speaking to inquire about rain, temperatures, travel or crops...'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: _userTranscription.isNotEmpty || _liveState == GeminiLiveState.speaking
                                ? Colors.white
                                : Colors.white54,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar (Mute, Red End Session Pill, Keyboard Mode)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute / Unmute Button
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isMuted ? Colors.white24 : const Color(0xFF1E1F20),
                        border: Border.all(color: const Color(0xFF333537)),
                      ),
                      child: Icon(
                        _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: _isMuted ? Colors.white : AppColors.geminiCyan,
                        size: 24,
                      ),
                    ),
                  ),

                  // End Live Session Pill Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.call_end_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'End Live',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Switch to Text Chat
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E1F20),
                        border: Border.all(color: const Color(0xFF333537)),
                      ),
                      child: const Icon(
                        Icons.keyboard_outlined,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatePrimaryColor() {
    switch (_liveState) {
      case GeminiLiveState.listening:
        return AppColors.geminiCyan;
      case GeminiLiveState.thinking:
        return AppColors.geminiPurple;
      case GeminiLiveState.speaking:
        return AppColors.emeraldGlow;
      case GeminiLiveState.paused:
        return Colors.orangeAccent;
      case GeminiLiveState.connecting:
        return AppColors.geminiBlue;
    }
  }

  Color _getStateSecondaryColor() {
    switch (_liveState) {
      case GeminiLiveState.listening:
        return const Color(0xFF4285F4);
      case GeminiLiveState.thinking:
        return const Color(0xFFFF758C);
      case GeminiLiveState.speaking:
        return const Color(0xFF00E5FF);
      case GeminiLiveState.paused:
      case GeminiLiveState.connecting:
        return const Color(0xFF9B72CF);
    }
  }

  Gradient _getStateGradient() {
    switch (_liveState) {
      case GeminiLiveState.speaking:
        return AppColors.emeraldGradient;
      case GeminiLiveState.thinking:
        return const LinearGradient(colors: [Color(0xFF9B72CF), Color(0xFFFF758C)]);
      default:
        return AppColors.geminiSparkleGradient;
    }
  }

  String _getStateLabel() {
    switch (_liveState) {
      case GeminiLiveState.connecting:
        return 'Connecting Gemini Live...';
      case GeminiLiveState.listening:
        return 'Listening...';
      case GeminiLiveState.thinking:
        return 'Analyzing Weather Telemetry...';
      case GeminiLiveState.speaking:
        return 'Megha Speaking...';
      case GeminiLiveState.paused:
        return 'Session Paused';
    }
  }
}
