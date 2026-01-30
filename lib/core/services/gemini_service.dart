import 'package:cloud_functions/cloud_functions.dart';

/// Small wrapper to call server-side callable function that provides a
/// single follow-up question (or a short response) using server-side Gemini
/// or deterministic fallback.
class GeminiService {
  final HttpsCallable _callable =
      FirebaseFunctions.instance.httpsCallable('getGeminiResponse');

  /// Calls the server-side callable with provided context and returns the question string
  Future<String?> getFollowUpQuestion({
    required String userProblem,
    required List<String> missingFields,
    required String lang,
    String? sector,
  }) async {
    try {
      final result = await _callable.call({
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
    } catch (e) {
      // Network or callable error - return null so caller can fallback locally
      return null;
    }
  }
}
