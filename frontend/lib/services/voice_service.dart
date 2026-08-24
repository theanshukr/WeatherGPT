import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'api_client.dart';
import '../core/constants/api_constants.dart';

/// Which engine produced (or should produce) the current speech.
enum VoiceEngine {
  /// On-device, free, works fully offline. Default — this is the
  /// reliability path for rural/low-connectivity users.
  device,

  /// Cloud-based natural voice via the backend's Sarvam integration.
  /// Costs API tokens and needs network — opt-in only.
  natural,
}

/// Thin wrapper around on-device TTS (flutter_tts) and the backend's
/// Sarvam TTS endpoint. Exactly one of these two paths is used per
/// utterance, decided by [VoiceEngine] passed to [speak].
///
/// Kept as a single class (not split across providers) so both engines
/// share one "currently speaking" concept and can't play concurrently.
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _deviceTts = FlutterTts();
  final AudioPlayer _cloudPlayer = AudioPlayer();
  final ApiClient _apiClient = ApiClient();

  bool _deviceTtsInitialized = false;

  Future<void> _ensureDeviceTtsInitialized() async {
    if (_deviceTtsInitialized) return;
    // Hindi default to match Megha's default reply language; callers can
    // still get English out of this since flutter_tts will use the
    // closest available voice/pitch for unsupported scripts rather than
    // failing outright.
    await _deviceTts.setLanguage('hi-IN');
    await _deviceTts.setSpeechRate(0.48);
    await _deviceTts.setPitch(1.0);
    await _deviceTts.setVolume(1.0);
    _deviceTtsInitialized = true;
  }

  /// Speaks [text] using the selected [engine]. Stops any currently
  /// playing speech from either engine first, so tapping a new Speak
  /// button never overlaps audio.
  ///
  /// Returns true on success. On failure (e.g. natural voice requested
  /// but the backend/API key isn't available), the caller should fall
  /// back to [VoiceEngine.device] — this method does NOT auto-fallback
  /// itself, so the UI can tell the user what happened.
  static String sanitizeForSpeech(String text) {
    if (text.isEmpty) return '';
    var t = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    t = t.replaceAll(RegExp(r'(\d+)\s*°\s*C'), r'$1 डिग्री');
    t = t.replaceAll(RegExp(r'(\d+)\s*%'), r'$1 प्रतिशत');
    t = t.replaceAll(RegExp(r'[*_~`#]'), ' ');
    t = t.replaceAll(RegExp(r'[-•–—|/]+'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  Future<bool> speak(String text, {required VoiceEngine engine, String languageCode = 'hi-IN'}) async {
    final clean = sanitizeForSpeech(text);
    if (clean.trim().isEmpty) return false;
    await stop();

    if (engine == VoiceEngine.device) {
      return _speakOnDevice(clean);
    }
    return _speakNatural(clean, languageCode: languageCode);
  }

  Future<bool> _speakOnDevice(String text) async {
    try {
      await _ensureDeviceTtsInitialized();
      final clean = sanitizeForSpeech(text);
      final result = await _deviceTts.speak(clean);
      // flutter_tts returns 1 on success across platforms.
      return result == 1;
    } catch (e) {
      developer.log('On-device TTS failed: $e', name: 'VoiceService');
      return false;
    }
  }

  Future<bool> _speakNatural(String text, {required String languageCode}) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.voiceTts,
        body: {
          'text': text,
          'language_code': languageCode,
        },
      );

      if (response == null) return false;

      final status = response['status'] as String?;
      final audioBase64 = response['audio_base64'] as String?;

      if (status == 'api_key_missing' || audioBase64 == null) {
        developer.log(
          'Natural voice unavailable (${response['message'] ?? status}); caller should fall back to device TTS.',
          name: 'VoiceService',
        );
        return false;
      }

      final bytes = base64Decode(audioBase64);
      await _cloudPlayer.setAudioSource(_Base64AudioSource(bytes));
      await _cloudPlayer.play();
      return true;
    } catch (e) {
      developer.log('Natural (Sarvam) TTS failed: $e', name: 'VoiceService');
      return false;
    }
  }

  /// Stops any audio currently playing from either engine.
  Future<void> stop() async {
    try {
      await _deviceTts.stop();
    } catch (_) {}
    try {
      await _cloudPlayer.stop();
    } catch (_) {}
  }

  void dispose() {
    _deviceTts.stop();
    _cloudPlayer.dispose();
  }
}

/// Lets just_audio play a raw in-memory MP3/WAV byte buffer (what the
/// backend hands back as base64) without writing a temp file first.
class _Base64AudioSource extends StreamAudioSource {
  final List<int> bytes;
  _Base64AudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
