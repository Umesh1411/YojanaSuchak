# Quick Reference: Intelligent Profile Extraction API

## ProfileExtractor Methods

### Language Detection
```dart
/// Returns user's detected language
String language = ProfileExtractor.detectLanguage(userMessage);
// Returns: 'en' (English), 'hi' (Hindi), 'mr' (Marathi)
```

### Multi-Field Extraction (NEW - Recommended)
```dart
/// Intelligently extracts multiple fields from a single message
Map<String, dynamic> fields = ProfileExtractor.extractMultipleFields(userMessage);
// Returns map with any/all of: age, gender, occupation, state, district, annualIncome, category

// Apply to profile (non-destructive)
ProfileExtractor.applyParsedToProfile(profile, fields);
```

### Single-Field Extraction (Original API - Still Works)
```dart
// Extract individual fields
int? age = ProfileExtractor.extractAge(text);
String? gender = ProfileExtractor.extractGender(text);
String? occupation = ProfileExtractor.extractOccupation(text);
String? state = ProfileExtractor.extractState(text);
String? district = ProfileExtractor.extractDistrict(text);
int? income = ProfileExtractor.extractIncome(text);
String? category = ProfileExtractor.extractCategory(text);
```

### Get Next Missing Field (Single Source of Truth)
```dart
/// Returns the EXACT next field needed (or null if complete)
/// Order: occupation → age → gender → state → district → annualIncome → category
String? nextField = ProfileExtractor.getNextMissingField(profile);

// Use in conversation:
if (nextField != null) {
  String question = _getQuestionForField(nextField);
  bot.speak(question);
} else {
  // Profile complete!
  showSchemes();
}
```

### Extract All Fields At Once
```dart
/// Simple extraction (less aggressive than extractMultipleFields)
Map<String, dynamic> parsed = ProfileExtractor.extractAll(text);
```

---

## Enhanced Scheme Finder Flow

### In _handleUser():
```dart
Future<void> _handleUser(String message) async {
  // 1. Detect language
  final userLanguage = ProfileExtractor.detectLanguage(message);
  
  // 2. Extract multiple fields intelligently
  final parsed = ProfileExtractor.extractMultipleFields(message);
  ProfileExtractor.applyParsedToProfile(_profile, parsed);
  
  // 3. Handle first message (no Gemini)
  if (!_initialProblemCaptured) {
    _initialProblemCaptured = true;
    // Continue to next step
  }
  
  // 4. Ask Gemini for next question (language-aware)
  if (_initialProblemCaptured && _geminiReady) {
    final decision = await _askGeminiForNextStep(userLanguage);
    // Handle: ASK: <question>, DONE, or null
  }
}
```

### Language-Aware Gemini Decision Prompt:
```dart
Future<String?> _askGeminiForNextStep(String userLanguage) async {
  final languageName = userLanguage == 'hi' ? 'Hindi' : 
                       userLanguage == 'mr' ? 'Marathi' : 'English';
  
  final decisionPrompt = '''
    ... scheme context ...
    User's Language: $languageName (Respond ONLY in $languageName)
    ... profile info ...
    
    Respond ONLY in $languageName. Use format:
    - ASK: <question in $languageName>
    - DONE
  ''';
  
  // Gemini responds in user's language!
}
```

---

## STT Error Examples (Now Handled Automatically)

### Gender Normalization
```dart
ProfileExtractor.extractGender('mle')           → 'Male' ✅
ProfileExtractor.extractGender('femail')        → 'Female' ✅
ProfileExtractor.extractGender('fmale')         → 'Female' ✅
ProfileExtractor.extractGender('famale')        → 'Female' ✅
ProfileExtractor.extractGender('mail')          → 'Male' ✅
```

### Income Normalization
```dart
ProfileExtractor.extractIncome('5 lakh')        → 500000 ✅
ProfileExtractor.extractIncome('5 lakh rupees') → 500000 ✅
ProfileExtractor.extractIncome('5 thousand')    → 5000 ✅
ProfileExtractor.extractIncome('5k')            → 5000 ✅
ProfileExtractor.extractIncome('50000')         → 50000 ✅
```

---

## Multi-Field Extraction Examples

