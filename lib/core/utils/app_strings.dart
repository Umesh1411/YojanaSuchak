import '../services/localization_service.dart';

/// App Strings for localization
class AppStrings {
  // App Name
  static String get appName => LocalizationService.get('appName');
  static String get appTagline => LocalizationService.get('appTagline');

  // Common
  static String get continueText => LocalizationService.get('continue');
  static String get skip => LocalizationService.get('skip');
  static String get next => LocalizationService.get('next');
  static String get back => LocalizationService.get('back');
  static String get done => LocalizationService.get('done');
  static String get cancel => LocalizationService.get('cancel');
  static String get save => LocalizationService.get('save');
  static String get edit => LocalizationService.get('edit');
  static String get delete => LocalizationService.get('delete');
  static String get logout => LocalizationService.get('logout');

  // Authentication
  static const String login = 'Login';
  static const String signUp = 'Sign Up';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String name = 'Name';
  static const String forgotPassword = 'Forgot Password?';
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String resetPassword = 'Reset Password';

  // Home
  static String get findScheme => LocalizationService.get('findScheme');
  static String get welcome => LocalizationService.get('welcome');
  static String get discoverSchemes => LocalizationService.get('discoverSchemes');

  // Menu
  static String get profile => LocalizationService.get('profile');
  static String get mySchemes => LocalizationService.get('mySchemes');
  static String get contactUs => LocalizationService.get('contactUs');
  static String get settings => LocalizationService.get('settings');
  static String get rateUs => LocalizationService.get('rateUs');
  static String get about => LocalizationService.get('about');

  // Onboarding
  static const String onboardingTitle1 = 'Voice-Powered Search';
  static const String onboardingDesc1 = 'Find schemes using natural voice conversation';
  static const String onboardingTitle2 = 'AI Recommendations';
  static const String onboardingDesc2 = 'Get personalized scheme recommendations powered by AI';
  static const String onboardingTitle3 = '200+ Schemes';
  static const String onboardingDesc3 = 'Access comprehensive database of Maharashtra government schemes';
}






