import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import '../core/services/language_service.dart';

/// Service for text-to-speech functionality
class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isAvailable = false;

  /// Initialize TTS with current language
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if TTS is available on this platform
      _isAvailable = await _flutterTts.isLanguageAvailable('en-US') ||
          await _flutterTts.isLanguageAvailable('en-IN');

      // On web, TTS might not be available immediately
      if (kIsWeb && !_isAvailable) {
        // Try to initialize with default settings
        _isAvailable = true; // Assume available, will fail gracefully if not
      }

      if (!_isAvailable) {
        print('⚠️ TTS not available on this platform');
        return;
      }

      // Get current language and set TTS language accordingly
      final locale = await LanguageService.getCurrentLanguage();
      String ttsLanguage = _getTtsLanguageCode(locale);

      await _flutterTts.setLanguage(ttsLanguage);
      await _flutterTts
          .setSpeechRate(1.0); // Normal speech rate for better user experience
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set up completion handler to track speaking state
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _isInitialized = true;
    } catch (e) {
      print('⚠️ TTS initialization error: $e');
      _isAvailable = false;
    }
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

  /// Check if TTS is available
  bool get isAvailable => _isAvailable && _isInitialized;

  /// Speak the given text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isAvailable) {
      print('⚠️ TTS not available, skipping speech');
      return;
    }

    try {
      // Update language if it changed
      final currentLocale = await LanguageService.getCurrentLanguage();
      await updateLanguage(currentLocale);

      _isSpeaking = true;
      await _flutterTts.speak(text);
    } catch (e) {
      print('⚠️ TTS speak error: $e');
      _isSpeaking = false;
    }
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
