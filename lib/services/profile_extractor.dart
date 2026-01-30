import '../models/user_profile.dart';

/// ProfileExtractor
///
/// Responsibilities:
/// - Extract as many profile fields as possible from arbitrary user text
/// - Never overwrite existing `UserProfile` values (non-destructive updates)
/// - Provide a single source-of-truth function `getNextMissingField`
///   which returns the next missing field in the exact order required by
///   the app: occupation → age → gender → state → district → annualIncome → category
class ProfileExtractor {
  // ------------------ Basic extractors (non-destructive) ------------------
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
    final cleaned = text.toLowerCase();
    if (cleaned.contains('female') || cleaned.contains('woman')) return 'Female';
    if (cleaned.contains('male') && !cleaned.contains('fe')) return 'Male';
    if (cleaned.contains('other') || cleaned.contains('trans')) return 'Other';
    return null;
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
    var cleaned = text.toLowerCase();
    cleaned = cleaned.replaceAll(RegExp(r'[₹,rs\.]'), '');
    final lakhRegex = RegExp(r'(\d+(?:\.\d+)?)\s*lakh');
    final lakhMatch = lakhRegex.firstMatch(cleaned);
    if (lakhMatch != null) {
      final d = double.tryParse(lakhMatch.group(1) ?? '0') ?? 0;
      return (d * 100000).toInt();
    }
    final thousandRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:thousand|k)');
    final tMatch = thousandRegex.firstMatch(cleaned);
    if (tMatch != null) {
      final d = double.tryParse(tMatch.group(1) ?? '0') ?? 0;
      return (d * 1000).toInt();
    }
    final numMatch = RegExp(r'\b(\d{4,8})\b').firstMatch(cleaned);
    if (numMatch != null) {
      final v = int.tryParse(numMatch.group(1) ?? '0') ?? 0;
      if (v >= 10000 && v <= 10000000) return v;
    }
    return null;
  }

  static String? extractCategory(String text) {
    final cleaned = text.toLowerCase();
    if (cleaned.contains('sc') || cleaned.contains('scheduled caste')) return 'SC';
    if (cleaned.contains('st') || cleaned.contains('scheduled tribe')) return 'ST';
    if (cleaned.contains('obc') || cleaned.contains('other backward class')) return 'OBC';
    if (cleaned.contains('general')) return 'General';

    final targetMap = {
      'student': 'student',
      'farmer': 'farmer',
      'woman': 'woman',
      'senior': 'senior_citizen',
      'unemployed': 'unemployed'
    };
    for (final e in targetMap.entries) {
      if (cleaned.contains(e.key)) return e.value;
    }
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
    if ((profile.caste == null && profile.category == null) && parsed['category'] != null) {
      profile.category = parsed['category'] as String?;
    }
  }

  /// The single source-of-truth for deciding the next missing field.
  /// Order (exact): occupation → age → gender → state → district → annualIncome → category
  static String? getNextMissingField(UserProfile profile) {
    if (profile.occupation == null || (profile.occupation?.trim().isEmpty ?? true)) return 'occupation';
    if (profile.age == null) return 'age';
    if (profile.gender == null) return 'gender';
    if (profile.state == null) return 'state';
    if (profile.district == null) return 'district';
    if (profile.annualIncome == null) return 'annualIncome';
    if ((profile.caste == null && profile.category == null)) return 'category';
    return null; // Profile complete
  }
}

