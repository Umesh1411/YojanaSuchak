import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/scheme.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import 'package:yojana_suchak/core/services/chat_service.dart';
import 'package:yojana_suchak/core/services/scheme_recommender.dart';
import '../services/profile_extractor.dart';
import '../services/data_service.dart';

/// Main screen with voice interaction and scheme recommendations
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();
  ChatService? _chatService;

  // State
  final UserProfile _userProfile = UserProfile();
  String _transcript = '';
  String _botResponse = '';
  bool _isListening = false;
  bool _isLoading = false;
  List<Scheme> _allSchemes = [];
  List<Map<String, String>> _conversationHistory = [];
  List<Scheme> _recommendations = [];

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
    // Initialize speech service
    await _speechService.initialize();
    await _ttsService.initialize();

    // Load schemes from Firestore only
    _allSchemes = await DataService.loadSchemes();

    if (_allSchemes.isEmpty) {
      setState(() {
        _botResponse =
            'No schemes found. Please ensure schemes are added to Firestore.';
      });
      return;
    }

    // Initialize Chat Service (server-side Gemini via callable)
    _chatService = ChatService();
    await _chatService?.initialize();

    // Start conversation with greeting
    _startConversation();
  }

  Future<void> _startConversation() async {
    if (_chatService == null || !_chatService!.isAvailable) {
      setState(() {
        _botResponse =
            'Hello! I\'m here to help you find suitable government schemes. Please tell me about yourself.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get initial greeting from Gemini with timeout
      String? maybeResponse = await _chatService!
          .getChatResponse(
        userMessage: 'Hello, I want to find government schemes.',
        profile: _userProfile.toJson(),
        availableSchemes: _allSchemes.map((s) => s.toJson()).toList(),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          return 'Hello! I\'m here to help you find suitable government schemes. Please tell me about yourself.';
        },
      );
      String response = maybeResponse ??
          'Hello! I\'m here to help you find suitable government schemes. Please tell me about yourself.';

      if (mounted) {
        setState(() {
          _botResponse = response;
          _isLoading = false;
        });

        // Add to conversation history
        _conversationHistory.add({
          'role': 'user',
          'message': 'Hello, I want to find government schemes.',
        });
        _conversationHistory.add({
          'role': 'assistant',
          'message': response,
        });

        // Speak the response
        await _speakMessage(response);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _botResponse =
              'Hello! I\'m here to help you find suitable government schemes. Please tell me about yourself.';
          _isLoading = false;
        });
        await _speakMessage(_botResponse);
      }
    }
  }

  Future<void> _processUserInput(String userMessage) async {
    if (_chatService == null || userMessage.trim().isEmpty) return;

    // Add user message to history
    _conversationHistory.add({
      'role': 'user',
      'message': userMessage,
    });

    // Try to extract profile information from the message
    _extractProfileInfo(userMessage);

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Get response from Gemini with timeout
      debugPrint('🔄 Starting Gemini API call...');
      String? maybeResponse = await _chatService!
          .getChatResponse(
        userMessage: userMessage,
        profile: _userProfile.toJson(),
        availableSchemes: _allSchemes.map((s) => s.toJson()).toList(),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏰ Gemini API call timed out');
          return 'Sorry, the request took too long. Please try again.';
        },
      );
      String response = maybeResponse ??
          'Sorry, the request took too long. Please try again.';

      debugPrint(
          '✅ Gemini API call completed. Response length: ${response.length}');
      debugPrint(
          '📝 Response preview: ${response.substring(0, response.length > 100 ? 100 : response.length)}');

      if (mounted) {
        // Add bot response to history
        _conversationHistory.add({
          'role': 'assistant',
          'message': response,
        });

        setState(() {
          _botResponse = response;
          _isLoading = false;
        });

        debugPrint('🔄 UI updated with response, _isLoading set to false');

        // Speak the response
        await _speakMessage(response);

        // Check if profile is complete and get recommendations
        if (_userProfile.isComplete() && _conversationHistory.length > 2) {
          // Wait a bit before showing recommendations
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _getRecommendations();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _processUserInput: $e');
      if (mounted) {
        setState(() {
          _botResponse = 'Sorry, I encountered an error. Please try again.';
          _isLoading = false;
        });
        await _speakMessage(_botResponse);
      }
    }
  }

  void _extractProfileInfo(String text) {
    // Use the consolidated, non-destructive extractor which also normalizes casing
    ProfileExtractor.updateProfileFromText(_userProfile, text);
  }

  Future<void> _getRecommendations() async {
    if (_chatService == null || _allSchemes.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use SchemeRecommender to obtain recommendations (server-side behavior).
      final rec = await SchemeRecommender()
          .recommend(_userProfile.toJson(), locale: Locale('en'));
      final recList =
          (rec['recommendations'] as List).cast<Map<String, dynamic>>();
      List<Scheme> recommendations =
          recList.map((m) => Scheme.fromJson(m)).toList();

      if (recommendations.isNotEmpty) {
        _recommendations = recommendations;
        // Show summary message - all schemes will be displayed in UI cards
        String recommendationText =
            'I found ${recommendations.length} suitable schemes for you. Please check the list below for details.';

        setState(() {
          _botResponse = recommendationText;
          _isLoading = false;
        });

        await _speakMessage(recommendationText);
      } else {
        setState(() {
          _botResponse =
              'Sorry, I could not find any schemes matching your profile. Please check back later or try different criteria.';
          _isLoading = false;
        });
        await _speakMessage(_botResponse);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
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
      }
    }

    setState(() {
      _isListening = false;
    });

    // Process the transcript after listening stops
    if (_transcript.isNotEmpty) {
      await _processUserInput(_transcript);
    }
  }

  void _stopListening() {
    _speechService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _speakMessage(String message) async {
    if (_ttsService.isAvailable) {
      await _ttsService.speak(message);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speechService.stopListening();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MahaVoice Scheme Assistant'),
        centerTitle: true,
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bot response card
              if (_botResponse.isNotEmpty) _buildBotResponseCard(),

              const SizedBox(height: 24),

              // Microphone button
              _buildMicrophoneButton(),

              const SizedBox(height: 24),

              // Transcript display
              if (_transcript.isNotEmpty) _buildTranscriptCard(),

              const SizedBox(height: 24),

              // User profile display
              if (_userProfile.age != null ||
                  _userProfile.district != null ||
                  _userProfile.annualIncome != null ||
                  _userProfile.category != null ||
                  _userProfile.gender != null ||
                  _userProfile.occupation != null)
                _buildProfileCard(),

              const SizedBox(height: 24),

              // Loading indicator
              if (_isLoading) _buildLoadingIndicator(),

              // Recommendations
              if (_recommendations.isNotEmpty) ..._buildRecommendationCards(),

              // Conversation history
              if (_conversationHistory.isNotEmpty) _buildConversationHistory(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotResponseCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Assistant',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _botResponse,
              style: Theme.of(context).textTheme.bodyMedium,
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
                  color: _isListening ? Colors.red : Colors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : Colors.blue)
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
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You said:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.blue.shade700,
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
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Profile',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.orange.shade700,
                  ),
            ),
            const SizedBox(height: 12),
            if (_userProfile.age != null)
              _buildProfileItem('Age', '${_userProfile.age} years'),
            if (_userProfile.gender != null)
              _buildProfileItem('Gender', _userProfile.gender!),
            if (_userProfile.state != null)
              _buildProfileItem('State', _userProfile.state!),
            if (_userProfile.district != null)
              _buildProfileItem('District', _userProfile.district!),
            if (_userProfile.annualIncome != null)
              _buildProfileItem(
                'Annual Income',
                '₹${_userProfile.annualIncome!.toStringAsFixed(0)}',
              ),
            if (_userProfile.occupation != null)
              _buildProfileItem('Occupation', _userProfile.occupation!),
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
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  List<Widget> _buildRecommendationCards() {
    return _recommendations.asMap().entries.map((entry) {
      int index = entry.key;
      Scheme scheme = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Card(
          elevation: 3,
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade700,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              scheme.schemeName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scheme.department,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (scheme.schemeLevel.isNotEmpty)
                  Text(
                    '${scheme.schemeLevel} Scheme • ${scheme.state}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                  ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Benefits
                    _buildSectionTitle('Benefits'),
                    const SizedBox(height: 8),
                    Text(
                      scheme.benefits,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    // Eligibility
                    _buildSectionTitle('Eligibility'),
                    const SizedBox(height: 8),
                    Text(
                      scheme.eligibility,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (scheme.otherEligibilityCriteria.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Additional Criteria: ${scheme.otherEligibilityCriteria}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Benefits Details
                    _buildSectionTitle('Benefit Details'),
                    const SizedBox(height: 8),
                    Text(
                      'Type: ${scheme.benefitType}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (scheme.benefitAmount.isNotEmpty)
                      Text(
                        'Amount: ${scheme.benefitAmount}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    if (scheme.benefitFrequency.isNotEmpty)
                      Text(
                        'Frequency: ${scheme.benefitFrequency}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 16),
                    // Application Details
                    _buildSectionTitle('Application'),
                    const SizedBox(height: 8),
                    Text(
                      'Mode: ${scheme.applicationMode}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Deadline: ${scheme.applicationDeadline}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (scheme.officialApplyLink.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          // Open link (you'll need url_launcher)
                        },
                        child: Text(
                          'Apply Online: ${scheme.officialApplyLink}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Required documents
                    if (scheme.requiredDocuments.isNotEmpty) ...[
                      _buildSectionTitle('Required Documents'),
                      const SizedBox(height: 8),
                      ...scheme.requiredDocuments.map(
                        (doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  doc,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
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

  Widget _buildConversationHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conversation History',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ..._conversationHistory.map((msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        msg['role'] == 'user' ? Icons.person : Icons.smart_toy,
                        size: 16,
                        color:
                            msg['role'] == 'user' ? Colors.blue : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          msg['message'] ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
    );
  }
}
