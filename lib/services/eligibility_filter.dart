import '../models/scheme.dart';
import '../models/user_profile.dart';
import 'package:flutter/foundation.dart';

/// Service for rule-based filtering of schemes before sending to Gemini
/// Implementation: SOFT MATCH → HARD ELIMINATION → SCORING
/// Ensures occupation is the primary signal and that soft matches
/// are preserved as a fallback if hard filters remove everything.
class EligibilityFilter {
  static List<Scheme> filterSchemes(
    List<Scheme> allSchemes,
    UserProfile profile, {
    String? initialProblemText,
  }) {
    // STEP 1: SOFT MATCH
    final soft = _softMatch(allSchemes, profile, initialProblemText);
    debugPrint('EligibilityFilter: soft matches ${soft.length} / ${allSchemes.length}');

    if (soft.isEmpty) {
      // No soft matches — score all schemes and return top candidates
      return _scoreAndRank(allSchemes, profile, initialProblemText).take(10).toList();
    }

    // STEP 2: HARD ELIMINATION applied to soft matches
    final hardPassed = _hardEliminate(soft, profile);
    debugPrint('EligibilityFilter: hardPassed ${hardPassed.length} / ${soft.length}');

    if (hardPassed.isEmpty) {
      // If hard elimination removed everything, fallback to scored soft matches
      debugPrint('EligibilityFilter: hard eliminated all; falling back to soft matches');
      return _scoreAndRank(soft, profile, initialProblemText).take(10).toList();
    }

    // STEP 3: Score and return
    return _scoreAndRank(hardPassed, profile, initialProblemText).take(10).toList();
  }

  /// Find relevant schemes by occupation, beneficiaryType, benefitType keywords,
  /// and problem intent. Does NOT eliminate by age/income/state.
  static List<Scheme> _softMatch(
    List<Scheme> allSchemes,
    UserProfile profile,
    String? initialProblemText,
  ) {
    final problem = (initialProblemText ?? '').toLowerCase();
    final occupation = (profile.occupation ?? '').toLowerCase();
    final special = (profile.specialCondition ?? '').toLowerCase();

    return allSchemes.where((s) {
      final name = s.schemeName.toLowerCase();
      final benefit = s.benefitType.toLowerCase();
      final ben = s.beneficiaryType.toLowerCase();

      // Occupation mention
      if (occupation.isNotEmpty) {
        if (s.occupationEligible.toLowerCase().contains(occupation) || ben.contains(occupation)) return true;
      }

      // Special condition: widows, disabled, elderly
      if (special.contains('widow')) {
        if (ben.contains('widow') || ben.contains('woman') || name.contains('widow') || s.department.toLowerCase().contains('welfare')) return true;
      }
      if (special.contains('disabled') || special.contains('divyang')) {
        if (ben.contains('disable') || ben.contains('disab') || name.contains('disab')) return true;
      }

      // Intent keywords
      final edu = ['education', 'scholarship', 'student', 'school', 'college', 'fees', 'study'];
      final agri = ['farmer', 'agriculture', 'crop', 'seeds', 'farming'];
      final pen = ['pension', 'elderly', 'senior', 'old'];
      final hous = ['house', 'housing', 'home', 'pucca', 'rural housing'];
      final health = ['hospital', 'illness', 'treatment', 'doctor', 'medical', 'medicine'];

      if (edu.any((k) => problem.contains(k))) {
        if (benefit.contains('education') || benefit.contains('scholarship') || name.contains('scholar')) return true;
      }
      if (agri.any((k) => problem.contains(k))) {
        if (benefit.contains('agriculture') || name.contains('farmer')) return true;
      }
      if (pen.any((k) => problem.contains(k))) {
        if (benefit.contains('pension')) return true;
      }
      if (hous.any((k) => problem.contains(k))) {
        if (benefit.contains('housing')) return true;
      }
      if (health.any((k) => problem.contains(k))) {
        if (benefit.contains('health') || name.contains('hospital') || name.contains('medical')) return true;
      }

      return false;
    }).toList();
  }

