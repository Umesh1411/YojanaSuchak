import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/app_strings.dart';
import '../../models/scheme.dart';
import '../../services/firestore_service.dart';
import '../../core/services/auth_service.dart';

/// My Schemes Screen with progress tracker and document checklist
class MySchemesScreen extends StatefulWidget {
  const MySchemesScreen({super.key});

  @override
  State<MySchemesScreen> createState() => _MySchemesScreenState();
}

class _MySchemesScreenState extends State<MySchemesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _mySchemes = [];
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _progressOptions = [
    'Not Applied',
    'Applied',
    'Documents Submitted',
    'Approved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadMySchemes();
  }

  Future<void> _loadMySchemes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _getUserId();
      if (userId == null) {
        setState(() {
          _mySchemes = [];
          _isLoading = false;
          _errorMessage = 'Please log in to view your saved schemes.';
        });
        return;
      }

      final schemes = await _firestoreService.getUserMySchemes(userId);
      if (mounted) {
        setState(() {
          _mySchemes = schemes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading my schemes: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load schemes. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  String? _getUserId() {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      return firebaseUser.uid;
    }
    final demoUser = _authService.demoUserData;
    return demoUser?['uid'] as String?;
  }

  Future<void> _updateProgress(String schemeId, String progress) async {
    final userId = _getUserId();
    if (userId == null) return;

    final success = await _firestoreService.updateSchemeProgress(
      userId,
      schemeId,
      progress,
    );

    if (success) {
      await _loadMySchemes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Progress updated to: $progress')),
        );
      }
    }
  }

  Future<void> _updateDocumentStatus(
    String schemeId,
    String documentName,
    bool isCompleted,
  ) async {
    final userId = _getUserId();
    if (userId == null) return;

    // Get current documents status
    final schemeData = _mySchemes.firstWhere(
      (s) => s['schemeId'] == schemeId,
      orElse: () => {},
    );

    final documents = Map<String, bool>.from(
      schemeData['documents'] ?? {},
    );
    documents[documentName] = isCompleted;

    final success = await _firestoreService.updateSchemeProgress(
      userId,
      schemeId,
      schemeData['progress'] ?? 'Not Applied',
      documents: documents,
    );

    if (success) {
      await _loadMySchemes();
    }
  }

  Future<void> _removeScheme(String schemeId) async {
    final userId = _getUserId();
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Scheme'),
        content: const Text(
            'Are you sure you want to remove this scheme from My Schemes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success =
        await _firestoreService.removeSchemeFromUser(userId, schemeId);
    if (success && mounted) {
      await _loadMySchemes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheme removed successfully')),
      );
    }
  }

  Color _getProgressColor(String progress) {
    switch (progress) {
      case 'Not Applied':
        return Colors.grey;
      case 'Applied':
        return Colors.blue;
      case 'Documents Submitted':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.mySchemes),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMySchemes,
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
                        onPressed: _loadMySchemes,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _mySchemes.isEmpty
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
                      onRefresh: _loadMySchemes,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _mySchemes.length,
                        itemBuilder: (context, index) {
                          final schemeData = _mySchemes[index];
                          final scheme = Scheme.fromJson(schemeData);
                          final progress =
                              schemeData['progress'] ?? 'Not Applied';
                          final documents = Map<String, bool>.from(
                            schemeData['documents'] ?? {},
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            child: InkWell(
                              onTap: () =>
                                  _showSchemeDetails(scheme, schemeData),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Scheme Name and Remove Button
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            scheme.schemeName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _removeScheme(scheme.schemeId),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      scheme.department,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Progress Tracker
                                    const Text(
                                      'Application Progress:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: progress,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: _getProgressColor(progress)
                                            .withOpacity(0.1),
                                      ),
                                      items: _progressOptions.map((option) {
                                        return DropdownMenuItem(
                                          value: option,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color:
                                                      _getProgressColor(option),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(option),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          _updateProgress(
                                            scheme.schemeId,
                                            value,
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Document Checklist
                                    const Text(
                                      'Document Checklist:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ..._buildDocumentChecklist(
                                      scheme,
                                      documents,
                                      scheme.schemeId,
                                    ),
                                    const SizedBox(height: 8),

                                    // View Details Button
                                    TextButton.icon(
                                      onPressed: () => _showSchemeDetails(
                                          scheme, schemeData),
                                      icon: const Icon(Icons.info_outline),
                                      label: const Text('View Full Details'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  List<Widget> _buildDocumentChecklist(
    Scheme scheme,
    Map<String, bool> documents,
    String schemeId,
  ) {
    // Default documents that are commonly required
    final defaultDocuments = [
      'Aadhaar',
      'Income Certificate',
      'Caste Certificate',
    ];

    // Merge with scheme-specific documents
    final allDocuments = [
      ...defaultDocuments,
      ...scheme.importantDocuments.where(
        (doc) => !defaultDocuments.any(
          (defaultDoc) => doc.toLowerCase().contains(defaultDoc.toLowerCase()),
        ),
      ),
    ];

    if (allDocuments.isEmpty) {
      return [
        Text(
          'No specific documents required',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ];
    }

    return allDocuments.map((doc) {
      final isCompleted = documents[doc] ?? false;
      return CheckboxListTile(
        title: Text(doc, style: const TextStyle(fontSize: 14)),
        value: isCompleted,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (value) {
          _updateDocumentStatus(schemeId, doc, value ?? false);
        },
      );
    }).toList();
  }

  void _showSchemeDetails(Scheme scheme, Map<String, dynamic> schemeData) {
    final progress = schemeData['progress'] ?? 'Not Applied';

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
              _buildDetailRow('Progress', progress),
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
              Text(scheme.allBenefitsDescription.isNotEmpty
                  ? scheme.allBenefitsDescription
                  : scheme.benefits),
              const SizedBox(height: 12),
              const Text(
                'Required Documents:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...scheme.importantDocuments.map((doc) => Text('• $doc')),
              if (scheme.maxIncomeINR != null)
                _buildDetailRow('Income Limit',
                    '₹${scheme.maxIncomeINR!.toStringAsFixed(0)}'),
              if (scheme.minAge != null || scheme.maxAge != null)
                _buildDetailRow(
                  'Age Range',
                  '${scheme.minAge ?? 'N/A'} - ${scheme.maxAge ?? 'N/A'} years',
                ),
              if (scheme.officialApplyLink.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Application Link:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                InkWell(
                  onTap: () {
                    // You can use url_launcher here to open the link
                    debugPrint('Open link: ${scheme.officialApplyLink}');
                  },
                  child: Text(
                    scheme.officialApplyLink,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
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
}
