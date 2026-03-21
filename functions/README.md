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

---

## LLM / Gemini configuration (optional, server-side)

The function `getGeminiResponse` supports calling a server-side LLM to generate a single short follow-up question. You can enable this with either Google Generative API (Gemini) or OpenAI.

Set config via `firebase functions:config:set` (do not commit secrets):

- Google Generative (Gemini/PaLM):
```bash
firebase functions:config:set gemini.key="YOUR_GOOGLE_API_KEY" gemini.provider="google" gemini.model="text-bison-001"
```
- OpenAI (if you prefer OpenAI models):
```bash
firebase functions:config:set gemini.key="sk-..." gemini.provider="openai" gemini.model="gpt-4o-mini"
```

Notes:
- When `gemini.key` is not set, `getGeminiResponse` uses a deterministic local fallback to keep behavior stable for development/testing.
- For Google Generative API, ensure the API key has access to the Generative Language API (or use service account credentials if deploying within a GCP project with appropriate IAM roles).
- To test locally use the Firebase Emulator and a `.env` file with `GEMINI_API_KEY` (for local key) and `GEMINI_PROVIDER` if desired.

---

## New: Gemini callables for structured chat flow

We added three new callables to support the structured initial/follow-up flow (mirrors the Python scripts in the repo):

1. `geminiInitialProfile` (callable)
- Purpose: Extract a structured profile from a free-form user statement, evaluate eligibility for provided schemes, and return a single short follow-up question if needed.
- Input (callable data): `{ callSid, userText, language, schemes }`
- Returns: `{ profile, additional_attributes, eligible_schemes, schemes_needing_more_info, followup_question }` (strict JSON shape)

2. `geminiUpdateProfile` (callable)
- Purpose: Given an existing profile + a follow-up answer, update the profile, finalize eligibility when possible, and return any new follow-up or final eligible schemes.
- Input (callable data): `{ callSid, followupText, language, schemes, existing_profile, existing_additional_attributes }`
- Returns: `{ updated_profile, updated_additional_attributes, final_eligible_schemes, still_missing_fields, followup_question }`

3. `geminiGenerateSchemeDetails` (callable)
- Purpose: Produce a concise, spoken-friendly explanation of a scheme (Who can apply, key benefits, required documents, where to apply).
- Input (callable data): `{ scheme, language }`
- Returns: `{ text }` (plain text)

Usage example (client-side callable):
```js
const initial = await firebase.app().functions('your-region').httpsCallable('geminiInitialProfile')({ callSid: 'abc', userText: 'I am a 45 year old farmer', language: 'en', schemes: [...] });
console.log(initial.data.followup_question);
```

Notes:
- If no `gemini.key` is set, these callables will return a conservative fallback (minimally useful JSON / deterministic followups) so the client can continue working offline or in dev mode.
- Be careful: model output is parsed as JSON; if the model fails to emit valid JSON we fall back to a minimal safe response.
- For production, set `gemini.key` in functions config and deploy.

---


