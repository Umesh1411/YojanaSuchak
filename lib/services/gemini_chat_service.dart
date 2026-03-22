import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/scheme.dart';
import '../models/user_profile.dart';


/// Service for Gemini-powered chat conversations
class GeminiChatService {
  final String apiKey;
  GenerativeModel? _model;
  bool _enabled = false;
  final List<Map<String, String>> _chatHistory = [];

  GeminiChatService({required this.apiKey}) {
    // Some platforms (notably Flutter Web) may not support the native
    // `google_generative_ai` model construction. Guard against that so the
    // app does not crash — service will report unavailable instead.
    if (kIsWeb) {
      debugPrint('GeminiChatService: running on Web, disabling direct model initialization');
      _model = null;
      _enabled = false;
    } else {
      _model = GenerativeModel(
        model: 'gemini-flash-lite-latest', // Changed to more stable model
        apiKey: apiKey,
      );
      _enabled = true;
    }
  }

  /// Detect language from user input
  /// Returns: 'hi' for Hindi, 'mr' for Marathi, 'en' for English
  String _detectLanguage(String text) {
    // Hindi character range: \u0900-\u097F
    // Marathi uses same Devanagari script but has some unique characters
    RegExp hindiMarathiRegex = RegExp(r'[\u0900-\u097F]');

    if (hindiMarathiRegex.hasMatch(text)) {
      // Simple heuristic: if text contains common Marathi words, it's Marathi
      // Otherwise assume Hindi (most common in Maharashtra)
      String lower = text.toLowerCase();
      if (lower.contains('आहे') ||
          lower.contains('मी') ||
          lower.contains('तुम्ही')) {
        return 'mr'; // Marathi
      }
      return 'hi'; // Hindi
    }
    return 'en'; // English
  }

