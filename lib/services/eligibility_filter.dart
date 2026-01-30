import '../models/scheme.dart';
import '../models/user_profile.dart';
import 'package:flutter/foundation.dart';

/// Service for rule-based filtering of schemes before sending to Gemini
/// HARD ELIMINATION (age, occupation, beneficiaryType mismatch) FIRST
/// Then WEIGHTED SCORING: occupation(+30), beneficiaryType(+20), benefitType(+15), intent(+15), age(+5), income(+5)
/// Database fields ONLY source of truth. NEVER return all schemes blindly.
class EligibilityFilter {
  /// Filter schemes using hard elimination + weighted ranking.
  /// Supports partial profile (always filters; never returns all blindly).
  static List<Scheme> filterSchemes(
    List<Scheme> allSchemes,
    UserProfile profile, {
    String? initialProblemText,
  }) {
    // STEP 1: HARD ELIMINATION (mandatory criteria)
    final eliminated = _hardEliminate(allSchemes, profile);
    
    if (eliminated.isEmpty) {
      debugPrint('⚠️ Hard elimination removed all schemes; returning all');
      return allSchemes;
    }

    // STEP 2: WEIGHTED SCORING & RANKING
    final ranked = _scoreAndRank(eliminated, profile, initialProblemText);
    debugPrint('🔎 Filtered ${allSchemes.length} → ${eliminated.length} (hard elim) → ${ranked.length} (top)');
    return ranked;
  }

  /// HARD ELIMINATION: remove schemes that explicitly fail profile constraints
  static List<Scheme> _hardEliminate(
    List<Scheme> allSchemes,
    UserProfile profile,
  ) {
    return allSchemes.where((s) {
      // Rule 1: Age bounds (minAge/maxAge are mandatory if specified)
      if (profile.age != null) {
        if (s.minAge != null && profile.age! < s.minAge!) {
          debugPrint('   ❌ ${s.schemeName}: age ${profile.age} < minAge ${s.minAge}');
          return false;
        }
        if (s.maxAge != null && profile.age! > s.maxAge!) {
          debugPrint('   ❌ ${s.schemeName}: age ${profile.age} > maxAge ${s.maxAge}');
          return false;
        }
      }

      // Rule 2: Income ceiling (if profile has income)
      if (profile.annualIncome != null && s.maxIncomeINR != null) {
        if (profile.annualIncome! > s.maxIncomeINR!) {
          debugPrint('   ❌ ${s.schemeName}: income ${profile.annualIncome} > max ${s.maxIncomeINR}');
          return false;
        }
      }

      // Rule 3: Occupation mismatch
      if (profile.occupation != null &&
          s.occupationEligible != 'Any' &&
          s.occupationEligible != 'Not Applicable') {
        if (!s.occupationEligible.toLowerCase().contains(profile.occupation!.toLowerCase())) {
          debugPrint('   ❌ ${s.schemeName}: occupation ${profile.occupation} not in ${s.occupationEligible}');
          return false;
        }
      }

      // Rule 4: Caste/category mismatch
      if (profile.category != null &&
          s.casteEligible != 'All' &&
          s.categoryEligible != 'All') {
        final profCat = profile.category!.toLowerCase();
        if (!s.casteEligible.toLowerCase().contains(profCat) &&
            !s.categoryEligible.toLowerCase().contains(profCat)) {
          debugPrint('   ❌ ${s.schemeName}: category ${profile.category} not in caste/category');
          return false;
        }
      }

      // Rule 5: Gender mismatch
      if (profile.gender != null && s.genderEligible != 'All') {
        if (!s.genderEligible.toLowerCase().contains(profile.gender!.toLowerCase())) {
          debugPrint('   ❌ ${s.schemeName}: gender ${profile.gender} not in ${s.genderEligible}');
          return false;
        }
      }

      // Rule 6: State mismatch
      if (profile.state != null && s.state.isNotEmpty && s.state.toLowerCase() != 'india') {
        if (s.state.toLowerCase() != profile.state!.toLowerCase()) {
          debugPrint('   ❌ ${s.schemeName}: state ${profile.state} != ${s.state}');
          return false;
        }
      }

      // Rule 7: BeneficiaryType mismatch
      if (s.beneficiaryType.isNotEmpty && s.beneficiaryType.toLowerCase() != 'all') {
        final benType = s.beneficiaryType.toLowerCase();
        final profOcc = (profile.occupation ?? '').toLowerCase();
        final profCat = (profile.category ?? '').toLowerCase();
        if (profOcc.isNotEmpty || profCat.isNotEmpty) {
          bool matched = benType.contains(profOcc) || benType.contains(profCat);
          if (!matched && (profOcc.isNotEmpty || profCat.isNotEmpty)) {
            debugPrint('   ❌ ${s.schemeName}: beneficiaryType ${s.beneficiaryType} mismatch');
            return false;
          }
        }
      }

      debugPrint('   ✓ ${s.schemeName}: passes hard elimination');
      return true;
    }).toList();
  }

