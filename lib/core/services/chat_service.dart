import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gemini_service.dart';
import 'package:yojana_suchak/core/services/scheme_recommender.dart';

/// Consolidated ChatService that provides:
/// - one-question follow-up logic
/// - a small chat-like getChatResponse that uses the recommender when possible
/// - server-side Gemini wrapper via `GeminiService`
class ChatService {
  final GeminiService _gemini;
  bool isAvailable = false;

  ChatService({GeminiService? gemini}) : _gemini = gemini ?? GeminiService();

  Future<void> initialize() async {
    // Check server-side callable availability with a lightweight probe
    try {
      final resp = await _gemini.getFollowUpQuestion(
          userProblem: 'availability_check', missingFields: [], lang: 'en');
      // If we get any response (even a fallback), consider the service available
      isAvailable = resp != null;
    } catch (e) {
      isAvailable = false;
    }
  }

  List<String> missingFields(Map<String, dynamic> profile) {
    final needed = <String>[
      'age',
      'gender',
      'income',
      'occupation',
      'category'
    ];
    final flags = ['student', 'farmer', 'woman', 'seniorCitizen', 'disability'];
    needed.addAll(flags);

    final missing = <String>[];
    for (final f in needed) {
      if (!profile.containsKey(f) ||
          profile[f] == null ||
          profile[f].toString().isEmpty) {
        missing.add(f);
      }
    }
    return missing;
  }

  String? detectSectorFromProblem(String problem) {
    final p = problem.toLowerCase();
    final mapping = {
      'education': [
        'student',
        'fees',
        'education',
        'scholarship',
        'college',
        'school'
      ],
      'health': ['health', 'medical', 'hospital', 'treatment', 'medicine'],
      'employment': ['job', 'employment', 'salary', 'wage', 'work'],
      'agriculture': [
        'farmer',
        'farming',
        'crop',
        'agriculture',
        'kisan',
        'shivar'
      ],
      'women': ['women', 'female', 'girl', 'ladki']
    };
    for (final entry in mapping.entries) {
      for (final kw in entry.value) {
        if (p.contains(kw)) return entry.key;
      }
    }
    return null;
  }

  Future<String> nextQuestion(
      String userProblem, Map<String, dynamic> profile, Locale locale) async {
    // Ensure sector asked first
    if (!profile.containsKey('sector') ||
        profile['sector'] == null ||
        profile['sector'].toString().isEmpty) {
      final inferred = detectSectorFromProblem(userProblem);
      if (inferred != null) {
        profile['sector'] = inferred;
      } else {
        return _localizedSectorQuestion(locale.languageCode);
      }
    }

    final missing = missingFields(profile);
    if (missing.isEmpty) return '';

    // Try server-side Gemini callable
    try {
      final g = await _gemini.getFollowUpQuestion(
          userProblem: userProblem,
          missingFields: missing,
          lang: locale.languageCode,
          sector: profile['sector']);
      if (g != null && g.trim().isNotEmpty) return g.trim();
    } catch (e) {
      // ignore and fallback
    }

    // Local fallback
    return _generateFallbackQuestion(userProblem, missing, locale.languageCode);
  }

  String _localized(String text, String lang) {
    // Minimal translations for the quick questions
    final map = {
      'Are you currently a student?': {
        'en': 'Are you currently a student? ',
        'hi': 'क्या आप वर्तमान में छात्र/छात्रा हैं?',
        'mr': 'आप सध्या विद्यार्थी आहात का?'
      },
      'What is your age?': {
        'en': 'What is your age?',
        'hi': 'आपकी आयु क्या है?',
        'mr': 'आपची वय किती आहे?'
      },
      'What is your monthly/annual income? (approx.)': {
        'en': 'What is your monthly/annual income? (approx.)',
        'hi': 'आपकी मासिक/वार्षिक आय क्या है? (लगभग)',
        'mr': 'आपले मासिक/वार्षिक उत्पन्न किती आहे? (सुमारे)'
      },
      'What is your occupation?': {
        'en': 'What is your occupation?',
        'hi': 'आपका पेशा क्या है?',
        'mr': 'आपचे व्यवसाय काय आहे?'
      },
      'Which category do you belong to? (General/SC/ST/OBC)': {
        'en': 'Which category do you belong to? (General/SC/ST/OBC)',
        'hi': 'आप किस श्रेणी से हैं? (General/SC/ST/OBC)',
        'mr': 'आप कोणत्या वर्गात आहात? (General/SC/ST/OBC)'
      },
      'What is your gender?': {
        'en': 'What is your gender?',
        'hi': 'आपका लिंग क्या है?',
        'mr': 'आपले लिंग काय आहे?'
      },
      'Are you a student? (yes/no)': {
        'en': 'Are you a student? (yes/no)',
        'hi': 'क्या आप छात्र/छात्रा हैं? (हाँ/नहीं)',
        'mr': 'आप विद्यार्थी आहात का? (होय/नाही)'
      },
      'Are you a farmer? (yes/no)': {
        'en': 'Are you a farmer? (yes/no)',
        'hi': 'क्या आप किसान हैं? (हाँ/नहीं)',
        'mr': 'आप शेतकरी आहात का? (होय/नाही)'
      },
      'Are you a woman? (yes/no)': {
        'en': 'Are you a woman? (yes/no)',
        'hi': 'क्या आप महिला हैं? (हाँ/नहीं)',
        'mr': 'आप स्त्री आहात का? (होय/नाही)'
      },
      'Are you a senior citizen (60+)? (yes/no)': {
        'en': 'Are you a senior citizen (60+)? (yes/no)',
        'hi': 'क्या आप 60+ वरिष्ठ नागरिक हैं? (हाँ/नहीं)',
        'mr': 'आप 60+ वरिष्ठ नागरिक आहात का? (होय/नाही)'
      },
      'Do you have any disability? (yes/no)': {
        'en': 'Do you have any disability? (yes/no)',
        'hi': 'क्या आपको कोई विकलांगता है? (हाँ/नहीं)',
        'mr': 'आपला काही अपंगत्व आहे का? (होय/नाही)'
      },
      'Please provide more details about your problem.': {
        'en': 'Please provide more details about your problem.',
        'hi': 'कृपया अपनी समस्या के बारे में और जानकारी दें।',
        'mr': 'कृपया आपल्या समस्येबद्दल अधिक माहिती द्या.'
      },
      'Which sector is this problem related to? (Education/Health/Employment/Agriculture/Other)':
          {
        'en':
            'Which sector is this problem related to? (Education/Health/Employment/Agriculture/Other)',
        'hi':
            'यह समस्या किन क्षेत्रों से संबंधित है? (शिक्षा/स्वास्थ्य/रोज़गार/कृषि/अन्य)',
        'mr':
            'ही समस्या कोणत्या क्षेत्राशी निगडीत आहे? (शिक्षण/आरोग्य/रोजगार/कृषी/इतर)'
      }
    };

    if (map.containsKey(text))
      return map[text]?[lang] ?? map[text]?['en'] ?? text;
    return text;
  }

