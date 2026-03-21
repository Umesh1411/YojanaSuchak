import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/scheme.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../services/data_service.dart';
import '../../services/gemini_chat_service.dart';
import '../../services/firestore_service.dart';
import '../../services/email_service.dart';
import '../../services/profile_extractor.dart';
import '../../services/eligibility_filter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import 'package:flutter/foundation.dart';

/// ===============================================================
/// ENHANCED SCHEME FINDER – GEMINI DRIVEN (SINGLE FILE VERSION)
/// ===============================================================
class EnhancedSchemeFinderScreen extends StatefulWidget {
  const EnhancedSchemeFinderScreen({super.key});

  @override
  State<EnhancedSchemeFinderScreen> createState() =>
      _EnhancedSchemeFinderScreenState();
}

class _EnhancedSchemeFinderScreenState extends State<EnhancedSchemeFinderScreen>
    with SingleTickerProviderStateMixin {
  // Post-recommendation flow state
  bool _showSchemeSelection = false;
  bool _showEmailPrompt = false;
  bool _emailSending = false;
  String? _emailResultMessage;
  List<bool> _selectedSchemes = [];
  // ------------------ Services ------------------
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();
  GeminiChatService? _geminiChatService;
  bool _geminiReady = false;

  // ------------------ State ------------------
  final UserProfile _profile = UserProfile();
  List<Scheme> _allSchemes = [];
  List<Scheme> _matchedSchemes = [];
  Map<String, int> _schemeScores = {};
  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _voiceMode = true;
  bool _isListening = false;
  bool _initialProblemCaptured = false; // True after first user message
  String? _initialProblemText; // Store first user message for context
  int _followUpCount = 0; // Track follow-up questions (soft limit at 5)

  // NEW: Session-level state for intelligent questioning
  String? _sessionLanguage; // Lock language to first message (en/hi/mr)
  final Set<String> _askedQuestions = {}; // Track which questions were asked
  Set<String> _requiredFields =
      {}; // Fields required by current matching schemes

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ------------------ Animation ------------------
  AnimationController? _animationController;

  // Animation pulse available for future UI animations
  // late Animation<double> _pulse;

  // ===============================================================
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    debugPrint("🚀 _init() starting...");

    // Initialize core services on all platforms
    final speechReady = await _speechService.initialize();
    await _ttsService.initialize();
    _allSchemes = await DataService.loadSchemes();

    // Set voice mode based on speech service availability (not platform)
    _voiceMode = speechReady;
    debugPrint('🎤 Voice mode: $_voiceMode (speech available: $speechReady)');

    // ======== GEMINI INITIALIZATION ========
    // Gemini API key was loaded in main.dart and stored in AppConfig
    // Only initialize if key is available
    final apiKey = AppConfig.geminiApiKey;
    if (apiKey.isNotEmpty) {
      try {
        _geminiChatService = GeminiChatService(apiKey: apiKey);
        _geminiReady = true;
        debugPrint('✅ GeminiChatService initialized');
      } catch (e) {
        debugPrint('❌ Failed to initialize GeminiChatService: $e');
        _geminiChatService = null;
        _geminiReady = false;
      }
    } else {
      debugPrint('⚠️ Gemini API key not configured');
      _geminiChatService = null;
      _geminiReady = false;
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Add initial bot message after initialization
    // Per design: user describes freely first, no questions asked
    Future.microtask(() {
      _addBot(
          'Tell me about your situation or problem. I\'ll find schemes for you.');
    });
  }

  // ===============================================================
  // CHAT HANDLING (GEMINI-DRIVEN, SCHEME-AWARE)
  // ===============================================================
  Future<void> _handleUser(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message and clear input
    _addUser(message);
    _textController.clear();

    setState(() => _isLoading = true);

    // Step 0: Detect user's language and LOCK it for the session
    final detectedLanguage = ProfileExtractor.detectLanguage(message);
    if (_sessionLanguage == null) {
      _sessionLanguage = detectedLanguage;
      debugPrint('🔒 Session language LOCKED: $_sessionLanguage');
    } else {
      debugPrint(
          '🌐 Using session language: $_sessionLanguage (detected: $detectedLanguage)');
    }

    // Step 1: Extract profile fields intelligently (handles multi-field in single message)
    final parsed = ProfileExtractor.extractMultipleFields(message);
    ProfileExtractor.applyParsedToProfile(_profile, parsed);

    if (parsed.isNotEmpty) {
      debugPrint('✅ Extracted fields: ${parsed.keys.join(", ")}');
      // Mark these fields as "answered" so we don't ask about them again
      for (final field in parsed.keys) {
        _askedQuestions.add(field.toString());
      }
    }

    // Step 2: First message is ALWAYS treated as problem description (no Gemini decision)
    if (!_initialProblemCaptured) {
      _initialProblemCaptured = true;
      _initialProblemText = message;
      debugPrint('📝 First message captured as problem description');

      // If Gemini is disabled, go straight to filtering
      if (!_geminiReady) {
        debugPrint('🚫 Gemini unavailable; filtering schemes directly');
        _matchedSchemes = _rankSchemes(_filterSchemes());
        await _showSchemeResults();
      }
      // If Gemini is enabled, continue to Step 3 for follow-up decision
    }

    // Step 3: Only call Gemini AFTER first message AND only if Gemini is ready
    if (_initialProblemCaptured && _geminiReady) {
      final filteredSchemes = _filterSchemes();
      final profileMissing = _getProfileMissingFields();

      // CRITICAL: Distinguish "no schemes matched" from "profile incomplete"
      final hasSchemes = filteredSchemes.isNotEmpty;
      final profileComplete = profileMissing.isEmpty;

      debugPrint(
          '📊 State: hasSchemes=$hasSchemes, profileComplete=$profileComplete, followUp=$_followUpCount/5');

      // Compute which fields are required by schemes that DID match
      _requiredFields =
          hasSchemes ? _computeRequiredFields(filteredSchemes) : <String>{};
      debugPrint('📋 Required from schemes: $_requiredFields');
      debugPrint('📋 Missing from profile: $profileMissing');

      // MERGED required fields: from schemes + profile missing
      // If schemes matched, prioritize their requirements
      // If no schemes matched, fall back to general profile missing fields
      final mergedMissingFields =
          hasSchemes ? _requiredFields.union(profileMissing) : profileMissing;

      // Compute which fields we haven't asked about yet
      final missingToAsk = mergedMissingFields
          .where((field) =>
              !_askedQuestions.contains(field) && !_isFieldFilled(field))
          .toSet();

      debugPrint('❓ To ask: $missingToAsk (total asked: $_askedQuestions)');

      // DECISION LOGIC:
      // 1. If profile complete AND schemes matched → show results
      // 2. If profile complete BUT no schemes → ask 1-2 last-resort clarifying Qs (soft limit +2)
      // 3. If profile incomplete → ask missing fields (soft limit at 5, hard limit at 7)
      // 4. Never ask if missingToAsk is empty

      final shouldShowResults =
          (profileComplete && hasSchemes) || (_followUpCount >= 7);
      final allowEmergencyQuestions =
          !hasSchemes && profileComplete && _followUpCount < 7;
      final normalQuestioning = !profileComplete && _followUpCount < 5;
      final softLimitReached = _followUpCount >= 5 && missingToAsk.length <= 1;

      if (missingToAsk.isEmpty) {
        // No more fields to ask about
        debugPrint('🛑 No missing fields to ask');
        _matchedSchemes = _rankSchemes(filteredSchemes);
        await _showSchemeResults();
      } else if (shouldShowResults) {
        // Hard stop at 7 questions or profile complete + schemes found
        debugPrint('🛑 Showing results (profile complete or hard limit)');
        _matchedSchemes = _rankSchemes(filteredSchemes);
        await _showSchemeResults();
      } else if (softLimitReached && !allowEmergencyQuestions) {
        // Soft limit: stop unless we have emergency questions to ask
        debugPrint('⚠️ Soft limit reached; showing results');
        _matchedSchemes = _rankSchemes(filteredSchemes);
        await _showSchemeResults();
      } else if (normalQuestioning || allowEmergencyQuestions) {
        // Continue asking (normal mode or emergency mode)
        debugPrint(
            '❓ Asking follow-up (normal=$normalQuestioning, emergency=$allowEmergencyQuestions)');

        final geminiDecision = await _askGeminiForNextStep(
          _sessionLanguage!,
          missingToAsk,
          filteredSchemes,
          noSchemeContext: !hasSchemes,
        );

        if (geminiDecision == null) {
          // Gemini call failed: fallback
          debugPrint('⚠️ Gemini call failed; filtering schemes');
          _matchedSchemes = _rankSchemes(filteredSchemes);
          await _showSchemeResults();
        } else if (geminiDecision == 'DONE') {
          // Gemini says: enough info, show schemes
          debugPrint('✅ Gemini returned DONE; showing schemes');
          _matchedSchemes = _rankSchemes(filteredSchemes);
          await _showSchemeResults();
        } else if (geminiDecision.startsWith('ASK:')) {
          // Gemini generated a question
          _followUpCount++;
          final question = geminiDecision.substring(4).trim();

          // Mark up to 2 missing fields as "asked" to prevent repeats
          final toMark = missingToAsk.take(2).toList();
          for (final f in toMark) {
            _askedQuestions.add(f);
          }

          _addBot(question);
          debugPrint(
              '❓ Follow-up $_followUpCount: $question (mode: ${allowEmergencyQuestions ? 'emergency' : 'normal'})');
        } else {
          // Unexpected format: treat as DONE
          debugPrint(
              '⚠️ Unexpected Gemini response: "$geminiDecision" — treating as DONE');
          _matchedSchemes = _rankSchemes(filteredSchemes);
          await _showSchemeResults();
        }
      } else {
        // Fallback: should not reach here, but show results
        debugPrint('⚠️ Unexpected state; showing results');
        _matchedSchemes = _rankSchemes(filteredSchemes);
        await _showSchemeResults();
      }
    }

    setState(() => _isLoading = false);
  }

  /// Ask Gemini to generate questions about missing required fields
  /// Returns "ASK: <question>", "DONE", or null if Gemini unavailable
  /// Respects session language and prevents asking already-asked questions
  Future<String?> _askGeminiForNextStep(
    String sessionLanguage,
    Set<String> missingFields,
    List<Scheme> candidateSchemes, {
    bool noSchemeContext = false,
  }) async {
    if (!_geminiReady || _geminiChatService == null) {
      return null; // Graceful degradation
    }

    try {
      // Map field names to user-friendly labels
      final fieldLabels = {
        'age': 'age',
        'gender': 'gender',
        'occupation': 'occupation',
        'location': 'state and district',
        'state': 'state',
        'district': 'district',
        'annualIncome': 'annual income',
        'category': 'caste/category',
      };

      final missingFieldsList =
          missingFields.map((f) => fieldLabels[f] ?? f).join(', ');

      final languageName = sessionLanguage == 'hi'
          ? 'Hindi'
          : sessionLanguage == 'mr'
              ? 'Marathi'
              : 'English';

      // Build context based on whether we have schemes or not
      String schemeSummary = '';
      String contextLine = '';

      if (noSchemeContext || candidateSchemes.isEmpty) {
        // No schemes matched yet: general profile-building context
        contextLine =
            'No schemes matched your profile yet. Let\'s gather more information.';
      } else {
        // Schemes exist: provide context
        schemeSummary = candidateSchemes
            .take(5)
            .map((s) =>
                '${s.schemeName} (occupation: ${s.occupationEligible}, minAge: ${s.minAge}, maxAge: ${s.maxAge}, maxIncome: ${s.maxIncomeINR}, category: ${s.categoryEligible})')
            .join('\n');
        contextLine =
            'Candidate Schemes (${candidateSchemes.length}):\n$schemeSummary\n';
      }

      // IMPORTANT: Gemini is told EXACTLY which fields are missing and required
      // It MUST NOT invent eligibility rules or decide which schemes to recommend
      final decisionPrompt =
          '''You are an eligibility assistant helping Indian citizens. Your role is ONLY to generate natural questions, NOT decide eligibility.

Language: Respond ONLY in $languageName.

$contextLine

Required Information MISSING from profile: $missingFieldsList

Your job:
1. Ask about the SPECIFIC missing fields above ONLY
2. Combine 1–2 fields into a natural question if possible (e.g., "What is your age and income?")
3. Do NOT ask any other questions
4. Do NOT decide eligibility or scheme relevance
5. Do NOT repeat these fields: ${_askedQuestions.join(", ")}

Respond with EXACTLY:
- ASK: <your natural question asking for: $missingFieldsList>
- DONE (if somehow all required info is present)

Do NOT include any other text.''';

      // Call Gemini
      final response = await _geminiChatService!.getChatResponse(
        userMessage: decisionPrompt,
        profile: _profile,
        availableSchemes: candidateSchemes,
      );

      // Parse response strictly
      final trimmed = response.trim();
      if (trimmed.startsWith('ASK:') || trimmed == 'DONE') {
        return trimmed;
      } else {
        // Invalid format — treat as DONE to prevent infinite loops
        debugPrint('⚠️ Gemini format invalid: "$trimmed" — treating as DONE');
        return 'DONE';
      }
    } catch (e) {
      debugPrint('❌ Gemini error: $e');
      return null; // Trigger fallback
    }
  }

  /// Display filtered schemes with explanations
  Future<void> _showSchemeResults() async {
    if (_matchedSchemes.isEmpty) {
      _addBot(
          "I found some schemes that may help you. I may need one or two more details to confirm eligibility.");
      return;
    }
    _matchedSchemes = _rankSchemes(_matchedSchemes);

    _addBot("Great! I found ${_matchedSchemes.length} scheme(s) for you:");

    for (final scheme in _matchedSchemes.take(3)) {
      final score = _schemeScores[scheme.schemeId] ?? 0;

      // If scheme is a low-scoring partial match, warn the user before explaining
      if (score < 20) {
        String note;
        if (_sessionLanguage == 'hi') {
          note =
              'नोट: यह योजना आंशिक रूप से मेल खाती है; कृपया पात्रता जाँचें।';
        } else if (_sessionLanguage == 'mr') {
          note = 'टीप: ही योजना आंशिक जुळणारी आहे; कृपया पात्रता तपासा.';
        } else {
          note =
              'Note: This scheme is a partial match; please verify eligibility.';
        }
        _addBot('${scheme.schemeName}: $note');
      }

      if (_geminiReady && _geminiChatService != null) {
        try {
          var explanation = await _geminiChatService!.explainScheme(
            profile: _profile,
            scheme: scheme,
          );
          // Ensure explanation starts with scheme name for consistent formatting
          if (!explanation
              .trim()
              .toLowerCase()
              .startsWith(scheme.schemeName.toLowerCase())) {
            explanation = '${scheme.schemeName}: ' + explanation.trim();
          }
          _addBot(explanation);
        } catch (e) {
          debugPrint('❌ Gemini explain error: $e');
          _addBot('${scheme.schemeName}: This scheme matches your profile.');
        }
      } else {
        _addBot('${scheme.schemeName}: This scheme matches your profile.');
      }
    }

    // After showing recommendations, start post-recommendation flow
    setState(() {
      _showSchemeSelection = true;
      _showEmailPrompt = false;
      _emailSending = false;
      _emailResultMessage = null;
      _selectedSchemes = List.generate(_matchedSchemes.length, (_) => false);
    });
  }

  // (Removed local Gemini caller and local parser; profile parsing is handled
  // by `ProfileExtractor` and Gemini calls are delegated to `GeminiChatService`.)
  // ===============================================================
  // ELIGIBILITY FILTER (NO AI) - STRICT DATABASE-DRIVEN FILTERING
  // ===============================================================
  List<Scheme> _filterSchemes() {
    // Use the EligibilityFilter service which performs:
    // 1. Hard elimination (7 strict rules: age, income, occupation, caste, gender, state, beneficiaryType)
    // 2. Weighted scoring + ranking (returns top 10)
    try {
      final filtered = EligibilityFilter.filterSchemes(
        _allSchemes,
        _profile,
        initialProblemText: _initialProblemText,
      );
      debugPrint(
          '🔍 Filtered ${_allSchemes.length} → ${filtered.length} schemes');
      return filtered;
    } catch (e) {
      debugPrint('⚠️ EligibilityFilter error: $e — returning all schemes');
      return _allSchemes;
    }
  }

  /// Compute which profile fields are REQUIRED by the given list of schemes
  /// Returns a Set<String> of field names (age, gender, occupation, etc.)
  /// that are needed to finalize eligibility for ANY of the schemes
  Set<String> _computeRequiredFields(List<Scheme> schemes) {
    final required = <String>{};

    for (final scheme in schemes) {
      // If scheme has age constraints, age is required
      if (scheme.minAge != null || scheme.maxAge != null) {
        required.add('age');
      }

      // If scheme has occupation constraints, occupation is required
      if (scheme.occupationEligible != 'Any' &&
          scheme.occupationEligible != 'Not Applicable') {
        required.add('occupation');
      }

      // If scheme has income constraints, income is required
      if (scheme.maxIncomeINR != null) {
        required.add('annualIncome');
      }

      // If scheme has gender constraints, gender is required
      if (scheme.genderEligible != 'All') {
        required.add('gender');
      }

      // If scheme has caste or category constraints, category is required
      if (scheme.categoryEligible != 'All' || scheme.casteEligible != 'All') {
        required.add('category');
      }

      // If scheme is state-specific, location is required (state/district combined)
      if (scheme.state.isNotEmpty && scheme.state.toLowerCase() != 'india') {
        required.add('location');
      }
      // If scheme explicitly mentions district-level eligibility in otherEligibilityCriteria or remarks, require location
      final otherLower = scheme.otherEligibilityCriteria.toLowerCase() +
          ' ' +
          scheme.remarks.toLowerCase();
      if (otherLower.contains('district')) {
        required.add('location');
      }
    }

    return required;
  }

  /// Check if a profile field is already filled
  bool _isFieldFilled(String field) {
    switch (field) {
      case 'age':
        return _profile.age != null;
      case 'gender':
        return _profile.gender != null;
      case 'occupation':
        return _profile.occupation != null && _profile.occupation!.isNotEmpty;
      case 'state':
        return _profile.state != null;
      case 'district':
        return _profile.district != null;
      case 'location':
        return _profile.state != null && _profile.district != null;
      case 'annualIncome':
        return _profile.annualIncome != null;
      case 'category':
        return _profile.category != null;
      default:
        return false;
    }
  }

  /// Get missing fields from the profile (wrapper around profile.getMissingFields())
  /// Maps profile missing fields to field names used in _requiredFields
  Set<String> _getProfileMissingFields() {
    final missing = _profile.getMissingFields();
    final mapped = <String>{};
    for (final field in missing) {
      if (field == 'age')
        mapped.add('age');
      else if (field == 'gender')
        mapped.add('gender');
      else if (field == 'occupation')
        mapped.add('occupation');
      else if (field == 'location')
        mapped.add('location');
      else if (field == 'annualIncome') {
        // Avoid asking income initially for students/unemployed
        final occ = (_profile.occupation ?? '').toLowerCase();
        if (occ.contains('student') || occ.contains('unemployed')) {
          // skip unless schemes explicitly require income (handled elsewhere)
        } else {
          mapped.add('annualIncome');
        }
      }
    }

    return mapped;
  }

  // ===============================================================
  // RANKING
  // ===============================================================
  List<Scheme> _rankSchemes(List<Scheme> schemes) {
    final problem = (_initialProblemText ?? '').toLowerCase();
    final List<MapEntry<Scheme, int>> scored = [];

    for (final s in schemes) {
      int score = 0;

      // +30 Occupation match (HIGHEST PRIORITY)
      if (_profile.occupation != null && _profile.occupation!.isNotEmpty) {
        if (s.occupationEligible
            .toLowerCase()
            .contains(_profile.occupation!.toLowerCase())) {
          score += 30;
        }
      }

      // +20 BeneficiaryType / targetGroup match
      if (_profile.occupation != null && _profile.occupation!.isNotEmpty) {
        if (s.beneficiaryType
            .toLowerCase()
            .contains(_profile.occupation!.toLowerCase())) {
          score += 20;
        }
      }
      if (_profile.category != null && _profile.category!.isNotEmpty) {
        if (s.beneficiaryType
            .toLowerCase()
            .contains(_profile.category!.toLowerCase())) {
          score += 20;
        }
      }

      // +15 BenefitType matches problem intent
      final intentKeywords = {
        'education': [
          'education',
          'scholarship',
          'fees',
          'school',
          'college',
          'study'
        ],
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
      if (_profile.category != null) {
        if (s.casteEligible
                .toLowerCase()
                .contains(_profile.category!.toLowerCase()) ||
            s.categoryEligible
                .toLowerCase()
                .contains(_profile.category!.toLowerCase())) {
          score += 10;
        }
      }

      // +5 Age match
      if (_profile.age != null && (s.minAge != null || s.maxAge != null)) {
        if ((s.minAge == null || _profile.age! >= s.minAge!) &&
            (s.maxAge == null || _profile.age! <= s.maxAge!)) {
          score += 5;
        }
      }

      // +5 Income match
      if (_profile.annualIncome != null && s.maxIncomeINR != null) {
        if (_profile.annualIncome! <= s.maxIncomeINR!) score += 5;
      }

      // -30 Penalty: health schemes when intent is NOT health
      final benefitLower = s.benefitType.toLowerCase();
      if (!problem.contains('health') &&
          !problem.contains('illness') &&
          benefitLower.contains('health')) {
        score -= 30;
      }
      if (problem.contains('education') && benefitLower.contains('health')) {
        score -= 30;
      }
      if (problem.contains('farmer') &&
          benefitLower.contains('health') &&
          !problem.contains('health')) {
        score -= 30;
      }

      scored.add(MapEntry(s, score));
      debugPrint('   🔎 ${s.schemeName}: score=$score');
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    _schemeScores = {for (final e in scored) e.key.schemeId: e.value};
    return scored.map((e) => e.key).toList();
  }

  // ===============================================================
  // UI HELPERS
  // ===============================================================
  void _addUser(String text) {
    setState(() => _messages.add(_ChatMessage(text, true)));
    _scrollToBottom();
  }

  void _addBot(String text) async {
    setState(() => _messages.add(_ChatMessage(text, false)));
    _scrollToBottom();
    if (_voiceMode && _ttsService.isAvailable) {
      await _ttsService.speak(text);
    }
  }

  void _scrollToBottom() {
    // Scroll to bottom after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ===============================================================
  // SPEECH LISTENING
  // ===============================================================
  Future<void> _startListening() async {
    if (_isListening || _isLoading || !_voiceMode) return;

    if (!_speechService.isAvailable) {
      final available = await _speechService.initialize();
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition is not available')),
        );
        return;
      }
    }

    setState(() {
      _isListening = true;
    });

    String lastText = '';

    try {
      await for (final text in _speechService.startListening()) {
        if (text.isNotEmpty) {
          lastText = text;
        }

        // stop pressed → exit loop cleanly
        if (!_isListening) {
          break;
        }
      }
    } catch (e) {
      debugPrint("Speech error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }

      if (lastText.isNotEmpty) {
        _handleUser(lastText);
      }
    }
  }

  void _stopListening() {
    _speechService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  // ===============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Schemes'),
        actions: [
          IconButton(
            icon: Icon(_voiceMode ? Icons.mic : Icons.keyboard),
            onPressed: () => setState(() => _voiceMode = !_voiceMode),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _bubble(_messages[i]),
            ),
          ),
          if (_showSchemeSelection && _matchedSchemes.isNotEmpty)
            _buildSchemeSelectionSection(),
          if (_showEmailPrompt) _buildEmailPromptSection(),
          if (_emailSending)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          if (_emailResultMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_emailResultMessage!,
                  style: TextStyle(color: Colors.green)),
            ),
          _inputArea(),
        ],
      ),
    );
  }

  Widget _buildSchemeSelectionSection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Which scheme(s) do you want to save to “My Schemes”?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._matchedSchemes.asMap().entries.map((entry) {
              int idx = entry.key;
              final scheme = entry.value;
              return CheckboxListTile(
                value: _selectedSchemes[idx],
                onChanged: (val) {
                  setState(() {
                    // Guard against index mismatch if matched schemes update concurrently
                    if (idx >= _selectedSchemes.length) {
                      _selectedSchemes =
                          List.generate(_matchedSchemes.length, (_) => false);
                    }
                    _selectedSchemes[idx] = val ?? false;
                  });
                },
                title: Text(scheme.schemeName),
                subtitle: Text(scheme.department),
              );
            }).toList(),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    final anySelected = _selectedSchemes.any((s) => s);
                    if (!anySelected) {
                      setState(() {
                        _showSchemeSelection = false;
                        _showEmailPrompt = false;
                        _emailResultMessage =
                            'You did not select any scheme. Thank you for using the assistant.';
                      });
                      return;
                    }
                    setState(() {
                      _showSchemeSelection = false;
                      _showEmailPrompt = true;
                    });
                  },
                  child: const Text('Save to My Schemes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailPromptSection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Do you want to receive a detailed email for the selected scheme(s)?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _emailSending = true;
                    });
                    await _saveSelectedSchemesAndSendEmail(sendEmail: true);
                    setState(() {
                      _showEmailPrompt = false;
                      _emailSending = false;
                    });
                  },
                  child: const Text('Yes'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _emailSending = true;
                    });
                    await _saveSelectedSchemesAndSendEmail(sendEmail: false);
                    setState(() {
                      _showEmailPrompt = false;
                      _emailSending = false;
                    });
                  },
                  child: const Text('No'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSelectedSchemesAndSendEmail(
      {required bool sendEmail}) async {
    final auth = AuthService();
    String userId = 'demo_user';
    String userEmail = 'user@example.com';
    String userName = 'User';

    try {
      if (auth.isFirebaseConfigured &&
          auth.isAuthenticated &&
          auth.currentUser != null) {
        final u = auth.currentUser!;
        userId = u.uid;
        userEmail = u.email ?? userEmail;
        userName = u.displayName ?? (u.email?.split('@').first ?? userName);
      } else if (auth.demoUserData != null) {
        final demo = auth.demoUserData!;
        userId = demo['uid'] ?? userId;
        userEmail = demo['email'] ?? userEmail;
        userName = demo['displayName'] ?? userName;
      }
    } catch (_) {}

    final selected = _matchedSchemes
        .asMap()
        .entries
        .where((e) => _selectedSchemes[e.key])
        .map((e) => e.value)
        .toList();

    final firestoreService = FirestoreService();
    final emailService = EmailService(
      smtpHost: AppConfig.smtpHost,
      smtpPort: AppConfig.smtpPort,
      username: AppConfig.smtpUsername,
      password: AppConfig.smtpPassword,
      useTls: AppConfig.useTls,
    );

    int savedCount = 0;
    for (final scheme in selected) {
      final saved = await firestoreService.saveSchemeToUser(userId, scheme);
      if (saved) savedCount++;
      if (sendEmail) {
        if (userEmail.isEmpty || userEmail.contains('@example.com')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Please update your email in Profile to receive mails.'),
          ));
          continue;
        }

        await emailService.sendSchemeDetails(
          recipientEmail: userEmail,
          recipientName: userName,
          scheme: scheme,
        );
      }
    }

    setState(() {
      _emailResultMessage = sendEmail
          ? 'Saved $savedCount scheme(s) and sent email(s) successfully.'
          : 'Saved $savedCount scheme(s) to My Schemes.';
      // Reset selection state to prevent stale selection state
      _selectedSchemes = List.generate(_matchedSchemes.length, (_) => false);
    });
  }

  Widget _bubble(_ChatMessage m) {
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: m.isUser ? AppTheme.primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          m.text,
          style: TextStyle(color: m.isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _inputArea() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleUser,
              decoration: InputDecoration(
                hintText: _voiceMode && _isListening
                    ? 'Listening...'
                    : 'Type your message...',
                border: const OutlineInputBorder(),
              ),
              enabled: !_isListening,
            ),
          ),
          const SizedBox(width: 8),
          if (_voiceMode && !_isLoading)
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red : AppTheme.primaryColor,
              ),
              onPressed: _isListening ? _stopListening : _startListening,
              tooltip: _isListening ? 'Stop listening' : 'Start listening',
            ),
          if (!_voiceMode || _isLoading)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _isLoading || _isListening
                  ? null
                  : () => _handleUser(_textController.text),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator()),
            )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _speechService.stopListening();
    _ttsService.stop();
    super.dispose();
  }
}

// ===============================================================
class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage(this.text, this.isUser);
}
