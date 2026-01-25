import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/scheme.dart';

/// Service for fetching schemes from Firestore
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static List<Scheme>? _cachedSchemes;

  /// Fetch all schemes from Firestore
  Future<List<Scheme>> fetchSchemes() async {
    // Return cached data if available
    if (_cachedSchemes != null) {
      return _cachedSchemes!;
    }

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('schemes')
          .get();

      _cachedSchemes = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Scheme.fromJson(data);
          })
          .toList();

      return _cachedSchemes ?? [];
    } catch (e) {
      debugPrint('Error fetching schemes from Firestore: $e');
      return [];
    }
  }

  /// Fetch a specific scheme by ID
  Future<Scheme?> fetchSchemeById(String schemeId) async {
    try {
      final doc = await _firestore
          .collection('schemes')
          .doc(schemeId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Scheme.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching scheme: $e');
      return null;
    }
  }

  /// Save a scheme to user's saved schemes (now uses my_schemes subcollection)
  Future<bool> saveSchemeToUser(String userId, Scheme scheme) async {
    try {
      // Generate a unique document ID based on scheme name
      final schemeId = _generateSchemeId(scheme.schemeName);
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('my_schemes')
          .doc(schemeId)
          .set({
        ...scheme.toJson(),
        'progress': 'Not Applied',
        'savedAt': FieldValue.serverTimestamp(),
        'schemeId': schemeId,
        'documents': {}, // Document checklist - will be populated by user
      }, SetOptions(merge: true));

      debugPrint('✅ Scheme saved successfully: ${scheme.schemeName} for user: $userId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving scheme to user: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Update scheme progress in my_schemes
  Future<bool> updateSchemeProgress(
    String userId,
    String schemeId,
    String progress, {
    Map<String, bool>? documents,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'progress': progress,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (documents != null) {
        updateData['documents'] = documents;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('my_schemes')
          .doc(schemeId)
          .update(updateData);

      debugPrint('✅ Scheme progress updated: $schemeId -> $progress');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating scheme progress: $e');
      return false;
    }
  }

  /// Get my_schemes with progress data
  Future<List<Map<String, dynamic>>> getUserMySchemes(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('my_schemes')
          .orderBy('savedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                ...doc.data() as Map<String, dynamic>,
                'docId': doc.id,
              })
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching my_schemes: $e');
      return [];
    }
  }

  /// Get all saved schemes for a user (backward compatibility - uses my_schemes)
  Future<List<Scheme>> getUserSavedSchemes(String userId) async {
    try {
      final mySchemes = await getUserMySchemes(userId);
      final schemes = mySchemes
          .map((data) => Scheme.fromJson(data))
          .toList();

      debugPrint('✅ Loaded ${schemes.length} saved schemes for user: $userId');
      return schemes;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching saved schemes: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  /// Remove a scheme from user's saved schemes (now uses my_schemes)
  Future<bool> removeSchemeFromUser(String userId, String schemeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('my_schemes')
          .doc(schemeId)
          .delete();

      debugPrint('✅ Scheme removed successfully: $schemeId for user: $userId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error removing scheme: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Check if a scheme is saved by the user (now uses my_schemes)
  Future<bool> isSchemeSaved(String userId, Scheme scheme) async {
    try {
      final schemeId = _generateSchemeId(scheme.schemeName);
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('my_schemes')
          .doc(schemeId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('❌ Error checking if scheme is saved: $e');
      return false;
    }
  }

  /// Generate a unique ID for a scheme based on its name
  String _generateSchemeId(String schemeName) {
    // Convert scheme name to a valid document ID
    return schemeName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, schemeName.length > 50 ? 50 : schemeName.length);
  }

  /// Save or update user profile
  Future<bool> saveUserProfile(String userId, Map<String, dynamic> profileData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
        ...profileData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ User profile saved successfully for user: $userId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving user profile: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      return null;
    }
  }

  /// Clear cache (useful for refreshing data)
  static void clearCache() {
    _cachedSchemes = null;
  }
}



