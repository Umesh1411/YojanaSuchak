import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage user's saved schemes stored under users/{userId}/mySchemes
class MySchemesService {
  final FirebaseFirestore _firestore;

  MySchemesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Save selected scheme IDs (or scheme names) for a user along with preferred emails
  Future<void> saveSchemes(String userId, List<String> schemeIds,
      {List<String>? emails}) async {
    final ref =
        _firestore.collection('users').doc(userId).collection('mySchemes');

    // Add timestamped records; replace existing set with provided ones
    final batch = _firestore.batch();

    // Delete old saved schemes first to keep in-sync
    final existing = await ref.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (final s in schemeIds) {
      final docRef = ref.doc();
      batch.set(docRef, {
        'schemeIdOrName': s,
        'savedAt': FieldValue.serverTimestamp(),
        'emails': emails ?? [],
      });
    }

    await batch.commit();
  }

  /// Get saved schemes for a user
  Future<List<Map<String, dynamic>>> getSavedSchemes(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('mySchemes')
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }
}
