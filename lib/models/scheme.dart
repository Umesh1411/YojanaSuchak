/// Model representing a Maharashtra government scheme
class Scheme {
  final String schemeName;
  final String department;
  final String targetGroup;
  final String eligibility;
  final String benefits;
  final List<String> requiredDocuments;
  final int? incomeLimit;
  final int? ageLimit;
  final String? category;

  Scheme({
    required this.schemeName,
    required this.department,
    required this.targetGroup,
    required this.eligibility,
    required this.benefits,
    required this.requiredDocuments,
    this.incomeLimit,
    this.ageLimit,
    this.category,
  });

  /// Create Scheme from JSON
  factory Scheme.fromJson(Map<String, dynamic> json) {
    return Scheme(
      schemeName: json['schemeName'] as String? ?? '',
      department: json['department'] as String? ?? '',
      targetGroup: json['targetGroup'] as String? ?? '',
      eligibility: json['eligibility'] as String? ?? '',
      benefits: json['benefits'] as String? ?? '',
      requiredDocuments:
          (json['requiredDocuments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      incomeLimit: json['incomeLimit'] as int?,
      ageLimit: json['ageLimit'] as int?,
      category: json['category'] as String?,
    );
  }

  /// Convert Scheme to JSON
  Map<String, dynamic> toJson() {
    return {
      'schemeName': schemeName,
      'department': department,
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





