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
    if (key.isNotEmpty) {
      return key;
    }

    try {
      final envVal = DotEnv().env['GEMINI_API_KEY'];
      if (envVal != null && envVal.isNotEmpty) {
        return envVal;
      }
    } catch (_) {
      // ignore - dotenv may not be loaded in some contexts
    }

    return null;
  }

  static bool get hasGemini => geminiApiKey != null && geminiApiKey!.isNotEmpty;

  /// SMTP configuration (read from dart-define or .env if present)
  static String? get smtpHost {
    const key = String.fromEnvironment('SMTP_HOST', defaultValue: '');
    if (key.isNotEmpty) return key;
    try {
      final envVal = DotEnv().env['SMTP_HOST'];
      if (envVal != null && envVal.isNotEmpty) return envVal;
    } catch (_) {}
    return null;
  }

  static int? get smtpPort {
    const key = String.fromEnvironment('SMTP_PORT', defaultValue: '');
    if (key.isNotEmpty) return int.tryParse(key);
    try {
      final envVal = DotEnv().env['SMTP_PORT'];
      if (envVal != null && envVal.isNotEmpty) return int.tryParse(envVal);
    } catch (_) {}
    return null;
  }

  static String? get smtpUsername {
    const key = String.fromEnvironment('SMTP_USERNAME', defaultValue: '');
    if (key.isNotEmpty) return key;
    try {
      final envVal = DotEnv().env['SMTP_USERNAME'];
      if (envVal != null && envVal.isNotEmpty) return envVal;
    } catch (_) {}
    return null;
  }

  static String? get smtpPassword {
    const key = String.fromEnvironment('SMTP_PASSWORD', defaultValue: '');
    if (key.isNotEmpty) return key;
    try {
      final envVal = DotEnv().env['SMTP_PASSWORD'];
      if (envVal != null && envVal.isNotEmpty) return envVal;
    } catch (_) {}
    return null;
  }

  static bool get smtpUseTls {
    const key = String.fromEnvironment('SMTP_USE_TLS', defaultValue: 'true');
    if (key.isNotEmpty) return key.toLowerCase() == 'true';
    try {
      final envVal = DotEnv().env['SMTP_USE_TLS'];
      if (envVal != null && envVal.isNotEmpty)
        return envVal.toLowerCase() == 'true';
    } catch (_) {}
    return true;
  }

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
      if (runtime.isNotEmpty) {
        return runtime.startsWith('models/')
            ? runtime.substring('models/'.length)
            : runtime;
      }
    } catch (_) {}

    return 'gemini-1.0-pro';
  }
}
