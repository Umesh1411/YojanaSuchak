/// Model representing a government scheme (supports both Central and State schemes)
class Scheme {
  // Basic Information
  final String schemeId;
  final String schemeName;
  final String state; // India, Maharashtra, etc.
  final String schemeLevel; // Central, State
  final String department;

  // Eligibility Criteria
  final String occupationEligible; // Farmer, Student, Any, etc.
  final String genderEligible; // All, Female, Male
  final String categoryEligible; // All, Reserved, EWS, etc.
  final String casteEligible; // All, SC, ST, OBC, General
  final int? minAge;
  final int? maxAge;
  final int? maxIncomeINR;
  final String incomeRuleType; // EXACT, APPROX, NO_LIMIT
  final String maritalStatus; // Any, Married, Widow, etc.
  final String otherEligibilityCriteria;

  // Benefits
  final String beneficiaryType;
  final String benefitType; // Pension, Scholarship, Subsidy, etc.
  final String benefitAmount; // ₹1,500/month, ₹5,000, etc.
  final String benefitFrequency; // Monthly, Yearly, One-time, etc.
  final String allBenefitsDescription;

  // Application Details
  final String applicationMode; // Online, Offline, etc.
  final String applicationDeadline; // Open, As notified, etc.
  final List<String> importantDocuments;
  final String officialApplyLink;
  final String officialSource;
  final String remarks;

  // Legacy fields for backward compatibility
  String get targetGroup => beneficiaryType;
  String get eligibility => _buildEligibilityString();
  String get benefits => allBenefitsDescription.isNotEmpty
      ? allBenefitsDescription
      : '$benefitType: $benefitAmount ($benefitFrequency)';
  List<String> get requiredDocuments => importantDocuments;
  int? get incomeLimit => maxIncomeINR;
  int? get ageLimit =>
      minAge; // Using minAge as ageLimit for backward compatibility
  String? get category =>
      casteEligible != 'All' ? casteEligible : categoryEligible;

  Scheme({
    required this.schemeId,
    required this.schemeName,
    required this.state,
    required this.schemeLevel,
    required this.department,
    required this.occupationEligible,
    required this.genderEligible,
    required this.categoryEligible,
    required this.casteEligible,
    this.minAge,
    this.maxAge,
    this.maxIncomeINR,
    required this.incomeRuleType,
    required this.maritalStatus,
    required this.otherEligibilityCriteria,
    required this.beneficiaryType,
    required this.benefitType,
    required this.benefitAmount,
    required this.benefitFrequency,
    required this.allBenefitsDescription,
    required this.applicationMode,
    required this.applicationDeadline,
    required this.importantDocuments,
    required this.officialApplyLink,
    required this.officialSource,
    required this.remarks,
  });

  /// Build eligibility string from all eligibility fields
  String _buildEligibilityString() {
    List<String> parts = [];

    if (state != 'India') {
      parts.add('Resident of $state');
    }

    if (minAge != null && maxAge != null) {
      parts.add('Age: $minAge-$maxAge years');
    } else if (minAge != null) {
      parts.add('Minimum age: $minAge years');
    } else if (maxAge != null) {
      parts.add('Maximum age: $maxAge years');
    }

    if (maxIncomeINR != null && incomeRuleType != 'NO_LIMIT') {
      parts.add(
          'Annual income below ₹${maxIncomeINR.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}');
    }

    if (occupationEligible != 'Not Applicable' && occupationEligible != 'Any') {
      parts.add('Occupation: $occupationEligible');
    }

    if (genderEligible != 'All') {
      parts.add('Gender: $genderEligible');
    }

    if (casteEligible != 'All') {
      parts.add('Caste: $casteEligible');
    }

    if (categoryEligible != 'All') {
      parts.add('Category: $categoryEligible');
    }

    if (maritalStatus != 'Not Applicable' && maritalStatus != 'Any') {
      parts.add('Marital Status: $maritalStatus');
    }

    if (otherEligibilityCriteria.isNotEmpty) {
      parts.add(otherEligibilityCriteria);
    }

    return parts.join(', ');
  }

