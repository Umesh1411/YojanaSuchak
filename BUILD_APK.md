# Building APK for MahaVoice Scheme Assistant

## Prerequisites

1. **Flutter SDK** installed and configured
2. **Android Studio** (optional, but recommended)
3. **Java JDK** (version 11 or higher)
4. **Android SDK** (comes with Android Studio or can be installed separately)

## Quick Build (Debug APK)

For testing purposes, you can build a debug APK:

```bash
flutter build apk --debug
```

The APK will be generated at:
`build/app/outputs/flutter-apk/app-debug.apk`

## Build Release APK (For Distribution)

### Step 1: Generate Keystore (First Time Only)

1. **Create a keystore file:**
   ```bash
   keytool -genkey -v -keystore ~/mahavoice-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mahavoice
   ```
   
   Or on Windows:
   ```bash
   keytool -genkey -v -keystore C:\Users\YourUsername\mahavoice-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mahavoice
   ```

2. **Fill in the required information:**
   - Password (remember this!)
   - Your name and organization details
   - Keep the keystore file safe - you'll need it for updates

### Step 2: Configure Signing

1. **Create `android/key.properties` file:**
   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=mahavoice
   storeFile=C:/Users/YourUsername/mahavoice-key.jks
   ```
   
   **Important:** 
   - Replace paths with your actual keystore path
   - Replace passwords with your actual passwords
   - **DO NOT commit this file to Git** (it's already in .gitignore)

2. **Update `android/app/build.gradle.kts`:**

   Add this at the top of the file (after the plugins block):
   ```kotlin
   // Load keystore properties
   val keystorePropertiesFile = rootProject.file("key.properties")
   val keystoreProperties = java.util.Properties()
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
   }
   ```

   Then update the `android` block to include signing config:
   ```kotlin
   android {
       // ... existing code ...
       
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
               storeFile = file(keystoreProperties["storeFile"] as String)
               storePassword = keystoreProperties["storePassword"] as String
           }
       }
       
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")
               // Optional: Enable code shrinking and obfuscation
               isMinifyEnabled = true
               proguardFiles(
                   getDefaultProguardFile("proguard-android-optimize.txt"),
                   "proguard-rules.pro"
               )
           }
       }
   }
   ```

### Step 3: Build Release APK

```bash
flutter build apk --release
```

The APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

### Step 4: Build App Bundle (For Google Play Store)

For Google Play Store, build an App Bundle instead:

```bash
flutter build appbundle --release
```

The AAB file will be at:
`build/app/outputs/bundle/release/app-release.aab`

## Build Split APKs (By Architecture)

To reduce APK size, you can build separate APKs for different architectures:

```bash
flutter build apk --split-per-abi
```

This creates:
- `app-armeabi-v7a-release.apk` (32-bit)
- `app-arm64-v8a-release.apk` (64-bit)
- `app-x86_64-release.apk` (x86_64)

## Install APK on Device

### Using ADB (Android Debug Bridge):

```bash
flutter install
```

Or manually:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Direct Installation:

1. Transfer the APK file to your Android device
2. Enable "Install from Unknown Sources" in device settings
3. Open the APK file and install

## Troubleshooting

### Error: "minSdkVersion is too low"
- The app requires minimum Android 5.0 (API 21)
- This is already configured in `build.gradle.kts`

### Error: "Keystore file not found"
- Check the path in `key.properties`
- Use absolute paths or paths relative to the `android` folder

### Error: "Signing config not found"
- Make sure you've updated `build.gradle.kts` with signing configuration
- Verify `key.properties` exists and has correct values

### Build Fails with Gradle Errors
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

## APK Size Optimization

The release APK is optimized by default. To further reduce size:

1. **Remove unused resources:**
   ```bash
   flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
   ```

2. **Enable code shrinking** (already in build.gradle.kts if configured)

## Testing the APK

Before distributing:

1. **Test on multiple devices** with different Android versions
2. **Test all features:**
   - Voice recognition
   - Text-to-speech
   - Gemini API calls
   - Scheme loading
3. **Check permissions** are requested properly

## Distribution

### Google Play Store:
- Build App Bundle (AAB) format
- Follow Google Play policies
- Add screenshots, descriptions, and privacy policy

### Direct Distribution:
- Share the APK file
- Users need to enable "Install from Unknown Sources"
- Consider using a file hosting service

## Notes

- **Debug APK**: Larger size, includes debug symbols, not optimized
- **Release APK**: Optimized, smaller size, ready for distribution
- **Keystore**: Keep it safe! You need it for app updates
- **Version**: Update `versionCode` and `versionName` in `pubspec.yaml` for each release










