/// Model representing user profile extracted from voice conversation
class UserProfile {
  int? age;
  String? district;
  String? state;
  int? annualIncome;
  String? gender;
  String? occupation; // e.g., Teacher, Engineer, Farmer, Student, Business, Government Employee
  String? category; // student, farmer, woman, senior_citizen, unemployed, general
  String? specialCondition;
  String? selectedSchemeForDetails; // Scheme user wants more info about

  UserProfile({
    this.age,
    this.district,
    this.state,
    this.annualIncome,
    this.gender,
    this.occupation,
    this.category,
    this.specialCondition,
    this.selectedSchemeForDetails,
  });

  /// Check if profile is complete enough for scheme recommendation
  bool isComplete() {
    return age != null &&
        state != null &&
        annualIncome != null &&
        gender != null;
  }

  /// Get missing fields for conversation flow
  List<String> getMissingFields() {
    List<String> missing = [];
    if (age == null) missing.add('age');
    if (state == null) missing.add('state');
    if (annualIncome == null) missing.add('income');
    if (gender == null) missing.add('gender');
    if (occupation == null) missing.add('occupation');
    if (category == null) missing.add('category');
    return missing;
  }

  /// Convert to string for Gemini prompt
  String toPromptString() {
    return '''
User Profile:
- Age: ${age ?? 'Not provided'}
- State: ${state ?? 'Not provided'}
- District: ${district ?? 'Not provided'}
- Gender: ${gender ?? 'Not provided'}
- Annual Income: ${annualIncome != null ? '₹$annualIncome per year' : 'Not provided'}
- Occupation: ${occupation ?? 'Not provided'}
- Category: ${category ?? 'Not provided'}
- Special Condition: ${specialCondition ?? 'None'}
''';
  }

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'state': state,
      'district': district,
      'gender': gender,
      'annualIncome': annualIncome,
      'occupation': occupation,
      'category': category,
      'specialCondition': specialCondition,
      'selectedSchemeForDetails': selectedSchemeForDetails,
    };
  }
}