  /// Create Scheme from JSON (supports both old and new format)
  factory Scheme.fromJson(Map<String, dynamic> json) {
    // Check if it's new format (has schemeId) or old format
    if (json.containsKey('schemeId')) {
      // New format from CSV
      return Scheme(
        schemeId: json['schemeId'] as String? ?? '',
        schemeName: json['schemeName'] as String? ?? '',
        state: json['state'] as String? ?? 'India',
        schemeLevel: json['schemeLevel'] as String? ?? 'Central',
        department: json['department'] as String? ?? '',
        occupationEligible: json['occupationEligible'] as String? ?? 'Any',
        genderEligible: json['genderEligible'] as String? ?? 'All',
        categoryEligible: json['categoryEligible'] as String? ?? 'All',
        casteEligible: json['casteEligible'] as String? ?? 'All',
        minAge: json['minAge'] as int?,
        maxAge: json['maxAge'] as int?,
        maxIncomeINR: json['maxIncomeINR'] as int?,
        incomeRuleType: json['incomeRuleType'] as String? ?? 'NO_LIMIT',
        maritalStatus: json['maritalStatus'] as String? ?? 'Any',
        otherEligibilityCriteria:
            json['otherEligibilityCriteria'] as String? ?? '',
        beneficiaryType: json['beneficiaryType'] as String? ?? '',
        benefitType: json['benefitType'] as String? ?? '',
        benefitAmount: json['benefitAmount'] as String? ?? '',
        benefitFrequency: json['benefitFrequency'] as String? ?? '',
        allBenefitsDescription: json['allBenefitsDescription'] as String? ?? '',
        applicationMode: json['applicationMode'] as String? ?? 'Online',
        applicationDeadline: json['applicationDeadline'] as String? ?? 'Open',
        importantDocuments: (json['importantDocuments'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        officialApplyLink: json['officialApplyLink'] as String? ?? '',
        officialSource: json['officialSource'] as String? ?? '',
        remarks: json['remarks'] as String? ?? '',
      );
    } else {
      // Old format - convert to new format
      return Scheme(
        schemeId: '',
        schemeName: json['schemeName'] as String? ?? '',
        state: 'Maharashtra',
        schemeLevel: 'State',
        department: json['department'] as String? ?? '',
        occupationEligible: 'Any',
        genderEligible: 'All',
        categoryEligible: json['category'] as String? ?? 'All',
        casteEligible: 'All',
        minAge: json['ageLimit'] as int?,
        maxAge: null,
        maxIncomeINR: json['incomeLimit'] as int?,
        incomeRuleType: json['incomeLimit'] != null ? 'EXACT' : 'NO_LIMIT',
        maritalStatus: 'Any',
        otherEligibilityCriteria: json['eligibility'] as String? ?? '',
        beneficiaryType: json['targetGroup'] as String? ?? '',
        benefitType: 'Benefit',
        benefitAmount: '',
        benefitFrequency: '',
        allBenefitsDescription: json['benefits'] as String? ?? '',
        applicationMode: 'Online',
        applicationDeadline: 'Open',
        importantDocuments: (json['requiredDocuments'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        officialApplyLink: '',
        officialSource: '',
        remarks: '',
      );
    }
  }

  /// Convert Scheme to JSON
  Map<String, dynamic> toJson() {
    return {
      'schemeId': schemeId,
      'schemeName': schemeName,
      'state': state,
      'schemeLevel': schemeLevel,
      'department': department,
      'occupationEligible': occupationEligible,
      'genderEligible': genderEligible,
      'categoryEligible': categoryEligible,
      'casteEligible': casteEligible,
      'minAge': minAge,
      'maxAge': maxAge,
      'maxIncomeINR': maxIncomeINR,
      'incomeRuleType': incomeRuleType,
      'maritalStatus': maritalStatus,
      'otherEligibilityCriteria': otherEligibilityCriteria,
      'beneficiaryType': beneficiaryType,
      'benefitType': benefitType,
      'benefitAmount': benefitAmount,
      'benefitFrequency': benefitFrequency,
      'allBenefitsDescription': allBenefitsDescription,
      'applicationMode': applicationMode,
      'applicationDeadline': applicationDeadline,
      'importantDocuments': importantDocuments,
      'officialApplyLink': officialApplyLink,
      'officialSource': officialSource,
      'remarks': remarks,
      // Legacy fields for backward compatibility
      'targetGroup': targetGroup,
      'eligibility': eligibility,
      'benefits': benefits,
      'requiredDocuments': requiredDocuments,
      'incomeLimit': incomeLimit,
      'ageLimit': ageLimit,
      'category': category,
    };
  }
}
