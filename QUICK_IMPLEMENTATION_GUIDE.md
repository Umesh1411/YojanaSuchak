# Quick Implementation Guide - Intelligent Questioning

## What Changed

### High-Level Flow
```
User Message
    ↓
Lock Session Language (first message only)
    ↓
Extract Profile Fields (multi-field support)
    ↓
Mark Asked Questions
    ↓
First Message? → No Gemini
    ↓
Filter Schemes STRICTLY (new: maxAge, gender checks)
    ↓
Compute Required Fields (DB-driven from schemes)
    ↓
Find Missing Required Fields (not asked, not filled)
    ↓
Stop? (no missing, or soft-limit reached)
    ├─ YES → Show Schemes
    └─ NO → Ask Gemini for Question
        ↓
        Gemini generates question about ONLY missing required fields
        ↓
        Respond in Session Language
        ↓
        Return "ASK: <question>" or "DONE"
```

---

## For Developers: Key Methods

### Session State (NEW)
```dart
String? _sessionLanguage;           // Locked at first message
final Set<String> _askedQuestions = {}; // Track all asked
Set<String> _requiredFields = {};   // From schemes
```

### Computation Methods (NEW)
```dart
Set<String> _computeRequiredFields(List<Scheme> schemes)
  → Returns fields required by ANY matching scheme

bool _isFieldFilled(String field)
  → Check if user provided this field

List<Scheme> _filterSchemes()
  → Enhanced with maxAge + gender checks + logging

Future<String?> _askGeminiForNextStep(
  String sessionLanguage,
  Set<String> missingFields,
  List<Scheme> candidateSchemes,
)
  → NEW: Takes missing fields, not whole profile
```

---

## For QA: Test Cases

### Test 1: No Repeated Questions
**Input**: 
```
User 1: "I'm 30 years old"
Bot: "What's your occupation?"
User 2: "I'm a farmer"
Bot: [should NOT ask "How old are you?" again]
```

**Expected**: Bot asks only about missing required fields, never repeats

---

### Test 2: Age-Based Scheme Filtering
**Input**: 
```
Age: 68
Bot: [shows schemes]
```

**Expected**: 
- ✅ Pension scheme (minAge 60) shown
- ✅ Housing scheme (any age) shown
- ❌ ICDS scheme (maxAge 6) NOT shown
- ❌ Student scheme (maxAge 25) NOT shown
- ❌ Maternity scheme (female only) NOT shown

---

### Test 3: Language Locking
**Input (Hindi)**:
```
User: "नमस्ते, मैं किसान हूँ"
Bot: [question in Hindi]
User: "मेरी उम्र 45 है"
Bot: [continues in Hindi, NEVER switches to English]
```

**Expected**: All bot responses in Hindi throughout session

---

### Test 4: Multi-Field Extraction
**Input**:
```
User: "I am 45 year old male farmer earning 8000 a month"
```

**Expected**: Extract all 5 fields in one message
- age: 45 ✅
- gender: Male ✅
- occupation: Farmer ✅
- annualIncome: 96000 ✅
- (district from context or next message)

---

### Test 5: STT Error Tolerance
**Input (Voice - STT Error)**:
```
User says: "I'm a femail"  
STT hears: "femail" (not "female")
Bot: [should still understand as Female]
```

**Expected**: 
- _normalizeGender("femail") → "Female" ✅
- Gender correctly recorded as Female
- No follow-up question about gender

---

### Test 6: Soft Limit on Questions
**Input**:
```
Follow-up 1: "What's your age?"
Follow-up 2: "What's your income?"
Follow-up 3: "What's your occupation?"
Follow-up 4: "What's your state?"
Follow-up 5: "What's your category?"
[At this point: _followUpCount = 5]

But ONE critical field still missing (e.g., income)
Bot: [SHOULD still ask]
```

**Expected**: 
- After 5 follow-ups: soft limit allows 1 more critical question
- After 6 follow-ups: definitely stop
- Shows schemes regardless

---

