import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_strings.dart';

/// Profile Screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.profile),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 60,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                (user?.displayName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              user?.displayName ?? 'User',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Email
            Text(
              user?.email ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            // Profile Info Cards
            Card(
              child: ListTile(
                leading: const Icon(Icons.email, color: AppTheme.primaryColor),
                title: const Text('Email'),
                subtitle: Text(user?.email ?? 'Not available'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: AppTheme.primaryColor),
                title: const Text('Display Name'),
                subtitle: Text(user?.displayName ?? 'Not set'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user, color: AppTheme.primaryColor),
                title: const Text('Email Verified'),
                subtitle: Text(user?.emailVerified == true ? 'Verified' : 'Not Verified'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}






