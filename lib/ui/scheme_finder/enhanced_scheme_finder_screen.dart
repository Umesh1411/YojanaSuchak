import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/scheme.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../services/data_service.dart';
import '../../services/gemini_chat_service.dart';
import '../../services/profile_extractor.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
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
  // ------------------ Services ------------------
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();
  GeminiChatService? _geminiChatService;
  bool _geminiReady = false;

  // ------------------ State ------------------
  final UserProfile _profile = UserProfile();
  List<Scheme> _allSchemes = [];
  List<Scheme> _matchedSchemes = [];
  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _voiceMode = true;
  bool _isListening = false;
  bool _initialProblemCaptured = false; // True after first user message
  int _followUpCount = 0; // Track follow-up questions (max 5)

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
      _addBot('Tell me about your situation or problem. I\'ll find schemes for you.');
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

    // Step 1: Always extract profile fields (non-destructive)
    final parsed = ProfileExtractor.extractAll(message);
    ProfileExtractor.applyParsedToProfile(_profile, parsed);

    // Step 2: First message is ALWAYS treated as problem description (no Gemini decision)
    if (!_initialProblemCaptured) {
      _initialProblemCaptured = true;
      debugPrint('📝 First message captured as problem description');
      
      // If Gemini is disabled, go straight to filtering
      if (!_geminiReady) {
        debugPrint('🚫 Gemini unavailable; filtering schemes directly');
        _matchedSchemes = _filterSchemes();
        await _showSchemeResults();
      }
      // If Gemini is enabled, it will be called in next step (below)
      // Continue to Step 3 for follow-up decision
    }

    // Step 3: Only call Gemini AFTER first message AND only if Gemini is ready
    if (_initialProblemCaptured && _geminiReady) {
      if (_followUpCount >= 5) {
        // Hard limit reached: show results
        debugPrint('🛑 Follow-up limit reached (5/5); showing schemes');
        _matchedSchemes = _filterSchemes();
        await _showSchemeResults();
      } else {
        // Ask Gemini whether to ask follow-up or show schemes
        final geminiDecision = await _askGeminiForNextStep();

        if (geminiDecision == null) {
          // Gemini call failed: fallback to filtering
          debugPrint('⚠️ Gemini call failed; filtering schemes');
          _matchedSchemes = _filterSchemes();
          await _showSchemeResults();
        } else if (geminiDecision == 'DONE') {
          // Gemini says: enough info, show schemes
          debugPrint('✅ Gemini returned DONE; showing schemes');
          _matchedSchemes = _filterSchemes();
          await _showSchemeResults();
        } else if (geminiDecision.startsWith('ASK:')) {
          // Gemini wants to ask one more question
          _followUpCount++;
          final question = geminiDecision.substring(4).trim();
          _addBot(question);
          debugPrint('❓ Follow-up $_followUpCount/5: $question');
        } else {
          // Unexpected format: treat as DONE
          debugPrint('⚠️ Unexpected Gemini response: $geminiDecision');
          _matchedSchemes = _filterSchemes();
          await _showSchemeResults();
        }
      }
    }

    setState(() => _isLoading = false);
  }

  /// Ask Gemini whether to ask another question or finish
  /// Returns "ASK: <question>", "DONE", or null if Gemini unavailable
  Future<String?> _askGeminiForNextStep() async {
    if (!_geminiReady || _geminiChatService == null) {
      return null; // Graceful degradation
    }

    try {
      // Compute filtered candidate schemes BEFORE Gemini context
      final candidateSchemes = _filterSchemes();
      
      if (candidateSchemes.isEmpty) {
        // No schemes match current profile — stop asking
        return 'DONE';
      }

      // Build concise context with only relevant candidate schemes
      final schemeSummary = candidateSchemes
          .take(5)
          .map((s) => 
              '${s.schemeName} (occupation: ${s.occupationEligible}, minAge: ${s.minAge}, maxIncome: ${s.maxIncomeINR}, category: ${s.categoryEligible})')
          .join('\n');

      // Build decision-making prompt (this is the CONTEXT, not the user message)
      final decisionPrompt = '''You are an eligibility assistant deciding what information is needed to confirm scheme eligibility.

User Profile So Far:
- Occupation: ${_profile.occupation ?? 'unknown'}
- Age: ${_profile.age ?? 'unknown'}
- Gender: ${_profile.gender ?? 'unknown'}
- State: ${_profile.state ?? 'unknown'}
- District: ${_profile.district ?? 'unknown'}
- Annual Income: ${_profile.annualIncome ?? 'unknown'}
- Category (caste): ${_profile.category ?? 'unknown'}

Candidate Schemes ($candidateSchemes.length match so far):
$schemeSummary

Questions asked so far: $_followUpCount / 5

Your job:
1. Look at what information is MISSING but REQUIRED for eligibility.
2. Ask ONLY ONE question that matters for these schemes.
3. Do NOT repeat questions already answered.
4. Do NOT ask irrelevant questions (e.g., occupation if all schemes don't care).
5. Respond with EXACTLY:
   - ASK: <your single question>
   - DONE (if you have enough info)

Do NOT include any other text. Just one of those two responses.''';

      // Call Gemini with decision prompt (as a regular user message, not system role)
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
      _addBot("I couldn't find schemes matching your criteria. Try adjusting your details.");
      return;
    }
    
    _addBot("Great! I found ${_matchedSchemes.length} scheme(s) for you:");
    
    for (final scheme in _matchedSchemes.take(3)) {
      if (_geminiReady && _geminiChatService != null) {
        try {
          final explanation = await _geminiChatService!.explainScheme(
            profile: _profile,
            scheme: scheme,
          );
          _addBot(explanation);
        } catch (e) {
          debugPrint('❌ Gemini explain error: $e');
          _addBot('${scheme.schemeName}: This scheme matches your profile.');
        }
      } else {
        _addBot('${scheme.schemeName}: This scheme matches your profile.');
      }
    }
  }

  // (Removed local Gemini caller and local parser; profile parsing is handled
  // by `ProfileExtractor` and Gemini calls are delegated to `GeminiChatService`.)
  // ===============================================================
  // ELIGIBILITY FILTER (NO AI)
  // ===============================================================
  List<Scheme> _filterSchemes() {
    return _allSchemes.where((s) {
      if (s.minAge != null && _profile.age != null && _profile.age! < s.minAge!)
        return false;
      if (s.maxIncomeINR != null &&
          _profile.annualIncome != null &&
          _profile.annualIncome! > s.maxIncomeINR!) return false;
      if (_profile.category != null) {
        if (s.categoryEligible != 'All' &&
            !s.categoryEligible.contains(_profile.category!)) return false;
      }
      if (_profile.state != null && s.state.isNotEmpty) {
        if (s.state.toLowerCase() != _profile.state!.toLowerCase())
          return false;
      }
      if (_profile.occupation != null) {
        if (s.occupationEligible != 'Any' &&
            s.occupationEligible != 'Not Applicable' &&
            !s.occupationEligible.contains(_profile.occupation!)) return false;
      }
      return true;
    }).toList();
  }

  // ===============================================================
  // Scheme explanations are now provided by `GeminiChatService.explainScheme`


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
          _inputArea(),
        ],
      ),
    );
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
