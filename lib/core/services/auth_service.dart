import 'package:firebase_auth/firebase_auth.dart';
import 'demo_auth_service.dart';

/// Service for handling Firebase Authentication
/// Falls back to demo mode if Firebase is not configured
class AuthService {
  FirebaseAuth? _auth;
  final DemoAuthService _demoAuth = DemoAuthService();
  bool _useDemoMode = false;

  bool get isFirebaseConfigured {
    try {
      _auth ??= FirebaseAuth.instance;
      return true;
    } catch (e) {
      _useDemoMode = true;
      return false;
    }
  }

  FirebaseAuth get auth {
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
        _useDemoMode = false;
      } catch (e) {
        // Firebase not initialized, use demo mode
        _useDemoMode = true;
        throw Exception('Firebase is not initialized. Using demo mode.');
      }
    }
    return _auth!;
  }

  // Get current user
  User? get currentUser {
    if (_useDemoMode) {
      // Return null for demo mode - handled separately
      return null;
    }
    try {
      return auth.currentUser;
    } catch (e) {
      return null;
    }
  }

  // Check if user is authenticated (works for both Firebase and demo mode)
  bool get isAuthenticated {
    if (_useDemoMode || !isFirebaseConfigured) {
      return _demoAuth.isAuthenticated;
    }
    return currentUser != null;
  }

  // Get demo user data if in demo mode
  Map<String, dynamic>? get demoUserData {
    if (_useDemoMode || !isFirebaseConfigured) {
      return _demoAuth.currentUserData;
    }
    return null;
  }

  // Auth state stream
  Stream<User?> get authStateChanges {
    if (_useDemoMode || !isFirebaseConfigured) {
      // Return stream that emits current demo user state
      return Stream.value(null);
    }
    try {
      return auth.authStateChanges();
    } catch (e) {
      // Return empty stream if Firebase not initialized
      return Stream.value(null);
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    // Check if Firebase is configured
    if (!isFirebaseConfigured) {
      // Use demo mode
      try {
        await _demoAuth.signIn(email: email, password: password);
        return null; // Demo mode doesn't return UserCredential
      } catch (e) {
        throw e.toString();
      }
    }

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An error occurred: ${e.toString()}';
    }
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    // Check if Firebase is configured
    if (!isFirebaseConfigured) {
      // Use demo mode
      try {
        await _demoAuth.signUp(email: email, password: password, name: name);
        return null; // Demo mode doesn't return UserCredential
      } catch (e) {
        throw e.toString();
      }
    }

    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An error occurred: ${e.toString()}';
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (_useDemoMode || !isFirebaseConfigured) {
      await _demoAuth.signOut();
      return;
    }

    try {
      await auth.signOut();
    } catch (e) {
      // Ignore errors
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    if (!isFirebaseConfigured) {
      throw 'Password reset is not available in demo mode. Please configure Firebase.';
    }

    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