  /// HARD ELIMINATION applied after soft matching.
  /// Enforces age, income, gender, occupation, state and disability/widow requirements.
  static List<Scheme> _hardEliminate(
    List<Scheme> allSchemes,
    UserProfile profile,
  ) {
    final occupation = (profile.occupation ?? '').toLowerCase();
    final special = (profile.specialCondition ?? '').toLowerCase();

    return allSchemes.where((s) {
      final name = s.schemeName.toLowerCase();
      final ben = s.beneficiaryType.toLowerCase();

      // Disability-specific schemes require disability mention
      if ((ben.contains('disable') || ben.contains('disab') || name.contains('disab')) && !(special.contains('disabled') || special.contains('divyang'))) {
        debugPrint('   ❌ ${s.schemeName}: requires disability but profile lacks it');
        return false;
      }

      // Widow-specific schemes require widow mention OR beneficiaryType includes widow/woman
      if ((ben.contains('widow') || name.contains('widow') || s.department.toLowerCase().contains('women')) && special.contains('widow')) {
        // keep
      }

      // Age check (if provided)
      if (profile.age != null && s.minAge != null && profile.age! < s.minAge!) {
        debugPrint('   ❌ ${s.schemeName}: age ${profile.age} < min ${s.minAge}');
        return false;
      }
      if (profile.age != null && s.maxAge != null && profile.age! > s.maxAge!) {
        debugPrint('   ❌ ${s.schemeName}: age ${profile.age} > max ${s.maxAge}');
        return false;
      }

      // Income check (if provided)
      if (profile.annualIncome != null && s.maxIncomeINR != null && profile.annualIncome! > s.maxIncomeINR!) {
        debugPrint('   ❌ ${s.schemeName}: income ${profile.annualIncome} > max ${s.maxIncomeINR}');
        return false;
      }

      // Gender
      if (profile.gender != null && s.genderEligible != 'All') {
        if (!s.genderEligible.toLowerCase().contains(profile.gender!.toLowerCase())) {
          debugPrint('   ❌ ${s.schemeName}: gender ${profile.gender} not eligible');
          return false;
        }
      }

      // Occupation mismatch: if profile provides occupation and scheme is restrictive, eliminate
      if (occupation.isNotEmpty && s.occupationEligible != 'Any' && s.occupationEligible != 'Not Applicable') {
        if (!s.occupationEligible.toLowerCase().contains(occupation)) {
          debugPrint('   ❌ ${s.schemeName}: occupation ${occupation} not in ${s.occupationEligible}');
          return false;
        }
      }

      // State (if provided and scheme is state-specific)
      if (profile.state != null && s.state.isNotEmpty && s.state.toLowerCase() != 'india') {
        if (s.state.toLowerCase() != profile.state!.toLowerCase()) {
          debugPrint('   ❌ ${s.schemeName}: state ${profile.state} != ${s.state}');
          return false;
        }
      }

      debugPrint('   ✓ ${s.schemeName}: passed hard checks');
      return true;
    }).toList();
  }

  /// WEIGHTED SCORING & RANKING
  /// Occupation match is the primary sort key; then score by weights.
  static List<Scheme> _scoreAndRank(
    List<Scheme> schemes,
    UserProfile profile,
    String? initialProblemText,
  ) {
    final problem = (initialProblemText ?? '').toLowerCase();
    final occupation = (profile.occupation ?? '').toLowerCase();
    final special = (profile.specialCondition ?? '').toLowerCase();

    final rows = <MapEntry<Scheme, Map<String, dynamic>>>[];

    for (final s in schemes) {
      int score = 0;
      final name = s.schemeName.toLowerCase();
      final ben = s.beneficiaryType.toLowerCase();
      final benefit = s.benefitType.toLowerCase();

      final occMatch = occupation.isNotEmpty && s.occupationEligible.toLowerCase().contains(occupation);

      // Student special: boost scholarships/education
      if (occupation.contains('student') && (benefit.contains('scholar') || benefit.contains('education') || ben.contains('student'))) {
        score += 40;
      }

      // Widow special: boost widow/women schemes
      if (special.contains('widow') && (ben.contains('widow') || ben.contains('woman') || name.contains('widow'))) {
        score += 35;
      }

      // Occupation match weight
      if (occMatch) score += 30;

      // BeneficiaryType medium weight
      if (occupation.isNotEmpty && ben.contains(occupation)) score += 20;
      if (profile.caste != null && ben.contains(profile.caste!.toLowerCase())) score += 15;

      // Intent match
      final intentK = {
        'education': ['education', 'scholarship', 'fees', 'school', 'college', 'study'],
        'agriculture': ['farmer', 'agriculture', 'crop', 'seeds', 'farming'],
        'pension': ['pension', 'elderly', 'senior', 'old'],
        'housing': ['house', 'housing', 'home'],
        'health': ['hospital', 'illness', 'treatment', 'doctor', 'medical']
      };
      for (final e in intentK.entries) {
        if (e.value.any((k) => problem.contains(k)) && benefit.contains(e.key)) score += 15;
      }

      // Age/income small boosts if they fit
      if (profile.age != null && (s.minAge != null || s.maxAge != null)) {
        if ((s.minAge == null || profile.age! >= s.minAge!) && (s.maxAge == null || profile.age! <= s.maxAge!)) score += 5;
      }
      if (profile.annualIncome != null && s.maxIncomeINR != null && profile.annualIncome! <= s.maxIncomeINR!) score += 5;

      // State small boost
      if (profile.state != null && s.state.isNotEmpty && s.state.toLowerCase() != 'india' && s.state.toLowerCase() == profile.state!.toLowerCase()) score += 3;

      // Penalize health schemes when not relevant (unless special)
      if (!occupation.contains('student') && !special.contains('widow') && !problem.contains('health') && benefit.contains('health')) score -= 30;

      rows.add(MapEntry(s, {'score': score, 'occ': occMatch}));
      debugPrint('   🔎 ${s.schemeName}: score=$score occMatch=$occMatch');
    }

    // Sort: occupation-match schemes first, then by score
    rows.sort((a, b) {
      final aOcc = a.value['occ'] as bool;
      final bOcc = b.value['occ'] as bool;
      if (aOcc != bOcc) return aOcc ? -1 : 1;
      final aScore = a.value['score'] as int;
      final bScore = b.value['score'] as int;
      return bScore.compareTo(aScore);
    });

    return rows.take(10).map((e) => e.key).toList();
  }
}









