import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service to recommend schemes based on user profile.
///
/// - Fetches active Maharashtra schemes from Firestore
/// - Matches eligibility against provided profile
/// - Returns EXACTLY 3 recommendations in the required JSON structure
class SchemeRecommender {
  final FirebaseFirestore? _firestore;

  SchemeRecommender({FirebaseFirestore? firestore}) : _firestore = firestore;

  /// Fetch schemes from Firestore where state == 'Maharashtra' and isActive == true
  Future<List<Map<String, dynamic>>> fetchActiveMaharashtraSchemes() async {
    if (_firestore == null) {
      // Firestore not available (unit tests or offline). Return empty list.
      return [];
    }

    final snapshot = await _firestore!
        .collection('schemes')
        .where('state', isEqualTo: 'Maharashtra')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((d) => d.data()..['id'] = d.id)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Main entry: recommend schemes for the profile and return EXACT JSON structure.
  /// profile should contain: age, gender, income, occupation, category, disability (bool), farmer, student, woman, seniorCitizen
  Future<Map<String, dynamic>> recommend(Map<String, dynamic> profile,
      {Locale? locale}) async {
    locale ??= Locale('en', 'IN');
    final schemes = await fetchActiveMaharashtraSchemes();
    final recs = recommendFromProfile(profile, schemes, locale);

    return {'recommendations': recs};
  }

  /// Pure function: given list of schemes and a profile, return top 3 recommendations
  List<Map<String, dynamic>> recommendFromProfile(Map<String, dynamic> profile,
      List<Map<String, dynamic>> schemes, Locale locale) {
    final scored = <Map<String, dynamic>>[];

    for (final scheme in schemes) {
      final score = _scoreSchemeForProfile(scheme, profile);
      scored.add({'scheme': scheme, 'score': score});
    }

    scored.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));

    final top = scored.take(3).map((entry) {
      final scheme = Map<String, dynamic>.from(entry['scheme']);
      final score = entry['score'] as num;

      final schemeName = _localizedString(scheme, 'schemeName', locale);
      final benefits = _localizedList(scheme, 'benefits', locale);
      final reason = _buildReason(scheme, profile, score, locale);

      return {
        'schemeId': scheme['id'] ?? schemeName,
        'schemeName': schemeName,
        'reason': reason,
        'keyBenefits': benefits,
      };
    }).toList();

    // If fewer than 3 schemes available, pad with empty entries (keeps format predictable)
    while (top.length < 3) {
      top.add({'schemeName': '', 'reason': '', 'keyBenefits': []});
    }

