import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../models/user_profile.dart';
import '../../models/scheme.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../services/data_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';

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
  late final GenerativeModel _gemini;

  // ------------------ State ------------------
  final UserProfile _profile = UserProfile();
  List<Scheme> _allSchemes = [];
  List<Scheme> _matchedSchemes = [];
  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _voiceMode = true;
  bool _isListening = false;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ------------------ Animation ------------------
  late AnimationController _animationController;
  // Animation pulse available for future UI animations
  // late Animation<double> _pulse;

  // ===============================================================
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _speechService.initialize();
    await _ttsService.initialize();
    _allSchemes = await DataService.loadSchemes();

    _gemini = GenerativeModel(
      model: 'gemini-1.5-pro', // Updated to stable Gemini model
      apiKey: AppConfig.geminiApiKey,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Animation pulse available for future UI animations
    // _pulse = Tween(begin: 1.0, end: 1.2).animate(_animationController);

    // Add initial bot message after initialization
    Future.microtask(() {
      _addBot(
          "Hello! I can help you find government schemes. You can tell me everything at once or step by step.");
    });
  }

  // ===============================================================
  // CHAT HANDLING
  // ===============================================================
  Future<void> _handleUser(String message) async {
    if (message.trim().isEmpty) return;

    _addUser(message);
    _textController.clear();
    setState(() => _isLoading = true);

    // Step 1: Parse profile
    _parseProfile(message);

    // Step 2: Ask Gemini what to do next
    final geminiReply = await _askGeminiNext(message);

    // Step 3: Act on Gemini response
    if (geminiReply == 'PROFILE_COMPLETE') {
      _matchedSchemes = _filterSchemes();

      if (_matchedSchemes.isEmpty) {
        _addBot(
            "Sorry, I couldn't find any scheme matching your details. You may change details and try again.");
      } else {
        _addBot(
            "Good news! I found ${_matchedSchemes.length} scheme(s) for you.");
        for (final s in _matchedSchemes.take(3)) {
          final explanation = await _explainScheme(s);
          _addBot(explanation);
        }
      }
    } else {
      _addBot(geminiReply);
    }

    setState(() => _isLoading = false);
  }

  // ===============================================================
  // GEMINI – NEXT QUESTION DECIDER
  // ===============================================================
  Future<String> _askGeminiNext(String userMessage) async {
    final prompt = '''
You are a polite Indian government scheme assistant.

User message:
"$userMessage"

Collected profile:
Age: ${_profile.age ?? "unknown"}
Income: ${_profile.annualIncome ?? "unknown"}
Occupation: ${_profile.occupation ?? "unknown"}
Category: ${_profile.category ?? "unknown"}
State: ${_profile.state ?? "unknown"}

Rules:
- Ask ONLY ONE missing question.
- If input format is wrong, explain correct format.
- If all details are present, reply exactly: PROFILE_COMPLETE
- Use simple Indian English.
''';

    final response = await _gemini.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? '';
  }

  // ===============================================================
  // PROFILE PARSER (SAFE & NON-DESTRUCTIVE)
  // ===============================================================
  void _parseProfile(String message) {
    final lower = message.toLowerCase();

    // AGE
    final age = RegExp(r'\b(\d{1,3})\b').firstMatch(lower);
    if (age != null && _profile.age == null) {
      final v = int.tryParse(age.group(1)!);
      if (v != null && v >= 1 && v <= 120) _profile.age = v;
    }

    // INCOME
    if (_profile.annualIncome == null) {
      if (lower.contains('lakh')) {
        final m = RegExp(r'(\d+(\.\d+)?)').firstMatch(lower);
        if (m != null) {
          _profile.annualIncome = (double.parse(m.group(1)!) * 100000).toInt();
        }
      } else {
        final m = RegExp(r'\b\d{4,8}\b').firstMatch(lower);
        if (m != null) _profile.annualIncome = int.parse(m.group(0)!);
      }
    }

    // OCCUPATION
    final occupations = [
      'farmer',
      'student',
      'labour',
      'worker',
      'business',
      'teacher',
      'government',
      'unemployed'
    ];
    for (final o in occupations) {
      if (lower.contains(o) && _profile.occupation == null) {
        _profile.occupation = o;
        break;
      }
    }

    // CATEGORY
    if (_profile.category == null) {
      if (lower.contains('sc')) _profile.category = 'SC';
      if (lower.contains('st')) _profile.category = 'ST';
      if (lower.contains('obc')) _profile.category = 'OBC';
      if (lower.contains('general')) _profile.category = 'General';
    }

    // STATE
    final states = ['maharashtra', 'gujarat', 'karnataka', 'delhi'];
    for (final s in states) {
      if (lower.contains(s) && _profile.state == null) {
        _profile.state = s[0].toUpperCase() + s.substring(1);
        break;
      }
    }
  }

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
  // GEMINI – SCHEME EXPLAINER
  // ===============================================================
  Future<String> _explainScheme(Scheme scheme) async {
    final prompt = '''
Explain politely why this government scheme matches the user.

User:
Occupation: ${_profile.occupation}
Age: ${_profile.age}
Income: ${_profile.annualIncome}
Category: ${_profile.category}
State: ${_profile.state}

Scheme:
Name: ${scheme.schemeName}
Eligibility: ${scheme.eligibility}
Benefits: ${scheme.benefits}

Explain in simple Indian English.
''';

    final response = await _gemini.generateContent([Content.text(prompt)]);
    return response.text ?? '';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition is not available')),
        );
        return;
      }
    }

    setState(() {
      _isListening = true;
    });

    try {
      await for (String text in _speechService.startListening()) {
        if (text.isNotEmpty && mounted) {
          setState(() {
            _isListening = false;
          });
          _handleUser(text);
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
    _animationController.dispose();
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
