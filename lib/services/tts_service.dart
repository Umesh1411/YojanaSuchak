import 'package:flutter_tts/flutter_tts.dart';
import '../core/services/language_service.dart';

/// Service for text-to-speech functionality
class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// Initialize TTS with current language
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Get current language and set TTS language accordingly
    final locale = await LanguageService.getCurrentLanguage();
    String ttsLanguage = _getTtsLanguageCode(locale);
    
    await _flutterTts.setLanguage(ttsLanguage);
    await _flutterTts.setSpeechRate(0.5); // Normal speech rate
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Set up completion handler to track speaking state
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  /// Get TTS language code from locale
  String _getTtsLanguageCode(dynamic locale) {
    String languageCode = locale.languageCode;
    switch (languageCode) {
      case 'hi':
        return 'hi-IN'; // Hindi (India)
      case 'mr':
        return 'mr-IN'; // Marathi (India)
      case 'en':
      default:
        return 'en-IN'; // English (India)
    }
  }

  /// Update TTS language
  Future<void> updateLanguage(dynamic locale) async {
    String ttsLanguage = _getTtsLanguageCode(locale);
    await _flutterTts.setLanguage(ttsLanguage);
  }

  /// Speak the given text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Update language if it changed
    final currentLocale = await LanguageService.getCurrentLanguage();
    await updateLanguage(currentLocale);

    _isSpeaking = true;
    await _flutterTts.speak(text);
  }

  /// Stop speaking
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  /// Check if TTS is currently speaking
  bool isSpeaking() {
    return _isSpeaking;
  }
}
