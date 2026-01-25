# Firebase Setup Instructions

## Prerequisites
1. Firebase account (https://firebase.google.com)
2. FlutterFire CLI installed: `dart pub global activate flutterfire_cli`

## Setup Steps

1. **Create Firebase Project:**
   - Go to https://console.firebase.google.com
   - Click "Add project"
   - Enter project name: "YojanaSuchak"
   - Follow the setup wizard

2. **Add Android App:**
   - In Firebase Console, click "Add app" > Android
   - Package name: `com.example.mahavoice_scheme_assistant`
   - Download `google-services.json`
   - Place it in `android/app/`

3. **Add Web App (for Chrome):**
   - In Firebase Console, click "Add app" > Web
   - Copy the Firebase config
   - Create `lib/firebase_options.dart` using FlutterFire CLI

4. **Enable Authentication:**
   - Go to Authentication > Sign-in method
   - Enable "Email/Password" provider

5. **Configure FlutterFire:**
   ```bash
   flutterfire configure
   ```
   This will automatically:
   - Generate `firebase_options.dart`
   - Configure Android and Web

6. **Update main.dart:**
   - Uncomment Firebase initialization code
   - Import `firebase_options.dart`

## After Setup

The app will automatically:
- Handle user authentication
- Store user profiles
- Save favorite schemes (when implemented)

## Note

The app will work without Firebase for basic functionality, but authentication and data persistence require Firebase setup.










