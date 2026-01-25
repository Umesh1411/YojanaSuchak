import '../models/user_profile.dart';
import '../models/conversation_state.dart';

/// Service for extracting user profile information from voice transcript
class ProfileExtractor {
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
  /// Matches against common Maharashtra district names
  static String? extractDistrict(String text) {
    String cleaned = text.toLowerCase().trim();

    // List of Maharashtra districts
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
        // Capitalize first letter of each word
        return district
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
      }
    }

    // If no match, try to extract any capitalized word (might be district name)
    RegExp capitalized = RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b');
    Match? match = capitalized.firstMatch(text);
    if (match != null) {
      return match.group(1);
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
    } else if (cleaned.contains('obc') || cleaned.contains('other backward class')) {
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

  /// Update user profile based on current state and transcript
  static void updateProfile(
    UserProfile profile,
    ConversationState state,
    String transcript,
  ) {
    switch (state) {
      case ConversationState.askAge:
        int? age = extractAge(transcript);
        if (age != null) {
          profile.age = age;
        }
        break;

      case ConversationState.askState:
        String? state = extractState(transcript);
        if (state != null) {
          profile.state = state;
        }
        break;

      case ConversationState.askGender:
        String? gender = extractGender(transcript);
        if (gender != null) {
          profile.gender = gender;
        }
        break;

      case ConversationState.askDistrict:
        String? district = extractDistrict(transcript);
        if (district != null) {
          profile.district = district;
        }
        break;

      case ConversationState.askIncome:
        int? income = extractIncome(transcript);
        if (income != null) {
          profile.annualIncome = income;
        }
        break;

      case ConversationState.askCategory:
      case ConversationState.askSpecialCondition:
        String? category = extractCategory(transcript);
        if (category != null) {
          profile.category = category;
        }
        break;

      default:
        break;
    }
  }
}

