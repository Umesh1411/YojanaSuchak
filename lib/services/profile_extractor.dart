import '../models/user_profile.dart';

/// ProfileExtractor
///
/// Responsibilities:
/// - Extract as many profile fields as possible from arbitrary user text
/// - Handle STT errors and normalize common variations
/// - Never overwrite existing `UserProfile` values (non-destructive updates)
/// - Provide a single source-of-truth function `getNextMissingField`
///   which returns the next missing field in the exact order required by
///   the app: occupation → age → gender → state → district → annualIncome → category
class ProfileExtractor {
  // ============== STT ERROR NORMALIZATION ==============
  /// Normalize common speech-to-text errors in gender field
  /// Handles: mle→male, femail→female, fmale→female, famale→female, mail→male, etc.
  static String? _normalizeGender(String input) {
    final cleaned = input.toLowerCase().trim();
    
    // Normalize common STT errors and variations
    final genderMap = {
      // Male variations (STT errors)
      'mle': 'male',
      'mail': 'male',
      'maal': 'male',
      'mere': 'male',
      'mil': 'male',
      
      // Female variations (STT errors)
      'femail': 'female',
      'fmale': 'female',
      'famale': 'female',
      'femle': 'female',
      'feml': 'female',
      'fmail': 'female',
      
      // Standard forms
      'male': 'male',
      'female': 'female',
      'man': 'male',
      'woman': 'female',
      'boy': 'male',
      'girl': 'female',
      'm': 'male',
      'f': 'female',
      
      // Other/Third gender variations
      'other': 'other',
      'third': 'other',
      'trans': 'other',
      'transgender': 'other',
      'prefer not': 'other',
    };
    
    for (final entry in genderMap.entries) {
      if (cleaned.contains(entry.key)) {
        final v = entry.value;
        if (v == 'male') return 'Male';
        if (v == 'female') return 'Female';
        return 'Other';
      }
    }
    return null;
  }

  /// Normalize income input (handles various formats and STT errors)
  /// Supports: "5 lakh", "5 lakh rupees", "5 thousand", "5k", "50000", etc.
  static int? _normalizeIncome(String input) {
    var cleaned = input.toLowerCase();
    // Remove currency markers but keep words like 'lakh'/'thousand'
    cleaned = cleaned.replaceAll(RegExp(r'[₹,]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'rs\.?'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    // Lakh format (100,000 units)
    // Handles: "5 lakh", "5lakh", "5 lakh rupees", etc.
    final lakhRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:lakh|lac)');
    final lakhMatch = lakhRegex.firstMatch(cleaned);
    if (lakhMatch != null) {
      final d = double.tryParse(lakhMatch.group(1) ?? '0') ?? 0;
      return (d * 100000).toInt();
    }
    
    // Thousand/K format
    // Handles: "5 thousand", "5 k", "5k", "5000", "5th", etc.
    final thousandRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:thousand|k|th)');
    final tMatch = thousandRegex.firstMatch(cleaned);
    if (tMatch != null) {
      final d = double.tryParse(tMatch.group(1) ?? '0') ?? 0;
      return (d * 1000).toInt();
    }
    
    // Direct 4-8 digit number
    final numMatch = RegExp(r'\b(\d{4,8})\b').firstMatch(cleaned);
    if (numMatch != null) {
      final v = int.tryParse(numMatch.group(1) ?? '0') ?? 0;
      if (v >= 10000 && v <= 10000000) return v;
    }
    
    
    // Support simple spoken-word numbers like "five thousand", "two lakh"
    final wordNumMatch = RegExp(r"(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)\s*(lakh|lac|thousand|k)?").firstMatch(cleaned);
    if (wordNumMatch != null) {
      final word = wordNumMatch.group(1) ?? '';
      final unit = wordNumMatch.group(2);
      final words = {
        'one': 1,
        'two': 2,
        'three': 3,
        'four': 4,
        'five': 5,
        'six': 6,
        'seven': 7,
        'eight': 8,
        'nine': 9,
        'ten': 10,
        'eleven': 11,
        'twelve': 12,
        'thirteen': 13,
        'fourteen': 14,
        'fifteen': 15,
        'sixteen': 16,
        'seventeen': 17,
        'eighteen': 18,
        'nineteen': 19,
        'twenty': 20,
        'thirty': 30,
        'forty': 40,
        'fifty': 50,
        'sixty': 60,
        'seventy': 70,
        'eighty': 80,
        'ninety': 90,
      };
      final base = words[word] ?? 0;
      if (unit == null) return base;
      if (unit.startsWith('l')) return base * 100000;
      return base * 1000;
    }

    return null;
  }

