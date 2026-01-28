import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/language_service.dart';
import 'core/services/localization_service.dart';
import 'core/utils/app_strings.dart';
import 'ui/screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }


  // Initialize localization
  await LocalizationService.initialize();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("dotenv not loaded (web?): $e");
  }

  runApp(const YojanaSuchakApp());
}

class YojanaSuchakApp extends StatefulWidget {
  const YojanaSuchakApp({super.key});

  @override
  State<YojanaSuchakApp> createState() => _YojanaSuchakAppState();
}

class _YojanaSuchakAppState extends State<YojanaSuchakApp> {
  Locale _locale = LanguageService.defaultLocale;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final locale = await LanguageService.getCurrentLanguage();
    LocalizationService.setLocale(locale);
    if (mounted) {
      setState(() {
        _locale = locale;
      });
    }
  }

  // Method to update language from anywhere in the app
  void updateLanguage(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(_locale.toString()), // Rebuild when locale changes
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: _locale,
      supportedLocales: LanguageService.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
