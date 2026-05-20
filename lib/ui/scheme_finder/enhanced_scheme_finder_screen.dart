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

  // Public welfare query detection keywords - dynamically updated from schemes
  late Set<String> _dynamicPublicWelfareKeywords;
  static const List<String> _intentActionWords = [
    'build', 'develop', 'construct', 'create', 'start', 'open', 'improve',
    'establish', 'setup', 'set up', 'launch', 'begin', 'initiate', 'organize',
    'organize', 'run', 'manage', 'support', 'implement', 'promote', 'provide',
    'need', 'want', 'require', 'seeking', 'looking for', 'apply', 'get',
  ];


  // NEW: State for public welfare direct-response mode
  bool _isPublicWelfareMode = false;

  // NEW: Store scores for public welfare matches
  Map<String, int> _publicWelfareScores = {};

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

    // 🔥 DYNAMIC KEYWORD EXTRACTION: Build keyword pool from actual schemes
    _buildDynamicPublicWelfareKeywords();

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

    final raw = message.toLowerCase();

    // 🔥 STEP 1: PUBLIC WELFARE DETECTION (FIRST PRIORITY)
    if (isPublicWelfareQuery(raw)) {
      debugPrint("🔥 PUBLIC WELFARE TRIGGERED BEFORE ANY FLOW");

      _addUser(message);
      setState(() => _isLoading = true);

      final results = _matchPublicWelfareSchemes(raw);

      await _showPublicWelfareResults(results, raw);

      if (!mounted) return; // ✅ PREVENT CRASH
      setState(() => _isLoading = false);

      return; // 🚨 HARD STOP — NOTHING ELSE RUNS
    }

    // 🔥 STEP 2: NORMAL FLOW (ONLY IF NOT WELFARE)

    _addUser(message);
    _textController.clear();

    if (!mounted) return;
    setState(() => _isLoading = true);

    if (!_initialProblemCaptured) {
      _initialProblemCaptured = true;
      _initialProblemText = message;
      debugPrint('📝 First message captured as problem description');
    }

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

    // Step 2: FALLBACK PUBLIC WELFARE CHECK (if raw check missed it)
    if (isPublicWelfareQuery(message)) {
      debugPrint('🚨 Public welfare query detected (fallback); bypassing follow-ups');
      _isPublicWelfareMode = true;
      final results = _matchPublicWelfareSchemes(message);
      await _showPublicWelfareResults(results, message);
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    // Step 3: First message initialization for Gemini flow (only if not welfare)
    if (!_initialProblemCaptured) {
      // If Gemini is disabled, go straight to filtering
      if (!_geminiReady) {
        debugPrint('🚫 Gemini unavailable; filtering schemes directly');
        _matchedSchemes = _rankSchemes(_filterSchemes());
        await _showSchemeResults();
      }
      // If Gemini is enabled, continue to Step 4 for follow-up decision
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
          debugPrint('🚨 Gemini failed → fallback to direct schemes');
          _matchedSchemes = _rankSchemes(filteredSchemes);
          await _showSchemeResults();
          return; // 🔥 CRITICAL: prevent follow-up logic
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
        sessionLanguage: sessionLanguage,
      );

      // Parse response strictly — ENFORCE FORMAT
      final trimmed = response.trim();
      if (!trimmed.startsWith('ASK:') && trimmed != 'DONE') {
        debugPrint('🚫 Invalid Gemini response — forcing DONE');
        return 'DONE';
      }
      return trimmed;
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

    final queryText = (_initialProblemText ?? '').trim();
    final normalizedQuery = _normalizeText(queryText);
    final keywords = _expandProblemKeywords(_extractProblemKeywords(normalizedQuery));

    for (final scheme in _matchedSchemes.take(3)) {
      final score = _schemeScores[scheme.schemeId] ?? 0;
      final reason = _schemeProblemMatchReason(scheme, keywords, normalizedQuery);
      final keyBenefit = _schemeKeyBenefit(scheme);
      final baseText =
          '${scheme.schemeName}: $reason\nKey benefit: $keyBenefit';

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
          _addBot('$baseText\n$explanation');
        } catch (e) {
          debugPrint('❌ Gemini explain error: $e');
          _addBot(baseText);
        }
      } else {
        _addBot(baseText);
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
    // Do not eliminate schemes early based on age/category/income.
    // All schemes should remain available for ranking by problem intent first.
    debugPrint('🔍 Using all ${_allSchemes.length} schemes for ranking (no hard eligibility elimination)');
    return _allSchemes;
  }

  /// Build a public welfare-friendly searchable string for each scheme
  String _schemeSearchText(Scheme scheme) {
    return '${scheme.schemeName} ${scheme.benefits} ${scheme.benefitType} ${scheme.allBenefitsDescription} ${scheme.remarks} ${scheme.department} ${scheme.targetGroup}'
        .toLowerCase();
  }

  /// Normalize text for keyword extraction and phrase matching
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extract the user problem keywords from a query
  Set<String> _extractProblemKeywords(String query) {
    const stopWords = {
      'the', 'and', 'for', 'with', 'from', 'that', 'this', 'will', 'have',
      'been', 'are', 'all', 'more', 'other', 'through', 'person', 'also',
      'individual', 'such', 'eligible', 'scheme', 'india', 'state', 'a',
      'an', 'in', 'on', 'at', 'by', 'of', 'to', 'or', 'as', 'is', 'it',
      'its', 'but', 'if', 'be', 'you', 'your', 'my', 'our', 'we', 'they',
      'them', 'their', 'these', 'those',
      'has', 'had', 'do', 'does', 'did', 'can', 'could', 'should', 'would'
    };

    return _normalizeText(query)
        .split(' ')
        .where((word) => word.length >= 3 && !stopWords.contains(word))
        .toSet();
  }

  /// Expand keywords using domain-aware synonyms so related schemes score higher.
  Set<String> _expandProblemKeywords(Set<String> keywords) {
    final expanded = Set<String>.from(keywords);
    for (final keyword in keywords) {
      switch (keyword) {
        case 'solar':
          expanded.addAll(['renewable', 'electricity', 'energy', 'pv']);
          break;
        case 'pump':
          expanded.addAll(['irrigation', 'water', 'submersible', 'borewell']);
          break;
        case 'farming':
        case 'farmer':
        case 'agriculture':
          expanded.addAll(['farm', 'crop', 'irrigation', 'harvest']);
          break;
        case 'irrigation':
          expanded.addAll(['water', 'pump', 'canal', 'drip']);
          break;
        case 'electric':
        case 'electricity':
          expanded.addAll(['power', 'solar', 'renewable']);
          break;
        case 'housing':
        case 'house':
        case 'home':
          expanded.addAll(['shelter', 'pucca', 'rental']);
          break;
        case 'health':
          expanded.addAll(['medical', 'hospital', 'treatment', 'doctor']);
          break;
        case 'education':
          expanded.addAll(['scholarship', 'school', 'college', 'training']);
          break;
        case 'women':
        case 'widow':
          expanded.addAll(['female', 'girl', 'mother']);
          break;
        case 'startup':
        case 'business':
        case 'entrepreneur':
          expanded.addAll(['loan', 'finance', 'funding', 'trade']);
          break;
        case 'skill':
        case 'training':
          expanded.addAll(['course', 'workshop', 'development']);
          break;
      }
      if (keyword.endsWith('ing') && keyword.length > 5) {
        expanded.add(keyword.substring(0, keyword.length - 3));
      }
      if (keyword.endsWith('s') && keyword.length > 3) {
        expanded.add(keyword.substring(0, keyword.length - 1));
      }
    }
    return expanded;
  }

  int _calculateProblemScore(
    Scheme scheme,
    Set<String> keywords,
    String normalizedQuery,
  ) {
    if (keywords.isEmpty) return 0;

    final searchText = _schemeSearchText(scheme);
    int score = 0;
    int keywordMatches = 0;

    for (final keyword in keywords) {
      if (!searchText.contains(keyword)) continue;
      keywordMatches += 1;
      if (scheme.schemeName.toLowerCase().contains(keyword)) {
        score += 18;
      } else if (scheme.benefitType.toLowerCase().contains(keyword) ||
          scheme.department.toLowerCase().contains(keyword) ||
          scheme.targetGroup.toLowerCase().contains(keyword)) {
        score += 14;
      } else {
        score += 10;
      }
    }

    if (keywordMatches > 1) {
      score += (keywordMatches - 1) * 6;
    }

    if (normalizedQuery.isNotEmpty && searchText.contains(normalizedQuery)) {
      score += 40;
    }

    if (keywordMatches >= 4) {
      score += 15;
    }

    return score.clamp(0, 100);
  }

  int _calculateEligibilityScore(Scheme scheme) {
    int score = 0;
    final occupation = (_profile.occupation ?? '').toLowerCase();
    final category = (_profile.category ?? '').toLowerCase();
    final gender = (_profile.gender ?? '').toLowerCase();
    final state = (_profile.state ?? '').toLowerCase();

    if (occupation.isNotEmpty &&
        scheme.occupationEligible.toLowerCase().contains(occupation)) {
      score += 20;
    }
    if (occupation.isNotEmpty &&
        scheme.beneficiaryType.toLowerCase().contains(occupation)) {
      score += 15;
    }
    if (category.isNotEmpty &&
        (scheme.categoryEligible.toLowerCase().contains(category) ||
            scheme.casteEligible.toLowerCase().contains(category))) {
      score += 15;
    }
    if (gender.isNotEmpty &&
        scheme.genderEligible.toLowerCase() != 'all' &&
        scheme.genderEligible.toLowerCase().contains(gender)) {
      score += 5;
    }
    if (state.isNotEmpty &&
        scheme.state.isNotEmpty &&
        scheme.state.toLowerCase() != 'india' &&
        scheme.state.toLowerCase() == state) {
      score += 5;
    }
    if (_profile.age != null && (scheme.minAge != null || scheme.maxAge != null)) {
      if ((scheme.minAge == null || _profile.age! >= scheme.minAge!) &&
          (scheme.maxAge == null || _profile.age! <= scheme.maxAge!)) {
        score += 10;
      }
    }
    if (_profile.annualIncome != null && scheme.maxIncomeINR != null) {
      if (_profile.annualIncome! <= scheme.maxIncomeINR!) {
        score += 10;
      }
    }
    return score.clamp(0, 100);
  }

  String _schemeProblemMatchReason(
    Scheme scheme,
    Set<String> keywords,
    String normalizedQuery,
  ) {
    final searchText = _schemeSearchText(scheme);
    if (normalizedQuery.isNotEmpty && searchText.contains(normalizedQuery)) {
      return 'Matches your request for "$normalizedQuery".';
    }

    final matched = keywords.where((k) => searchText.contains(k)).toList();
    if (matched.isNotEmpty) {
      final top = matched.take(4).join(', ');
      return 'Matches your problem keywords: $top.';
    }
    return 'This scheme is relevant based on your problem and eligibility.';
  }

  String _schemeKeyBenefit(Scheme scheme) {
    final benefitSource = scheme.benefitType.isNotEmpty
        ? scheme.benefitType
        : scheme.benefits.isNotEmpty
            ? scheme.benefits
            : scheme.allBenefitsDescription.isNotEmpty
                ? scheme.allBenefitsDescription
                : scheme.remarks;

    final normalized = _normalizeText(benefitSource);
    if (normalized.length > 100) {
      return '${normalized.substring(0, 100).trim()}...';
    }
    return normalized.isEmpty ? 'No benefit details available.' : normalized;
  }

  /// 🔥 DYNAMIC KEYWORD EXTRACTION: Build keyword pool from Firestore schemes
  /// This runs once in _init() to populate _dynamicPublicWelfareKeywords
  /// from actual scheme fields instead of hardcoding
  void _buildDynamicPublicWelfareKeywords() {
    final keywords = <String>{};

    // Extract nouns, verbs, and domain-specific terms from all schemes
    for (final scheme in _allSchemes) {
      _extractKeywordsFromText(scheme.schemeName, keywords);
      _extractKeywordsFromText(scheme.benefitType, keywords);
      _extractKeywordsFromText(scheme.benefits, keywords);
      _extractKeywordsFromText(scheme.allBenefitsDescription, keywords);
      _extractKeywordsFromText(scheme.department, keywords);
      _extractKeywordsFromText(scheme.targetGroup, keywords);
      _extractKeywordsFromText(scheme.remarks, keywords);
    }

    _dynamicPublicWelfareKeywords = keywords;
    debugPrint(
        '🔑 Built dynamic keyword pool: ${keywords.length} unique keywords');
    if (keywords.length <= 50) {
      debugPrint('   Keywords: ${keywords.take(20).join(", ")}...');
    }
  }

  /// Extract meaningful keywords from text by splitting and filtering
  /// Removes common stop words and keeps only significant terms
  void _extractKeywordsFromText(String text, Set<String> keywordSet) {
    if (text.isEmpty) return;

    // Normalize: lowercase, remove punctuation, split by common delimiters
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && word.length > 3) // Only >3 chars
        .toList();

    // Common stop words to exclude
    const stopWords = {
      'the', 'and', 'for', 'with', 'from', 'that', 'this', 'will', 'have',
      'been', 'are', 'all', 'more', 'other', 'through', 'person', 'also',
      'individual', 'such', 'eligible', 'benefit', 'scheme', 'india', 'state'
    };

    for (final word in normalized) {
      if (!stopWords.contains(word)) {
        keywordSet.add(word);
      }
    }
  }

  /// Detect public welfare queries using both scheme fields and strong keywords
  bool isPublicWelfareQuery(String text) {
    final t = text.toLowerCase();

    // 🔥 INTENT WORDS
    const intentWords = [
      'build', 'develop', 'construct', 'create', 'start', 'make',
      'open', 'setup', 'establish', 'launch', 'improve', 'upgrade'
    ];

    // 🔥 DOMAIN WORDS (VERY IMPORTANT)
    const domainWords = [
      'garden', 'park', 'playground', 'tree', 'plantation', 'forest',
      'road', 'drainage', 'sewage', 'water', 'toilet', 'sanitation',
      'vendor', 'street', 'shop', 'market', 'tourism', 'temple',
      'community', 'hall', 'camp', 'event', 'training', 'solar',
      'electric', 'waste', 'recycle', 'green', 'environment'
    ];

    if (intentWords.any((w) => t.contains(w))) return true;
    if (domainWords.any((w) => t.contains(w))) return true;

    if (_dynamicPublicWelfareKeywords.isNotEmpty) {
      if (_dynamicPublicWelfareKeywords.any((w) => t.contains(w))) {
        return true;
      }
    }

    for (final scheme in _allSchemes) {
      if (scheme.schemeId.toUpperCase().startsWith('ENV')) {
        if (_queryMatchesSchemeFields(scheme, t)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _queryMatchesSchemeFields(Scheme scheme, String query) {
    final searchText = _schemeSearchText(scheme);
    final queryWords = query.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (queryWords.isEmpty) return false;

    int hits = 0;
    for (final word in queryWords) {
      if (searchText.contains(word)) {
        hits++;
      }
    }

    return hits >= 1;
  }

  /// Return schemes that match broad public welfare intent keywords and scheme fields
  List<Map<String, dynamic>> _matchPublicWelfareSchemes(String query) {
    final lowerQuery = query.toLowerCase();
    final queryWords = lowerQuery.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();

    final matched = <Scheme, int>{};

    for (final scheme in _allSchemes) {
      final searchText = _schemeSearchText(scheme);
      int score = 0;

      if (scheme.schemeId.toUpperCase().startsWith('ENV')) {
        score += 30;
      }

      for (final word in queryWords) {
        if (searchText.contains(word)) {
          score += 20;
        }
      }

      if (queryWords.length > 1) {
        final phrase = queryWords.join(' ');
        if (searchText.contains(phrase)) {
          score += 25;
        }
      }

      if (score > 0) {
        matched[scheme] = score;
      }
    }

    final sorted = matched.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .map((entry) => {
              'scheme': entry.key,
              'score': entry.value,
            })
        .toList();
  }

  String _shortSchemeDescription(Scheme scheme) {
    var description = scheme.benefits.isNotEmpty
        ? scheme.benefits
        : scheme.allBenefitsDescription.isNotEmpty
            ? scheme.allBenefitsDescription
            : scheme.remarks;
    description = description.trim();
    if (description.isEmpty) {
      return 'No short description available.';
    }
    if (description.length > 90) {
      description = '${description.substring(0, 90).trim()}...';
    }
    return description;
  }

  String _publicWelfareMatchReason(Scheme scheme, String query) {
    final searchText = _schemeSearchText(scheme);
    final queryWords = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();

    final matched = queryWords.where((word) => searchText.contains(word)).toList();
    if (matched.isNotEmpty) {
      final reasonWords = matched.take(3).join(', ');
      return 'Matches your request for $reasonWords.';
    }
    if (scheme.schemeId.toUpperCase().startsWith('ENV')) {
      return 'This is an environmental/public welfare scheme.';
    }
    return 'This scheme is relevant to your request.';
  }

  Future<void> _showPublicWelfareResults(
      List<Map<String, dynamic>> results, String query) async {
    if (results.isEmpty) {
      _addBot(
          'No relevant public welfare schemes found. Try keywords like garden, vendor, or tourism.');
      return;
    }

    _addBot(
        'I found ${results.length} public welfare scheme(s) for your request. Here are the best matches:');

    final displayCount = results.length > 7 ? 7 : results.length;
    _matchedSchemes = results
        .take(displayCount)
        .map((entry) => entry['scheme'] as Scheme)
        .toList();

    final topCount = displayCount >= 3 ? 3 : displayCount;
    for (int i = 0; i < topCount; i++) {
      final scheme = results[i]['scheme'] as Scheme;
      final description = _shortSchemeDescription(scheme);
      final reason = _publicWelfareMatchReason(scheme, query);
      final detailLine = scheme.officialApplyLink.isNotEmpty
          ? 'View Details: ${scheme.officialApplyLink}'
          : 'View details in the app.';
      _addBot(
          '${i + 1}. ${scheme.schemeName}\n$reason\n$description\n$detailLine');
    }

    for (int i = topCount; i < displayCount; i++) {
      final scheme = results[i]['scheme'] as Scheme;
      final description = _shortSchemeDescription(scheme);
      _addBot('${i + 1}. ${scheme.schemeName}: $description');
    }

    if (results.length > displayCount) {
      _addBot(
          'There are ${results.length} matching public welfare schemes in total. Use the app list to explore more.');
    }

    if (!mounted) return;
    setState(() {
      _showSchemeSelection = true;
      _showEmailPrompt = false;
      _emailSending = false;
      _emailResultMessage = null;
      _selectedSchemes = List.generate(_matchedSchemes.length, (_) => false);
    });
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
    final queryText = (_initialProblemText ?? '').trim();
    final normalizedQuery = _normalizeText(queryText);
    final baseKeywords = _extractProblemKeywords(normalizedQuery);
    final keywords = _expandProblemKeywords(baseKeywords);

    debugPrint('🔑 User keywords: ${keywords.toList()}');

    final List<MapEntry<Scheme, int>> scored = [];

    for (final scheme in schemes) {
      final problemScore = _calculateProblemScore(scheme, keywords, normalizedQuery);
      final eligibilityScore = _calculateEligibilityScore(scheme);
      final finalScore = ((problemScore * 70) + (eligibilityScore * 30)) ~/ 100;

      scored.add(MapEntry(scheme, finalScore));
      debugPrint(
          '   🔎 ${scheme.schemeName}: problemScore=$problemScore eligibilityScore=$eligibilityScore finalScore=$finalScore');
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    _schemeScores = {for (final e in scored) e.key.schemeId: e.value};
    return scored.map((e) => e.key).toList();
  }

  // ===============================================================
  // UI HELPERS
  // ===============================================================
  void _addUser(String text) {
    if (!mounted) return;
    setState(() => _messages.add(_ChatMessage(text, true)));
    _scrollToBottom();
  }

  void _addBot(String text) async {
    if (!mounted) return;
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
          if (_voiceMode)
            IconButton(
              icon: const Icon(Icons.volume_off),
              tooltip: 'Skip audio / Stop TTS',
              onPressed: () => _ttsService.stop(),
            ),
          IconButton(
            icon: Icon(_voiceMode ? Icons.mic : Icons.keyboard),
            onPressed: () => setState(() => _voiceMode = !_voiceMode),
          )
        ],
      ),
      body: Column(
        children: [
          if (_emailSending) const LinearProgressIndicator(),
          if (_emailResultMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_emailResultMessage!,
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_showSchemeSelection && _matchedSchemes.isNotEmpty ? 1 : 0),
              itemBuilder: (_, i) {
                if (i < _messages.length) {
                  return _bubble(_messages[i]);
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: _buildSaveCard(),
                  );
                }
              },
            ),
          ),
          SafeArea(child: _inputArea()),
        ],
      ),
    );
  }

  Widget _buildSaveCard() {
    final anySelected = _selectedSchemes.any((s) => s);
    final selectedCount = _selectedSchemes.where((s) => s).length;
    final titleText = _sessionLanguage == 'hi' 
        ? 'योजनाएं सहेजें' 
        : _sessionLanguage == 'mr' 
            ? 'योजना जतन करा' 
            : 'Save Schemes';
    final subText = _sessionLanguage == 'hi'
        ? '🔖 चुनें, फिर सेव या ईमेल करें'
        : _sessionLanguage == 'mr'
            ? '🔖 निवडा, नंतर जतन करा किंवा ईमेल करा'
            : 'Tap 🔖 to select, then save or email';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.4), width: 1.5),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.bookmark_add_outlined, color: AppTheme.primaryColor),
        title: Text(
          anySelected ? '$titleText  (✓ $selectedCount)' : titleText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        subtitle: Text(subText),
        children: [
          ..._matchedSchemes.asMap().entries.map((entry) {
            int idx = entry.key;
            final scheme = entry.value;
            final selected = _selectedSchemes.length > idx && _selectedSchemes[idx];
            return ListTile(
              onTap: () {
                setState(() {
                  if (_selectedSchemes.length > idx) {
                    _selectedSchemes[idx] = !_selectedSchemes[idx];
                  }
                });
              },
              leading: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey(selected),
                  color: selected ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
              title: Text(
                scheme.schemeName,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppTheme.primaryColor : Colors.black87,
                ),
              ),
              subtitle: Text(scheme.department, style: const TextStyle(fontSize: 12)),
              trailing: selected
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                  : null,
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: anySelected && !_emailSending
                      ? () async {
                          setState(() => _emailSending = true);
                          await _saveSelectedSchemesAndSendEmail(sendEmail: false);
                        }
                      : null,
                  icon: const Icon(Icons.bookmark_add),
                  label: Text(_sessionLanguage == 'hi' ? 'सहेजें (Save)' : _sessionLanguage == 'mr' ? 'जतन करा (Save)' : 'Save to My Schemes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: anySelected && !_emailSending
                      ? () async {
                          setState(() => _emailSending = true);
                          await _saveSelectedSchemesAndSendEmail(sendEmail: true);
                        }
                      : null,
                  icon: const Icon(Icons.email_outlined),
                  label: Text(_sessionLanguage == 'hi' ? 'ईमेल करें (Email)' : _sessionLanguage == 'mr' ? 'ईमेल करा (Email)' : 'Save & Email Me'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