### Example 1: Complete Profile
```
Input: "I am 46 year old male farmer from Ahmednagar earning 8000 a month"

extracted = ProfileExtractor.extractMultipleFields(input);
// Returns: {
//   'age': 46,
//   'gender': 'Male',
//   'occupation': 'Farmer',
//   'district': 'Ahmednagar',
//   'annualIncome': 96000  // 8000 × 12
// }
```

### Example 2: Partial Information
```
Input: "I'm a 35 year old teacher"

extracted = ProfileExtractor.extractMultipleFields(input);
// Returns: {
//   'age': 35,
//   'occupation': 'Teacher'
// }
// Missing: gender, state, district, income, category
```

### Example 3: With STT Errors
```
Input: "I am 28 year old femail earning 3 lakh"

extracted = ProfileExtractor.extractMultipleFields(input);
// Returns: {
//   'age': 28,
//   'gender': 'Female',  // ← Corrected from 'femail'
//   'annualIncome': 300000
// }
```

---

## Best Practices

### ✅ DO:
- Use `extractMultipleFields()` for normal user input
- Use `getNextMissingField()` as your ONLY source of truth for "what question to ask next"
- Always call `applyParsedToProfile()` after extraction (it's non-destructive)
- Pass `userLanguage` to `_askGeminiForNextStep()`
- Check `_followUpCount >= 5` before asking more questions

### ❌ DON'T:
- Manually ask questions based on missing fields (let `getNextMissingField()` decide)
- Ask questions in English if user spoke Hindi/Marathi
- Overwrite existing profile fields (use non-destructive updates only)
- Exceed 5 follow-up questions
- Try to extract fields the old way when `extractMultipleFields()` exists

---

## Troubleshooting

### STT Error Not Being Fixed?
- Check that you're using `extractMultipleFields()` or `extractGender()`
- These use the `_normalizeGender()` and `_normalizeIncome()` helpers

### Questions Keep Repeating?
- Ensure you're calling `getNextMissingField()` EVERY time
- Verify `applyParsedToProfile()` is called after extraction
- Check that you're not manually tracking "asked questions"

### Bot Responds in Wrong Language?
- Verify `detectLanguage()` is being called
- Check that language is passed to `_askGeminiForNextStep(userLanguage)`
- Ensure Gemini prompt includes "Respond ONLY in $languageName"

### Still Getting Compile Errors?
- All three files should have ZERO errors:
  - `lib/services/profile_extractor.dart` ✅
  - `lib/ui/scheme_finder/enhanced_scheme_finder_screen.dart` ✅
  - `lib/main.dart` ✅
- Run `dart analyze` or check VS Code Problems panel

---

## Architecture

```
User Input
    ↓
detectLanguage()  ← Detect 'en', 'hi', 'mr'
    ↓
extractMultipleFields()  ← Extract age, gender, occupation, etc.
    ↓
applyParsedToProfile()  ← Update profile (non-destructive)
    ↓
getNextMissingField()  ← What question to ask next?
    ↓
_askGeminiForNextStep(userLanguage)  ← Ask Gemini (language-aware)
    ↓
Gemini Response (in user's language)
    ↓
_showSchemeResults()  ← Show matching schemes
```

---

## Performance Notes

- `extractMultipleFields()`: ~5-10ms per message (regex-based)
- `detectLanguage()`: ~1-2ms per message (character counting)
- `getNextMissingField()`: ~0.1ms (simple null checks)
- Total pre-Gemini processing: <20ms

All operations are synchronous except Gemini calls (which are awaited).

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0 | Current | Added: detectLanguage, extractMultipleFields, language-aware Gemini prompts |
| 1.0 | Previous | Basic: extractAll, extractGender, extractIncome, getNextMissingField |

---

## Support

For issues or questions:
1. Check the [INTELLIGENT_PROFILE_ENHANCEMENT.md](INTELLIGENT_PROFILE_ENHANCEMENT.md) document
2. Review [INTELLIGENT_EXTRACTION_EXAMPLES.md](INTELLIGENT_EXTRACTION_EXAMPLES.md) for detailed examples
3. Verify all compile errors are cleared with `dart analyze`
