import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

/// Wrapper to check authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    // Check if user is authenticated (works for both Firebase and demo mode)
    if (authService.isAuthenticated) {
      return const HomeScreen();
    }

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Check authentication status again
        if (authService.isAuthenticated) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}


