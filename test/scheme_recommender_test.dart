import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:yojana_suchak/core/services/scheme_recommender.dart';

void main() {
  group('SchemeRecommender', () {
    final recommender = SchemeRecommender();

    test('returns exactly 3 recommendations and localized text (English)', () {
      final profile = {
        'age': 30,
        'gender': 'Female',
        'income': 80000,
        'occupation': 'Farmer',
        'category': 'General',
        'disability': false,
        'farmer': true,
        'student': false,
        'woman': true,
        'seniorCitizen': false,
      };

      final schemes = [
        {
          'schemeName': 'General Farmer Support',
          'schemeName_en': 'General Farmer Support',
          'eligibility': {
            'minAge': 18,
            'maxAge': 60,
            'occupation': 'Farmer',
            'farmer': true,
          },
          'benefits': ['Cash support', 'Training']
        },
        {
          'schemeName': 'Women Empowerment',
          'schemeName_en': 'Women Empowerment',
          'eligibility': {
            'woman': true,
            'minAge': 18,
            'maxAge': 45,
          },
          'benefits': ['Skill training']
        },
        {
          'schemeName': 'Senior Citizens Health',
          'schemeName_en': 'Senior Citizens Health',
          'eligibility': {
            'minAge': 60,
          },
          'benefits': ['Health coverage']
        },
        {
          'schemeName': 'General Education Grant',
          'schemeName_en': 'General Education Grant',
          'eligibility': {
            'student': true,
          },
          'benefits': ['Scholarship']
        }
      ];

      final result =
          recommender.recommendFromProfile(profile, schemes, Locale('en'));

      expect(result.length, 3);

      // Top recommendation should be Farmer Support
      expect(result[0]['schemeName'], 'General Farmer Support');
      expect((result[0]['reason'] as String).isNotEmpty, true);
      expect(result[0]['keyBenefits'], isA<List<String>>());

      // All recommendations should contain required keys
      for (final r in result) {
        expect(r.containsKey('schemeName'), true);
        expect(r.containsKey('reason'), true);
        expect(r.containsKey('keyBenefits'), true);
      }
    });

    test('localizes reasons to Marathi when locale is mr', () {
      final profile = {'age': 35, 'category': 'SC'};
      final schemes = [
        {
          'schemeName': 'SC Welfare',
          'schemeName_mr': 'अनुसूचित जाती कल्याण',
          'eligibility': {'category': 'SC', 'minAge': 18, 'maxAge': 60},
          'benefits_mr': ['सशुल्क मदत']
        }
      ];

      final result =
          recommender.recommendFromProfile(profile, schemes, Locale('mr'));
      expect(result[0]['schemeName'], 'अनुसूचित जाती कल्याण');
      expect((result[0]['reason'] as String).isNotEmpty, true);
      expect(result[0]['keyBenefits'], ['सशुल्क मदत']);
    });
  });
}
