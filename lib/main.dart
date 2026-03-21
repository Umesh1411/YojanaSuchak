import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/language_service.dart';
import 'core/services/localization_service.dart';
import 'core/utils/app_strings.dart';
import 'core/config/app_config.dart';
import 'ui/screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables BEFORE anything else
  try {
    await dotenv.load(fileName: ".env");
    final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    AppConfig.setGeminiApiKey(geminiKey);
    if (geminiKey.isNotEmpty) {
      debugPrint('✅ Gemini API key loaded (length: \\${geminiKey.length})');
    } else {
      debugPrint('⚠️ Gemini API key not found in .env');
    }

    // Load SMTP config
    final smtpHost = dotenv.env['SMTP_HOST'] ?? 'smtp.gmail.com';
    final smtpPort = int.tryParse(dotenv.env['SMTP_PORT'] ?? '587') ?? 587;
    final smtpUser = dotenv.env['SMTP_USER'] ?? '';
    final smtpPass = dotenv.env['SMTP_PASS'] ?? '';
    final smtpSecure =
        (dotenv.env['SMTP_SECURE'] ?? 'false').toLowerCase() == 'true';
    AppConfig.setSmtpConfig(
      host: smtpHost,
      port: smtpPort,
      username: smtpUser,
      password: smtpPass,
      secure: smtpSecure,
    );
    debugPrint(
        '✅ SMTP config loaded: host=$smtpHost, port=$smtpPort, user=$smtpUser, secure=$smtpSecure');

    // Load admin password (optional, local/dev only)
    final adminPassword = dotenv.env['ADMIN_PASSWORD'] ?? '';
    AppConfig.setAdminPassword(adminPassword);
  } catch (e) {
    debugPrint('⚠️ Could not load .env file: $e');
    AppConfig.setGeminiApiKey('');
  }

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
