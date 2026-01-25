/// App Configuration - Store API keys and settings here
class AppConfig {
  // Gemini API Key - Replace with your actual key
  static const String geminiApiKey = 'AIzaSyDqZJ3zsYDTR7Gvr_X3bNWefidrc1pA8Q8';

  // Email SMTP Configuration - Replace with your SMTP details
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;
  static const String smtpUsername = 'yojanasuchak@gmail.com';
  static const String smtpPassword = 'khon jioy lole cuwz';
  static const bool useTls = true;

  // Check if Gemini is configured
  static bool get isGeminiConfigured =>
      geminiApiKey.isNotEmpty && !geminiApiKey.contains('YOUR_GEMINI');

  // Check if Email is configured
  static bool get isEmailConfigured =>
      smtpUsername != 'yojanasuchak@gmail.com' &&
      smtpPassword != 'khon jioy lole cuwz';

  // Admin Password for scheme upload access
  // IMPORTANT: In production, use environment variables or secure storage
  // This is stored here for simplicity but should be moved to secure storage
  static const String adminPassword = 'yojanasuchak@791317';
}
