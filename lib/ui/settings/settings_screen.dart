import 'package:flutter/material.dart';
import '../../main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_strings.dart';
import '../../core/services/language_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/auth_service.dart';

/// Settings Screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Locale _currentLocale = LanguageService.defaultLocale;
  bool _notificationsEnabled = true;
  bool _voiceFeedbackEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserNotificationSetting();
  }

  Future<void> _loadSettings() async {
    final locale = await LanguageService.getCurrentLanguage();
    setState(() {
      _currentLocale = locale;
    });
  }

  // Load the user's notifications preference from Firestore (if authenticated)
  Future<void> _loadUserNotificationSetting() async {
    try {
      final auth = AuthService();
      if (auth.isFirebaseConfigured && auth.currentUser != null) {
        final uid = auth.currentUser!.uid;
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data.containsKey('notificationsEnabled')) {
            setState(() {
              _notificationsEnabled = data['notificationsEnabled'] as bool;
            });
          }
        }
      }
    } catch (e) {
      // ignore - keep default
    }
  }

  // Save the user's notifications preference to Firestore (if authenticated)
  Future<void> _saveUserNotificationSetting(bool value) async {
    try {
      final auth = AuthService();
      if (auth.isFirebaseConfigured && auth.currentUser != null) {
        final uid = auth.currentUser!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'notificationsEnabled': value,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Notification preference saved.'),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sign in to save notification preference.'),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save preference. Please try again.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.settings),
      ),
      body: ListView(
        children: [
          // Language Setting
          ListTile(
            leading: const Icon(Icons.language, color: AppTheme.primaryColor),
            title: const Text('Language'),
            subtitle: Text(LanguageService.getLanguageName(_currentLocale)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final selectedLocale = await showDialog<Locale>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Language'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: LanguageService.supportedLocales.map((locale) {
                      return ListTile(
                        title: Text(LanguageService.getLanguageName(locale)),
                        leading: Radio<Locale>(
                          value: locale,
                          groupValue: _currentLocale,
                          onChanged: (value) {
                            Navigator.pop(context, value);
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context, locale);
                        },
                      );
                    }).toList(),
                  ),
                ),
              );

              if (selectedLocale != null) {
                await LanguageService.setLanguage(selectedLocale);
                LocalizationService.setLocale(selectedLocale);
                setState(() {
                  _currentLocale = selectedLocale;
                });
                // Reload app to apply language change - restart from root
                if (mounted) {
                  // Navigate to root and rebuild MaterialApp
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const YojanaSuchakApp()),
                    (Route<dynamic> route) => false,
                  );
                }
              }
            },
          ),
          const Divider(),
          // Notifications
          SwitchListTile(
            secondary:
                const Icon(Icons.notifications, color: AppTheme.primaryColor),
            title: const Text('Notifications'),
            subtitle: const Text('Enable push notifications'),
            value: _notificationsEnabled,
            onChanged: (value) async {
              setState(() {
                _notificationsEnabled = value;
              });
              await _saveUserNotificationSetting(value);
            },
          ),
          // Voice Feedback
          SwitchListTile(
            secondary:
                const Icon(Icons.volume_up, color: AppTheme.primaryColor),
            title: const Text('Voice Feedback'),
            subtitle: const Text('Enable text-to-speech responses'),
            value: _voiceFeedbackEnabled,
            onChanged: (value) {
              setState(() {
                _voiceFeedbackEnabled = value;
              });
            },
          ),
          const Divider(),
          // About
          ListTile(
            leading: const Icon(Icons.info, color: AppTheme.primaryColor),
            title: const Text('About'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppStrings.appName,
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 YojanaSuchak',
              );
            },
          ),
          // Privacy Policy
          ListTile(
            leading:
                const Icon(Icons.privacy_tip, color: AppTheme.primaryColor),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show privacy policy
            },
          ),
          // Terms of Service
          ListTile(
            leading:
                const Icon(Icons.description, color: AppTheme.primaryColor),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show terms of service
            },
          ),
        ],
      ),
    );
  }
}