    return top.cast<Map<String, dynamic>>();
  }

  num _scoreSchemeForProfile(
      Map<String, dynamic> scheme, Map<String, dynamic> profile) {
    num score = 0;

    final eligibility = scheme['eligibility'] as Map<String, dynamic>? ?? {};

    // Age
    final userAge = profile['age'] as int?;
    if (userAge != null) {
      final minAge = eligibility['minAge'] as int?;
      final maxAge = eligibility['maxAge'] as int?;
      if (minAge != null && maxAge != null) {
        if (userAge >= minAge && userAge <= maxAge) score += 20;
      } else if (minAge != null) {
        if (userAge >= minAge) score += 10;
      } else if (maxAge != null) {
        if (userAge <= maxAge) score += 10;
      }
    }

    // Gender
    final userGender = (profile['gender'] ?? '').toString().toLowerCase();
    final genderReq = (eligibility['gender'] ?? '').toString().toLowerCase();
    if (genderReq.isNotEmpty) {
      if (userGender == genderReq) score += 15;
    } else {
      score += 2; // small boost for general eligibility
    }

    // Income
    final userIncome = _toNum(profile['income']);
    final incomeLimit = _toNum(eligibility['incomeLimit']);
    if (incomeLimit != null && userIncome != null) {
      if (userIncome <= incomeLimit) score += 20;
    }

    // Occupation
    final userOcc = (profile['occupation'] ?? '').toString().toLowerCase();
    final occReq = (eligibility['occupation'] ?? '').toString().toLowerCase();
    if (occReq.isNotEmpty) {
      if (userOcc == occReq) score += 15;
    }

    // Category
    final userCat = (profile['category'] ?? '').toString().toLowerCase();
    final catReq = (eligibility['category'] ?? '').toString().toLowerCase();
    if (catReq.isNotEmpty) {
      if (userCat == catReq) score += 20;
    }

    // Disability
    final userDis = profile['disability'] == true;
    final disReq = eligibility['disabilityRequired'] == true;
    if (disReq && userDis) score += 25;

    // Sector match (high priority)
    final userSector = (profile['sector'] ?? '').toString().toLowerCase();
    final schemeSector = (scheme['sector'] ?? '').toString().toLowerCase();
    final schemeSectors = <String>[];
    if (scheme['sectors'] is List) {
      schemeSectors.addAll(
          (scheme['sectors'] as List).map((e) => e.toString().toLowerCase()));
    }
    if (schemeSector.isNotEmpty) schemeSectors.add(schemeSector);

    if (userSector.isNotEmpty && schemeSectors.contains(userSector)) {
      score += 30; // big boost for sector match
    } else if (userSector.isNotEmpty && schemeSectors.isEmpty) {
      // Try to infer scheme sector from its name, benefits or description if not provided
      final name = (scheme['schemeName'] ?? '').toString().toLowerCase();
      final benefitsText = (scheme['benefits'] ?? '').toString().toLowerCase();
      final desc = (scheme['description'] ?? '').toString().toLowerCase();
      final combined = '$name $benefitsText $desc';
      final mapping = {
        'education': [
          'student',
          'education',
          'scholarship',
          'fees',
          'school',
          'college'
        ],
        'health': ['health', 'hospital', 'medical', 'treatment', 'medicine'],
        'employment': ['job', 'employment', 'skill', 'training', 'salary'],
        'agriculture': ['farmer', 'crop', 'agriculture', 'kisan', 'soil'],
        'women': ['woman', 'female', 'women', 'ladki']
      };

      for (final entry in mapping.entries) {
        for (final kw in entry.value) {
          if (combined.contains(kw)) {
            if (entry.key == userSector)
              score += 25; // slightly lower boost for inferred match
            break;
          }
        }
      }
    }

    // Flags: farmer/student/woman/senior
    final flagKeys = ['farmer', 'student', 'woman', 'seniorCitizen'];
    for (final k in flagKeys) {
      final userFlag = profile[k] == true;
      final schemeFlag = (eligibility[k] == true);
      if (schemeFlag && userFlag) score += 10;
    }

    return score;
  }

  num? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  String _buildReason(Map<String, dynamic> scheme, Map<String, dynamic> profile,
      num score, Locale locale) {
    // Build concise 2-3 sentence reason in the requested language
    final lang = locale.languageCode;
    final reasons = <String>[];

    final eligibility = scheme['eligibility'] as Map<String, dynamic>? ?? {};

    // Age reason
    final userAge = profile['age'] as int?;
    final minAge = eligibility['minAge'] as int?;
    final maxAge = eligibility['maxAge'] as int?;
    if (userAge != null &&
        minAge != null &&
        maxAge != null &&
        userAge >= minAge &&
        userAge <= maxAge) {
      reasons.add(_localizedText(lang, 'age_match',
          args: {'min': minAge.toString(), 'max': maxAge.toString()}));
    }

    // Category
    final userCat = (profile['category'] ?? '').toString();
    final catReq = (eligibility['category'] ?? '').toString();
    if (catReq.isNotEmpty && userCat.toLowerCase() == catReq.toLowerCase()) {
      reasons.add(
          _localizedText(lang, 'category_match', args: {'category': userCat}));
    }

    // Income
    final userIncome = _toNum(profile['income']);
    final incomeLimit = _toNum(eligibility['incomeLimit']);
    if (incomeLimit != null &&
        userIncome != null &&
        userIncome <= incomeLimit) {
      reasons.add(_localizedText(lang, 'income_match',
          args: {'limit': incomeLimit.toString()}));
    }

    // Sector reason
    final userSector = (profile['sector'] ?? '').toString();
    final schemeSector = (scheme['sector'] ?? '')..toString();
    if (userSector.isNotEmpty &&
        schemeSector.toString().isNotEmpty &&
        userSector.toLowerCase() == schemeSector.toString().toLowerCase()) {
      reasons.add(
          _localizedText(lang, 'sector_match', args: {'sector': userSector}));
    }

    // If none of the above, give a generic reason based on score
    if (reasons.isEmpty) {
      reasons.add(_localizedText(lang, 'general_match'));
    }

    // Join into 2-3 sentences
    final joined = reasons.join(' ');

    return joined;
  }

  String _localizedText(String lang, String key, {Map<String, String>? args}) {
    // Minimal localization for reasons (English, Hindi, Marathi)
    final templates = {
      'en': {
        'age_match':
            'You fall within the eligible age range (${args?['min']}-${args?['max']}).',
        'category_match':
            'This scheme targets ${args?['category']} category, which matches your profile.',
        'income_match':
            'Your income falls within the eligible limit (<= ₹${args?['limit']}).',
        'general_match':
            'This scheme is suitable based on your profile and provides relevant benefits.',
        'sector_match':
            'This scheme matches your sector: ${args?['sector']}, so it is highly relevant.'
      },
      'hi': {
        'age_match':
            'आप योग्य आयु सीमा (${args?['min']}-${args?['max']}) में आते हैं।',
        'category_match':
            'यह योजना ${args?['category']} वर्ग को लक्षित करती है, जो आपकी प्रोफ़ाइल से मेल खाती है।',
        'income_match':
            'आपकी आय पात्रता सीमा (<= ₹${args?['limit']}) के भीतर है।',
        'general_match':
            'आपकी प्रोफ़ाइल के आधार पर यह योजना उपयुक्त है और उपयोगी लाभ प्रदान करती है।',
        'sector_match':
            'यह योजना आपके क्षेत्र के अनुरूप है: ${args?['sector']}, इसलिए यह बहुत प्रासंगिक है।'
      },
      'mr': {
        'age_match':
            'आप पात्र वयोमर्यादेत (${args?['min']}-${args?['max']}) यातील आहेत.',
        'category_match':
            'ही योजने ${args?['category']} वर्गासाठी आहे, जी आपल्या प्रोफाइलशी जुळते.',
        'income_match':
            'आपली उत्पन्न पात्र मर्यादेत (<= ₹${args?['limit']}) आहे.',
        'general_match':
            'आपल्या प्रोफाइलच्या आधारावर ही योजना उपयुक्त आहे आणि संबंधित लाभ देते.',
        'sector_match':
            'ही योजना आपल्या क्षेत्राशी जुळते: ${args?['sector']}, म्हणून ही अत्यंत संबंधित आहे.'
      }
    };

    final map = templates[lang] ?? templates['en']!;
    return map[key] ?? map['general_match']!;
  }

  String _localizedString(
      Map<String, dynamic> map, String baseKey, Locale locale) {
    final lang = locale.languageCode;
    final keyWithLang = '${baseKey}_$lang';
    if (map.containsKey(keyWithLang)) return map[keyWithLang].toString();
    if (map.containsKey(baseKey)) return map[baseKey].toString();
    return '';
  }

  List<String> _localizedList(
      Map<String, dynamic> map, String baseKey, Locale locale) {
    final lang = locale.languageCode;
    final keyWithLang = '${baseKey}_$lang';
    if (map.containsKey(keyWithLang) && map[keyWithLang] is List)
      return List<String>.from(map[keyWithLang]);
    if (map.containsKey(baseKey) && map[baseKey] is List)
      return List<String>.from(map[baseKey]);
    // Fallback: if benefits is a string, return single item
    if (map.containsKey(baseKey) && map[baseKey] is String)
      return [map[baseKey]];
    return [];
  }

  /// Generate a short chat-like summary message for the recommended schemes in the user's language.
  String generateChatMessage(List<Map<String, dynamic>> recommendations,
      Map<String, dynamic> profile, Locale locale) {
    final lang = locale.languageCode;

    if (recommendations.isEmpty) {
      switch (lang) {
        case 'hi':
          return 'क्षमा करें, आपके लिए कोई उपयुक्त योजना नहीं मिली।';
        case 'mr':
          return 'क्षमस्व, आपल्यासाठी काही योजना सापडल्या नाहीत.';
        default:
          return 'Sorry, no suitable schemes were found for you.';
      }
    }

    final schemeNames = recommendations
        .map((r) => r['schemeName'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    switch (lang) {
      case 'hi':
        return 'मैंने शीर्ष योजनाएँ सुझायी हैं: ${schemeNames.join(', ')}. क्या आप इनमें से किसी को सेव करना चाहेंगे? अगर हाँ, तो ईमेल पता दें ताकि हम विवरण भेज सकें।';
      case 'mr':
        return 'मी शीर्ष योजना सुचवल्या आहेत: ${schemeNames.join(', ')}. आपण यापैकी कोणतीही जतन करू इच्छिता? होय असल्यास, विवरण पाठविण्यासाठी ईमेल द्या.';
      default:
        return 'I have suggested the top schemes: ${schemeNames.join(', ')}. Would you like to save any of these? If yes, provide an email address to send details.';
    }
  }
}
