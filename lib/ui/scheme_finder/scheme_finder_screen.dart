import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/conversation_state.dart';
import '../../models/scheme.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../services/gemini_service.dart';
import '../../services/eligibility_filter.dart';
import '../../services/profile_extractor.dart';
import '../../services/data_service.dart';
import '../../services/firestore_service.dart';
import '../../services/email_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_strings.dart';
import '../../core/config/app_config.dart';

/// Scheme Finder Screen with Voice Interaction
class SchemeFinderScreen extends StatefulWidget {
  const SchemeFinderScreen({super.key});

  @override
  State<SchemeFinderScreen> createState() => _SchemeFinderScreenState();
}

class _SchemeFinderScreenState extends State<SchemeFinderScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();
  GeminiService? _geminiService;

  // State
  ConversationState _currentState = ConversationState.greeting;
  final UserProfile _userProfile = UserProfile();
  String _transcript = '';
  bool _isListening = false;
  bool _isLoading = false;
  List<SchemeRecommendation> _recommendations = [];
  List<bool> _selectedSchemes = [];
  bool _showSchemeSelection = false;
  bool _showEmailPrompt = false;
  bool _emailSending = false;
  String? _emailResultMessage;
  List<Scheme> _allSchemes = [];

  // Animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initializeServices() async {
    await _speechService.initialize();
    await _ttsService.initialize();
    _allSchemes = await DataService.loadSchemes();

    if (AppConfig.isGeminiConfigured) {
      _geminiService = GeminiService(apiKey: AppConfig.geminiApiKey);
    }

    _startConversation();
  }

  void _startConversation() {
    setState(() {
      _currentState = ConversationState.greeting;
    });
    _speakMessage(ConversationState.greeting.getMessage());
    Future.delayed(const Duration(seconds: 3), () {
      _moveToNextState();
    });
  }

  void _moveToNextState() {
    if (!_userProfile.isComplete()) {
      List<String> missing = _userProfile.getMissingFields();
      if (missing.contains('age') &&
          _currentState != ConversationState.askAge) {
        setState(() {
          _currentState = ConversationState.askAge;
        });
        _speakMessage(ConversationState.askAge.getMessage());
      } else if (missing.contains('district') &&
          _currentState != ConversationState.askDistrict) {
        setState(() {
          _currentState = ConversationState.askDistrict;
        });
        _speakMessage(ConversationState.askDistrict.getMessage());
      } else if (missing.contains('income') &&
          _currentState != ConversationState.askIncome) {
        setState(() {
          _currentState = ConversationState.askIncome;
        });
        _speakMessage(ConversationState.askIncome.getMessage());
      } else if (missing.contains('category') &&
          _currentState != ConversationState.askCategory) {
        setState(() {
          _currentState = ConversationState.askCategory;
        });
        _speakMessage(ConversationState.askCategory.getMessage());
      }
    } else {
      _sendToGemini();
    }
  }

  Future<void> _sendToGemini() async {
    setState(() {
      _currentState = ConversationState.sendToGemini;
      _isLoading = true;
    });

    _speakMessage(ConversationState.sendToGemini.getMessage());

    try {
      List<Scheme> filteredSchemes =
          EligibilityFilter.filterSchemes(_allSchemes, _userProfile);

      if (_geminiService != null) {
        _recommendations = await _geminiService!
            .getRecommendations(_userProfile, filteredSchemes);
      } else {
        _recommendations = _getFallbackRecommendations(filteredSchemes);
      }

      setState(() {
        _currentState = ConversationState.result;
        _isLoading = false;
        _showSchemeSelection = true;
        _selectedSchemes = List.generate(_recommendations.length, (_) => false);
        _showEmailPrompt = false;
        _emailResultMessage = null;
      });

      _speakMessage(ConversationState.result.getMessage());
    } catch (e) {
      setState(() {
        _currentState = ConversationState.error;
        _isLoading = false;
      });
      _speakMessage(ConversationState.error.getMessage());
    }
  }

  List<SchemeRecommendation> _getFallbackRecommendations(List<Scheme> schemes) {
    return schemes.take(3).map((scheme) {
      return SchemeRecommendation(
        scheme: scheme,
        reason: 'This scheme matches your profile.',
        keyBenefits: scheme.benefits,
      );
    }).toList();
  }

  void _speakMessage(String message) {
    _ttsService.speak(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheme Finder'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStateCard(),
            const SizedBox(height: 16),
            _buildProfileCard(),
            const SizedBox(height: 16),
            if (_isLoading)
              _buildLoadingIndicator()
            else if (_currentState == ConversationState.result &&
                _recommendations.isNotEmpty) ...[
              if (_showSchemeSelection) _buildSchemeSelectionSection(),
              if (_showEmailPrompt) ...[
                const SizedBox(height: 16),
                _buildEmailPromptSection(),
              ],
              if (_emailResultMessage != null) ...[
                const SizedBox(height: 16),
                Text(_emailResultMessage!,
                    style: const TextStyle(color: Colors.green)),
              ],
              const SizedBox(height: 16),
              ..._buildRecommendationCards(),
            ] else if (_currentState == ConversationState.error)
              _buildErrorCard(),
            const SizedBox(height: 16),
            _buildMicrophoneButton(),
            if (_transcript.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTranscriptCard(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startListening() async {
    if (_isListening || _isLoading) return;

    setState(() {
      _isListening = true;
      _transcript = '';
    });

    await for (String text in _speechService.startListening()) {
      if (text.isNotEmpty) {
        setState(() {
          _transcript = text;
        });

        // Use new non-destructive extractor: parse all possible fields then apply
        final parsed = ProfileExtractor.extractAll(text);
        ProfileExtractor.applyParsedToProfile(_userProfile, parsed);

        if (_userProfile.isComplete() ||
            (_currentState == ConversationState.askAge &&
                _userProfile.age != null) ||
            (_currentState == ConversationState.askDistrict &&
                _userProfile.district != null) ||
            (_currentState == ConversationState.askIncome &&
                _userProfile.annualIncome != null) ||
            (_currentState == ConversationState.askCategory &&
                _userProfile.category != null)) {
          _speechService.stopListening();
          setState(() {
            _isListening = false;
          });

          Future.delayed(const Duration(milliseconds: 500), () {
            _moveToNextState();
          });
          break;
        }
      }
    }

    setState(() {
      _isListening = false;
    });
  }

  void _stopListening() {
    _speechService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  Widget _buildSchemeSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Which scheme(s) do you want to save to “My Schemes”?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recommendations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final rec = _recommendations[idx];
              final selected = _selectedSchemes[idx];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    // Guard against index mismatch if recommendations update concurrently
                    if (idx >= _selectedSchemes.length) {
                      _selectedSchemes =
                          List.generate(_recommendations.length, (_) => false);
                    }
                    _selectedSchemes[idx] = !_selectedSchemes[idx];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryColor.withOpacity(0.15)
                        : Colors.white,
                    border: Border.all(
                      color: selected
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (selected)
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color:
                                selected ? AppTheme.primaryColor : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rec.scheme.schemeName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? AppTheme.primaryColor
                                    : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rec.scheme.department,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rec.keyBenefits,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton(
              onPressed: _selectedSchemes.any((s) => s)
                  ? () {
                      setState(() {
                        _showSchemeSelection = false;
                        _showEmailPrompt = true;
                      });
                    }
                  : null,
              child: const Text('Save to My Schemes'),
            ),
            const SizedBox(width: 12),
            if (!_selectedSchemes.any((s) => s))
              Expanded(
                child: Text(
                  'Select at least one scheme to enable saving.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmailPromptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Do you want to receive a detailed email for the selected scheme(s)?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        if (_emailSending)
          Row(
            children: const [
              SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Sending...'),
            ],
          )
        else
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _emailSending = true;
                  });
                  await _saveSelectedSchemesAndSendEmail(sendEmail: true);
                  if (!mounted) return;
                  setState(() {
                    _showEmailPrompt = false;
                    _emailSending = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            _emailResultMessage ?? 'Saved and email sent.')),
                  );
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
                  if (!mounted) return;
                  setState(() {
                    _showEmailPrompt = false;
                    _emailSending = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            _emailResultMessage ?? 'Saved to My Schemes.')),
                  );
                },
                child: const Text('No'),
              ),
            ],
          ),
      ],
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

    final selected = _recommendations
        .asMap()
        .entries
        .where((e) => _selectedSchemes[e.key])
        .map((e) => e.value.scheme)
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
      // Reset selection state so UI reflects saved state and prevents stale indices
      _selectedSchemes = List.generate(_recommendations.length, (_) => false);
    });
  }

  Widget _buildStateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentState.getMessage(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    return Center(
      child: GestureDetector(
        onTap: _isListening ? _stopListening : _startListening,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isListening ? _scaleAnimation.value : 1.0,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.red : AppTheme.primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : AppTheme.primaryColor)
                          .withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTranscriptCard() {
    return Card(
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You said:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _transcript,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      color: AppTheme.secondaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Profile',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.secondaryColor,
                  ),
            ),
            const SizedBox(height: 12),
            if (_userProfile.age != null)
              _buildProfileItem('Age', '${_userProfile.age} years'),
            if (_userProfile.district != null)
              _buildProfileItem('District', _userProfile.district!),
            if (_userProfile.annualIncome != null)
              _buildProfileItem(
                'Annual Income',
                '₹${_userProfile.annualIncome!.toStringAsFixed(0)}',
              ),
            if (_userProfile.category != null)
              _buildProfileItem('Category', _userProfile.category!),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  List<Widget> _buildRecommendationCards() {
    return _recommendations.asMap().entries.map((entry) {
      int index = entry.key;
      SchemeRecommendation recommendation = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Card(
          elevation: 3,
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              recommendation.scheme.schemeName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: Text(
              recommendation.scheme.department,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Why this scheme?'),
                    const SizedBox(height: 8),
                    Text(recommendation.reason),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Key Benefits'),
                    const SizedBox(height: 8),
                    Text(recommendation.keyBenefits),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Eligibility'),
                    const SizedBox(height: 8),
                    Text(recommendation.scheme.eligibility),
                    if (recommendation.scheme.requiredDocuments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Required Documents'),
                      const SizedBox(height: 8),
                      ...recommendation.scheme.requiredDocuments.map(
                        (doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 16, color: AppTheme.successColor),
                              const SizedBox(width: 8),
                              Expanded(child: Text(doc)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: AppTheme.errorColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'An error occurred. Please try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.errorColor,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
