# Quick APK Build Guide

## Fastest Way to Build APK (Debug - For Testing)

```bash
flutter build apk --debug
```

Install on connected device:
```bash
flutter install
```

Or find the APK at: `build/app/outputs/flutter-apk/app-debug.apk`

## Build Release APK (For Distribution)

### Option 1: Without Signing (Quick Test)

```bash
flutter build apk --release
```

**Note:** This uses debug signing. For production, use Option 2.

### Option 2: With Proper Signing (Production Ready)

1. **Generate keystore** (one time):
   ```bash
   keytool -genkey -v -keystore mahavoice-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mahavoice
   ```

2. **Create `android/key.properties`**:
   ```properties
   storePassword=YOUR_PASSWORD
   keyPassword=YOUR_PASSWORD
   keyAlias=mahavoice
   storeFile=C:/path/to/mahavoice-key.jks
   ```

3. **Update `android/app/build.gradle.kts`** - Add signing config (see BUILD_APK.md for details)

4. **Build:**
   ```bash
   flutter build apk --release
   ```

## What's Already Configured

✅ **Android permissions** (microphone, internet)  
✅ **Minimum SDK** (Android 5.0+)  
✅ **App name** (MahaVoice Scheme Assistant)  
✅ **ProGuard rules** for code obfuscation  
✅ **Build configuration** files

## Common Commands

```bash
# Clean build
flutter clean && flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Build split APKs (smaller size)
flutter build apk --release --split-per-abi

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Install on device
flutter install
```

## Troubleshooting

**"Gradle sync failed"**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

**"Permission denied"**
- Check AndroidManifest.xml has microphone permission
- Grant microphone permission on device

**"Build failed"**
- Ensure Android SDK is installed
- Check Java JDK version (need 11+)
- Run `flutter doctor` to check setup

For detailed instructions, see [BUILD_APK.md](BUILD_APK.md)






