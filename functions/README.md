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
```bash
# Set SMTP credentials
firebase functions:config:set smtp.user="your-email@gmail.com"
firebase functions:config:set smtp.pass="your-app-password"
```

**Note**: For Gmail, you need to:
1. Enable 2-factor authentication
2. Generate an "App Password" (not your regular password)
3. Use that app password in the config

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

### Test via HTTP Endpoint
```bash
curl -X POST https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/sendTestNotification
```

### Test via Firebase Console
1. Go to Firestore Console
2. Add a new document to `schemes` collection
3. Function will automatically trigger

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
