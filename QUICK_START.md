# Quick Start Guide

## Prerequisites
- Flutter SDK installed
- Google Gemini API Key

## Steps to Run on Chrome

1. **Get your Gemini API Key:**
   - Visit: https://makersuite.google.com/app/apikey
   - Create a new API key
   - Copy the key

2. **Add API Key to the app:**
   - Open: `lib/ui/home_screen.dart`
   - Find line 71: `const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';`
   - Replace with your actual key

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run on Chrome:**
   ```bash
   flutter run -d chrome
   ```

## First Run

1. When the app opens, allow microphone permissions when prompted
2. Click the microphone button to start
3. Follow the voice prompts to provide:
   - Your age
   - Your district in Maharashtra
   - Your annual income
   - Your category (student, farmer, woman, etc.)
4. Wait for AI analysis
5. View your top 3 recommended schemes!

## Troubleshooting

- **Microphone not working**: Check browser permissions (Chrome Settings > Privacy > Site Settings > Microphone)
- **API errors**: Verify your Gemini API key is correct
- **No schemes loading**: Ensure `assets/data/maharashtra_schemes.json` exists

## Note

The app will work with fallback recommendations even without Gemini API key, but AI-powered recommendations require a valid key.






