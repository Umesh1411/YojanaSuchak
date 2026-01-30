# Intelligent Profile Extraction Examples

## STT Error Normalization

### Gender Normalization
- Input: "mle" → Output: "Male" ✅
- Input: "femail" → Output: "Female" ✅
- Input: "mail" → Output: "Male" ✅
- Input: "fmale" → Output: "Female" ✅
- Input: "famale" → Output: "Female" ✅

### Income Normalization
- Input: "5 lakh" → Output: 500,000 ✅
- Input: "5 lakh rupees" → Output: 500,000 ✅
- Input: "5 thousand" → Output: 5,000 ✅
- Input: "5k" → Output: 5,000 ✅
- Input: "50000" → Output: 50,000 ✅

## Multi-Field Extraction (New!)

### Example 1: Complete Profile in One Message
```
User: "I am 46 year old male farmer from Ahmednagar earning 8000 a month"

Extracted Fields:
- Age: 46 ✅
- Gender: Male ✅
- Occupation: Farmer ✅
- State: (inferred from Ahmednagar) Maharashtra
- District: Ahmednagar ✅
- Annual Income: ~96,000 (8000 × 12) ✅
```

### Example 2: Multiple Fields with STT Errors
```
User: "I'm a 35 year old femail teacher in Pune with salary 3 lakh"

Extracted Fields:
- Age: 35 ✅
- Gender: Female ✅ (corrected from "femail")
- Occupation: Teacher ✅
- State: Maharashtra (inferred from Pune)
- District: Pune ✅
- Annual Income: 300,000 ✅
```

### Example 3: Partial Information
```
User: "Namaste, main ek 28 saal ka ladka hoon"  
(Hindi: "Hello, I am a 28 year old boy")

Detected Language: Hindi ✅
Extracted Fields:
- Age: 28 ✅
- Gender: Male ✅
- [Awaiting occupatio occupation, state, etc.]
```

## Language Detection

### Supported Languages
- **English**: "I am a farmer from Maharashtra"
- **Hindi (Devanagari)**: "मैं महाराष्ट्र से एक किसान हूँ"
- **Marathi (Devanagari)**: "मी महाराष्ट्र मधून शेतकरी आहे"

### How It Works
1. Scans input for Devanagari characters (used in both Hindi and Marathi)
2. If >30% Devanagari → Assumes Hindi (more common)
3. Otherwise → Assumes English
4. Language is passed to Gemini for language-aware responses

## Smart Question Selection (Language-Aware)

### English Conversation
```
Bot: "Tell me about your situation or problem. I'll find schemes for you."
User: "I'm a 46 year old farmer from Ahmednagar earning 8000 a month"
Bot: "What's your caste/category? (SC/ST/OBC/General)"
```

### Hindi Conversation
```
Bot: "अपनी स्थिति या समस्या के बारे में बताएं। मैं आपके लिए योजनाएं खोजूंगा।"
User: "मैं अहमदनगर से 46 साल का किसान हूँ और 8000 रुपये कमाता हूँ"
Bot: "आपकी जाति/श्रेणी क्या है? (SC/ST/OBC/General)"
```

### Marathi Conversation
```
Bot: "आपल्या परिस्थिती किंवा समस्येबद्दल सांगा। मी तुमच्यासाठी योजना शोधून देईन।"
User: "मी अहमदनगर मधून 46 वर्षांचा शेतकरी आहे आणि 8000 रुपये कमवतो"
Bot: "तुमची जाती/श्रेणी काय आहे? (SC/ST/OBC/General)"
```

## Code Integration

### In `profile_extractor.dart`:

```dart
// Detect language
String userLanguage = ProfileExtractor.detectLanguage(userMessage);
// Returns: 'en', 'hi', or 'mr'

// Extract multiple fields intelligently
Map<String, dynamic> parsed = ProfileExtractor.extractMultipleFields(userMessage);
// Returns: {
//   'age': 46,
//   'gender': 'Male',
//   'occupation': 'Farmer',
//   'district': 'Ahmednagar',
//   'annualIncome': 96000
// }

// Apply to profile (non-destructive)
ProfileExtractor.applyParsedToProfile(profile, parsed);

// Get next missing field
String? nextField = ProfileExtractor.getNextMissingField(profile);
// Returns: 'state', 'category', etc. (never a field already set)
```

### In `enhanced_scheme_finder_screen.dart`:

```dart
// Inside _handleUser():
final userLanguage = ProfileExtractor.detectLanguage(message);
final parsed = ProfileExtractor.extractMultipleFields(message);

// Language is passed to Gemini decision maker:
final geminiDecision = await _askGeminiForNextStep(userLanguage);

// Gemini responds in the user's language:
// English: "ASK: What is your caste category?"
// Hindi: "ASK: आपकी जाति श्रेणी क्या है?"
// Marathi: "ASK: तुमची जाती श्रेणी काय आहे?"
```

## Benefits

✅ **STT Error Resilience**: Handles common speech-to-text errors automatically
✅ **Faster Profile Building**: Multi-field extraction reduces follow-up questions
✅ **Language Awareness**: Gemini responds in user's detected language
✅ **Non-Destructive**: Never overwrites existing profile data
✅ **Single Source of Truth**: `getNextMissingField()` guarantees no re-asking
✅ **Hard Limit Protection**: Max 5 follow-up questions, then force results
✅ **Graceful Degradation**: Works without Gemini (filtering-only mode)
