import '../models/scheme.dart';
import '../models/user_profile.dart';

/// Service for rule-based filtering of schemes before sending to Gemini
/// This optimizes performance by reducing payload size
class EligibilityFilter {
  /// Filter schemes based on basic eligibility criteria
  /// Returns schemes that match age, income, and category requirements
  static List<Scheme> filterSchemes(
    List<Scheme> allSchemes,
    UserProfile profile,
  ) {
    if (!profile.isComplete()) {
      return allSchemes; // Return all if profile incomplete
    }

    List<Scheme> filtered = [];

    for (var scheme in allSchemes) {
      bool matches = true;

      // Check age limit
      if (scheme.ageLimit != null && profile.age != null) {
        // Some schemes have minimum age, some have maximum
        // For simplicity, we check if user age is within reasonable range
        // You can customize this logic based on scheme requirements
        if (scheme.ageLimit! > 0 && profile.age! < scheme.ageLimit!) {
          matches = false;
        }
      }

      // Check income limit
      if (scheme.incomeLimit != null && profile.annualIncome != null) {
        // Income limit typically means maximum income
        if (profile.annualIncome! > scheme.incomeLimit!) {
          matches = false;
        }
      }

      // Check category/target group match
      if (scheme.category != null && profile.category != null) {
        String schemeCategory = scheme.category!.toLowerCase();
        String userCategory = profile.category!.toLowerCase();

        // Basic category matching
        if (schemeCategory != 'general' && schemeCategory != userCategory) {
          // Check if target group mentions the category
          if (!scheme.targetGroup.toLowerCase().contains(userCategory)) {
            matches = false;
          }
        }
      }

      // Check target group keywords
      if (profile.category != null) {
        String targetGroup = scheme.targetGroup.toLowerCase();
        String userCategory = profile.category!.toLowerCase();

        // If scheme doesn't explicitly match category, check target group
        if (!targetGroup.contains(userCategory) &&
            scheme.category == null &&
            userCategory != 'general') {
          // Still include if no specific category requirement
          // This is lenient to allow Gemini to make final decision
        }
      }

      if (matches) {
        filtered.add(scheme);
      }
    }

    // If filtering is too strict, return at least top 50 schemes
    // This ensures Gemini has enough options to choose from
    if (filtered.length < 20) {
      // Return top 50 by relevance score
      return _getTopSchemesByRelevance(allSchemes, profile, 50);
    }

    return filtered;
  }

  /// Get top N schemes by relevance score
  static List<Scheme> _getTopSchemesByRelevance(
    List<Scheme> schemes,
    UserProfile profile,
    int topN,
  ) {
    List<MapEntry<Scheme, int>> scored = [];

    for (var scheme in schemes) {
      int score = 0;

      // Score based on category match
      if (profile.category != null && scheme.category != null) {
        if (scheme.category!.toLowerCase() == profile.category!.toLowerCase()) {
          score += 10;
        }
      }

      // Score based on target group match
      if (profile.category != null) {
        String targetGroup = scheme.targetGroup.toLowerCase();
        String userCategory = profile.category!.toLowerCase();
        if (targetGroup.contains(userCategory)) {
          score += 5;
        }
      }

      // Score based on age eligibility
      if (scheme.ageLimit != null && profile.age != null) {
        if (profile.age! >= scheme.ageLimit! || scheme.ageLimit! <= 0) {
          score += 3;
        }
      }

      // Score based on income eligibility
      if (scheme.incomeLimit != null && profile.annualIncome != null) {
        if (profile.annualIncome! <= scheme.incomeLimit!) {
          score += 3;
        }
      }

      scored.add(MapEntry(scheme, score));
    }

    // Sort by score (descending) and return top N
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(topN).map((e) => e.key).toList();
  }
}





