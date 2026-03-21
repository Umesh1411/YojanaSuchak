import 'package:cloud_functions/cloud_functions.dart';

/// Small wrapper to call server-side callable function that provides a
/// single follow-up question (or a short response) using server-side Gemini
/// or deterministic fallback.
class GeminiService {
  final HttpsCallable _followUpCallable =
      FirebaseFunctions.instance.httpsCallable('getGeminiResponse');
  final HttpsCallable _initialCallable =
      FirebaseFunctions.instance.httpsCallable('geminiInitialProfile');
  final HttpsCallable _updateCallable =
      FirebaseFunctions.instance.httpsCallable('geminiUpdateProfile');
  final HttpsCallable _schemeCallable =
      FirebaseFunctions.instance.httpsCallable('geminiGenerateSchemeDetails');

  /// Calls the server-side callable with provided context and returns the question string
  Future<String?> getFollowUpQuestion({
    required String userProblem,
    required List<String> missingFields,
    required String lang,
    String? sector,
  }) async {
    try {
      final result = await _followUpCallable.call({
        'userProblem': userProblem,
        'missingFields': missingFields,
        'lang': lang,
        'sector': sector,
      });

      final data = result.data;
      if (data == null) return null;
      if (data is Map && data['question'] != null)
        return data['question'] as String;
      if (data is String) return data;
      return null;
    } catch (_) {
      // Network or callable error - return null so caller can fallback locally
      return null;
    }
  }

  /// Run initial profile extraction + eligibility on the server.
  /// Returns a parsed map with the exact shape:
  /// { profile, additional_attributes, eligible_schemes, schemes_needing_more_info, followup_question }
  Future<Map<String, dynamic>?> initialProfileAndEligibility({
    required String callSid,
    required String userText,
    required String language,
    required List<Map<String, dynamic>> schemes,
  }) async {
    try {
      final result = await _initialCallable.call({
        'callSid': callSid,
        'userText': userText,
        'language': language,
        'schemes': schemes,
      });
      final data = result.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Send a follow-up answer to the server and get updated profile + finalization.
  /// Expects server to return: { updated_profile, updated_additional_attributes, final_eligible_schemes, still_missing_fields, followup_question }
  Future<Map<String, dynamic>?> updateProfileAndFinalize({
    required String callSid,
    required String followupText,
    required String language,
    required List<Map<String, dynamic>> schemes,
    Map<String, dynamic>? existingProfile,
    Map<String, dynamic>? existingAdditionalAttributes,
  }) async {
    try {
      final result = await _updateCallable.call({
        'callSid': callSid,
        'followupText': followupText,
        'language': language,
        'schemes': schemes,
        'existing_profile': existingProfile ?? {},
        'existing_additional_attributes': existingAdditionalAttributes ?? {},
      });
      final data = result.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Generate a short spoken explanation for a scheme.
  Future<String?> generateSchemeDetails({
    required Map<String, dynamic> scheme,
    required String language,
  }) async {
    try {
      final result =
          await _schemeCallable.call({'scheme': scheme, 'language': language});
      final data = result.data;
      if (data is Map && data['text'] != null) return data['text'] as String;
      if (data is String) return data;
      return null;
    } catch (_) {
      return null;
    }
  }
}
