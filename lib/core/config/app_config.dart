/// App Configuration - Store API keys and settings here

/// Centralized application configuration that reads from environment variables.
///
/// IMPORTANT: API keys are loaded ONCE in main.dart and stored here.
/// This class does NOT access dotenv directly.
class AppConfig {
  /// Gemini API key - loaded from .env in main.dart
  static String? _geminiApiKey;

  /// Set Gemini API key (called from main.dart during app initialization)
  static void setGeminiApiKey(String key) {
    _geminiApiKey = key;
  }

  /// Get Gemini API key safely
  /// Returns empty string if not set
  static String get geminiApiKey => _geminiApiKey ?? '';

  /// Check if Gemini is configured
  static bool get isGeminiConfigured => _geminiApiKey != null && _geminiApiKey!.isNotEmpty;

  // Email SMTP Configuration - can be extended if needed
  static String get smtpHost => 'smtp.gmail.com';
  static int get smtpPort => 587;
  static String get smtpUsername => '';
  static String get smtpPassword => '';
  static bool get useTls => true;

  // Check if Email is configured
  static bool get isEmailConfigured => smtpUsername.isNotEmpty && smtpPassword.isNotEmpty;

  // Admin password
  static String get adminPassword => '';
}
