import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:yojana_suchak/core/services/scheme_recommender.dart';

class SchemeRecommendationDemo extends StatefulWidget {
  const SchemeRecommendationDemo({super.key});

  @override
  State<SchemeRecommendationDemo> createState() =>
      _SchemeRecommendationDemoState();
}

class _SchemeRecommendationDemoState extends State<SchemeRecommendationDemo> {
  final _recommender = SchemeRecommender();
  String _result = '';

  Future<void> _runDemo() async {
    // Example profile - in real app this comes from authenticated user profile
    final profile = {
      'age': 30,
      'gender': 'Female',
      'income': 50000,
      'occupation': 'Farmer',
      'category': 'General',
      'disability': false,
      'farmer': true,
      'student': false,
      'woman': true,
      'seniorCitizen': false,
    };

    final result =
        await _recommender.recommend(profile, locale: const Locale('en'));
    setState(() {
      _result = const JsonEncoder.withIndent('  ').convert(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheme Recommendation Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
                onPressed: _runDemo, child: const Text('Get Recommendations')),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: Text(_result)))
          ],
        ),
      ),
    );
  }
}
