import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_profile.dart';
import '../../models/scheme.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../services/data_service.dart';
import '../../services/gemini_chat_service.dart';
import '../../services/profile_extractor.dart';
import '../../core/theme/app_theme.dart';

class EnhancedSchemeFinderScreen extends StatefulWidget {
  const EnhancedSchemeFinderScreen({super.key});

  @override
  State<EnhancedSchemeFinderScreen> createState() =>
      _EnhancedSchemeFinderScreenState();
}

class _EnhancedSchemeFinderScreenState extends State<EnhancedSchemeFinderScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();
  late final GeminiChatService _chatService;

  // State
  final UserProfile _profile = UserProfile();
  List<Scheme> _allSchemes = [];
  List<Scheme> _matchedSchemes = [];
  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _voiceMode = true;
  bool _isListening = false;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _speechService.initialize();
    await _ttsService.initialize();
    _allSchemes = await DataService.loadSchemes();

    // Initialize Gemini Chat Service - reads API key from env/config
    _chatService = GeminiChatService();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Disable voice on Web gracefully (no mic support on web)
    if (kIsWeb) {
      setState(() => _voiceMode = false);
    }

    // 🔥 FORCE FIRST QUESTION - let Gemini decide next question; we seed with occupation prompt to keep behavior stable
    Future.microtask(() {
      _addBot("What is your occupation?");
    });
  }

  // ===============================================================
  // CORE CHAT HANDLER (FIXED)
  // ===============================================================
  Future<void> _handleUser(String message) async {
    if (message.trim().isEmpty) return;

    _addUser(message);
    _textController.clear();
    setState(() => _isLoading = true);

    try {
      // 1️⃣ Extract all possible profile info FIRST (NON-DESTRUCTIVE)
      ProfileExtractor.updateProfileFromText(_profile, message);

      // 2️⃣ Find next missing field using single source-of-truth
      final nextMissing = _profile.nextMissingField();

      // 3️⃣ If profile incomplete → ask the next missing field.
      if (nextMissing != null) {
        // If Gemini is available, ask it the next question. Otherwise fall back to a
        // local, deterministic question so the user flow continues without showing
        // diagnostics or error messages in the UI.
        if (_chatService.isAvailable) {
          final reply = await _chatService.getChatResponse(
            userMessage: message,
            profile: _profile,
            availableSchemes: _allSchemes,
          );
          _addBot(reply);
          return;
        } else {
          // Local fallback: ask one concise question for the next missing field
          final q = _localQuestionForField(nextMissing);
          _addBot(q);
          return;
        }
      }

      // 4️⃣ Profile complete → recommend schemes (pure Dart filtering)
      _matchedSchemes = _filterSchemes();

      if (_matchedSchemes.isEmpty) {
        _addBot(
          "I could not find any scheme matching your details. You may update your information.",
        );
      } else {
        _addBot(
          "I found ${_matchedSchemes.length} schemes suitable for you.",
        );

        for (final s in _matchedSchemes.take(3)) {
          _addBot("${s.schemeName} - ${s.benefits}");
        }
      }
    } catch (e) {
      debugPrint('Chat error: $e');
      _addBot("Sorry, something went wrong. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ===============================================================
  // NEXT MISSING FIELD (SINGLE SOURCE OF TRUTH)
  // ===============================================================

  // ===============================================================
  // PROFILE PARSER (NON-DESTRUCTIVE)
  // ===============================================================
  // Profile parsing moved to `ProfileExtractor.updateProfileFromText()` (non-destructive).
  // The legacy `_parseProfile()` was removed to avoid duplicate extraction logic and centralize
  // profile field extraction in `ProfileExtractor`.

  // Local deterministic question templates used when Gemini is not available.
  String _localQuestionForField(String field) {
    switch (field) {
      case 'age':
        return 'What is your age?';
      case 'gender':
        return 'What is your gender? (Male/Female/Other)';
      case 'state':
        return 'Which state do you belong to?';
      case 'district':
        return 'Which district do you belong to?';
      case 'annual income':
        return 'What is your approximate annual income in rupees?';
      case 'occupation':
        return 'What is your occupation? (e.g., Teacher, Farmer, Student)';
      case 'category':
        return 'What is your category? (SC/ST/OBC/General)';
      default:
        return 'Could you provide more details?';
    }
  }

  // ===============================================================
  // PURE DART SCHEME FILTER
  // ===============================================================
  List<Scheme> _filterSchemes() {
    return _allSchemes.where((s) {
      if (s.minAge != null && _profile.age != null && _profile.age! < s.minAge!)
        return false;

      if (s.maxIncomeINR != null &&
          _profile.annualIncome != null &&
          _profile.annualIncome! > s.maxIncomeINR!) return false;

      if (_profile.category != null &&
          s.categoryEligible != 'All' &&
          !s.categoryEligible.contains(_profile.category!)) return false;

      if (_profile.state != null &&
          s.state.isNotEmpty &&
          s.state.toLowerCase() != _profile.state!.toLowerCase()) return false;

      if (_profile.occupation != null &&
          s.occupationEligible != 'Any' &&
          s.occupationEligible != 'Not Applicable' &&
          !s.occupationEligible.contains(_profile.occupation!)) return false;

      return true;
    }).toList();
  }

  // ===============================================================
  // UI HELPERS (UNCHANGED)
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
  // SPEECH HANDLING (UNCHANGED)
  // ===============================================================
  Future<void> _startListening() async {
    if (_isListening || _isLoading || !_voiceMode) return;

    setState(() => _isListening = true);

    await for (String text in _speechService.startListening()) {
      if (text.isNotEmpty && mounted) {
        setState(() => _isListening = false);
        _handleUser(text);
        break;
      }
    }
  }

  void _stopListening() {
    _speechService.stopListening();
    setState(() => _isListening = false);
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
          ),
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
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(),
              ),
              enabled: !_isListening,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.red : AppTheme.primaryColor,
            ),
            onPressed: _isListening ? _stopListening : _startListening,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _speechService.stopListening();
    _ttsService.stop();
    super.dispose();
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage(this.text, this.isUser);
}
