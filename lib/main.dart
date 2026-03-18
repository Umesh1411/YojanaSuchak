import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/language_service.dart';
import 'core/services/localization_service.dart';
import 'core/utils/app_strings.dart';
import 'services/environment_scheme_seeder.dart';
import 'ui/screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load runtime .env if present. This makes local dev easier (you can set GEMINI_API_KEY in a .env file).
  // Note: compile-time `--dart-define` still takes priority in EnvConfig.
  try {
    // For local non-web development, load a .env file if present. For web builds, prefer --dart-define and avoid fetching an asset.
    if (!bool.fromEnvironment('dart.vm.product') && !kIsWeb) {
      await DotEnv().load(fileName: '.env');
    }
  } catch (e) {
    // silent: if no .env file present, that's okay
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Seed environment schemes into Firestore once (silent & non-intrusive)
  await EnvironmentSchemeSeeder.seedOnce();

  // Initialize localization
  await LocalizationService.initialize();

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
