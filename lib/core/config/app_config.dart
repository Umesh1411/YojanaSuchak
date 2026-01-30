/// App Configuration - Feature flags and settings only
/// IMPORTANT: No secrets or API keys should be stored here.
/// In production, API keys must be injected via backend or secure runtime configuration.
/// For development, use environment variables or secure storage.
class AppConfig {
  // Feature flags
  static const bool enableVoiceMode = true;
  static const bool enableOfflineMode = false;

  // Placeholder for Gemini API key - MUST be injected at runtime
  // In production: Obtain from backend service or secure storage
  // static String? geminiApiKey; // Set at app startup from secure source

  // Placeholder for email configuration - MUST be injected at runtime
  // static String? smtpHost;
  // static String? smtpUsername;
  // static String? smtpPassword;

  // Check if Gemini is configured (runtime check)
  static bool get isGeminiConfigured =>
      false; // Always false in this config, check runtime

  // Check if Email is configured (runtime check)
  static bool get isEmailConfigured =>
      false; // Always false in this config, check runtime
}
