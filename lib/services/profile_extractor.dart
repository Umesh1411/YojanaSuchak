import '../models/user_profile.dart';

/// Service for extracting user profile information from voice transcript
/// NOTE: This utility no longer depends on a conversation state enum.
/// Use `updateProfileFromText` to non-destructively add parsed fields to a UserProfile.
class ProfileExtractor {
  // ----------------------
  // Normalization helpers
  // ----------------------
  static String _titleCase(String input) {
    final s = input.trim();
    if (s.isEmpty) return s;
    return s
        .split(RegExp(r'\s+'))
        .map((w) =>
            w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1).toLowerCase()))
        .join(' ');
  }

  static String? _normalizeGender(String? input) {
    if (input == null) return null;
    final lower = input.toLowerCase();
    if (lower.contains('female') || lower.contains('woman')) return 'Female';
    if (lower.contains('male') || lower.contains('man')) return 'Male';
    if (lower.contains('other') || lower.contains('trans')) return 'Other';
    return _titleCase(input);
  }

  static String? _normalizeState(String? input) {
    if (input == null) return null;
    return _titleCase(input);
  }

  static String? _normalizeDistrict(String? input) {
    if (input == null) return null;
    return _titleCase(input);
  }

  static String? _normalizeOccupation(String? input) {
    if (input == null) return null;
    return _titleCase(input);
  }

  static String? _normalizeCategory(String? input) {
    if (input == null) return null;
    final lower = input.toLowerCase().trim();
    if (lower.contains('sc') || lower.contains('scheduled caste')) {
      return 'SC';
    }
    if (lower.contains('st') || lower.contains('scheduled tribe')) {
      return 'ST';
    }
    if (lower.contains('obc') || lower.contains('other backward class')) {
      return 'OBC';
    }
    if (lower.contains('general')) {
      return 'General';
    }
    // target groups like 'student','farmer' keep as lower-case for matching
    return lower;
  }

  /// Extract age from text
  /// Handles both numeric (e.g., "25", "thirty five") and word forms
  static int? extractAge(String text) {
    // Remove non-alphanumeric except spaces
    String cleaned = text.toLowerCase().trim();

    // Try to find numbers
    RegExp numberRegex = RegExp(r'\b(\d{1,3})\b');
    Match? match = numberRegex.firstMatch(cleaned);
    if (match != null) {
      int age = int.tryParse(match.group(1) ?? '') ?? 0;
      if (age > 0 && age < 150) {
        return age;
      }
    }

    // Word number mapping (basic)
    Map<String, int> wordNumbers = {
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

    for (var entry in wordNumbers.entries) {
      if (cleaned.contains(entry.key)) {
        // Try to extract compound numbers like "twenty five"
        RegExp compound = RegExp('${entry.key}\\s*(\\w+)');
        Match? compoundMatch = compound.firstMatch(cleaned);
        if (compoundMatch != null) {
          String secondPart = compoundMatch.group(1) ?? '';
          Map<String, int> units = {
            'one': 1,
            'two': 2,
            'three': 3,
            'four': 4,
            'five': 5,
            'six': 6,
            'seven': 7,
            'eight': 8,
            'nine': 9,
          };
          if (units.containsKey(secondPart)) {
            return entry.value + units[secondPart]!;
          }
        }
        return entry.value;
      }
    }

    return null;
  }

  /// Extract state from text
  static String? extractState(String text) {
    String cleaned = text.toLowerCase().trim();

    if (cleaned.contains('maharashtra')) {
      return 'Maharashtra';
    }

    // Add other states if needed
    List<String> states = ['maharashtra', 'gujarat', 'karnataka', 'goa'];
    for (var state in states) {
      if (cleaned.contains(state)) {
        return state[0].toUpperCase() + state.substring(1);
      }
    }

    return null;
  }

  /// Extract gender from text
  static String? extractGender(String text) {
    String cleaned = text.toLowerCase().trim();

    if (cleaned.contains('male') && !cleaned.contains('fe')) {
      return 'Male';
    } else if (cleaned.contains('female') || cleaned.contains('woman')) {
      return 'Female';
    } else if (cleaned.contains('other') || cleaned.contains('trans')) {
      return 'Other';
    }

    return null;
  }

  /// Extract district from text
  /// Matches against common Maharashtra district names and returns title-case district
  static String? extractDistrict(String text) {
    String cleaned = text.toLowerCase().trim();

    // List of Maharashtra districts (lowercased)
    List<String> districts = [
      'mumbai',
      'pune',
      'nagpur',
      'nashik',
      'aurangabad',
      'solapur',
      'thane',
      'pimpri chinchwad',
      'kalyan',
      'vasai',
      'nanded',
      'sangli',
      'kolhapur',
      'akola',
      'latur',
      'dhule',
      'ahmednagar',
      'chandrapur',
      'parbhani',
      'ichalkaranji',
      'jalgaon',
      'bhusawal',
      'panvel',
      'satara',
      'beed',
      'yavatmal',
      'kamptee',
      'gondia',
      'barshi',
      'achalpur',
      'osmanabad',
      'nandurbar',
      'wardha',
      'udgir',
      'hinganghat',
    ];

    for (var district in districts) {
      if (cleaned.contains(district)) {
        return _titleCase(district);
      }
    }

    // Fallback: try to grab any multi-word token of letters (len>=3)
    RegExp fallback =
        RegExp(r'\b([a-z]{3,}(?:\s+[a-z]{3,})*)\b', caseSensitive: false);
    Match? match = fallback.firstMatch(cleaned);
    if (match != null) {
      return _titleCase(match.group(1)!);
    }

    return null;
  }

  /// Extract annual income from text
  /// Handles various formats: "50000", "fifty thousand", "5 lakh", etc.
  static int? extractIncome(String text) {
    String cleaned = text.toLowerCase().trim();

    // Remove currency symbols and commas
    cleaned = cleaned.replaceAll(RegExp(r'[₹,rs\.]'), '').trim();

    // Handle lakh format (e.g., "2 lakh", "2.5 lakh")
    RegExp lakhRegex = RegExp(r'(\d+(?:\.\d+)?)\s*lakh', caseSensitive: false);
    Match? lakhMatch = lakhRegex.firstMatch(cleaned);
    if (lakhMatch != null) {
      double lakhs = double.tryParse(lakhMatch.group(1) ?? '') ?? 0;
      return (lakhs * 100000).toInt();
    }

    // Handle thousand format (e.g., "50 thousand", "50k")
    RegExp thousandRegex =
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:thousand|k)', caseSensitive: false);
    Match? thousandMatch = thousandRegex.firstMatch(cleaned);
    if (thousandMatch != null) {
      double thousands = double.tryParse(thousandMatch.group(1) ?? '') ?? 0;
      return (thousands * 1000).toInt();
    }

    // Try to find direct number
    RegExp numberRegex = RegExp(r'\b(\d{4,8})\b');
    Match? match = numberRegex.firstMatch(cleaned);
    if (match != null) {
      int income = int.tryParse(match.group(1) ?? '') ?? 0;
      // Assume it's annual income if reasonable
      if (income >= 10000 && income <= 10000000) {
        return income;
      }
    }

    // Word number mapping for income
    Map<String, int> incomeWords = {
      'fifty thousand': 50000,
      'one lakh': 100000,
      'two lakh': 200000,
      'three lakh': 300000,
      'four lakh': 400000,
      'five lakh': 500000,
      'ten lakh': 1000000,
    };

    for (var entry in incomeWords.entries) {
      if (cleaned.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Extract category from text
  /// Supports both social categories (SC/ST/OBC/General) and target groups (student, farmer, woman, etc.)
  static String? extractCategory(String text) {
    String cleaned = text.toLowerCase().trim();

    // Social category keywords (SC/ST/OBC/General) - PRIORITY
    if (cleaned.contains('sc') || cleaned.contains('scheduled caste')) {
      return 'SC';
    } else if (cleaned.contains('st') || cleaned.contains('scheduled tribe')) {
      return 'ST';
    } else if (cleaned.contains('obc') ||
        cleaned.contains('other backward class')) {
      return 'OBC';
    } else if (cleaned.contains('general') && !cleaned.contains('category')) {
      return 'General';
    }

    // Target group keywords (secondary)
    Map<String, String> targetGroupMap = {
      'student': 'student',
      'studying': 'student',
      'college': 'student',
      'school': 'student',
      'farmer': 'farmer',
      'farming': 'farmer',
      'agriculture': 'farmer',
      'woman': 'woman',
      'female': 'woman',
      'lady': 'woman',
      'senior citizen': 'senior_citizen',
      'senior': 'senior_citizen',
      'elderly': 'senior_citizen',
      'old': 'senior_citizen',
      'retired': 'senior_citizen',
      'unemployed': 'unemployed',
      'jobless': 'unemployed',
      'no job': 'unemployed',
    };

    for (var entry in targetGroupMap.entries) {
      if (cleaned.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Extract occupation from text
  static String? extractOccupation(String text) {
    String cleaned = text.toLowerCase().trim();

    // Occupation keywords mapping
    Map<String, String> occupationMap = {
      'teacher': 'Teacher',
      'teaching': 'Teacher',
      'shikshak': 'Teacher',
      'farmer': 'Farmer',
      'farming': 'Farmer',
      'kisan': 'Farmer',
      'student': 'Student',
      'studying': 'Student',
      'vidyarthi': 'Student',
      'engineer': 'Engineer',
      'engineering': 'Engineer',
      'abhiyanta': 'Engineer',
      'doctor': 'Doctor',
      'medical': 'Doctor',
      'daktar': 'Doctor',
      'business': 'Business',
      'vyapari': 'Business',
      'government employee': 'Government Employee',
      'sarkari': 'Government Employee',
      'nurse': 'Nurse',
      'lawyer': 'Lawyer',
      'advocate': 'Lawyer',
      'driver': 'Driver',
      'labour': 'Labour',
      'mazdoor': 'Labour',
    };

    for (var entry in occupationMap.entries) {
      if (cleaned.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Update user profile by extracting ALL possible fields from `transcript`.
  /// Non-destructive: existing values in `profile` are NEVER overwritten by this method.
  static void updateProfileFromText(UserProfile profile, String transcript) {
    // Occupation
    if (profile.occupation == null) {
      final occ = extractOccupation(transcript);
      if (occ != null) profile.occupation = _normalizeOccupation(occ);
    }

    // Age
    if (profile.age == null) {
      final a = extractAge(transcript);
      if (a != null) profile.age = a;
    }

    // Gender
    if (profile.gender == null) {
      final g = extractGender(transcript);
      if (g != null) profile.gender = _normalizeGender(g);
    }

    // State
    if (profile.state == null) {
      final s = extractState(transcript);
      if (s != null) profile.state = _normalizeState(s);
    }

    // District
    if (profile.district == null) {
      final d = extractDistrict(transcript);
      if (d != null) profile.district = _normalizeDistrict(d);
    }

    // Income
    if (profile.annualIncome == null) {
      final inc = extractIncome(transcript);
      if (inc != null) profile.annualIncome = inc;
    }

    // Category / Caste
    if (profile.caste == null && profile.category == null) {
      final c = extractCategory(transcript);
      if (c != null) profile.category = _normalizeCategory(c);
    }
  }
}
