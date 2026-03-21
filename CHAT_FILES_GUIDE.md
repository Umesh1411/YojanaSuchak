# Chat System Files Guide

## Overview
The YojanaSuchak app uses a Gemini-powered chat system for scheme recommendations with voice support. Below is a complete guide to all chat-related files.

---

## 🤖 Core Chat Service Files

### 1. **Gemini Chat Service** (Main Chat Engine)
- **File**: `lib/services/gemini_chat_service.dart`
- **Purpose**: Handles AI-powered conversations with Gemini API
- **Key Methods**:
  - `getChatResponse()`: Gets AI response from Gemini
  - `_buildStrictPrompt()`: Creates system prompt with rules
  - `_getFallbackResponse()`: Fallback when API key is missing
  - `_detectLanguage()`: Detects Hindi/Marathi/English
- **Status**: ⚠️ Uses fallback mode (no API key configured)

### 2. **Gemini Service** (Scheme Recommendations)
- **File**: `lib/services/gemini_service.dart`
- **Purpose**: Gets scheme recommendations from Gemini based on user profile
- **Key Methods**:
  - `getRecommendations()`: Gets top 3 recommended schemes
  - `_buildPrompt()`: Creates recommendation prompt
  - `_getFallbackRecommendations()`: Fallback recommendations without API

### 3. **User Profile Model**
- **File**: `lib/models/user_profile.dart`
- **Purpose**: Manages user profile data collected during chat
- **Fields**: age, gender, state, district, annualIncome, occupation, category

### 4. **Conversation State Model**
- **File**: `lib/models/conversation_state.dart`
- **Purpose**: Enum for conversation flow states
- **States**: greeting → askAge → askGender → askState → ... → result

---

## 🎤 Voice Integration Files

### 5. **Speech to Text Service**
- **File**: `lib/services/speech_to_text_service.dart`
- **Purpose**: Converts voice input to text
- **Platforms**: iOS, Android, Web

### 6. **Text to Speech Service**
- **File**: `lib/services/tts_service.dart`
- **Purpose**: Reads bot responses aloud
- **Supported**: Multiple languages

---

## 🖥️ UI Screen Files

### 7. **Home Screen** (Main Chat Interface)
- **File**: `lib/ui/home_screen.dart`
- **Purpose**: Initial chat interface with voice input
- **Features**: Voice/text input, conversation history, recommendations

### 8. **Enhanced Scheme Finder Screen**
- **File**: `lib/ui/scheme_finder/enhanced_scheme_finder_screen.dart`
- **Purpose**: Improved chat UI with better conversation flow
- **Features**: 
  - Real-time message filtering
  - Profile extraction
  - Scheme recommendations
  - Better mobile experience

### 9. **Scheme Finder Screen**
- **File**: `lib/ui/scheme_finder/scheme_finder_screen.dart` (deleted)
- **Purpose**: Legacy chat interface
- **Status**: Older version (deleted), use `Enhanced Scheme Finder` instead

---

## ⚙️ Configuration & Localization

### 10. **Localization Service** (Multi-language)
- **File**: `lib/core/services/localization_service.dart`
- **Purpose**: Provides chat messages in English, Hindi, and Marathi
- **Key Messages**:
  - `askGender`: "What is your gender?"
  - `chatbotGreeting`: Initial greeting
  - All other profile questions

### 11. **App Config** (API Keys & Settings)
- **File**: `lib/core/config/app_config.dart`
- **Purpose**: Centralized configuration
- **Status**: 🔴 **Gemini API key not configured** (see below)

---

## 📊 Data Models

### 12. **Scheme Model**
- **File**: `lib/models/scheme.dart`
- **Purpose**: Structure for government schemes

### 13. **Chat History Model**
- **File**: Internal to services
- **Structure**: `{ role: 'user'/'assistant', message: String }`

---

## 🔑 Gemini API Key Configuration

### ❌ **Current Status**: NOT CONFIGURED

**Why Gemini is not working:**
```
❌ Gemini API key not provided. Using fallback mode.
🔄 Using fallback chat response (no Gemini API key)
```

**The Problem:**
- Gemini API key is intentionally set to `null` in the code
- This triggers fallback mode - predefined responses only
- No intelligent conversation possible

**Files that need the API key:**
1. `lib/ui/scheme_finder/enhanced_scheme_finder_screen.dart` (Line 41)
2. `lib/ui/home_screen.dart` (Line 75)
3. `lib/services/gemini_service.dart` (Line 70)

