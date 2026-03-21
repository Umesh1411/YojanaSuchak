import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage user's saved schemes stored under users/{userId}/my_schemes (app standard)
class MySchemesService {
  final FirebaseFirestore _firestore;

  MySchemesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Save selected scheme IDs (document IDs) or scheme names for a user along with preferred emails
  Future<void> saveSchemes(String userId, List<String> schemeIds,
      {List<String>? emails}) async {
    final ref =
        _firestore.collection('users').doc(userId).collection('my_schemes');

    // Replace existing saved schemes to keep in-sync
    final batch = _firestore.batch();

    final existing = await ref.get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (final schemeId in schemeIds) {
      // Try to fetch scheme by id
      try {
        final schemeDoc =
            await _firestore.collection('schemes').doc(schemeId).get();
        if (schemeDoc.exists) {
          // Use FirestoreService helper to save properly
          final data = schemeDoc.data() as Map<String, dynamic>;
          // generate schemeId key consistent with FirestoreService
          final id = _generateSchemeId(data['schemeName']);
          final docRef = ref.doc(id);
          batch.set(
              docRef,
              {
                ...data,
                'progress': 'Not Applied',
                'savedAt': FieldValue.serverTimestamp(),
                'schemeId': id,
                'documents': {},
                'emails': emails ?? [],
              },
              SetOptions(merge: true));
          continue;
        }
      } catch (e) {
        // ignore
      }

      // Fallback: treat schemeId as schemeName and save with generated id
      final generatedId = _generateSchemeId(schemeId);
      final docRef = ref.doc(generatedId);
      batch.set(
          docRef,
          {
            'schemeId': generatedId,
            'schemeName': schemeId,
            'savedAt': FieldValue.serverTimestamp(),
            'progress': 'Not Applied',
            'documents': {},
            'emails': emails ?? [],
          },
          SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Get saved schemes for a user
  Future<List<Map<String, dynamic>>> getSavedSchemes(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('my_schemes')
        .orderBy('savedAt', descending: true)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  /// Local generator for scheme document id
  String _generateSchemeId(String schemeName) {
    return schemeName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .substring(0, schemeName.length > 50 ? 50 : schemeName.length);
  }
}
