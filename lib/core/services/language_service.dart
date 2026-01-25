import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Service for managing app language
class LanguageService {
  static const String _languageKey = 'app_language';
  static const Locale defaultLocale = Locale('en', 'IN');

  // Supported languages
  static const List<Locale> supportedLocales = [
    Locale('en', 'IN'), // English
    Locale('hi', 'IN'), // Hindi
    Locale('mr', 'IN'), // Marathi
  ];

  // Get current language
  static Future<Locale> getCurrentLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);
    
    if (languageCode != null) {
      final parts = languageCode.split('_');
      if (parts.length == 2) {
        return Locale(parts[0], parts[1]);
      }
    }
    
    return defaultLocale;
  }

  // Set language
  static Future<void> setLanguage(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, '${locale.languageCode}_${locale.countryCode}');
  }

  // Get language name
  static String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिंदी';
      case 'mr':
        return 'मराठी';
      default:
        return 'English';
    }
  }
}










