# YojanaSuchak

A Flutter application that uses voice interaction and Google Gemini AI to recommend the best government schemes from a comprehensive database of Maharashtra schemes.

## Features

- 🎤 **Voice Interaction**: Natural voice-based conversation to collect user profile
- 🤖 **AI-Powered Recommendations**: Uses Google Gemini API for intelligent scheme matching
- 📊 **200+ Schemes**: Comprehensive database of Maharashtra government schemes
- 🎯 **Smart Filtering**: Hybrid filtering (rule-based + AI) for optimal performance
- 🔊 **Text-to-Speech**: AI voice feedback for better user experience
- 🔐 **Firebase Integration**: User authentication and data persistence
- 📧 **Email Notifications**: Send scheme details via email

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Google Gemini API Key ([Get it here](https://makersuite.google.com/app/apikey))
- Firebase project (optional, for authentication and data storage)

## Quick Start

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure API Keys:**
   - Open `lib/core/config/app_config.dart`
   - Add your Gemini API key: `geminiApiKey`
   - Configure email SMTP settings (optional)

3. **Run the app:**
   ```bash
   flutter run
   ```

For detailed setup instructions, see [CONFIGURATION_GUIDE.md](CONFIGURATION_GUIDE.md)

## Building APK

See [QUICK_BUILD_APK.md](QUICK_BUILD_APK.md) for quick build instructions or [BUILD_APK.md](BUILD_APK.md) for complete guide with signing.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── config/
│   │   └── app_config.dart   # API keys and configuration
│   └── services/            # Core services
├── models/                   # Data models
├── services/                 # Business logic services
└── ui/                       # UI screens
```

## Configuration

All API keys and configuration are centralized in `lib/core/config/app_config.dart`:
- Gemini API Key
- Email SMTP Settings
- Admin Password

## License

This project is created for educational/hackathon purposes.
