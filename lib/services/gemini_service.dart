import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/scheme.dart';
import '../models/user_profile.dart';

/// Model for Gemini recommendation result
class SchemeRecommendation {
  final Scheme scheme;
  final String reason;
  final String keyBenefits;

  SchemeRecommendation({
    required this.scheme,
    required this.reason,
    required this.keyBenefits,
  });
}

/// Service for interacting with Google Gemini API
class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiService({required this.apiKey}) {
    _model = GenerativeModel(model: 'gemini-flash-lite-latest', apiKey: apiKey); // Updated to current Gemini model
  }

  /// Get top 3 scheme recommendations from Gemini
  ///
  /// This method:
  /// 1. Constructs a detailed prompt with user profile and schemes
  /// 2. Sends request to Gemini API
  /// 3. Parses the response to extract top 3 schemes with explanations
  Future<List<SchemeRecommendation>> getRecommendations(
    UserProfile profile,
    List<Scheme> schemes,
  ) async {
    try {
      // Construct the prompt
      String prompt = _buildPrompt(profile, schemes);

      // Send to Gemini
      final response = await _model.generateContent([Content.text(prompt)]);

      // Parse response
      return _parseResponse(response.text ?? '', schemes);
    } catch (e) {
      print('Gemini API Error: $e');
      // Fallback: return top 3 schemes by basic matching
      return _getFallbackRecommendations(profile, schemes);
    }
  }

  /// Build the prompt for Gemini
  String _buildPrompt(UserProfile profile, List<Scheme> schemes) {
    // Convert schemes to JSON string (limited to avoid token limits)
    String schemesJson = jsonEncode(
      schemes.take(100).map((s) => s.toJson()).toList(),
    );

    return '''
You are a government scheme recommendation expert for Maharashtra, India.
Based on the following user profile, select the BEST 3 schemes from the provided list.

${profile.toPromptString()}

Schemes Dataset (JSON):
$schemesJson

IMPORTANT: Return your response in the following EXACT JSON format:
{
  "recommendations": [
    {
      "schemeName": "Exact scheme name from dataset",
      "reason": "Why this scheme is suitable for this user (2-3 sentences)",
      "keyBenefits": "Key benefits this user will receive (bullet points)"
    },
    {
      "schemeName": "Second scheme name",
      "reason": "Why this scheme is suitable",
      "keyBenefits": "Key benefits"
    },
    {
      "schemeName": "Third scheme name",
      "reason": "Why this scheme is suitable",
      "keyBenefits": "Key benefits"
    }
  ]
}

Return ONLY valid JSON, no additional text before or after.
''';
  }

  /// Parse Gemini's response into structured recommendations
  List<SchemeRecommendation> _parseResponse(
    String responseText,
    List<Scheme> allSchemes,
  ) {
    try {
      // Clean the response - remove markdown code blocks if present
      String cleaned = responseText.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      }
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      // Parse JSON
      Map<String, dynamic> json = jsonDecode(cleaned);
      List<dynamic> recommendations = json['recommendations'] as List;

      List<SchemeRecommendation> result = [];

      for (var rec in recommendations) {
        String schemeName = rec['schemeName'] as String? ?? '';
        String reason = rec['reason'] as String? ?? '';
        String keyBenefits = rec['keyBenefits'] as String? ?? '';

        // Find the matching scheme from our dataset
        Scheme? scheme = allSchemes.firstWhere(
          (s) => s.schemeName.toLowerCase() == schemeName.toLowerCase(),
          orElse: () => allSchemes.first, // Fallback
        );

        result.add(
          SchemeRecommendation(
            scheme: scheme,
            reason: reason,
            keyBenefits: keyBenefits,
          ),
        );
      }

      return result.take(3).toList();
    } catch (e) {
      print('Error parsing Gemini response: $e');
      print('Response text: $responseText');
      return [];
    }
  }

  /// Fallback recommendations if Gemini fails
  List<SchemeRecommendation> _getFallbackRecommendations(
    UserProfile profile,
    List<Scheme> schemes,
  ) {
    // Simple matching based on category
    List<Scheme> matched = schemes.where((s) {
      if (profile.category == null) return true;
      return s.category?.toLowerCase() == profile.category?.toLowerCase() ||
          s.targetGroup.toLowerCase().contains(profile.category!.toLowerCase());
    }).toList();

    if (matched.isEmpty) {
      matched = schemes;
    }

    return matched.take(3).map((scheme) {
      return SchemeRecommendation(
        scheme: scheme,
        reason:
            'This scheme matches your profile category: ${profile.category ?? "general"}.',
        keyBenefits: scheme.benefits,
      );
    }).toList();
  }
}





