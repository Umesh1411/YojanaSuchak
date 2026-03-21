import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import '../../models/user_profile.dart';
import '../../models/scheme.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../services/data_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/my_schemes_service.dart';
import '../../core/services/notification_service.dart';
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
  ChatService? _chatService;
  final MySchemesService _mySchemesService = MySchemesService();
  final NotificationService _notificationService = NotificationService();

  // State
  final UserProfile _profile = UserProfile();
  List<Scheme> _allSchemes = [];
  List<Scheme> _matchedSchemes = [];
  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _voiceMode = true;
  bool _isListening = false;
  bool _showSchemeSelection = false;
  bool _showEmailPrompt = false;
  bool _emailSending = false;
  String? _emailResultMessage;
  List<bool> _selectedSchemes = [];
  bool _isSelectionDialogOpen = false;
  bool _hasShownPopupOnce = false;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Animation
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _speechService.initialize();
    await _ttsService.initialize();
    _allSchemes = await DataService.loadSchemes();

    // Initialize ChatService (uses GeminiService internally)
    try {
      _chatService = ChatService();
      await _chatService!.initialize();
    } catch (e) {
      debugPrint('❌ Failed to initialize ChatService: $e');
      _chatService = null;
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    if (kIsWeb) {
      setState(() => _voiceMode = false);
    }

    Future.microtask(() {
      _addBot(
          "Tell me about your situation or problem. I'll find schemes for you.");
    });
  }

  // ===============================================================
  // CHAT HANDLING (GEMINI-DRIVEN, SCHEME-AWARE, POST-RECOMMENDATION FLOW)
  // ===============================================================
  Future<void> _handleUser(String message) async {
    if (message.trim().isEmpty) return;

    _addUser(message);
    _textController.clear();
    setState(() => _isLoading = true);

    // If showing scheme selection, treat input as selection
    if (_showSchemeSelection && _matchedSchemes.isNotEmpty) {
      final match = RegExp(r'(save|select)?\s*(\d+)', caseSensitive: false)
          .firstMatch(message);
      if (match != null) {
        final idx = int.tryParse(match.group(2) ?? '') ?? -1;
        if (idx > 0 && idx <= _matchedSchemes.length) {
          setState(() {
            _selectedSchemes =
                List.generate(_matchedSchemes.length, (i) => i == (idx - 1));
            _showSchemeSelection = false;
            _showEmailPrompt = true;
          });
          return;
        }
      }
    }

    try {
      // Extract profile info
      ProfileExtractor.updateProfileFromText(_profile, message);
      final nextMissing = _profile.nextMissingField();

      if (nextMissing != null) {
        // Ask next question (Gemini or fallback)
        if (_chatService != null) {
          final profileMap = _profile.toJson();
          final reply = await _chatService!.getChatResponse(
            userMessage: message,
            profile: profileMap,
            availableSchemes: _allSchemes,
          );
          if (reply != null) _addBot(reply);
        } else {
          _addBot(_localQuestionForField(nextMissing));
        }
        return;
      }

      // Profile complete → recommend schemes
      _matchedSchemes = _filterSchemes();
      if (_matchedSchemes.isEmpty) {
        _addBot(
            "I could not find any scheme matching your details. You may update your information.");
      } else {
        _addBot("Great! I found ${_matchedSchemes.length} scheme(s) for you:");
        for (int i = 0; i < _matchedSchemes.length; i++) {
          final s = _matchedSchemes[i];
          _addBot("${i + 1}. ${s.schemeName} - ${s.benefits}");
        }
        setState(() {
          _showSchemeSelection = true;
          _showEmailPrompt = false;
          _emailSending = false;
          _emailResultMessage = null;
          _selectedSchemes =
              List.generate(_matchedSchemes.length, (_) => false);
        });
        _hasShownPopupOnce = false;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isSelectionDialogOpen || _hasShownPopupOnce) return;

          _hasShownPopupOnce = true;

          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted || _isSelectionDialogOpen) return;

            print("Popup triggered from handleUser (final fix)");

            _showSchemeSelectionPopup(_matchedSchemes);
          });
        });
        _addBot(
            "Which scheme(s) do you want to save to 'My Schemes'? Reply with the scheme number (e.g., 'Save 2') or tap the sidebar list.");
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_scaffoldKey.currentState?.isEndDrawerOpen != true) {
            _scaffoldKey.currentState?.openEndDrawer();
          }
        });
        return;
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
  // POST-RECOMMENDATION: SCHEME SELECTION, EMAIL PROMPT, SAVE
  // ===============================================================
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
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'anonymous';
    final userEmail = user?.email;
    final selected = _matchedSchemes
        .asMap()
        .entries
        .where((e) => _selectedSchemes[e.key])
        .map((e) => e.value)
        .toList();
    if (selected.isEmpty) return;

    int savedCount = 0;
    final selectedSchemeIds = selected
        .map((s) => s.schemeId.isNotEmpty ? s.schemeId : s.schemeName)
        .toList();

    await _mySchemesService.saveSchemes(userId, selectedSchemeIds,
        emails: userEmail != null ? [userEmail] : []);
    savedCount = selectedSchemeIds.length;

    if (sendEmail && userEmail != null) {
      for (final scheme in selected) {
        await _notificationService.sendSchemeDetailsToEmails(
          schemeId: scheme.schemeId.isNotEmpty ? scheme.schemeId : scheme.schemeName,
          emails: [userEmail],
        );
      }
    }

    setState(() {
      _emailResultMessage = sendEmail
          ? 'Saved $savedCount scheme(s) and sent email(s) successfully.'
          : 'Saved $savedCount scheme(s) to My Schemes.';
    });
  }

  Future<void> _showSchemeSelectionPopup(List<Scheme> recommendations) async {
    if (recommendations.isEmpty || !mounted) return;
    _isSelectionDialogOpen = true;

    final TextEditingController emailController = TextEditingController();
    final localSelected = List<bool>.filled(recommendations.length, false);
    bool isSubmitting = false;
    String? validationError;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Save Recommended Schemes'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select schemes to save and send via email:'),
                        const SizedBox(height: 10),
                        ...recommendations.asMap().entries.map((entry) {
                          final i = entry.key;
                          final scheme = entry.value;
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: localSelected[i],
                            onChanged: isSubmitting
                                ? null
                                : (val) {
                                    setDialogState(() {
                                      localSelected[i] = val ?? false;
                                    });
                                  },
                            title: Text(scheme.schemeName),
                            subtitle: Text(scheme.department),
                          );
                        }),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          enabled: !isSubmitting,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email(s) (comma separated)',
                            hintText: 'abc@example.com, xyz@example.com',
                          ),
                        ),
                        if (validationError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            validationError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final selectedSchemes = recommendations
                                .asMap()
                                .entries
                                .where((e) => localSelected[e.key])
                                .map((e) => e.value)
                                .toList();

                            final emails = emailController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();

                            if (selectedSchemes.isEmpty) {
                              setDialogState(() {
                                validationError =
                                    'Please select at least one scheme.';
                              });
                              return;
                            }
                            if (emails.isEmpty) {
                              setDialogState(() {
                                validationError =
                                    'Please enter at least one email address.';
                              });
                              return;
                            }

                            setDialogState(() {
                              isSubmitting = true;
                              validationError = null;
                            });

                            try {
                              final userId =
                                  FirebaseAuth.instance.currentUser?.uid ??
                                      'anonymous';
                              final selectedSchemeIds = selectedSchemes
                                  .map((s) => s.schemeId.isNotEmpty
                                      ? s.schemeId
                                      : s.schemeName)
                                  .toList();

                              await _mySchemesService.saveSchemes(
                                userId,
                                selectedSchemeIds,
                                emails: emails,
                              );

                              for (final scheme in selectedSchemes) {
                                final schemeId = scheme.schemeId.isNotEmpty
                                    ? scheme.schemeId
                                    : scheme.schemeName;
                                await _notificationService
                                    .sendSchemeDetailsToEmails(
                                  schemeId: schemeId,
                                  emails: emails,
                                );
                              }

                              if (!mounted) return;
                              setState(() {
                                _emailResultMessage =
                                    'Saved selected schemes and sent email successfully.';
                              });
                              Navigator.of(dialogContext).pop();
                            } catch (e) {
                              setDialogState(() {
                                isSubmitting = false;
                                validationError =
                                    'Failed to save/send. Please try again.';
                              });
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save & Send Email'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      emailController.dispose();
      _isSelectionDialogOpen = false;
    }
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
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Find Schemes'),
        actions: [
          IconButton(
            icon: Icon(_voiceMode ? Icons.mic : Icons.keyboard),
            onPressed: () => setState(() => _voiceMode = !_voiceMode),
          ),
          if (_showSchemeSelection && _matchedSchemes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Show Recommended Schemes',
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
        ],
      ),
      endDrawer: _showSchemeSelection && _matchedSchemes.isNotEmpty
          ? Drawer(
              child: SafeArea(
                child: ListView.builder(
                  itemCount: _matchedSchemes.length,
                  itemBuilder: (context, i) {
                    final s = _matchedSchemes[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(s.schemeName),
                      subtitle: Text(s.benefits),
                      onTap: () {
                        Navigator.of(context).pop();
                        _handleUser('Save ${i + 1}');
                      },
                    );
                  },
                ),
              ),
            )
          : null,
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
          if (_matchedSchemes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () {
                  if (!_isSelectionDialogOpen) {
                    print("Popup safe trigger");
                    _showSchemeSelectionPopup(_matchedSchemes);
                  }
                },
                child: const Text("Select & Save Schemes"),
              ),
            ),
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
    _animationController?.dispose();
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