### Test 7: Language Variations in Gender
**Inputs**:
```
English: "mle" → Male
Hindi: "पुरुष" (puruSH) → [future enhancement]
Error: "femail" → Female
Abbrev: "m" → Male, "f" → Female
```

**Expected**: All normalized correctly

---

### Test 8: Income Format Tolerance
**Inputs**:
```
"5 lakh" → 500000
"5 lakh rupees" → 500000
"5 thousand" → 5000
"5k" → 5000
"5th" (STT error) → 5000
"50000" → 50000
```

**Expected**: All parsed correctly

---

## Debugging Guide

### Check Language Locking
**Look for**:
```
🔒 Session language LOCKED: hi
🌐 Using session language: hi (detected: en)
```

If you see different language on every message, something's wrong.

---

### Check Question Tracking
**Look for**:
```
✅ Extracted fields: age, occupation
❓ Missing required fields: {income, category} (asked: {age, occupation})
```

If the same field appears in "asked" but user is asked again, bug.

---

### Check Scheme Filtering
**Look for**:
```
   ❌ ICDS: age 70 > maxAge 6
   ❌ Student: age 70 > maxAge 25
   ✅ Pension: matches
   ✅ Housing: matches
```

If you see schemes passing that shouldn't (e.g., ICDS for age 70), filtering broke.

---

### Check Required Fields Computation
**Look for**:
```
📋 Required fields from schemes: {age, income, occupation}
❓ Missing required fields: {income} (asked: {age, occupation})
```

Count should match scheme requirements.

---

### Check Gemini Role
**Prompt should say**:
```
Your role is ONLY to generate natural questions, NOT decide eligibility.
Required Information MISSING from profile: annual income
```

If prompt mentions "decide eligibility" or "filter schemes", wrong.

---

## How to Deploy

### Pre-Deployment Checklist
- [ ] Run `dart analyze` → Zero errors
- [ ] Test all 8 test cases above
- [ ] Test on Android APK
- [ ] Test on Flutter Web
- [ ] Check debug logs for expected patterns
- [ ] Verify no API key exposure
- [ ] Verify old features still work

### Deployment Steps
1. Pull latest code
2. Run flutter pub get
3. Test on device
4. Monitor logs for above patterns
5. Gather user feedback on:
   - Question repetition (should be zero)
   - Scheme relevance (should be high)
   - Language consistency (should stay same)

---

## Known Limitations

### Marathi Language
- Currently grouped with Hindi (Devanagari detection)
- Could be enhanced with word list later
- Still works for questioning, just not perfectly differentiated

### Income Handling
- Word forms like "five thousand" not recognized
- Only digit-based formats parsed
- Future: Add word-to-number conversion

### Multi-Language Sessions
- Session language locks at first message
- Cannot switch mid-session
- Design choice to prevent confusion

---

## Performance Notes

**_filterSchemes()**: O(schemes × filters) = ~1-5ms  
**_computeRequiredFields()**: O(schemes) = ~1ms  
**_askGeminiForNextStep()**: O(1) setup + Gemini latency (500-2000ms)  

Total conversation latency: Mostly Gemini API, not our code.

---

## Future Enhancements

1. **Smarter Question Clubbing**
   - Currently: Gemini decides
   - Future: Club 2-3 fields programmatically based on type

2. **Marathi Differentiation**
   - Add Marathi-specific word list
   - Distinguish 'hi' vs 'mr' better

3. **Word-Based Income Parsing**
   - "Five lakh" → recognize "Five"
   - "One thousand" → recognize "One"

4. **Scheme-Aware Question Order**
   - Ask income before occupation if income more selective
   - Prioritize by filtering power

5. **Multi-Message Context**
   - Remember conversation context across messages
   - Better natural language understanding

---

## Support

**For Issues**:
1. Check debug logs for patterns above
2. Look at INTELLIGENT_QUESTIONING_FIX.md for detailed explanation
3. Verify _filterSchemes() is eliminating irrelevant schemes
4. Verify _computeRequiredFields() matches actual scheme requirements

---

**Quick Start**: Run app, say "I'm 70 years old", expect pension/housing only, no ICDS/student/maternity. ✅
