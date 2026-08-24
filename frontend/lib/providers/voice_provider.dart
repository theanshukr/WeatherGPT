import 'package:flutter/material.dart';
import '../services/voice_service.dart';

/// Drives text-to-speech for the app. On-device (flutter_tts) is the
/// default engine — free, offline, no API key needed — which matters for
/// rural users with unreliable connectivity. Sarvam's cloud "natural
/// voice" is opt-in only, since it costs API tokens and requires network.
class VoiceProvider with ChangeNotifier {
  final VoiceService _voiceService = VoiceService();

  /// Whether WeatherGPT should automatically speak its replies.
  bool _autoSpeechEnabled = true;

  /// Whether the user has opted into the higher-quality cloud voice.
  /// True = use Sarvam natural voice by default (falls back to device if unavailable).
  bool _naturalVoiceEnabled = true;

  /// Message id currently being spoken, if any — lets the UI show a
  /// per-message "speaking" state instead of a single global spinner.
  String? _speakingMessageId;

  /// Set when a natural-voice request fails (e.g. no backend/API key)
  /// so the UI can tell the user it silently fell back to on-device.
  bool _lastSpeakFellBackToDevice = false;

  bool get autoSpeechEnabled => _autoSpeechEnabled;
  bool get naturalVoiceEnabled => _naturalVoiceEnabled;
  String? get speakingMessageId => _speakingMessageId;
  bool get lastSpeakFellBackToDevice => _lastSpeakFellBackToDevice;
  bool isSpeaking(String messageId) => _speakingMessageId == messageId;

  void setAutoSpeechEnabled(bool value) {
    _autoSpeechEnabled = value;
    if (!value) {
      _voiceService.stop();
      _speakingMessageId = null;
    }
    notifyListeners();
  }

  void setNaturalVoiceEnabled(bool value) {
    _naturalVoiceEnabled = value;
    notifyListeners();
  }

  /// Speaks [text] tagged to [messageId] using whichever engine is
  /// currently selected. Falls back to on-device TTS automatically if
  /// the natural-voice request fails (e.g. Sarvam key missing/network
  /// down) so a reply is never silently dropped.
  Future<void> speakMessage(String messageId, String text, {String languageCode = 'hi-IN'}) async {
    _speakingMessageId = messageId;
    _lastSpeakFellBackToDevice = false;
    notifyListeners();

    final engine = _naturalVoiceEnabled ? VoiceEngine.natural : VoiceEngine.device;
    bool ok = await _voiceService.speak(text, engine: engine, languageCode: languageCode);

    if (!ok && engine == VoiceEngine.natural) {
      _lastSpeakFellBackToDevice = true;
      ok = await _voiceService.speak(text, engine: VoiceEngine.device, languageCode: languageCode);
    }

    _speakingMessageId = null;
    notifyListeners();
  }

  Future<void> stop() async {
    await _voiceService.stop();
    _speakingMessageId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}
