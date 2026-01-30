import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// EnvConfig centralizes environment/runtime configuration.
///
/// Usage:
/// - For local development set using `--dart-define=GEMINI_API_KEY=your_key`
/// - For CI / production inject the environment using your deployment system.
/// - For web, use `--dart-define` during build and set the same key.

class EnvConfig {
  /// Read the Gemini API key. Priority:
  /// 1) Compile-time `--dart-define=GEMINI_API_KEY=...`
  /// 2) Runtime `.env` value (dotenv) if present (useful for local dev)
  static String? get geminiApiKey {
    const key = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (key.isNotEmpty) return key;

    try {
      final envVal = DotEnv().env['GEMINI_API_KEY'];
      if (envVal != null && envVal.isNotEmpty) return envVal;
    } catch (_) {
      // ignore - dotenv may not be loaded in some contexts
    }

    return null;
  }

  static bool get hasGemini => geminiApiKey != null && geminiApiKey!.isNotEmpty;

  /// Convenience for platform-specific checks
  static bool get isWeb => kIsWeb;

  /// The model to use for Gemini calls. Priority:
  /// 1) Compile-time `--dart-define=GEMINI_MODEL=...`
  /// 2) Runtime `.env` value GEMINI_MODEL if present
  /// 3) Default to 'gemini-1.0-pro'
  static String get geminiModel {
    const raw = String.fromEnvironment('GEMINI_MODEL', defaultValue: '');
    if (raw.isNotEmpty) {
      return raw.startsWith('models/') ? raw.substring('models/'.length) : raw;
    }

    try {
      final runtime = DotEnv().env['GEMINI_MODEL'] ?? '';
      if (runtime.isNotEmpty)
        return runtime.startsWith('models/')
            ? runtime.substring('models/'.length)
            : runtime;
    } catch (_) {}

    return 'gemini-1.0-pro';
  }
}