  // ============== BASIC EXTRACTORS (NON-DESTRUCTIVE) ==============
  static int? extractAge(String text) {
    final cleaned = text.toLowerCase();
    final numberRegex = RegExp(r'\b(\d{1,3})\b');
    final match = numberRegex.firstMatch(cleaned);
    if (match != null) {
      final v = int.tryParse(match.group(1) ?? '');
      if (v != null && v > 0 && v < 150) return v;
    }

    // Simple word-based mapping (basic support)
    final wordNumbers = {
      'eighteen': 18,
      'nineteen': 19,
      'twenty': 20,
      'thirty': 30,
      'forty': 40,
      'fifty': 50,
      'sixty': 60,
    };
    for (final e in wordNumbers.entries) {
      if (cleaned.contains(e.key)) return e.value;
    }
    return null;
  }

  static String? extractGender(String text) {
    final normalized = _normalizeGender(text);
    return normalized;
  }

  static String? extractState(String text) {
    final cleaned = text.toLowerCase();
    final states = ['maharashtra', 'gujarat', 'karnataka', 'delhi', 'goa'];
    for (final s in states) {
      if (cleaned.contains(s)) return s[0].toUpperCase() + s.substring(1);
    }
    return null;
  }

  static String? extractDistrict(String text) {
    final cleaned = text.toLowerCase();
    final districts = [
      'mumbai',
      'pune',
      'nagpur',
      'nashik',
      'aurangabad',
      'solapur',
      'thane',
      'jalgaon',
      'kolhapur'
    ];
    for (final d in districts) {
      if (cleaned.contains(d)) return d.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    }
    return null;
  }

  static int? extractIncome(String text) {
    return _normalizeIncome(text);
  }

  static String? extractCategory(String text) {
    // ONLY detect caste/category (SC/ST/OBC/General). Do NOT map occupation/target groups here.
    final cleaned = text.toLowerCase();
    if (cleaned.contains('sc') || cleaned.contains('scheduled caste')) return 'SC';
    if (cleaned.contains('st') || cleaned.contains('scheduled tribe')) return 'ST';
    if (cleaned.contains('obc') || cleaned.contains('other backward class')) return 'OBC';
    if (cleaned.contains('general')) return 'General';
    return null;
  }

  static String? extractOccupation(String text) {
    final cleaned = text.toLowerCase();
    final map = {
      'teacher': 'Teacher',
      'farmer': 'Farmer',
      'student': 'Student',
      'engineer': 'Engineer',
      'doctor': 'Doctor',
      'business': 'Business',
      'government': 'Government Employee',
      'unemployed': 'Unemployed',
      'labour': 'Labour',
    };
    for (final e in map.entries) {
      if (cleaned.contains(e.key)) return e.value;
    }
    return null;
  }

  /// Extract special conditions like widow, disabled, elderly
  static String? extractSpecialCondition(String text) {
    final cleaned = text.toLowerCase();
    if (cleaned.contains('widow') || cleaned.contains('widowed')) return 'widow';
    if (cleaned.contains('disabled') || cleaned.contains('disability') || cleaned.contains('divyang')) return 'disabled';
    if (cleaned.contains('senior') || cleaned.contains('elderly') || cleaned.contains('aged')) return 'elderly';
    return null;
  }

  // ============== LANGUAGE & MULTI-FIELD DETECTION ==============
  /// Detect user's likely language from input text (Hindi, Marathi, or English)
  /// Returns 'hi', 'mr', or 'en'
  static String detectLanguage(String text) {
    final devanagariScript = RegExp(r'[\u0900-\u097F]');
    
    // Count Devanagari characters (used in both Hindi and Marathi)
    final devanagariCount = devanagariScript.allMatches(text).length;
    
    // If significant Devanagari presence, default to Hindi (more common)
    if (devanagariCount > text.length * 0.3) {
      return 'hi'; // Could be more sophisticated with word lists
    }
    
    // Check for Marathi-specific words if needed
    // For now, default to Hindi for any Devanagari
    if (devanagariCount > 0) {
      return 'hi';
    }
    
    // Default to English
    return 'en';
  }

