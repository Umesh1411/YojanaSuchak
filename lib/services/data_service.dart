import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/scheme.dart';
import 'firestore_service.dart';

/// Service for loading scheme data
/// Tries Firestore first, falls back to local JSON if Firestore fails
class DataService {
  static List<Scheme>? _cachedSchemes;
  static final FirestoreService _firestoreService = FirestoreService();

  /// Load schemes - tries Firestore first, then local JSON
  static Future<List<Scheme>> loadSchemes() async {
    if (_cachedSchemes != null) {
      return _cachedSchemes!;
    }

    // Try Firestore first
    try {
      final schemes = await _firestoreService.fetchSchemes();
      if (schemes.isNotEmpty) {
        _cachedSchemes = schemes;
        return schemes;
      }
    } catch (e) {
      print('Firestore fetch failed, trying local JSON: $e');
    }

    // Fallback to local JSON
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/maharashtra_schemes.json');

      final List<dynamic> jsonList = jsonDecode(jsonString);

      _cachedSchemes = jsonList
          .map((json) => Scheme.fromJson(json as Map<String, dynamic>))
          .toList();

      return _cachedSchemes!;
    } catch (e) {
      print('Error loading schemes: $e');
      return [];
    }
  }

  /// Clear cached schemes (useful for testing or reloading)
  static void clearCache() {
    _cachedSchemes = null;
    FirestoreService.clearCache();
  }
}




