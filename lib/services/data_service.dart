import '../models/scheme.dart';
import 'firestore_service.dart';

/// Service for loading scheme data
/// Only loads from Firestore - no JSON fallback
class DataService {
  static List<Scheme>? _cachedSchemes;
  static final FirestoreService _firestoreService = FirestoreService();

  /// Load schemes - only from Firestore
  static Future<List<Scheme>> loadSchemes() async {
    if (_cachedSchemes != null) {
      return _cachedSchemes!;
    }

    // Only try Firestore
    try {
      final schemes = await _firestoreService.fetchSchemes();
      if (schemes.isNotEmpty) {
        _cachedSchemes = schemes;
        return schemes;
      } else {
        print('⚠️ No schemes found in Firestore. Please add schemes to Firestore collection.');
        return [];
      }
    } catch (e) {
      print('❌ Firestore fetch failed: $e');
      print('⚠️ Please ensure Firestore is properly configured and schemes collection exists.');
      return [];
    }
  }

  /// Clear cached schemes (useful for testing or reloading)
  static void clearCache() {
    _cachedSchemes = null;
    FirestoreService.clearCache();
  }
}




