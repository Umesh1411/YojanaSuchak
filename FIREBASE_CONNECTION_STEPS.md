# Firebase Connection Steps - Quick Guide

## What You Need from Firebase Console

To connect your app to your Firebase project, you need:

### 1. For Android App:
- **File**: `google-services.json`
- **Location**: Download from Firebase Console → Project Settings → Your Android App
- **Place in**: `android/app/google-services.json`

### 2. For Web App:
- **Firebase Config Object** (contains apiKey, authDomain, projectId, etc.)
- **Location**: Firebase Console → Project Settings → Your Web App → Config
- **Will be used to**: Generate `lib/firebase_options.dart`

## Step-by-Step Instructions

### Step 1: Get Android Configuration

1. Go to https://console.firebase.google.com
2. Select your Firebase project
3. Click the **⚙️ Settings icon** → **Project settings**
4. Scroll down to **"Your apps"** section
5. If you don't have an Android app yet:
   - Click **"Add app"** → Select **Android**
   - **Package name**: `com.example.mahavoice_scheme_assistant` (from android/app/build.gradle.kts)
   - **App nickname**: YojanaSuchak (optional)
   - Click **Register app**
6. Download `google-services.json`
7. **Place it in**: `android/app/google-services.json`

### Step 2: Get Web Configuration

1. In the same Firebase Console → Project Settings
2. Click **"Add app"** → Select **Web** (if not already added)
3. Register your web app
4. Copy the **Firebase configuration object** (it looks like this):

```javascript
const firebaseConfig = {
  apiKey: "AIza...",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef"
};
```

### Step 3: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### Step 4: Configure FlutterFire

Run this command in your project root:

```bash
flutterfire configure
```

This will:
- Ask you to select your Firebase project
- Generate `lib/firebase_options.dart` automatically
- Configure both Android and Web

### Step 5: Update main.dart

After `flutterfire configure`, uncomment Firebase initialization in `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const YojanaSuchakApp());
}
```

### Step 6: Enable Authentication

1. In Firebase Console → **Authentication**
2. Click **Get started**
3. Go to **Sign-in method** tab
4. Enable **Email/Password** provider
5. Click **Save**

### Step 7: Update Android build.gradle

Make sure `android/app/build.gradle.kts` includes the Google Services plugin:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Add this
}
```

And in `android/build.gradle.kts`:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0") // Add this
    }
}
```

## Quick Checklist

- [ ] Firebase project created
- [ ] Android app added to Firebase project
- [ ] `google-services.json` downloaded and placed in `android/app/`
- [ ] Web app added to Firebase project
- [ ] FlutterFire CLI installed
- [ ] `flutterfire configure` run successfully
- [ ] `lib/firebase_options.dart` generated
- [ ] Firebase initialization uncommented in `main.dart`
- [ ] Email/Password authentication enabled in Firebase Console
- [ ] Google Services plugin added to build.gradle files

## After Setup

Once configured, the app will automatically use Firebase instead of demo mode. You can test by:
1. Running the app
2. Creating a new account (will be saved in Firebase)
3. Logging in with that account

## Need Help?

If you get stuck, share:
1. Your Firebase project ID
2. Any error messages
3. Which step you're on









