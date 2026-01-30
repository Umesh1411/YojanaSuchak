# YojanaSuchak Cloud Functions

## Overview
This directory contains Firebase Cloud Functions that automatically send email and push notifications when new schemes are added to Firestore.

## Features
- **Automatic Notifications**: Triggers when a new scheme is added to `schemes` collection
- **Email Notifications**: Sends HTML emails to subscribed users
- **Push Notifications**: Sends FCM push notifications to app users
- **Multi-language Support**: Email content in Hindi/English

## Setup Instructions

### 1. Install Dependencies
```bash
cd functions
npm install
```

### 2. Configure Firebase
```bash
# Login to Firebase
firebase login

# Initialize (if not done)
firebase init functions
```

### 3. Configure SMTP Email
You can provide SMTP credentials either via Firebase functions config (recommended for production) or via environment variables for local testing.

Production (Firebase):
```bash
# Set SMTP credentials in Firebase Functions config
firebase functions:config:set smtp.user="your-email@gmail.com" smtp.pass="your-app-password" smtp.host="smtp.gmail.com" smtp.port=587 smtp.secure=false
```

Local testing (emulator):
- Create a `.env` file inside the `functions/` folder (this file **must not** be committed to version control).
- Add the following keys to `functions/.env`:
```
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
```
- Start the emulator: `firebase emulators:start --only functions`

**Important:**
- Do **not** commit `.env` or actual secrets to the repository. The project `.gitignore` already excludes `.env`.
- For Gmail, generate an App Password (requires 2FA) and use that as `SMTP_PASS`.

The functions code will prefer `functions.config().smtp` when present, and will fall back to `process.env` values (useful when running locally).

### 4. Deploy Functions
```bash
firebase deploy --only functions
```

## User Data Structure

Users in Firestore should have this structure:
```javascript
{
  email: "user@example.com",
  fcmToken: "device-fcm-token",
  notificationsEnabled: true
}
```

## Testing

### Testing the functions
- Use the Firebase Emulators for local testing: `firebase emulators:start --only functions`.
- To test notifications or email sending, create or update real `schemes` documents (preferably in a test project) and observe the functions' behavior. Do not use open test endpoints; tests should be done via emulator or secure calls.

## Monitoring

View function logs:
```bash
firebase functions:log
```

Or in Firebase Console:
- Go to Functions → Logs

## New: Admin re-evaluation on scheme updates

- **Function**: `onSchemeCreatedOrUpdated`
- **Behavior**: When a scheme is added or updated, the function re-evaluates all users and sends localized notifications/emails only to users who become newly eligible. This avoids notifying users who were already eligible.

## Troubleshooting

### Email not sending
- Check SMTP credentials are correct
- Verify Gmail app password is used (not regular password)
- Check function logs for errors

### Push notifications not working
- Verify FCM token is stored in user document
- Check if token is valid (invalid tokens are auto-removed)
- Verify Firebase Cloud Messaging is enabled in Firebase Console

### Function not triggering
- Verify Firestore rules allow function to read `users` collection
- Check function deployment status
- Verify scheme document structure matches expected format
