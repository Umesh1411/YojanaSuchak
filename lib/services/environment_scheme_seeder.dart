import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeds a fixed set of environment schemes into Firestore on first app launch.
///
/// This is intended as a one-time, silent seeding action. It does not show any
/// UI notifications and will not overwrite existing documents.
class EnvironmentSchemeSeeder {
  static const _prefsKey = 'environment_schemes_seeded';
  static const _assetPath = 'assets/data/environment_schemes.json';
  static const _collection = 'environment_schemes';

  /// Seed the environment schemes into Firestore once.
  ///
  /// Returns true if seeding was performed (or already done), false if an error occurred.
  static Future<bool> seedOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadySeeded = prefs.getBool(_prefsKey) ?? false;
      if (alreadySeeded) {
        return true;
      }

      final content = await rootBundle.loadString(_assetPath);
      final Map<String, dynamic> json = jsonDecode(content);
      if (json['schemes'] == null || json['schemes'] is! List) {
        return false;
      }

      final List<dynamic> schemes = json['schemes'] as List<dynamic>;
      final firestore = FirebaseFirestore.instance;

      for (final dynamic scheme in schemes) {
        if (scheme is! Map<String, dynamic>) continue;
        final docId = (scheme['Scheme_ID'] as String?)?.trim();
        if (docId == null || docId.isEmpty) {
          continue;
        }

        final docRef = firestore.collection(_collection).doc(docId);
        final docSnapshot = await docRef.get();
        if (docSnapshot.exists) {
          // Already present - skip
          continue;
        }

        await docRef.set(scheme);
      }

      await prefs.setBool(_prefsKey, true);
      return true;
    } catch (e) {
      // Silent failure - we do not show notifications
      debugPrint('EnvironmentSchemeSeeder: failed to seed schemes: $e');
      return false;
    }
  }
}
