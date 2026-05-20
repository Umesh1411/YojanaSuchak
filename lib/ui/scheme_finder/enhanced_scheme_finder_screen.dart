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


  // Public welfare variables removed

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
  bool isProfileComplete(UserProfile profile) {
    return profile.occupation != null && profile.occupation!.trim().isNotEmpty &&
           profile.annualIncome != null &&
           profile.age != null &&
           profile.state != null && profile.state!.trim().isNotEmpty;
  }

  String _getFollowUpQuestion(String field, String lang) {
    if (lang == 'hi') {
      if (field == 'occupation') return 'आपका व्यवसाय क्या है?';
      if (field == 'income') return 'आपकी वार्षिक आय कितनी है?';
      if (field == 'age') return 'आपकी उम्र क्या है?';
      if (field == 'state') return 'आप किस राज्य से हैं?';
      if (field == 'location') return 'आप किस राज्य और ज़िले से हैं?';
      if (field == 'annualIncome') return 'आपकी वार्षिक आय कितनी है?';
    } else if (lang == 'mr') {
      if (field == 'occupation') return 'तुमचा व्यवसाय काय आहे?';
      if (field == 'income') return 'तुमचे वार्षिक उत्पन्न किती आहे?';
      if (field == 'age') return 'तुमचे वय किती आहे?';
      if (field == 'state') return 'तुम्ही कोणत्या राज्यातील आहात?';
      if (field == 'location') return 'तुम्ही कोणत्या राज्य आणि जिल्ह्यात आहात?';
      if (field == 'annualIncome') return 'तुमचे वार्षिक उत्पन्न किती आहे?';
    }
    if (field == 'occupation') return 'What is your occupation?';
    if (field == 'income') return 'What is your annual income?';
    if (field == 'age') return 'What is your age?';
    if (field == 'state') return 'Which state do you belong to?';
    if (field == 'location') return 'Which state and district do you belong to?';
    if (field == 'annualIncome') return 'What is your annual income?';
    return 'Please provide more details.';
  }

  Future<void> _handleUser(String message) async {
    if (message.trim().isEmpty) return;

    _addUser(message);
    _textController.clear();

    if (!mounted) return;
    setState(() => _isLoading = true);

    debugPrint('✉️ Received message: "$message"');

    final detectedLanguage = ProfileExtractor.detectLanguage(message);
    if (_sessionLanguage == null) {
      _sessionLanguage = detectedLanguage;
      debugPrint('🔒 Session language LOCKED: $_sessionLanguage');
    }

    final parsed = ProfileExtractor.extractMultipleFields(message);
    ProfileExtractor.applyParsedToProfile(_profile, parsed);

    if (!_initialProblemCaptured) {
      _initialProblemCaptured = true;
      _initialProblemText = message;
    }

    // Step 1: Public Welfare Exception bypass
    final isWelfare = isPublicWelfareException(message);
    if (isWelfare) {
      debugPrint('🔥 PUBLIC WELFARE EXCEPTION DETECTED: directly showing schemes');
      final results = _matchPublicWelfareSchemes(message);
      await _showPublicWelfareResults(results, message);
      setState(() => _isLoading = false);
      return;
    }

    // Step 2: Enforce Profile Completeness
    final complete = isProfileComplete(_profile);
    debugPrint('📊 Profile completeness check: $complete');

    if (complete) {
      // Profile is complete! Filter, rank, and return top 3 schemes.
      debugPrint('✅ Profile complete, filtering and ranking schemes.');
      final filteredSchemes = _filterSchemes();
      _matchedSchemes = _rankSchemes(filteredSchemes).take(3).toList();
      await _showSchemeResults();
    } else {
      // Profile is incomplete! Ask ONE missing field based on actual required information.
      final candidateSchemes = _filterSchemes();
      final requiredFields = _computeRequiredFields(candidateSchemes);
      final nextField = _selectNextMissingField(requiredFields);

      if (nextField != null) {
        // Avoid asking the same field repeatedly; if it is still missing, rephrase politely.
        final alreadyAsked = _askedQuestions.contains(nextField);
        final question = _getFollowUpQuestion(nextField, _sessionLanguage!);
        _followUpCount++;
        _addBot(question);
        _askedQuestions.add(nextField);
        debugPrint('❓ Follow-up asked for: "$nextField" (alreadyAsked=$alreadyAsked)');
      } else {
        // No specific missing field determined: fallback to profile order.
        final fallbackField = ProfileExtractor.getNextMissingField(_profile);
        if (fallbackField != null) {
          final question = _getFollowUpQuestion(fallbackField, _sessionLanguage!);
          _followUpCount++;
          _addBot(question);
          _askedQuestions.add(fallbackField);
          debugPrint('❓ Fallback follow-up asked for: "$fallbackField"');
        } else {
          // Fallback if all required fields are present (should not reach here)
          final filteredSchemes = _filterSchemes();
          _matchedSchemes = _rankSchemes(filteredSchemes).take(3).toList();
          await _showSchemeResults();
        }
      }
    }

    setState(() => _isLoading = false);
  }

  String? _selectNextMissingField(Set<String> requiredFields) {
    final priority = [
      'occupation',
      'age',
      'gender',
      'location',
      'annualIncome',
      'category',
    ];

    final profileField = ProfileExtractor.getNextMissingField(_profile);
    if (profileField != null && requiredFields.contains(profileField)) {
      return profileField;
    }

    for (final field in priority) {
      if (requiredFields.contains(field) && !_isFieldFilled(field)) {
        return field;
      }
    }

    // If no scheme requires any missing field, ask the next profile field in our standard order.
    return profileField;
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

      final trimmed = response.trim();
      if (trimmed.isEmpty) {
        return 'Sorry, I couldn\'t understand. Could you please repeat?';
      }

      final upper = trimmed.toUpperCase();
      if (upper == 'DONE' || upper.startsWith('DONE ') || upper.endsWith(' DONE') || upper.contains(' DONE ')) {
        return 'DONE';
      }

      if (trimmed.startsWith('ASK:')) {
        return trimmed;
      }

      // Accept any non-empty natural language follow-up question.
      return 'ASK: ${trimmed}';
    } catch (e) {
      debugPrint('❌ Gemini error: $e');
      return null; // Trigger fallback
    }
  }

  /// Display filtered schemes with explanations
  /// ⚠️ CRITICAL: Always displays ONLY TOP 3 highest-scoring schemes
  Future<void> _showSchemeResults() async {
    if (_matchedSchemes.isEmpty) {
      _addBot(
          "I found some schemes that may help you. I may need one or two more details to confirm eligibility.");
      debugPrint('📊 NO SCHEMES: Empty matched list after filtering');
      return;
    }
    
    // Re-rank to ensure consistent sorting by final scores
    _matchedSchemes = _rankSchemes(_matchedSchemes);
    final topSchemes = _matchedSchemes.take(3).toList();
    final scores = topSchemes.map((s) => _schemeScores[s.schemeId] ?? 0).toList();
    
    debugPrint('📊 SCHEME DISPLAY: Total=${_matchedSchemes.length}, Showing=TOP 3');
    debugPrint('📊 Top 3 Scores: ${scores.join(", ")}');

    _addBot("Great! I found ${topSchemes.length} matching scheme(s) for you:");

    final queryText = (_initialProblemText ?? '').trim();
    final normalizedQuery = _normalizeText(queryText);
    final keywords = _expandProblemKeywords(_extractProblemKeywords(normalizedQuery));

    for (final scheme in topSchemes) {
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
    try {
      final filtered = EligibilityFilter.filterSchemes(
        _allSchemes,
        _profile,
        initialProblemText: _initialProblemText,
      );
      debugPrint('🔍 Filtered ${_allSchemes.length} → ${filtered.length} schemes');
      return filtered;
    } catch (e) {
      debugPrint('⚠️ EligibilityFilter error: $e — returning all schemes');
      return _allSchemes;
    }
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

  /// Public Welfare Exception Check
  bool isPublicWelfareException(String query) {
    final q = query.toLowerCase();

    final positiveRegex = RegExp(r'\b(garden|park|plantation|community infrastructure)\b');
    final negativeRegex = RegExp(r'\b(student|job|farmer|personal benefit|business)\b');

    bool hasPositive = positiveRegex.hasMatch(q);
    bool hasNegative = negativeRegex.hasMatch(q);

    return hasPositive && !hasNegative;
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

    final displayCount = results.length > 3 ? 3 : results.length;
    _matchedSchemes = results
        .take(displayCount)
        .map((entry) => entry['scheme'] as Scheme)
        .toList();

    for (int i = 0; i < displayCount; i++) {
      final scheme = results[i]['scheme'] as Scheme;
      final description = _shortSchemeDescription(scheme);
      final reason = _publicWelfareMatchReason(scheme, query);
      final detailLine = scheme.officialApplyLink.isNotEmpty
          ? 'View Details: ${scheme.officialApplyLink}'
          : 'View details in the app.';
      _addBot(
          '${i + 1}. ${scheme.schemeName}\n$reason\n$description\n$detailLine');
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
    // ⚠️ CRITICAL: This function MUST be called before displaying ANY schemes
    // It ensures consistent scoring, sorting, and selection of top 3
    
    if (schemes.isEmpty) {
      debugPrint('⚠️ RANK: Empty input list');
      return [];
    }
    
    final queryText = (_initialProblemText ?? '').trim();
    final normalizedQuery = _normalizeText(queryText);
    final baseKeywords = _extractProblemKeywords(normalizedQuery);
    final keywords = _expandProblemKeywords(baseKeywords);

    debugPrint('🎯 RANK: Scoring ${schemes.length} schemes using query: "$queryText"');
    debugPrint('🔑 RANK: Keywords: ${keywords.toList()}');

    final List<MapEntry<Scheme, int>> scored = [];

    for (final scheme in schemes) {
      final problemScore = _calculateProblemScore(scheme, keywords, normalizedQuery);
      final eligibilityScore = _calculateEligibilityScore(scheme);
      final finalScore = ((problemScore * 70) + (eligibilityScore * 30)) ~/ 100;

      scored.add(MapEntry(scheme, finalScore));
      
      final schemeName = scheme.schemeName.length > 50 
          ? scheme.schemeName.substring(0, 50) + "..." 
          : scheme.schemeName;
      debugPrint('   🔎 [$finalScore pts] $schemeName (problem=$problemScore, eligibility=$eligibilityScore)');
    }

    // Sort by score descending (highest first)
    scored.sort((a, b) => b.value.compareTo(a.value));
    
    // Store scores for reference
    _schemeScores = {for (final e in scored) e.key.schemeId: e.value};
    
    // Return sorted list
    final ranked = scored.map((e) => e.key).toList();
    
    // Log top 3
    if (ranked.isNotEmpty) {
      final top3Scores = scored.take(3).map((e) => e.value).toList();
      debugPrint('✅ RANK: Top 3 scores: $top3Scores');
    }
    
    return ranked;
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
