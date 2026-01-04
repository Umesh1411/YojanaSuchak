import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/scheme.dart';
import '../models/user_profile.dart';
import '../models/conversation_state.dart';

/// Service for Gemini-powered chat conversations
class GeminiChatService {
  final String apiKey;
  late final GenerativeModel _model;
  final List<Map<String, String>> _chatHistory = [];

  GeminiChatService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // Updated to latest model
      apiKey: apiKey,
    );
  }

  /// Get chat response from Gemini
  Future<String> getChatResponse({
    required String userMessage,
    required UserProfile profile,
    required List<Scheme> availableSchemes,
    ConversationState? currentState,
  }) async {
    try {
      // Add user message to history
      _chatHistory.add({
        'role': 'user',
        'message': userMessage,
      });

      // Build conversational prompt
      String prompt = _buildConversationalPrompt(profile, availableSchemes, userMessage);
      
      debugPrint('📤 Sending prompt to Gemini...');
      debugPrint('📤 Prompt length: ${prompt.length} characters');
      debugPrint('📤 API Key (first 10 chars): ${apiKey.substring(0, 10)}...');
      debugPrint('📤 Model: gemini-1.5-flash');
      debugPrint('📤 Prompt preview: ${prompt.substring(0, prompt.length > 300 ? 300 : prompt.length)}...');

      // Get response with timeout
      debugPrint('📡 Calling Gemini API...');
      final response = await _model.generateContent([Content.text(prompt)])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('⏱️ Request timed out after 30 seconds');
              throw TimeoutException('Request timed out after 30 seconds', const Duration(seconds: 30));
            },
          );

      debugPrint('📥 Received response from Gemini API');
      String assistantResponse = response.text ?? 'I apologize, I could not generate a response.';
      
      if (assistantResponse.isEmpty) {
        debugPrint('⚠️ Empty response from Gemini');
        assistantResponse = 'I apologize, I could not generate a response. Please try again.';
      }
      
      debugPrint('✅ Response text length: ${assistantResponse.length} characters');
      debugPrint('✅ Response: ${assistantResponse.substring(0, assistantResponse.length > 200 ? 200 : assistantResponse.length)}');

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
        errorMessage = 'API key error. Please check the Gemini API key configuration.';
      } else if (e.toString().contains('quota') || e.toString().contains('rate limit')) {
        errorMessage = 'API quota exceeded. Please try again later.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('403') || e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your API key permissions.';
      }
      
      return errorMessage;
    }
  }

  /// Build conversational prompt (more natural, less instructional)
  String _buildConversationalPrompt(
    UserProfile profile,
    List<Scheme> schemes,
    String userMessage,
  ) {
    // Build conversation history
    String conversationHistory = '';
    if (_chatHistory.length > 2) {
      // Include last 4 messages for context
      int startIndex = _chatHistory.length > 6 ? _chatHistory.length - 6 : 0;
      for (int i = startIndex; i < _chatHistory.length - 1; i++) {
        final msg = _chatHistory[i];
        conversationHistory += '${msg['role'] == 'user' ? 'User' : 'Assistant'}: ${msg['message']}\n';
      }
    }

    // Get missing fields
    List<String> missingFields = [];
    if (profile.age == null) missingFields.add('age');
    if (profile.gender == null) missingFields.add('gender');
    if (profile.state == null) missingFields.add('state');
    if (profile.district == null && profile.state != null) missingFields.add('district');
    if (profile.annualIncome == null) missingFields.add('annual income');
    if (profile.occupation == null && profile.age != null && profile.gender != null && profile.state != null && profile.annualIncome != null) {
      missingFields.add('occupation');
    }
    if (profile.category == null && profile.occupation != null) {
      missingFields.add('category');
    }

    // Get relevant schemes (limit to 20 for token efficiency)
    String schemesInfo = '';
    if (schemes.isNotEmpty) {
      List<Scheme> relevantSchemes = schemes.take(20).toList();
      schemesInfo = relevantSchemes.map((s) => 
        '${s.schemeName} - ${s.department}'
      ).join('\n');
    }

    String schemesContext = '';
    if (schemes.isEmpty) {
      schemesContext = 'IMPORTANT: There are NO available schemes that match the user\'s criteria. You must apologize sincerely and let them know that unfortunately, no schemes were found. Be empathetic and suggest they check back later or try different criteria.';
    } else {
      schemesContext = 'Available schemes (${schemes.length} total):\n$schemesInfo\n\nWhen recommending schemes, be enthusiastic and explain why they\'re good matches.';
    }

    String missingFieldsText = '';
    if (missingFields.isNotEmpty) {
      missingFieldsText = '\n\nIMPORTANT - MISSING INFORMATION:\nYou need to collect the following information from the user:\n${missingFields.map((f) => '- $f').join('\n')}\n\nYou MUST ask for ONE missing piece of information in your response. Ask naturally and conversationally.';
      
      // Priority order for asking questions
      if (missingFields.contains('age')) {
        missingFieldsText += '\n\nAsk: "What is your age?"';
      } else if (missingFields.contains('gender')) {
        missingFieldsText += '\n\nAsk: "What is your gender? (Male/Female/Other)"';
      } else if (missingFields.contains('state')) {
        missingFieldsText += '\n\nAsk: "Which state do you belong to?"';
      } else if (missingFields.contains('annual income')) {
        missingFieldsText += '\n\nAsk: "What is your approximate annual income in rupees?"';
      } else if (missingFields.contains('occupation')) {
        missingFieldsText += '\n\nAsk: "What is your occupation? (e.g., Teacher, Engineer, Farmer, Student, Business, Government Employee, etc.)"';
      } else if (missingFields.contains('category')) {
        missingFieldsText += '\n\nAsk: "What is your category? (Student, Farmer, Woman, Senior Citizen, Unemployed, General)"';
      }
    } else {
      missingFieldsText = '\n\nAll required information has been collected. You can now provide scheme recommendations or ask if they need more help.';
    }

    return '''You are a friendly and helpful AI assistant for YojanaSuchak, a government scheme recommendation app for Maharashtra, India. You're chatting with a user who wants to find suitable government schemes.

YOUR ROLE:
1. Collect user information naturally through conversation
2. Ask ONE question at a time
3. Be friendly, warm, and conversational - like talking to a friend
4. Acknowledge what the user tells you
5. Once you have all information, help them find suitable schemes

IMPORTANT RULES:
- Always ask ONE question at a time if information is missing
- Be natural and conversational - don't sound like a form
- Respond in the same language the user is using (English, Hindi, or Marathi)
- Keep responses short (1-2 sentences)
- Acknowledge what the user says before asking the next question
- Don't ask questions that have already been answered

${conversationHistory.isNotEmpty ? 'Previous conversation:\n$conversationHistory\n' : ''}
User's current information:
${profile.toPromptString()}
$missingFieldsText

$schemesContext

User just said: "$userMessage"

Your response (be natural, friendly, and ask ONE question if information is missing):''';
  }

  /// Get scheme recommendations from Gemini
  Future<List<Scheme>> getRecommendations({
    required UserProfile profile,
    required List<Scheme> allSchemes,
  }) async {
    try {
      if (allSchemes.isEmpty) {
        return [];
      }

      // Filter schemes based on basic eligibility and occupation/department
      List<Scheme> filteredSchemes = allSchemes.where((scheme) {
        // Age check
        if (profile.age != null && scheme.ageLimit != null) {
          if (profile.age! < scheme.ageLimit!) return false;
        }
        // Income check
        if (profile.annualIncome != null && scheme.incomeLimit != null) {
          if (profile.annualIncome! > scheme.incomeLimit!) return false;
        }
        // Occupation/Department filter - schemes are filtered by department in Firestore
        // We keep all eligible schemes and let Gemini prioritize based on occupation
        // Category check (if applicable)
        if (profile.category != null && scheme.category != null) {
          if (!scheme.category!.toLowerCase().contains(profile.category!.toLowerCase()) &&
              !profile.category!.toLowerCase().contains(scheme.category!.toLowerCase())) {
            // Still allow, but will be ranked lower by Gemini
          }
        }
        return true;
      }).toList();

      if (filteredSchemes.isEmpty) {
        return [];
      }

      // Limit to top 50 schemes to avoid token limits
      List<Scheme> schemesToAnalyze = filteredSchemes.take(50).toList();
      String schemesJson = jsonEncode(
        schemesToAnalyze.map((s) => s.toJson()).toList(),
      );

      String prompt = '''
You are an expert at matching users with government schemes. Based on this user profile, recommend the top 3 most suitable schemes from the available list.

User Profile:
${profile.toPromptString()}

IMPORTANT - Department Matching for Firestore Schemes:
- User's occupation: ${profile.occupation ?? 'Not provided'}
- Schemes in Firestore are organized department-wise
- CRITICAL: Prioritize schemes from departments that match the user's occupation:
  * Teacher/Education → Education Department schemes (HIGHEST PRIORITY)
  * Farmer/Agriculture → Agriculture Department schemes (HIGHEST PRIORITY)
  * Doctor/Medical/Health → Health Department schemes (HIGHEST PRIORITY)
  * Engineer/Technical → Technical/Engineering Department schemes
  * Student → Education/Youth Department schemes
  * Business → Commerce/Business Department schemes
- Match occupation to department FIRST, then consider age, income, gender, category
- If occupation matches a department, those schemes should be in the top 3 recommendations

Available Schemes (${schemesToAnalyze.length} schemes):
$schemesJson

IMPORTANT: 
- Return ONLY valid JSON in this exact format:
{
  "recommendations": [
    {"schemeName": "Exact scheme name from the list above"},
    {"schemeName": "Second scheme name"},
    {"schemeName": "Third scheme name"}
  ]
}
- Use EXACT scheme names as they appear in the list
- If fewer than 3 schemes match, return only the matching ones
- Priority order: 1) Occupation-Department match, 2) Eligibility criteria match
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      List<Scheme> recommendations = _parseRecommendations(response.text ?? '', schemesToAnalyze);
      
      // If parsing failed, return top 3 from filtered schemes
      if (recommendations.isEmpty && filteredSchemes.isNotEmpty) {
        return filteredSchemes.take(3).toList();
      }
      
      return recommendations;
    } catch (e) {
      print('Error getting recommendations: $e');
      // Fallback: return top 3 eligible schemes
      List<Scheme> fallback = allSchemes.where((scheme) {
        if (profile.age != null && scheme.ageLimit != null) {
          if (profile.age! < scheme.ageLimit!) return false;
        }
        if (profile.annualIncome != null && scheme.incomeLimit != null) {
          if (profile.annualIncome! > scheme.incomeLimit!) return false;
        }
        return true;
      }).take(3).toList();
      return fallback;
    }
  }

  List<Scheme> _parseRecommendations(String response, List<Scheme> allSchemes) {
    try {
      String cleaned = response.trim();
      if (cleaned.contains('```json')) {
        cleaned = cleaned.split('```json')[1].split('```')[0].trim();
      } else if (cleaned.contains('```')) {
        cleaned = cleaned.split('```')[1].split('```')[0].trim();
      }

      final json = jsonDecode(cleaned);
      final recommendations = json['recommendations'] as List;

      List<Scheme> result = [];
      for (var rec in recommendations) {
        String schemeName = rec['schemeName'] ?? '';
        Scheme? scheme = allSchemes.firstWhere(
          (s) => s.schemeName.toLowerCase() == schemeName.toLowerCase(),
          orElse: () => allSchemes.first,
        );
        result.add(scheme);
      }

      return result.take(3).toList();
    } catch (e) {
      print('Error parsing recommendations: $e');
      return [];
    }
  }

  /// Clear chat history
  void clearHistory() {
    _chatHistory.clear();
  }
}
