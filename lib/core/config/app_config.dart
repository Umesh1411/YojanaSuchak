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
  static bool get isGeminiConfigured =>
      _geminiApiKey != null && _geminiApiKey!.isNotEmpty;

  // Email SMTP Configuration
  static String? _smtpHost;
  static int? _smtpPort;
  static String? _smtpUsername;
  static String? _smtpPassword;
  static bool? _smtpSecure;

  static void setSmtpConfig({
    required String host,
    required int port,
    required String username,
    required String password,
    required bool secure,
  }) {
    _smtpHost = host;
    _smtpPort = port;
    _smtpUsername = username;
    _smtpPassword = password;
    _smtpSecure = secure;
  }

  static String get smtpHost => _smtpHost ?? '';
  static int get smtpPort => _smtpPort ?? 587;
  static String get smtpUsername => _smtpUsername ?? '';
  static String get smtpPassword => _smtpPassword ?? '';
  static bool get useTls => _smtpSecure ?? true;

  // Check if Email is configured
  static bool get isEmailConfigured =>
      smtpUsername.isNotEmpty && smtpPassword.isNotEmpty;

  // Admin password (for local/dev use only)
  static String? _adminPassword;
  static void setAdminPassword(String password) {
    _adminPassword = password;
  }

  static String get adminPassword => _adminPassword ?? '';
  static bool get isAdminConfigured => adminPassword.isNotEmpty;
}
