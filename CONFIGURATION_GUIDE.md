# Configuration Guide - YojanaSuchak

## Required Configurations

### Gemini API Key



```dart
static const String geminiApiKey = 'AIzaSyA3gAiETNFx80ni7VUZVrOarNEABBAwQuw';
```

###Email SMTP Configuration

**Location**: `lib/core/config/app_config.dart`

**Steps**:
1. Enable 2-Step Verification on your Google account
2. Generate an App Password:
   - Go to: https://myaccount.google.com/apppasswords
   - Select "Mail" and "Other (Custom name)"
   - Enter "YojanaSuchak"
   - Copy the 16-character password
3. Open `lib/core/config/app_config.dart`
4. Update the email configuration:

```dart
static const String smtpHost = 'smtp.gmail.com';
static const int smtpPort = 587;
static const String smtpUsername = 'your-email@gmail.com';
static const String smtpPassword = 'your-16-char-app-password';
static const bool useTls = true;
```

### 3. Firestore Setup

**Steps**:
1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project: `yojana-suchak-backend`
3. Go to **Firestore Database**
4. Create a collection named `schemes`
5. Add documents with the following structure:

```json
{
  "schemeName": "Scheme Name",
  "department": "Department Name",
  "targetGroup": "Target Group",
  "eligibility": "Eligibility criteria",
  "benefits": "Benefits description",
  "requiredDocuments": ["Document 1", "Document 2"],
  "incomeLimit": 500000,
  "ageLimit": 18,
  "category": "student"
}
```

**Note**: The app will automatically fetch schemes from Firestore. If Firestore is empty or fails, it will fall back to the local JSON file.

## Features Enabled After Configuration

### With Gemini API Key:
- ✅ Intelligent chat responses
- ✅ Context-aware conversations
- ✅ Smart scheme recommendations
- ✅ Follow-up question handling

### With Email Configuration:
- ✅ Send scheme details via email
- ✅ Professional HTML email templates
- ✅ Automatic email to user's registered email

### With Firestore:
- ✅ Real-time scheme updates
- ✅ No need to update app for new schemes
- ✅ Centralized scheme management

## Testing

After configuration:
1. Run the app
2. Go to "Find Scheme"
3. Try both voice and text chat
4. Complete the profile questions
5. Get recommendations
6. Request scheme details
7. Test email functionality

## Troubleshooting

**Gemini not working?**
- Check API key is correct
- Verify API key has quota remaining
- Check internet connection

**Email not sending?**
- Verify App Password is correct (not regular password)
- Check 2-Step Verification is enabled
- Ensure SMTP settings are correct

**Firestore not loading?**
- Check Firestore rules allow read access
- Verify collection name is "schemes"
- Check internet connection
- App will fallback to local JSON if Firestore fails