  /// Extract multiple fields from a single message (e.g., age, gender, income all in one)
  /// Returns a map with all successfully extracted fields
  /// This is more aggressive than extractAll() and looks for patterns more carefully
  static Map<String, dynamic> extractMultipleFields(String text) {
    final result = <String, dynamic>{};
    
    // Age: Look for "year old" or just numbers with context
    final ageMatch = RegExp(r'(\d{1,3})\s*(?:year|yr|years|yrs)\s*old').firstMatch(text.toLowerCase());
    if (ageMatch != null) {
      final age = int.tryParse(ageMatch.group(1) ?? '');
      if (age != null && age > 0 && age < 150) {
        result['age'] = age;
      }
    } else {
      final age = extractAge(text);
      if (age != null) result['age'] = age;
    }
    
    // Gender: Use existing extractor
    final gender = extractGender(text);
    if (gender != null) result['gender'] = gender;
    
    // Occupation: Use existing extractor
    final occupation = extractOccupation(text);
    if (occupation != null) result['occupation'] = occupation;
    
    // State and District: Use existing extractors
    final state = extractState(text);
    if (state != null) result['state'] = state;
    
    final district = extractDistrict(text);
    if (district != null) result['district'] = district;
    
    // Income: Use existing extractor
    final income = extractIncome(text);
    if (income != null) result['annualIncome'] = income;
    
    // Category: Use existing extractor
    final category = extractCategory(text);
    if (category != null) result['category'] = category;
    
    return result;
  }

  // ------------------ High-level helpers ------------------
  /// Extract as many fields as possible from `text` and return a small map.
  /// This does NOT modify the provided profile.
  static Map<String, dynamic> extractAll(String text) {
    return {
      'age': extractAge(text),
      'gender': extractGender(text),
      'state': extractState(text),
      'district': extractDistrict(text),
      'annualIncome': extractIncome(text),
      'category': extractCategory(text),
      'occupation': extractOccupation(text),
      'specialCondition': extractSpecialCondition(text),
    };
  }

  /// Apply parsed values to profile WITHOUT overwriting existing values.
  static void applyParsedToProfile(UserProfile profile, Map<String, dynamic> parsed) {
    if (profile.occupation == null && parsed['occupation'] != null) {
      profile.occupation = parsed['occupation'] as String?;
    }
    if (profile.age == null && parsed['age'] != null) {
      profile.age = parsed['age'] as int?;
    }
    if (profile.gender == null && parsed['gender'] != null) {
      profile.gender = parsed['gender'] as String?;
    }
    if (profile.state == null && parsed['state'] != null) {
      profile.state = parsed['state'] as String?;
    }
    if (profile.district == null && parsed['district'] != null) {
      profile.district = parsed['district'] as String?;
    }
    if (profile.annualIncome == null && parsed['annualIncome'] != null) {
      profile.annualIncome = parsed['annualIncome'] as int?;
    }
    // If parser detected caste (SC/ST/OBC/General), store in `caste` only.
    if (profile.caste == null && parsed['category'] != null) {
      profile.caste = parsed['category'] as String?;
    }
    if (profile.specialCondition == null && parsed['specialCondition'] != null) {
      profile.specialCondition = parsed['specialCondition'] as String?;
    }
  }

  /// The single source-of-truth for deciding the next missing field.
  /// Order (exact): occupation → age → gender → state → district → annualIncome → category
  static String? getNextMissingField(UserProfile profile) {
    if (profile.occupation == null || (profile.occupation?.trim().isEmpty ?? true)) return 'occupation';
    if (profile.age == null) return 'age';
    if (profile.gender == null) return 'gender';
    // Combine state/district into single 'location' question
    if (profile.state == null || profile.district == null) return 'location';
    if (profile.annualIncome == null) return 'annualIncome';
    return null; // Profile sufficiently complete for many schemes
  }
}

