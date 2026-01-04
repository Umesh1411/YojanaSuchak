import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../models/conversation_state.dart';
import '../../models/scheme.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../services/gemini_chat_service.dart';
import '../../services/data_service.dart';
import '../../services/email_service.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../core/services/language_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/auth_service.dart';

/// Enhanced Scheme Finder with Voice + Text Chat + Gemini + Email
class EnhancedSchemeFinderScreen extends StatefulWidget {
  const EnhancedSchemeFinderScreen({super.key});

  @override
  State<EnhancedSchemeFinderScreen> createState() =>
      _EnhancedSchemeFinderScreenState();
}

class _EnhancedSchemeFinderScreenState
    extends State<EnhancedSchemeFinderScreen>
    with SingleTickerProviderStateMixin {
  // Services
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();
  GeminiChatService? _geminiChatService;
  EmailService? _emailService;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // State
  ConversationState _currentState = ConversationState.greeting;
  final UserProfile _userProfile = UserProfile();
  List<Scheme> _allSchemes = [];
  List<Scheme> _recommendedSchemes = [];
  Scheme? _selectedSchemeForDetails;

  // Chat
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  bool _isListening = false;
  bool _isVoiceMode = true; // Toggle between voice and text

  // Animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 EnhancedSchemeFinderScreen initState called');
    _initializeServices();
    _setupAnimation();
    _startConversation();
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
    debugPrint('🔧 _initializeServices called');
    await _speechService.initialize();
    debugPrint('✅ Speech service initialized');
    await _ttsService.initialize();
    debugPrint('✅ TTS service initialized');
    
    _allSchemes = await DataService.loadSchemes();
    debugPrint('✅ Loaded ${_allSchemes.length} schemes');

    // Initialize Gemini - always try if key is configured
    debugPrint('🔧 Checking Gemini configuration...');
    debugPrint('🔧 API Key: ${AppConfig.geminiApiKey.substring(0, 10)}...');
    debugPrint('🔧 Is configured: ${AppConfig.isGeminiConfigured}');
    
    if (AppConfig.isGeminiConfigured) {
      try {
        debugPrint('🚀 Initializing Gemini Chat Service...');
        _geminiChatService = GeminiChatService(apiKey: AppConfig.geminiApiKey);
        debugPrint('✅ Gemini Chat Service initialized successfully');
        debugPrint('✅ Model: gemini-1.5-flash');
        
        // Test if service is actually created
        if (_geminiChatService != null) {
          debugPrint('✅ Gemini service is NOT NULL - ready to use');
        } else {
          debugPrint('❌ Gemini service is NULL after initialization');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Error initializing Gemini: $e');
        debugPrint('❌ Stack trace: $stackTrace');
      }
    } else {
      debugPrint('⚠️ Gemini API key not configured - using fallback mode');
    }

    // Initialize Email Service
    if (AppConfig.isEmailConfigured) {
      _emailService = EmailService(
        smtpHost: AppConfig.smtpHost,
        smtpPort: AppConfig.smtpPort,
        username: AppConfig.smtpUsername,
        password: AppConfig.smtpPassword,
        useTls: AppConfig.useTls,
      );
    }
  }

  void _startConversation() {
    debugPrint('💬 Starting conversation...');
    debugPrint('💬 Gemini service available: ${_geminiChatService != null}');
    _addBotMessage(LocalizationService.get('chatbotGreeting'));
    _setState(ConversationState.greeting);
    
    // Ask first question after a short delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      _askNextQuestion();
    });
  }

  Future<void> _handleUserMessage(String message) async {
    if (message.trim().isEmpty) return;

    _addUserMessage(message);
    _textController.clear();

    setState(() => _isLoading = true);

    // Extract profile information from message
    _extractProfileInfo(message);

    // Check if user wants to send email
    if (_currentState == ConversationState.sendEmail) {
      final lowerMessage = message.toLowerCase();
      if (lowerMessage.contains('yes') || lowerMessage.contains('हां') || lowerMessage.contains('होय') || lowerMessage.contains('send')) {
        await _sendEmail();
        setState(() => _isLoading = false);
        return;
      } else if (lowerMessage.contains('no') || lowerMessage.contains('नहीं') || lowerMessage.contains('नाही')) {
        _addBotMessage('Okay! Let me know if you need anything else.');
        setState(() => _isLoading = false);
        return;
      }
    }

    // Check if user is asking for scheme details
    if (_currentState == ConversationState.askSchemeDetails && _recommendedSchemes.isNotEmpty) {
      await _handleSchemeDetailsRequest(message);
      setState(() => _isLoading = false);
      return;
    }

    // Simple question-asking flow - ask questions directly
    await _askNextQuestion();

    setState(() => _isLoading = false);
  }

  Future<void> _askNextQuestion() async {
    // Check what information is missing and ask the next question
    if (_userProfile.age == null) {
      _setState(ConversationState.askAge);
      _addBotMessage(LocalizationService.get('askAge'));
      return;
    }

    if (_userProfile.gender == null) {
      _setState(ConversationState.askGender);
      _addBotMessage(LocalizationService.get('askGender'));
      return;
    }

    if (_userProfile.state == null) {
      _setState(ConversationState.askState);
      _addBotMessage(LocalizationService.get('askState'));
      return;
    }

    if (_userProfile.annualIncome == null) {
      _setState(ConversationState.askIncome);
      _addBotMessage(LocalizationService.get('askIncome'));
      return;
    }

    if (_userProfile.occupation == null) {
      _setState(ConversationState.askOccupation);
      _addBotMessage(LocalizationService.get('askOccupation'));
      return;
    }

    if (_userProfile.category == null) {
      _setState(ConversationState.askCategory);
      _addBotMessage(LocalizationService.get('askCategory'));
      return;
    }

    // All information collected - get recommendations
    if (_recommendedSchemes.isEmpty) {
      _addBotMessage(LocalizationService.get('analyzingSchemes'));
      await _getRecommendations();
    }
  }

  void _extractProfileInfo(String message) {
    final lower = message.toLowerCase();

    // Extract age
    final ageMatch = RegExp(r'\b(\d{1,3})\b').firstMatch(lower);
    if (ageMatch != null) {
      final age = int.tryParse(ageMatch.group(1) ?? '');
      if (age != null && age > 0 && age < 150) {
        _userProfile.age = age;
      }
    }

    // Extract gender
    if (lower.contains('male') && !lower.contains('fe')) {
      _userProfile.gender = 'Male';
    } else if (lower.contains('female') || lower.contains('woman') || lower.contains('स्त्री') || lower.contains('महिला')) {
      _userProfile.gender = 'Female';
    } else if (lower.contains('other') || lower.contains('अन्य') || lower.contains('इतर')) {
      _userProfile.gender = 'Other';
    }

    // Extract state
    if (lower.contains('maharashtra') || lower.contains('महाराष्ट्र')) {
      _userProfile.state = 'Maharashtra';
    }

    // Extract income
    if (lower.contains('lakh') || lower.contains('लाख')) {
      final lakhMatch = RegExp(r'(\d+(?:\.\d+)?)\s*lakh').firstMatch(lower);
      if (lakhMatch != null) {
        final lakhs = double.tryParse(lakhMatch.group(1) ?? '') ?? 0;
        _userProfile.annualIncome = (lakhs * 100000).toInt();
      }
    } else {
      final incomeMatch = RegExp(r'\b(\d{4,8})\b').firstMatch(lower);
      if (incomeMatch != null) {
        final income = int.tryParse(incomeMatch.group(1) ?? '');
        if (income != null && income >= 10000 && income <= 10000000) {
          _userProfile.annualIncome = income;
        }
      }
    }

    // Extract occupation
    final occupationPatterns = [
      'teacher', 'engineer', 'farmer', 'student', 'business', 'government employee',
      'doctor', 'lawyer', 'accountant', 'nurse', 'driver', 'shopkeeper',
      'शिक्षक', 'अभियंता', 'शेतकरी', 'विद्यार्थी', 'व्यवसाय', 'सरकारी कर्मचारी',
      'डॉक्टर', 'वकील', 'लेखापाल', 'नर्स'
    ];
    for (var pattern in occupationPatterns) {
      if (lower.contains(pattern)) {
        _userProfile.occupation = message.split(RegExp(r'\s+')).firstWhere(
          (word) => word.toLowerCase().contains(pattern.toLowerCase()),
          orElse: () => pattern,
        );
        break;
      }
    }

    // Extract category
    if (lower.contains('student') || lower.contains('विद्यार्थी') || lower.contains('छात्र')) {
      _userProfile.category = 'student';
    } else if (lower.contains('farmer') || lower.contains('शेतकरी') || lower.contains('किसान')) {
      _userProfile.category = 'farmer';
    } else if (lower.contains('woman') || lower.contains('स्त्री') || lower.contains('महिला')) {
      _userProfile.category = 'woman';
    } else if (lower.contains('senior') || lower.contains('वरिष्ठ') || lower.contains('बुजुर्ग')) {
      _userProfile.category = 'senior_citizen';
    } else if (lower.contains('unemployed') || lower.contains('बेरोजगार')) {
      _userProfile.category = 'unemployed';
    } else if (lower.contains('general') || lower.contains('सामान्य')) {
      _userProfile.category = 'general';
    }
  }


  Future<void> _getRecommendations() async {
    try {
      if (_geminiChatService != null) {
        debugPrint('🤖 Getting recommendations from Gemini...');
        _recommendedSchemes = await _geminiChatService!.getRecommendations(
          profile: _userProfile,
          allSchemes: _allSchemes,
        );
        debugPrint('✅ Got ${_recommendedSchemes.length} recommendations from Gemini');
      } else {
        debugPrint('⚠️ Using fallback filtering (Gemini not available)');
        // Fallback: simple filtering
        _recommendedSchemes = _allSchemes
            .where((s) {
              if (_userProfile.age != null && s.ageLimit != null) {
                if (_userProfile.age! < s.ageLimit!) return false;
              }
              if (_userProfile.annualIncome != null && s.incomeLimit != null) {
                if (_userProfile.annualIncome! > s.incomeLimit!) return false;
              }
              return true;
            })
            .take(3)
            .toList();
        debugPrint('✅ Got ${_recommendedSchemes.length} recommendations from fallback');
      }
    } catch (e) {
      debugPrint('❌ Error getting recommendations: $e');
      // Fallback on error
      _recommendedSchemes = _allSchemes.take(3).toList();
    }

    if (_recommendedSchemes.isNotEmpty) {
      _setState(ConversationState.result);
      _addBotMessage(LocalizationService.get('schemesRecommended', params: {'count': _recommendedSchemes.length.toString()}));
      _addBotMessage(LocalizationService.get('whichSchemeDetails'));
      _setState(ConversationState.askSchemeDetails);
    } else {
      // No schemes found
      _setState(ConversationState.result);
      _addBotMessage(LocalizationService.get('noSchemesFound'));
    }
  }

  Future<void> _handleSchemeDetailsRequest(String message) async {
    // Find which scheme user is asking about
    for (var scheme in _recommendedSchemes) {
      if (message.toLowerCase().contains(scheme.schemeName.toLowerCase()) ||
          message.toLowerCase().contains('${_recommendedSchemes.indexOf(scheme) + 1}')) {
        _selectedSchemeForDetails = scheme;
        _showSchemeDetails(scheme);
        
        // Save scheme to user's saved schemes
        await _saveSchemeToMySchemes(scheme);
        
        _askForEmail();
        return;
      }
    }
    _addBotMessage('Please specify which scheme you want details about (1, 2, or 3).');
  }

  void _showSchemeDetails(Scheme scheme) {
    String details = '''
**${scheme.schemeName}**

Department: ${scheme.department}
Target Group: ${scheme.targetGroup}

**Eligibility:**
${scheme.eligibility}

**Benefits:**
${scheme.benefits}

**Required Documents:**
${scheme.requiredDocuments.map((d) => '• $d').join('\n')}
''';

    _addBotMessage(details);
  }

  Future<void> _saveSchemeToMySchemes(Scheme scheme) async {
    try {
      // Get user ID (handle both Firebase and demo auth)
      String? userId;
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
      } else {
        final demoUser = _authService.demoUserData;
        if (demoUser != null) {
          userId = demoUser['uid'] as String?;
        }
      }

      if (userId == null) {
        debugPrint('⚠️ Cannot save scheme: User not authenticated');
        return;
      }

      // Check if scheme is already saved
      final isSaved = await _firestoreService.isSchemeSaved(userId, scheme);
      if (isSaved) {
        debugPrint('ℹ️ Scheme already saved: ${scheme.schemeName}');
        return;
      }

      // Save scheme
      final success = await _firestoreService.saveSchemeToUser(userId, scheme);
      if (success) {
        debugPrint('✅ Scheme saved to My Schemes: ${scheme.schemeName}');
        // Optionally notify user
        // _addBotMessage('Scheme saved to My Schemes!');
      } else {
        debugPrint('❌ Failed to save scheme: ${scheme.schemeName}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving scheme to My Schemes: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  void _askForEmail() {
    _setState(ConversationState.sendEmail);
    _addBotMessage('Would you like to receive these details via email? (Yes/No)');
  }

  Future<void> _sendEmail() async {
    if (_emailService == null || _selectedSchemeForDetails == null) {
      _addBotMessage('Email service is not configured. Please contact support.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      _addBotMessage('Please log in to receive email. Your email: ${user?.email}');
      return;
    }

    setState(() => _isLoading = true);
    _addBotMessage('Sending email...');
    debugPrint('📧 Attempting to send email to: ${user!.email}');
    debugPrint('📧 Scheme: ${_selectedSchemeForDetails!.schemeName}');

    try {
      final success = await _emailService!.sendSchemeDetails(
        recipientEmail: user.email!,
        recipientName: user.displayName ?? 'User',
        scheme: _selectedSchemeForDetails!,
      );

      setState(() => _isLoading = false);

      if (success) {
        debugPrint('✅ Email sent successfully!');
        _addBotMessage('Email sent successfully to ${user.email}!');
      } else {
        debugPrint('❌ Email sending failed');
        _addBotMessage('Failed to send email. Please check your email settings or try again later.');
      }
    } catch (e) {
      debugPrint('❌ Error sending email: $e');
      setState(() => _isLoading = false);
      _addBotMessage('Error sending email: ${e.toString()}. Please try again later.');
    }
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
    });

    // Get current locale for speech recognition
    final currentLocale = await LanguageService.getCurrentLanguage();
    String localeId = 'en_IN';
    if (currentLocale.languageCode == 'hi') {
      localeId = 'hi_IN';
    } else if (currentLocale.languageCode == 'mr') {
      localeId = 'mr_IN';
    }

    try {
      await for (String text in _speechService.startListening(localeId: localeId)) {
        if (text.isNotEmpty) {
          await _handleUserMessage(text);
          break;
        }
      }
    } catch (e) {
      print('Speech listening error: $e');
    } finally {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _stopListening() {
    _speechService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  void _addUserMessage(String message) {
    setState(() {
      _chatMessages.add(ChatMessage(text: message, isUser: true));
    });
  }

  void _addBotMessage(String message) async {
    setState(() {
      _chatMessages.add(ChatMessage(text: message, isUser: false));
    });
    if (_isVoiceMode) {
      // Update TTS language based on current app language
      final currentLocale = await LanguageService.getCurrentLanguage();
      await _ttsService.updateLanguage(currentLocale);
      _ttsService.speak(message);
    }
  }

  void _setState(ConversationState state) {
    setState(() {
      _currentState = state;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    _speechService.stopListening();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Schemes'),
        actions: [
          // Toggle Voice/Text
          IconButton(
            icon: Icon(_isVoiceMode ? Icons.mic : Icons.keyboard),
            onPressed: () {
              setState(() {
                _isVoiceMode = !_isVoiceMode;
              });
            },
            tooltip: _isVoiceMode ? 'Switch to Text' : 'Switch to Voice',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                return _buildChatBubble(_chatMessages[index]);
              },
            ),
          ),
          // Recommended schemes cards
          if (_recommendedSchemes.isNotEmpty && _currentState == ConversationState.askSchemeDetails)
            _buildRecommendedSchemes(),
          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppTheme.primaryColor
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedSchemes() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendedSchemes.length,
        itemBuilder: (context, index) {
          final scheme = _recommendedSchemes[index];
          return Container(
            width: 250,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${scheme.schemeName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      scheme.department,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        _selectedSchemeForDetails = scheme;
                        _showSchemeDetails(scheme);
                        
                        // Save scheme to user's saved schemes
                        await _saveSchemeToMySchemes(scheme);
                        
                        _askForEmail();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        minimumSize: const Size(double.infinity, 36),
                      ),
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_isVoiceMode) ...[
            // Voice input
            Expanded(
              child: GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _scaleAnimation.value : 1.0,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? Colors.red : AppTheme.primaryColor,
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else ...[
            // Text input
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    _handleUserMessage(text);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  _handleUserMessage(_textController.text);
                }
              },
              color: AppTheme.primaryColor,
            ),
          ],
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

