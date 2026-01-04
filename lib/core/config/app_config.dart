/// App Configuration - Store API keys and settings here
class AppConfig {
  // Gemini API Key - Replace with your actual key
  static const String geminiApiKey = 'AIzaSyA3gAiETNFx80ni7VUZVrOarNEABBAwQuw';

  // Email SMTP Configuration - Replace with your SMTP details
  static const String smtpHost = 'smtp.gmail.com';
  static const int smtpPort = 587;
  static const String smtpUsername = 'yojanasuchak@gmail.com';
  static const String smtpPassword = 'igof lbth reel pyfa';
  static const bool useTls = true;

  // Check if Gemini is configured
  static bool get isGeminiConfigured =>
      geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';

  // Check if Email is configured
  static bool get isEmailConfigured =>
      smtpUsername != 'YOUR_EMAIL@gmail.com' &&
      smtpPassword != 'YOUR_APP_PASSWORD';
}


