import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/scheme.dart';
import '../models/user_profile.dart';
import 'eligibility_filter.dart';

/// Service for auto-notifying users when new eligible schemes are launched
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Listen for new schemes and notify eligible users
  /// This should be called once when app starts (or use Cloud Functions in production)
  void startListeningForNewSchemes() {
    _firestore
        .collection('schemes')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final schemeData = snapshot.docs.first.data();
        final scheme = Scheme.fromJson(schemeData);
        _notifyEligibleUsers(scheme);
      }
    });

    debugPrint('✅ Started listening for new schemes');
  }

  /// Check all users and notify those eligible for the new scheme
  Future<void> _notifyEligibleUsers(Scheme scheme) async {
    try {
      debugPrint('🔔 Checking eligible users for scheme: ${scheme.schemeName}');

      // Get all users from Firestore
      final usersSnapshot = await _firestore.collection('users').get();

      int notifiedCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;

        // Skip if user doesn't have profile data
        if (!_hasCompleteProfile(userData)) {
          continue;
        }

        // Build user profile from Firestore data
        final userProfile = UserProfile.fromJson(userData);

        // Check if user is eligible using eligibility filter
        final allSchemes = [scheme];
        final eligibleSchemes = EligibilityFilter.filterSchemes(
          allSchemes,
          userProfile,
        );

        if (eligibleSchemes.isNotEmpty) {
          // User is eligible - send notification and email
          await _sendNotificationToUser(userId, scheme, userProfile, userData);
          notifiedCount++;
        }
      }

      debugPrint(
          '✅ Notified $notifiedCount eligible users about ${scheme.schemeName}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error notifying eligible users: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  /// Check if user has complete profile for eligibility matching
  bool _hasCompleteProfile(Map<String, dynamic> userData) {
    return userData.containsKey('age') &&
        userData.containsKey('gender') &&
        userData.containsKey('state') &&
        userData.containsKey('district') &&
        userData.containsKey('annualIncome') &&
        userData.containsKey('occupation') &&
        (userData.containsKey('caste') || userData.containsKey('category'));
  }

  /// Send notification and email to eligible user
  Future<void> _sendNotificationToUser(
    String userId,
    Scheme scheme,
    UserProfile userProfile,
    Map<String, dynamic> userData,
  ) async {
    try {
      // Create in-app notification document
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': 'new_scheme',
        'schemeId': scheme.schemeId,
        'schemeName': scheme.schemeName,
        'message': 'New scheme available: ${scheme.schemeName}',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send email if user has email address
      final userEmail = userData['email'] as String?;
      if (userEmail != null && userEmail.isNotEmpty) {
        await _sendEligibilityEmail(
          userEmail: userEmail,
          userName: userProfile.fullName ?? 'User',
          scheme: scheme,
          userProfile: userProfile,
        );
      }

      debugPrint('✅ Notification sent to user: $userId');
    } catch (e) {
      debugPrint('❌ Error sending notification to user $userId: $e');
    }
  }

  /// Send eligibility email to user
  Future<void> _sendEligibilityEmail({
    required String userEmail,
    required String userName,
    required Scheme scheme,
    required UserProfile userProfile,
  }) async {
    try {
      // Build eligibility explanation
      final eligibilityExplanation = _buildEligibilityExplanation(
        scheme,
        userProfile,
      );

      // PRODUCTION: Email sending disabled - no SMTP config in AppConfig
      // TODO: Implement email via backend service
      debugPrint(
          'Email sending disabled - SMTP not configured in AppConfig. Eligibility: \n$eligibilityExplanation');
      // final emailService = EmailService(
      //   smtpHost: AppConfig.smtpHost,
      //   smtpPort: AppConfig.smtpPort,
      //   username: AppConfig.smtpUsername,
      //   password: AppConfig.smtpPassword,
      //   useTls: AppConfig.useTls,
      // );

      // await emailService.sendEligibleSchemeEmail(
      //   recipientEmail: userEmail,
      //   recipientName: userName,
      //   scheme: scheme,
      //   eligibilityExplanation: eligibilityExplanation,
      // );

      debugPrint('✅ Eligibility flow finished for: $userEmail');
    } catch (e) {
      debugPrint('❌ Error sending eligibility email: $e');
    }
  }

  /// Build explanation of why user is eligible
  String _buildEligibilityExplanation(Scheme scheme, UserProfile profile) {
    List<String> reasons = [];

    // Age eligibility
    if (profile.age != null) {
      if (scheme.minAge != null && scheme.maxAge != null) {
        if (profile.age! >= scheme.minAge! && profile.age! <= scheme.maxAge!) {
          reasons.add(
              'Your age (${profile.age} years) falls within the required range (${scheme.minAge}-${scheme.maxAge} years).');
        }
      } else if (scheme.minAge != null && profile.age! >= scheme.minAge!) {
        reasons.add(
            'Your age (${profile.age} years) meets the minimum requirement (${scheme.minAge} years).');
      }
    }

    // Income eligibility
    if (profile.annualIncome != null && scheme.maxIncomeINR != null) {
      if (profile.annualIncome! <= scheme.maxIncomeINR!) {
        reasons.add(
            'Your annual income (₹${profile.annualIncome}) is within the eligible limit (₹${scheme.maxIncomeINR}).');
      }
    }

    // Occupation eligibility
    if (profile.occupation != null &&
        scheme.occupationEligible != 'Any' &&
        scheme.occupationEligible
            .toLowerCase()
            .contains(profile.occupation!.toLowerCase())) {
      reasons.add(
          'Your occupation (${profile.occupation}) matches the target group for this scheme.');
    }

    // Category eligibility
    if (profile.casteOrCategory != null &&
        scheme.casteEligible != 'All' &&
        scheme.casteEligible.toUpperCase() ==
            profile.casteOrCategory!.toUpperCase()) {
      reasons.add(
          'Your category (${profile.casteOrCategory}) is eligible for this scheme.');
    }

    // State eligibility
    if (profile.state != null && scheme.state == profile.state) {
      reasons.add(
          'You are a resident of ${profile.state}, which qualifies you for this scheme.');
    }

    if (reasons.isEmpty) {
      return 'Based on your profile information, you appear to be eligible for this scheme.';
    }

    return reasons.join('\n\n');
  }
}
