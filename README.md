# MahaVoice Scheme Assistant

A Flutter application that uses voice interaction and Google Gemini AI to recommend the best government schemes from a dataset of 200 Maharashtra schemes.

## Features

- 🎤 **Voice Interaction**: Natural voice-based conversation to collect user profile
- 🤖 **AI-Powered Recommendations**: Uses Google Gemini API for intelligent scheme matching
- 📊 **200+ Schemes**: Comprehensive database of Maharashtra government schemes
- 🎯 **Smart Filtering**: Hybrid filtering (rule-based + AI) for optimal performance
- 🔊 **Text-to-Speech**: AI voice feedback for better user experience

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Google Gemini API Key ([Get it here](https://makersuite.google.com/app/apikey))

## Setup Instructions

1. **Clone or download the project**

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Add your Gemini API Key:**
   - Open `lib/ui/home_screen.dart`
   - Find the line: `const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';`
   - Replace `YOUR_GEMINI_API_KEY_HERE` with your actual API key

4. **Run on Chrome:**
   ```bash
   flutter run -d chrome
   ```

## Building APK for Android

### Quick Build (Debug APK for Testing):
```bash
flutter build apk --debug
```
APK location: `build/app/outputs/flutter-apk/app-debug.apk`

### Build Release APK:
```bash
flutter build apk --release
```
APK location: `build/app/outputs/flutter-apk/app-release.apk`

**For detailed APK build instructions including signing configuration, see:**
- [QUICK_BUILD_APK.md](QUICK_BUILD_APK.md) - Quick reference
- [BUILD_APK.md](BUILD_APK.md) - Complete guide with signing setup

### What's Configured:
- ✅ Android permissions (microphone, internet)
- ✅ Minimum SDK 21 (Android 5.0+)
- ✅ App name and icon
- ✅ ProGuard rules for code obfuscation
- ✅ Build configuration files

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── scheme.dart          # Scheme data model
│   ├── user_profile.dart    # User profile model
│   └── conversation_state.dart  # Conversation state enum
├── services/
│   ├── speech_service.dart  # Speech-to-text service
│   ├── tts_service.dart     # Text-to-speech service
│   ├── gemini_service.dart   # Gemini API integration
│   ├── eligibility_filter.dart  # Rule-based filtering
│   ├── profile_extractor.dart   # Extract profile from voice
│   └── data_service.dart     # Load schemes from JSON
└── ui/
    └── home_screen.dart      # Main UI screen
```

## How It Works

1. **Greeting**: App greets the user and explains the process
2. **Profile Collection**: Asks questions via voice:
   - Age
   - District (Maharashtra)
   - Annual Income
   - Category (student, farmer, woman, senior citizen, unemployed, general)
3. **Filtering**: Applies rule-based filtering to reduce dataset size
4. **AI Analysis**: Sends filtered schemes + user profile to Gemini
5. **Recommendations**: Displays top 3 schemes with explanations

## Conversation Flow

The app uses a state machine to guide the conversation:
- `GREETING` → `ASK_AGE` → `ASK_DISTRICT` → `ASK_INCOME` → `ASK_CATEGORY` → `SEND_TO_GEMINI` → `RESULT`

## Technologies Used

- **Flutter**: UI framework
- **speech_to_text**: Voice recognition
- **flutter_tts**: Text-to-speech
- **google_generative_ai**: Gemini API integration
- **Local JSON**: Scheme dataset

## Notes

- The app requires microphone permissions for voice input
- Chrome browser supports speech recognition
- Ensure you have a stable internet connection for Gemini API calls
- The app works offline for basic filtering, but requires internet for AI recommendations

## Troubleshooting

1. **Speech recognition not working**: Check browser permissions for microphone
2. **Gemini API errors**: Verify your API key is correct and has quota
3. **Schemes not loading**: Ensure `assets/data/maharashtra_schemes.json` exists

## License

This project is created for educational/hackathon purposes.

