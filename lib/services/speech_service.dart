import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service for handling speech-to-text functionality
/// NOTE: On Web (`kIsWeb == true`) speech recognition is disabled and
/// all operations are no-ops that return immediately. This prevents crashes
/// and infinite waiting loops on platforms where the mic is unavailable.
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  StreamController<String>? _resultController;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (kIsWeb) {
      // Web: speech_to_text is not supported reliably. Disable gracefully.
      _isAvailable = false;
      return _isAvailable;
    }

    _isAvailable = await _speech.initialize(
      onError: (error) {
        print('Speech recognition error: $error');
        _isListening = false;
        _resultController?.add('');
        _resultController?.close();
        _resultController = null;
      },
      onStatus: (status) {
        print('Speech recognition status: $status');
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _isAvailable;
  }

  /// Check if speech recognition is available
  bool get isAvailable => _isAvailable;

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Start listening for speech input
  /// Returns a stream of recognized text
  Stream<String> startListening({String? localeId}) async* {
    if (kIsWeb) {
      // On web, do not attempt to listen. Return empty stream immediately.
      yield '';
      return;
    }

    if (!_isAvailable) {
      await initialize();
    }

    if (!_isAvailable) {
      yield '';
      return;
    }

    _isListening = true;
    _resultController = StreamController<String>();
    String finalResult = '';
    bool hasResult = false;

    // Listen for speech
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          finalResult = result.recognizedWords;
          hasResult = true;
          _resultController?.add(finalResult);
        } else {
          // Partial results - update but don't close
          _resultController?.add(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: localeId ?? 'en_IN',
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: false,
        partialResults: true,
      ),
    );

    // Wait for results with timeout
    try {
      await for (String text in _resultController!.stream.timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) {
          sink.add(finalResult);
          sink.close();
        },
      )) {
        if (text.isNotEmpty && hasResult) {
          yield text;
          break;
        }
      }
    } catch (e) {
      print('Speech listening error: $e');
      yield finalResult;
    } finally {
      _isListening = false;
      _resultController?.close();
      _resultController = null;
    }
  }

  /// Stop listening
  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
      _resultController?.close();
      _resultController = null;
    }
  }

  /// Cancel listening
  void cancelListening() {
    if (_isListening) {
      _speech.cancel();
      _isListening = false;
      _resultController?.close();
      _resultController = null;
    }
  }
}
