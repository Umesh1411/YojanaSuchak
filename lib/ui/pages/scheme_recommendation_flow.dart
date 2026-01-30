import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:yojana_suchak/core/services/chat_service.dart';
import 'package:yojana_suchak/core/services/my_schemes_service.dart';
import 'package:yojana_suchak/core/services/notification_service.dart';
import 'package:yojana_suchak/core/services/scheme_recommender.dart';
import 'package:yojana_suchak/core/services/language_service.dart';

class SchemeRecommendationFlow extends StatefulWidget {
  const SchemeRecommendationFlow({super.key});

  @override
  State<SchemeRecommendationFlow> createState() =>
      _SchemeRecommendationFlowState();
}

class _SchemeRecommendationFlowState extends State<SchemeRecommendationFlow> {
  final _problemCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final _chat = ChatService();
  final _recommender = SchemeRecommender();
  final _mySchemes = MySchemesService();
  final _notif = NotificationService();

  Map<String, dynamic> _profile = {};
  String _currentQuestion = '';
  String _languageCode = 'en';

  Map<String, dynamic> _recommendationsResponse = {};
  List<Map<String, dynamic>> _recommendations = [];
  List<bool> _selected = [];

  bool _asking = false;
  bool _showResults = false;

  @override
  void dispose() {
    _problemCtrl.dispose();
    _answerCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _startFlow() async {
    setState(() {
      _profile = {};
      _recommendations = [];
      _selected = [];
      _showResults = false;
      _asking = true;
    });

    _profile['problem'] = _problemCtrl.text.trim();

    // Detect app language
    try {
      final locale = await LanguageService.getCurrentLanguage();
      _languageCode = locale.languageCode;
    } catch (e) {
      _languageCode = 'en';
    }

    // Ask first question
    final q = await _chat.nextQuestion(
        _profile['problem'], _profile, Locale(_languageCode));
    setState(() {
      _currentQuestion = q;
      _answerCtrl.text = '';
    });
  }

  String _chatMessage = '';

  Future<void> _submitAnswer() async {
    final ans = _answerCtrl.text.trim();
    if (ans.isEmpty) return;

    // Sector answer detection (education/health/employment/agriculture/other)
    final sector = _sectorFromAnswer(ans);
    if (sector != null) {
      _profile['sector'] = sector;
    } else {
      // Simple mapping rules to store answer in profile
      final q = _currentQuestion.toLowerCase();

      if (q.contains('age') || q.contains('विफा') || q.contains('वय')) {
        _profile['age'] = int.tryParse(ans) ?? ans;
      } else if (q.contains('student') ||
          q.contains('छात्र') ||
          q.contains('विद्यार्थी')) {
        _profile['student'] = _boolFromYesNo(ans);
      } else if (q.contains('farmer') ||
          q.contains('शेतकरी') ||
          q.contains('किसान')) {
        _profile['farmer'] = _boolFromYesNo(ans);
      } else if (q.contains('senior') ||
          q.contains('वरिष्ठ') ||
          q.contains('वरिष्ठ नागरिक')) {
        _profile['seniorCitizen'] = _boolFromYesNo(ans);
      } else if (q.contains('disability') || q.contains('विकलांग')) {
        _profile['disability'] = _boolFromYesNo(ans);
      } else if (q.contains('occupation') ||
          q.contains('पेशा') ||
          q.contains('व्यवसाय')) {
        _profile['occupation'] = ans;
      } else if (q.contains('income') ||
          q.contains('आय') ||
          q.contains('उत्पन्न')) {
        _profile['income'] = num.tryParse(ans) ?? ans;
      } else if (q.contains('category') || q.contains('श्रेणी')) {
        _profile['category'] = ans;
      } else if (q.contains('gender') ||
          q.contains('लिंग') ||
          q.contains('लैंगिक')) {
        _profile['gender'] = ans;
      } else if (q.contains('woman') || q.contains('महिला')) {
        _profile['woman'] = _boolFromYesNo(ans);
      } else {
        // fallback store under 'notes'
        _profile['notes'] = ans;
      }
    }

    // Get next question or finish
    final next = await _chat.nextQuestion(
        _profile['problem'] ?? '', _profile, Locale(_languageCode));
    if (next.isEmpty) {
      // ready to recommend
      final rec =
          await _recommender.recommend(_profile, locale: Locale(_languageCode));
      final list =
          (rec['recommendations'] as List).cast<Map<String, dynamic>>();
      final chat = _recommender.generateChatMessage(
          list, _profile, Locale(_languageCode));
      setState(() {
        _recommendationsResponse = rec;
        _recommendations = list;
        _selected = List.filled(list.length, false);
        _showResults = true;
        _asking = false;
        _chatMessage = chat;
      });
    } else {
      setState(() {
        _currentQuestion = next;
        _answerCtrl.text = '';
      });
    }
  }

  bool _boolFromYesNo(String a) {
    final v = a.trim().toLowerCase();
    return v == 'yes' ||
        v == 'y' ||
        v == 'हाँ' ||
        v == 'ho' ||
        v == 'होय' ||
        v == 'yes.' ||
        v == 'y.';
  }

  String? _sectorFromAnswer(String ans) {
    final v = ans.trim().toLowerCase();
    if (v.contains('education') ||
        v.contains('student') ||
        v.contains('fees') ||
        v.contains('शिक्ष') ||
        v.contains('विद्यार्थी')) return 'education';
    if (v.contains('health') ||
        v.contains('medical') ||
        v.contains('hospital') ||
        v.contains('आरोग्य') ||
        v.contains('हेल्थ')) return 'health';
    if (v.contains('job') ||
        v.contains('employment') ||
        v.contains('work') ||
        v.contains('रोज़गार')) return 'employment';
    if (v.contains('farmer') ||
        v.contains('agri') ||
        v.contains('कृषि') ||
        v.contains('शेतकरी')) return 'agriculture';
    if (v.contains('women') || v.contains('female') || v.contains('महिला'))
      return 'women';
    if (['education', 'health', 'employment', 'agriculture', 'women', 'other']
        .contains(v)) return v;
    return null;
  }

  Future<void> _saveSelectedSchemes() async {
    final u = FirebaseAuth.instance.currentUser;
    final userId = u?.uid ?? 'anonymous';
    final ids = <String>[];
    for (int i = 0; i < _recommendations.length; i++) {
      if (_selected[i]) {
        // Use schemeId if provided, else fallback to schemeName
        final schemeId = _recommendations[i]['schemeId'] as String? ??
            (_recommendations[i]['schemeName'] as String? ?? '');
        ids.add(schemeId);
      }
    }

    if (ids.isEmpty) return;

    // Ask for emails in a simple dialog
    final emails = _emailCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    await _mySchemes.saveSchemes(userId, ids, emails: emails);

    // Send email details if emails provided
    if (emails.isNotEmpty) {
      for (int i = 0; i < _recommendations.length; i++) {
        if (_selected[i]) {
          // We don't have schemeId here; in production use real scheme ID. For now using schemeName if backend supports it.
          final schemeName = _recommendations[i]['schemeName'] as String? ?? '';
          // Attempt to call notification service using schemeName as id; backend will try to resolve
          try {
            await _notif.sendSchemeDetailsToEmails(
                schemeId: schemeName, emails: emails, lang: _languageCode);
          } catch (e) {
            // ignore errors for now
          }
        }
      }
    }

    // confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved selected schemes.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Schemes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _showResults ? _buildResults() : _buildQuestionFlow(),
      ),
    );
  }

  Widget _buildQuestionFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _problemCtrl,
          decoration: const InputDecoration(
              labelText:
                  'Describe your problem (e.g. health, education, fees)'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: _startFlow, child: const Text('Start')),
        const SizedBox(height: 16),
        if (_asking) ...[
          Text(_currentQuestion,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _answerCtrl,
            decoration: const InputDecoration(labelText: 'Answer'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _submitAnswer, child: const Text('Submit')),
        ]
      ],
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Top 3 Recommendations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _recommendations.length,
            itemBuilder: (c, i) {
              final r = _recommendations[i];
              return CheckboxListTile(
                value: _selected[i],
                onChanged: (v) => setState(() => _selected[i] = v ?? false),
                title: Text(r['schemeName'] ?? ''),
                subtitle: Text(r['reason'] ?? ''),
              );
            },
          ),
        ),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
              labelText: 'Emails to send details (comma separated)'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
            onPressed: _saveSelectedSchemes,
            child: const Text('Save & Send Emails'))
      ],
    );
  }
}