  String _localizedSectorQuestion(String lang) {
    return _localized(
        'Which sector is this problem related to? (Education/Health/Employment/Agriculture/Other)',
        lang);
  }

  String _generateFallbackQuestion(
      String userProblem, List<String> missingFields, String lang) {
    final p = userProblem.toLowerCase();
    if (p.contains('student') ||
        p.contains('education') ||
        p.contains('fees')) {
      if (missingFields.contains('student'))
        return _localized('Are you currently a student?', lang);
      if (missingFields.contains('age'))
        return _localized('What is your age?', lang);
      if (missingFields.contains('income'))
        return _localized(
            'What is your monthly/annual income? (approx.)', lang);
    }

    if (p.contains('health') || p.contains('medical')) {
      if (missingFields.contains('seniorCitizen'))
        return _localized('Are you a senior citizen (60+)? (yes/no)', lang);
      if (missingFields.contains('disability'))
        return _localized('Do you have any disability? (yes/no)', lang);
      if (missingFields.contains('age'))
        return _localized('What is your age?', lang);
    }

    final order = [
      'sector',
      'occupation',
      'age',
      'income',
      'category',
      'gender',
      'student',
      'farmer',
      'woman',
      'seniorCitizen',
      'disability'
    ];
    for (final f in order) {
      if (missingFields.contains(f)) {
        switch (f) {
          case 'occupation':
            return _localized('What is your occupation?', lang);
          case 'age':
            return _localized('What is your age?', lang);
          case 'income':
            return _localized(
                'What is your monthly/annual income? (approx.)', lang);
          case 'category':
            return _localized(
                'Which category do you belong to? (General/SC/ST/OBC)', lang);
          case 'gender':
            return _localized('What is your gender?', lang);
          case 'student':
            return _localized('Are you a student? (yes/no)', lang);
          case 'farmer':
            return _localized('Are you a farmer? (yes/no)', lang);
          case 'woman':
            return _localized('Are you a woman? (yes/no)', lang);
          case 'seniorCitizen':
            return _localized('Are you a senior citizen (60+)? (yes/no)', lang);
          case 'disability':
            return _localized('Do you have any disability? (yes/no)', lang);
          default:
            return _localized('Please provide your $f.', lang);
        }
      }
    }

    return _localized('Please provide more details about your problem.', lang);
  }

  /// Lightweight chat-like behavior used by UI screens.
  /// If profile has enough info -> return recommendations summary (via recommender)
  /// Otherwise return a single follow-up question.
  Future<String?> getChatResponse({
    required String userMessage,
    required Map<String, dynamic> profile,
    required List<dynamic> availableSchemes,
  }) async {
    // If profile looks complete, ask recommender for top 3
    final missing = missingFields(profile);
    if (missing.isEmpty) {
      final rec =
          await SchemeRecommender().recommend(profile, locale: Locale('en'));
      final recList =
          (rec['recommendations'] as List).cast<Map<String, dynamic>>();
      // Build a short user-facing message
      final msgs = recList
          .map((r) => '- ${r['schemeName']}: ${r['reason'] ?? ''}')
          .take(3)
          .join('\n');
      final msg = recList.isEmpty
          ? 'Sorry, no schemes match your profile.'
          : 'Here are some schemes that may help you:\n$msgs';
      return msg;
    }

    // Otherwise ask a follow-up question
    final q = await nextQuestion(userMessage, profile, Locale('en'));
    return q;
  }
}
