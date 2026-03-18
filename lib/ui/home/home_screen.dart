import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/localization_service.dart';
import '../scheme_finder/enhanced_scheme_finder_screen.dart';
import '../profile/profile_screen.dart';
import '../my_schemes/my_schemes_screen.dart';
import '../contact/contact_us_screen.dart';
import '../settings/settings_screen.dart';
import '../rate_us/rate_us_screen.dart';
import '../admin/admin_scheme_upload_screen.dart';

/// Main Home Screen with Drawer Menu
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  Locale _currentLocale = LanguageService.defaultLocale;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final locale = await LanguageService.getCurrentLanguage();
    setState(() {
      _currentLocale = locale;
    });
  }

  String _getUserName() {
    final user = _authService.currentUser;
    if (user != null) {
      return user.displayName ?? 'User';
    }
    final demoUser = _authService.demoUserData;
    if (demoUser != null) {
      return demoUser['displayName'] ?? 'Demo User';
    }
    return 'User';
  }

  Future<void> _showLanguageDialog() async {
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
      // Reload the app to apply language change - restart from root
      if (mounted) {
        // Navigate to root and rebuild MaterialApp
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const YojanaSuchakApp()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.appName),
        actions: [
          // Language selector
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: _showLanguageDialog,
            tooltip: 'Change Language',
          ),
        ],
      ),
      drawer: _buildDrawer(user),
      body: _buildHomeContent(),
    );
  }

  Widget _buildDrawer(User? user) {
    final authService = AuthService();
    final demoUser = authService.demoUserData;

    // Get user info from Firebase or demo mode
    final String displayName = user?.displayName ??
        (demoUser != null ? (demoUser['displayName'] as String?) : null) ??
        'User';
    final String email = user?.email ??
        (demoUser != null ? (demoUser['email'] as String?) : null) ??
        '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Drawer header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
            ),
            accountName: Text(
              displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (user?.displayName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          // Menu items
          _buildDrawerItem(
            icon: Icons.person_outline,
            title: AppStrings.profile,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.bookmark_outline,
            title: AppStrings.mySchemes,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MySchemesScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.contact_support_outlined,
            title: AppStrings.contactUs,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactUsScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.settings_outlined,
            title: AppStrings.settings,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const Divider(),
          // Admin Upload Scheme (for admins)
          _buildDrawerItem(
            icon: Icons.cloud_upload,
            title: 'Upload Scheme (Admin)',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminSchemeUploadScreen()),
              );
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.star_outline,
            title: AppStrings.rateUs,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RateUsScreen()),
              );
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.info_outline,
            title: AppStrings.about,
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog();
            },
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: AppStrings.logout,
            onTap: () async {
              Navigator.pop(context);
              await _authService.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero section with image and name
          Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.7),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.mic,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // App Name
                      Text(
                        AppStrings.appName,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tagline
                      Text(
                        AppStrings.discoverSchemes,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Welcome message
                Text(
                  '${AppStrings.welcome}, ${_getUserName()}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find the best government schemes tailored for you',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                // Find Scheme button
                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EnhancedSchemeFinderScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search, size: 28),
                    label: Text(
                      AppStrings.findScheme,
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Quick stats or info cards
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.library_books,
                        title: '200+',
                        subtitle: 'Schemes',
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.psychology,
                        title: 'AI',
                        subtitle: 'Powered',
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        icon: Icons.mic,
                        title: 'Voice',
                        subtitle: 'Search',
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About YojanaSuchak'),
        content: const Text(
          'YojanaSuchak is a voice-powered AI assistant that helps you discover the best Maharashtra government schemes tailored to your needs.\n\n'
          'Version: 1.0.0\n'
          'Powered by Google Gemini AI',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
