import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/app_strings.dart';
import '../../models/scheme.dart';
import '../../services/firestore_service.dart';
import '../../core/services/auth_service.dart';

/// My Schemes Screen - Shows saved/favorite schemes
class MySchemesScreen extends StatefulWidget {
  const MySchemesScreen({super.key});

  @override
  State<MySchemesScreen> createState() => _MySchemesScreenState();
}

class _MySchemesScreenState extends State<MySchemesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<Scheme> _savedSchemes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedSchemes();
  }

  Future<void> _loadSavedSchemes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get user ID (handle both Firebase and demo auth)
      String? userId;
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
      } else {
        final demoUser = _authService.demoUserData;
        if (demoUser != null) {
          userId = demoUser['uid'] as String?;
        }
      }

      if (userId == null) {
        setState(() {
          _savedSchemes = [];
          _isLoading = false;
          _errorMessage = 'Please log in to view your saved schemes.';
        });
        return;
      }

      final schemes = await _firestoreService.getUserSavedSchemes(userId);
      if (mounted) {
        setState(() {
          _savedSchemes = schemes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading saved schemes: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load saved schemes. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeScheme(Scheme scheme) async {
    try {
      // Get user ID
      String? userId;
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
      } else {
        final demoUser = _authService.demoUserData;
        if (demoUser != null) {
          userId = demoUser['uid'] as String?;
        }
      }

      if (userId == null) return;

      // Generate scheme ID (same logic as in FirestoreService)
      final schemeId = scheme.schemeName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .substring(0, scheme.schemeName.length > 50 ? 50 : scheme.schemeName.length);

      final success = await _firestoreService.removeSchemeFromUser(userId, schemeId);
      if (success && mounted) {
        // Reload schemes
        await _loadSavedSchemes();
        
        // Show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${scheme.schemeName} removed from My Schemes'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error removing scheme: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove scheme: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSchemeDetails(Scheme scheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(scheme.schemeName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Department', scheme.department),
              _buildDetailRow('Target Group', scheme.targetGroup),
              const SizedBox(height: 12),
              const Text(
                'Eligibility:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(scheme.eligibility),
              const SizedBox(height: 12),
              const Text(
                'Benefits:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(scheme.benefits),
              const SizedBox(height: 12),
              const Text(
                'Required Documents:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...scheme.requiredDocuments.map((doc) => Text('• $doc')),
              if (scheme.incomeLimit != null)
                _buildDetailRow('Income Limit', '₹${scheme.incomeLimit!.toStringAsFixed(0)}'),
              if (scheme.ageLimit != null)
                _buildDetailRow('Age Limit', '${scheme.ageLimit} years'),
            ],
          ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.mySchemes),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedSchemes,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSavedSchemes,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _savedSchemes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No saved schemes yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Save schemes from recommendations to view them here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSavedSchemes,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _savedSchemes.length,
                        itemBuilder: (context, index) {
                          final scheme = _savedSchemes[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                scheme.schemeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    scheme.department,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (scheme.targetGroup.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Target: ${scheme.targetGroup}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.visibility, size: 20),
                                        SizedBox(width: 8),
                                        Text('View Details'),
                                      ],
                                    ),
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () => _showSchemeDetails(scheme),
                                      );
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Remove', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () => _removeScheme(scheme),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              onTap: () => _showSchemeDetails(scheme),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

