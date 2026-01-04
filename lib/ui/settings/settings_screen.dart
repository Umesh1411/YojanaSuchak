import 'package:flutter/material.dart';
import '../../main.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_strings.dart';
import '../../core/services/language_service.dart';
import '../../core/services/localization_service.dart';

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
  }

  Future<void> _loadSettings() async {
    final locale = await LanguageService.getCurrentLanguage();
    setState(() {
      _currentLocale = locale;
    });
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
            secondary: const Icon(Icons.notifications, color: AppTheme.primaryColor),
            title: const Text('Notifications'),
            subtitle: const Text('Enable push notifications'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          // Voice Feedback
          SwitchListTile(
            secondary: const Icon(Icons.volume_up, color: AppTheme.primaryColor),
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
            leading: const Icon(Icons.privacy_tip, color: AppTheme.primaryColor),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show privacy policy
            },
          ),
          // Terms of Service
          ListTile(
            leading: const Icon(Icons.description, color: AppTheme.primaryColor),
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