  /// Get chat response from Gemini
  /// CRITICAL: Always sends full composed prompt, never raw user text
  Future<String> getChatResponse({
    required String userMessage,
    required UserProfile profile,
    required List<Scheme> availableSchemes,
    String? sessionLanguage,
  }) async {
    try {
      if (!_enabled || _model == null) {
        debugPrint('GeminiChatService: model not enabled or unavailable on this platform');
        return 'AI assistance is not available on this platform. Please provide the missing information via text.';
      }
      // Add user message to history
      _chatHistory.add({
        'role': 'user',
        'message': userMessage,
      });

      // Prioritize session language over detection
      String detectedLanguage = sessionLanguage ?? _detectLanguage(userMessage);

      // Build STRICT system prompt with full context
      // NEVER send raw user text - always compose full prompt
      String prompt = _buildStrictPrompt(
          profile, availableSchemes, userMessage, detectedLanguage);

      debugPrint('📤 Sending prompt to Gemini...');
      debugPrint('📤 Prompt length: ${prompt.length} characters');
      
      debugPrint('📤 Model: gemini-flash-lite-latest');
      debugPrint(
          '📤 Prompt preview: ${prompt.substring(0, prompt.length > 300 ? 300 : prompt.length)}...');

      // Get response with timeout
      debugPrint('📡 Calling Gemini API...');
        final response =
          await _model!.generateContent([Content.text(prompt)]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏱️ Request timed out after 30 seconds');
          throw TimeoutException('Request timed out after 30 seconds',
              const Duration(seconds: 30));
        },
      );

      debugPrint('📥 Received response from Gemini API');
      String assistantResponse =
          response.text ?? 'I apologize, I could not generate a response.';

      if (assistantResponse.isEmpty) {
        debugPrint('⚠️ Empty response from Gemini');
        assistantResponse =
            'I apologize, I could not generate a response. Please try again.';
      }

      debugPrint(
          '✅ Response text length: ${assistantResponse.length} characters');
      debugPrint(
          '✅ Response: ${assistantResponse.substring(0, assistantResponse.length > 200 ? 200 : assistantResponse.length)}');

      // Add response to history
      _chatHistory.add({
        'role': 'assistant',
        'message': assistantResponse,
      });

      // Keep only last 10 messages to avoid token limits
      if (_chatHistory.length > 10) {
        _chatHistory.removeRange(0, _chatHistory.length - 10);
      }

      return assistantResponse;
    } catch (e, stackTrace) {
      debugPrint('Gemini Chat Error: $e');
      debugPrint('Stack trace: $stackTrace');

      // More specific error messages
      String errorMessage = 'Sorry, I encountered an error. Please try again.';

      if (e.toString().contains('API key')) {
        errorMessage =
            'API key error. Please check the Gemini API key configuration.';
      } else if (e.toString().contains('not found') ||
          e.toString().contains('not supported') ||
          e.toString().contains('gemini-pro')) {
        errorMessage =
            'Model error. The Gemini model has been updated. Please restart the app.';
      } else if (e.toString().contains('quota') ||
          e.toString().contains('rate limit')) {
        errorMessage = 'API quota exceeded. Please try again later.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('403') ||
          e.toString().contains('permission')) {
        errorMessage =
            'Permission denied. Please check your API key permissions.';
      }

      return errorMessage;
    }
  }

  /// Build STRICT system prompt with production-safe rules
  /// Structure: System Prompt → Profile Context → Schemes Context → User Message → Instructions
  String _buildStrictPrompt(
    UserProfile profile,
    List<Scheme> schemes,
    String userMessage,
    String detectedLanguage,
  ) {
    // Build conversation history (last 4 messages for context)
    String conversationHistory = '';
    if (_chatHistory.length > 2) {
      int startIndex = _chatHistory.length > 6 ? _chatHistory.length - 6 : 0;
      for (int i = startIndex; i < _chatHistory.length - 1; i++) {
        final msg = _chatHistory[i];
        conversationHistory +=
            '${msg['role'] == 'user' ? 'User' : 'Assistant'}: ${msg['message']}\n';
      }
    }

    // Get missing profile fields (REQUIRED: age, gender, state, district, annualIncome, category, occupation)
    List<String> missingFields = [];
    if (profile.age == null) missingFields.add('age');
    if (profile.gender == null) missingFields.add('gender');
    if (profile.state == null) missingFields.add('state');
    if (profile.district == null) missingFields.add('district');
    if (profile.annualIncome == null) missingFields.add('annual income');
    if (profile.occupation == null) missingFields.add('occupation');
    if (profile.category == null) missingFields.add('category');

    // Build schemes context - ONLY from Firestore, NEVER invent schemes
    String schemesContext = '';
    if (schemes.isEmpty) {
      schemesContext =
          '⚠️ CRITICAL: NO SCHEMES AVAILABLE IN FIRESTORE.\nYou must politely inform the user that no schemes are currently available. Do NOT invent or suggest any schemes.';
    } else {
      // Include ALL schemes from Firestore (limit to 20 for token efficiency)
      List<Scheme> schemesToInclude = schemes.take(20).toList();
      String schemesList = schemesToInclude
          .map((s) =>
              '- ${s.schemeName} (Department: ${s.department}, Category: ${s.category ?? "general"})')
          .join('\n');

      schemesContext =
          '''✅ AVAILABLE SCHEMES FROM FIRESTORE (${schemes.length} total, showing first 20):
$schemesList

CRITICAL RULES FOR SCHEMES:
- You can ONLY recommend schemes from the list above
- NEVER invent, create, or suggest schemes that are NOT in this list
- If user asks about a scheme not in the list, politely say it's not available
- All schemes come from Firestore database - you have no other source''';
    }

    // Language-specific response instruction
    String languageInstruction = '';
    switch (detectedLanguage) {
      case 'hi':
        languageInstruction =
            'RESPOND IN THE EXACT SAME LANGUAGE AS THE USER\'S CURRENT MESSAGE. Ensure your response is entirely in simple Hindi. Do not use English if you are supposed to reply in Hindi.';
        break;
      case 'mr':
        languageInstruction =
            'RESPOND IN THE EXACT SAME LANGUAGE AS THE USER\'S CURRENT MESSAGE. Ensure your response is entirely in simple Marathi. Do not use English if you are supposed to reply in Marathi.';
        break;
      default:
        languageInstruction =
            'RESPOND IN SIMPLE ENGLISH. Use easy-to-understand words suitable for rural citizens.';
    }

    // Build missing fields instruction
    String missingFieldsInstruction = '';
    if (missingFields.isNotEmpty) {
      // Priority order: age → gender → state → district → income → occupation → category
      String nextField = missingFields.first;
      String questionTemplate = '';

      switch (nextField) {
        case 'age':
          questionTemplate = detectedLanguage == 'hi'
              ? 'आपकी उम्र क्या है?'
              : detectedLanguage == 'mr'
                  ? 'तुमचे वय किती आहे?'
                  : 'What is your age?';
          break;
        case 'gender':
          questionTemplate = detectedLanguage == 'hi'
              ? 'आपका लिंग क्या है? (पुरुष/महिला/अन्य)'
              : detectedLanguage == 'mr'
                  ? 'तुमचे लिंग काय आहे? (पुरुष/स्त्री/इतर)'
                  : 'What is your gender? (Male/Female/Other)';
          break;
        case 'state':
          questionTemplate = detectedLanguage == 'hi'
              ? 'आप किस राज्य से हैं?'
              : detectedLanguage == 'mr'
                  ? 'तुम कोणत्या राज्यातून आहात?'
                  : 'Which state do you belong to?';
          break;
        case 'district':
          questionTemplate = detectedLanguage == 'hi'
              ? 'आप किस जिले से हैं?'
              : detectedLanguage == 'mr'
                  ? 'तुम कोणत्या जिल्ह्यातून आहात?'
                  : 'Which district do you belong to?';
          break;
        case 'annual income':
          questionTemplate = detectedLanguage == 'hi'
              ? 'आपकी वार्षिक आय कितनी है? (रुपये में)'
              : detectedLanguage == 'mr'
                  ? 'तुमचे वार्षिक उत्पन्न किती आहे? (रुपयांमध्ये)'
                  : 'What is your approximate annual income in rupees?';
          break;
        case 'occupation':
          questionTemplate = detectedLanguage == 'hi'
              ? 'आपका व्यवसाय क्या है? (जैसे: शिक्षक, किसान, छात्र, इंजीनियर, आदि)'
              : detectedLanguage == 'mr'
                  ? 'तुमचे व्यवसाय काय आहे? (उदा: शिक्षक, शेतकरी, विद्यार्थी, अभियंता, इ.)'
                  : 'What is your occupation? (e.g., Teacher, Farmer, Student, Engineer, etc.)';
          break;
        case 'category':
          questionTemplate = detectedLanguage == 'hi'
              ? 'आपकी श्रेणी क्या है? (SC/ST/OBC/General)'
              : detectedLanguage == 'mr'
                  ? 'तुमची श्रेणी काय आहे? (SC/ST/OBC/General)'
                  : 'What is your category? (SC/ST/OBC/General)';
          break;
      }

      missingFieldsInstruction = '''
⚠️ MISSING PROFILE INFORMATION:
The following fields are still missing: ${missingFields.join(', ')}

ACTION REQUIRED:
- Ask ONLY ONE question for the next missing field: "$nextField"
- Use this question: "$questionTemplate"
- Keep your response to maximum 3 sentences
- Acknowledge what user said (if anything) before asking
- STOP asking questions once all fields are filled''';
    } else {
      missingFieldsInstruction = '''
✅ ALL PROFILE FIELDS COMPLETE:
- Age: ${profile.age}
- Gender: ${profile.gender}
- State: ${profile.state}
- District: ${profile.district}
- Annual Income: ₹${profile.annualIncome}
- Occupation: ${profile.occupation}
- Category: ${profile.category}

ACTION REQUIRED:
- Now you can provide scheme recommendations
- Use ONLY schemes from the Firestore list provided above
- Explain why each scheme is suitable for this user''';
    }

    // ============================================
    // STRICT SYSTEM PROMPT - PRODUCTION SAFE
    // ============================================
    return '''You are a government scheme assistant for YojanaSuchak app in Maharashtra, India.

═══════════════════════════════════════════════════════════
STRICT SYSTEM RULES (MUST FOLLOW):
═══════════════════════════════════════════════════════════

1. QUESTION RULES:
   - Ask ONLY ONE question at a time
   - Ask questions ONLY for missing profile fields: age, gender, state, district, annual income, category, occupation
   - Once profile is complete → STOP asking questions → provide scheme recommendations
   - Keep replies under 3 sentences
   - Use simple, rural-friendly language

2. SCHEME RULES (CRITICAL):
   - NEVER invent, create, or suggest schemes that are NOT in the Firestore list
   - Use ONLY schemes passed from Firestore database
   - If user asks about a scheme not in the list → politely say it's not available
   - All schemes come from Firestore - you have no other source

3. LANGUAGE RULES:
   $languageInstruction

4. RESPONSE RULES:
   - Maximum 3 sentences per response
   - Be polite, helpful, and empathetic
   - Acknowledge user's input before asking next question
   - Use simple words that rural citizens can understand

═══════════════════════════════════════════════════════════
CONVERSATION CONTEXT:
═══════════════════════════════════════════════════════════

${conversationHistory.isNotEmpty ? 'Previous conversation:\n$conversationHistory\n' : ''}

═══════════════════════════════════════════════════════════
USER PROFILE STATUS:
═══════════════════════════════════════════════════════════

${profile.toPromptString()}

$missingFieldsInstruction

═══════════════════════════════════════════════════════════
AVAILABLE SCHEMES (FROM FIRESTORE ONLY):
═══════════════════════════════════════════════════════════

$schemesContext

═══════════════════════════════════════════════════════════
USER'S CURRENT MESSAGE:
═══════════════════════════════════════════════════════════

"$userMessage"

═══════════════════════════════════════════════════════════
YOUR RESPONSE (FOLLOW ALL RULES ABOVE):
═══════════════════════════════════════════════════════════

''';
  }

  /// Get ALL applicable scheme recommendations from Firestore
  /// Returns ALL schemes that match user profile, not just top 3
  /// CRITICAL: Only uses schemes from Firestore, never invents schemes
  Future<List<Scheme>> getRecommendations({
    required UserProfile profile,
    required List<Scheme> allSchemes,
  }) async {
    try {
      if (allSchemes.isEmpty) {
        debugPrint('⚠️ No schemes available in Firestore');
        return [];
      }

      // Filter schemes based on eligibility criteria using NEW CSV structure
      // This ensures we only show schemes user is actually eligible for
      List<Scheme> eligibleSchemes = allSchemes.where((scheme) {
        // Age eligibility check (using minAge and maxAge from CSV)
        if (profile.age != null) {
          if (scheme.minAge != null && profile.age! < scheme.minAge!) {
            return false; // User too young
          }
          if (scheme.maxAge != null && profile.age! > scheme.maxAge!) {
            return false; // User too old
          }
        }

        // Income eligibility check (using maxIncomeINR and incomeRuleType)
        if (profile.annualIncome != null && scheme.maxIncomeINR != null) {
          if (scheme.incomeRuleType == 'EXACT' ||
              scheme.incomeRuleType == 'APPROX') {
            if (profile.annualIncome! > scheme.maxIncomeINR!) {
              return false; // User income too high
            }
          }
        }

        // Occupation matching (using occupationEligible from CSV)
        if (profile.occupation != null &&
            scheme.occupationEligible != 'Any' &&
            scheme.occupationEligible != 'Not Applicable') {
          String userOccupation = profile.occupation!.toLowerCase();
          String schemeOccupation = scheme.occupationEligible.toLowerCase();

          // Check if user occupation matches scheme requirement
          if (!schemeOccupation.contains(userOccupation) &&
              !userOccupation.contains(schemeOccupation) &&
              schemeOccupation != 'unemployed/any' &&
              schemeOccupation != 'any') {
            // Still allow but rank lower
          }
        }

        // Gender matching (using genderEligible from CSV)
        if (profile.gender != null && scheme.genderEligible != 'All') {
          String userGender = profile.gender!.toLowerCase();
          String schemeGender = scheme.genderEligible.toLowerCase();

          if (schemeGender == 'female' && userGender != 'female') {
            return false; // Scheme is only for females
          }
          if (schemeGender == 'male' && userGender != 'male') {
            return false; // Scheme is only for males
          }
        }

        // Caste matching (using casteEligible from CSV)
        if (profile.category != null && scheme.casteEligible != 'All') {
          String userCaste = profile.category!.toUpperCase();
          String schemeCaste = scheme.casteEligible.toUpperCase();

          // Check if user caste matches (SC, ST, OBC, General)
          if (userCaste != schemeCaste &&
              schemeCaste != 'ALL' &&
              !(userCaste == 'GENERAL' && schemeCaste == 'ALL')) {
            // Still allow but rank lower - some schemes may have multiple categories
          }
        }

        // Category matching (using categoryEligible from CSV)
        if (profile.category != null && scheme.categoryEligible != 'All') {
          String userCategory = profile.category!.toLowerCase();
          String schemeCategory = scheme.categoryEligible.toLowerCase();

          // Check for reserved categories, EWS, etc.
          if (schemeCategory == 'reserved' &&
              userCategory != 'sc' &&
              userCategory != 'st' &&
              userCategory != 'obc') {
            // Still allow but rank lower
          }
        }

        // State matching (if scheme is state-specific)
        if (scheme.state != 'India' && profile.state != null) {
          if (profile.state!.toLowerCase() != scheme.state.toLowerCase()) {
            return false; // Scheme is for different state
          }
        }

        return true; // Scheme is eligible
      }).toList();

      if (eligibleSchemes.isEmpty) {
        debugPrint('⚠️ No eligible schemes found for user profile');
        return [];
      }

      debugPrint(
          '✅ Found ${eligibleSchemes.length} eligible schemes out of ${allSchemes.length} total');

      // Return ALL eligible schemes - user requested all applicable, not just top 3
      // If there are too many (e.g., > 100), we can still return all but UI should handle pagination
      return eligibleSchemes;
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting recommendations: $e');
      debugPrint('Stack trace: $stackTrace');
      // Fail gracefully - return empty list
      return [];
    }
  }

  /// Explain why a given scheme matches the user profile in simple language.
  Future<String> explainScheme({
    required UserProfile profile,
    required Scheme scheme,
  }) async {
    if (!_enabled || _model == null) {
      debugPrint('GeminiChatService: explainScheme unavailable on this platform');
      return 'This scheme matches your profile based on the details you provided.';
    }

    try {
      final prompt = '''Explain politely in simple Indian English why this government scheme matches the user's profile.

User Profile:
Occupation: ${profile.occupation}
Age: ${profile.age}
Income: ${profile.annualIncome}
Category: ${profile.category}
State: ${profile.state}

Scheme:
Name: ${scheme.schemeName}
Eligibility: ${scheme.eligibility}
Benefits: ${scheme.benefits}

Keep the explanation to 2-3 short sentences.''';

      final response = await _model!.generateContent([Content.text(prompt)]).timeout(
        const Duration(seconds: 20),
      );

      return response.text ?? 'This scheme matches your profile.';
    } catch (e) {
      debugPrint('GeminiChatService explainScheme error: $e');
      return 'This scheme matches your profile based on the details you provided.';
    }
  }

  // Removed _parseRecommendations - no longer needed as we return all eligible schemes directly

  /// Clear chat history
  void clearHistory() {
    _chatHistory.clear();
  }
}
