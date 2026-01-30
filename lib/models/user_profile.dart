/// Model representing user profile extracted from voice conversation
class UserProfile {
  // Basic Information
  String? fullName;
  String? phoneNumber;
  int? age;
  String? gender; // Male, Female, Other
  String?
      occupation; // e.g., Teacher, Engineer, Farmer, Student, Business, Government Employee
  String? caste; // SC, ST, OBC, General (social category/caste)
  String?
      category; // SC, ST, OBC, General (social category) OR student, farmer, woman, senior_citizen, unemployed (target group) - legacy support
  int? annualIncome;
  String? state;
  String? district;

  // Additional fields
  String? specialCondition;
  String? selectedSchemeForDetails; // Scheme user wants more info about

  UserProfile({
    this.fullName,
    this.phoneNumber,
    this.age,
    this.gender,
    this.occupation,
    this.caste,
    this.category,
    this.annualIncome,
    this.state,
    this.district,
    this.specialCondition,
    this.selectedSchemeForDetails,
  });

  /// Get caste/category for eligibility checking (prefers caste, falls back to category)
  String? get casteOrCategory => caste ?? category;

  /// Check if profile is complete enough for scheme recommendation
  /// REQUIRED FIELDS: age, gender, state, district, annualIncome, occupation, caste/category
  bool isComplete() {
    return age != null &&
        gender != null &&
        state != null &&
        district != null &&
        annualIncome != null &&
        occupation != null &&
        (caste != null || category != null);
  }

  /// Get missing fields for conversation flow
  /// Returns list of missing REQUIRED fields in priority order
  List<String> getMissingFields() {
    List<String> missing = [];
    if (age == null) missing.add('age');
    if (gender == null) missing.add('gender');
    if (state == null) missing.add('state');
    if (district == null) missing.add('district');
    if (annualIncome == null) missing.add('income');
    if (occupation == null) missing.add('occupation');
    if (caste == null && category == null) missing.add('category');
    return missing;
  }

  /// Single source-of-truth: get the NEXT missing field in the exact priority required
  /// Priority order (MANDATORY): occupation → age → gender → state → district → annualIncome → category
  /// Returns the field key (e.g., 'occupation', 'age', ...) or null if profile is complete
  String? nextMissingField() {
    if (occupation == null) return 'occupation';
    if (age == null) return 'age';
    if (gender == null) return 'gender';
    if (state == null) return 'state';
    if (district == null) return 'district';
    if (annualIncome == null) return 'annual income';
    if (caste == null && category == null) return 'category';
    return null;
  }

  /// Convert to string for Gemini prompt
  String toPromptString() {
    return '''
User Profile:
- Full Name: ${fullName ?? 'Not provided'}
- Phone: ${phoneNumber ?? 'Not provided'}
- Age: ${age ?? 'Not provided'}
- Gender: ${gender ?? 'Not provided'}
- State: ${state ?? 'Not provided'}
- District: ${district ?? 'Not provided'}
- Annual Income: ${annualIncome != null ? '₹$annualIncome per year' : 'Not provided'}
- Occupation: ${occupation ?? 'Not provided'}
- Caste/Category: ${casteOrCategory ?? 'Not provided'}
- Special Condition: ${specialCondition ?? 'None'}
''';
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'age': age,
      'gender': gender,
      'occupation': occupation,
      'caste': caste,
      'category': category, // Keep for backward compatibility
      'annualIncome': annualIncome,
      'state': state,
      'district': district,
      'specialCondition': specialCondition,
      'selectedSchemeForDetails': selectedSchemeForDetails,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Create UserProfile from Firestore JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['fullName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      occupation: json['occupation'] as String?,
      caste: json['caste'] as String?,
      category: json['category'] as String?,
      annualIncome: json['annualIncome'] as int?,
      state: json['state'] as String?,
      district: json['district'] as String?,
      specialCondition: json['specialCondition'] as String?,
      selectedSchemeForDetails: json['selectedSchemeForDetails'] as String?,
    );
  }
}