### ✅ **How to Fix** (3 Steps):

**Step 1: Get API Key**
- Go to: https://makersuite.google.com/app/apikey
- Create a new API key for Google Gemini

**Step 2: Add to Environment**
Option A - Use environment variable (Recommended):
```bash
export GEMINI_API_KEY="your-api-key-here"
```

Option B - Direct in code (Development only):
```dart
GeminiChatService(apiKey: 'YOUR_API_KEY_HERE')
```

**Step 3: Update Files**
Replace `apiKey: null` with your actual API key in:
- `enhanced_scheme_finder_screen.dart:41`
- `home_screen.dart:75`
- `gemini_service.dart:70`

**Example**:
```dart
_chatService = GeminiChatService(
  apiKey: const String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'null')
);
```

---

## 🔄 Chat Flow Diagram

```
User Input (Voice/Text)
    ↓
Speech to Text (if voice)
    ↓
Gemini Chat Service
    ├─ Check missing fields (age, gender, state, etc.)
    ├─ Ask next question OR provide recommendations
    └─ Fallback if no API key
    ↓
Extract Profile Info
    ↓
Text to Speech (read response)
    ↓
Display in Chat UI
    ↓
If profile complete → Get Recommendations
    ├─ Gemini Service recommends schemes
    └─ Display top 3 schemes
```

---

## 📝 Key Issues & Fixes

### Issue 1: "See what is gender?" Repeating
**Root Cause**: Fallback mode asks for missing fields repeatedly
**Why**: Gender field not being set in profile after user answers
**File**: `lib/services/gemini_chat_service.dart` (Lines 29-90)
**Fix**: Need to extract gender from user response and update profile

### Issue 2: Gemini API Not Working
**Root Cause**: API key not configured (set to `null`)
**Files**: Configuration in `gem ini_chat_service.dart`, usage in screen files
**Fix**: Set valid Gemini API key (see Step 1-3 above)

### Issue 3: Missing Scheme ID Field in Admin Upload
**Root Cause**: Admin upload form doesn't allow entering custom scheme IDs
**File**: `lib/ui/admin/admin_scheme_upload_screen.dart` (Line 181)
**Fix**: Add manual scheme ID input field (see admin upload section)

---

## 🧪 Testing the Chat System

### Test with Fallback (No API Key):
```bash
flutter run
# Chat will ask predefined questions only
# No intelligent responses
```

### Test with Gemini API:
```bash
export GEMINI_API_KEY="your-key"
flutter run
# Chat will be fully intelligent
# Multi-turn conversations work
```

### Debug Chat Messages:
- Check logs for: `🔄 Using fallback chat response`
- Check logs for: `📡 Calling Gemini API...`

---

## 🎯 Chat System Architecture

```
Services Layer:
  ├─ GeminiChatService (AI Conversation)
  ├─ GeminiService (Recommendations)
  ├─ SpeechToTextService (Voice Input)
  ├─ TTSService (Voice Output)
  └─ DataService (Scheme Data)

Models Layer:
  ├─ UserProfile
  ├─ Scheme
  ├─ ConversationState
  └─ ChatMessage

UI Layer:
  ├─ HomeScreen
  ├─ EnhancedSchemeFinder
  └─ SchemeFinder (Legacy)

Config Layer:
  ├─ LocalizationService (Multi-language)
  ├─ AppConfig (API Keys)
  └─ AppTheme
```

---

## 📚 All Chat-Related Files Summary

| File | Type | Purpose |
|------|------|---------|
| `gemini_chat_service.dart` | Service | Main chat engine |
| `gemini_service.dart` | Service | Recommendations |
| `speech_to_text_service.dart` | Service | Voice input |
| `tts_service.dart` | Service | Voice output |
| `user_profile.dart` | Model | User data |
| `conversation_state.dart` | Model | Chat states |
| `scheme.dart` | Model | Scheme data |
| `home_screen.dart` | UI | Chat screen |
| `enhanced_scheme_finder_screen.dart` | UI | Better chat |
| `scheme_finder_screen.dart` | UI | Legacy chat |
| `localization_service.dart` | Config | Multi-language |
| `app_config.dart` | Config | API keys |

---

## 🚀 Next Steps

1. **Immediate**: Get Gemini API key and configure it
2. **Short-term**: Fix gender question repetition
3. **Short-term**: Add scheme ID field to admin upload
4. **Medium-term**: Add backend API for security
5. **Long-term**: Add conversation persistence
