/// Demo Authentication Service - Works without Firebase
/// Use this for testing when Firebase is not configured
class DemoAuthService {
  static final DemoAuthService _instance = DemoAuthService._internal();
  factory DemoAuthService() => _instance;
  DemoAuthService._internal();

  Map<String, String> _users = {
    'demo@yojanasuchak.com': 'demo123',
    'test@test.com': 'test123',
  };

  Map<String, Map<String, dynamic>> _userData = {
    'demo@yojanasuchak.com': {
      'email': 'demo@yojanasuchak.com',
      'displayName': 'Demo User',
      'uid': 'demo_user_1',
    },
    'test@test.com': {
      'email': 'test@test.com',
      'displayName': 'Test User',
      'uid': 'test_user_1',
    },
  };

  String? _currentUserEmail;

  String? get currentUserEmail => _currentUserEmail;
  
  Map<String, dynamic>? get currentUserData {
    if (_currentUserEmail != null) {
      return _userData[_currentUserEmail];
    }
    return null;
  }

  bool get isAuthenticated => _currentUserEmail != null;

  Future<Map<String, dynamic>?> signIn({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (_users.containsKey(email) && _users[email] == password) {
      _currentUserEmail = email;
      return _userData[email];
    } else {
      throw 'Invalid email or password. Try: demo@yojanasuchak.com / demo123';
    }
  }

  Future<Map<String, dynamic>?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (_users.containsKey(email)) {
      throw 'An account already exists for that email.';
    }

    if (password.length < 6) {
      throw 'Password must be at least 6 characters.';
    }

    // Create new user
    final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
    _users[email] = password;
    _userData[email] = {
      'email': email,
      'displayName': name,
      'uid': uid,
    };

    _currentUserEmail = email;
    return _userData[email];
  }

  Future<void> signOut() async {
    _currentUserEmail = null;
  }
}