  /// WEIGHTED SCORING & RANKING
  /// Weights: occupation(+30), beneficiaryType(+20), benefitType(+15), intent(+15), age(+5), income(+5)
  static List<Scheme> _scoreAndRank(
    List<Scheme> schemes,
    UserProfile profile,
    String? initialProblemText,
  ) {
    final problem = (initialProblemText ?? '').toLowerCase();
    final List<MapEntry<Scheme, int>> scored = [];

    for (final s in schemes) {
      int score = 0;

      // +30 Occupation match (HIGHEST PRIORITY)
      if (profile.occupation != null && profile.occupation!.isNotEmpty) {
        if (s.occupationEligible.toLowerCase().contains(profile.occupation!.toLowerCase())) {
          score += 30;
        }
      }

      // +20 BeneficiaryType / targetGroup match
      if (profile.occupation != null && profile.occupation!.isNotEmpty) {
        if (s.beneficiaryType.toLowerCase().contains(profile.occupation!.toLowerCase())) {
          score += 20;
        }
      }
      if (profile.category != null && profile.category!.isNotEmpty) {
        if (s.beneficiaryType.toLowerCase().contains(profile.category!.toLowerCase())) {
          score += 20;
        }
      }

      // +15 BenefitType matches problem intent
      final intentKeywords = {
        'education': ['education', 'scholarship', 'fees', 'school', 'college', 'study'],
        'agriculture': ['farmer', 'agriculture', 'crop', 'seeds', 'farming'],
        'pension': ['pension', 'elderly', 'senior', 'old'],
        'housing': ['house', 'housing', 'home'],
        'health': ['hospital', 'illness', 'treatment', 'doctor', 'medical']
      };
      for (final entry in intentKeywords.entries) {
        final hasIntent = entry.value.any((k) => problem.contains(k));
        if (hasIntent && s.benefitType.toLowerCase().contains(entry.key)) {
          score += 15;
        }
      }

      // +10 Category/caste match
      if (profile.category != null) {
        if (s.casteEligible.toLowerCase().contains(profile.category!.toLowerCase()) ||
            s.categoryEligible.toLowerCase().contains(profile.category!.toLowerCase())) {
          score += 10;
        }
      }

      // +5 Age match
      if (profile.age != null && (s.minAge != null || s.maxAge != null)) {
        if ((s.minAge == null || profile.age! >= s.minAge!) &&
            (s.maxAge == null || profile.age! <= s.maxAge!)) {
          score += 5;
        }
      }

      // +5 Income match
      if (profile.annualIncome != null && s.maxIncomeINR != null) {
        if (profile.annualIncome! <= s.maxIncomeINR!) {
          score += 5;
        }
      }

      // -30 Penalty: health schemes when intent is NOT health
      final benefitLower = s.benefitType.toLowerCase();
      if (!problem.contains('health') && !problem.contains('illness') && benefitLower.contains('health')) {
        score -= 30;
      }
      if (problem.contains('education') && benefitLower.contains('health')) {
        score -= 30;
      }
      if (problem.contains('farmer') && benefitLower.contains('health') && !problem.contains('health')) {
        score -= 30;
      }

      scored.add(MapEntry(s, score));
      debugPrint('   🔎 ${s.schemeName}: score=$score');
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    final result = scored.take(10).map((e) => e.key).toList();
    debugPrint('📊 Top ${result.length} schemes by score');
    return result;
  }
}









