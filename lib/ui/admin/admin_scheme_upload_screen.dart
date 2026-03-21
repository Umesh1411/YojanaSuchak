import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';

/// Admin-only scheme upload screen with password protection
class AdminSchemeUploadScreen extends StatefulWidget {
  const AdminSchemeUploadScreen({super.key});

  @override
  State<AdminSchemeUploadScreen> createState() =>
      _AdminSchemeUploadScreenState();
}

class _AdminSchemeUploadScreenState extends State<AdminSchemeUploadScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAuthenticated = false;
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _schemeIdController = TextEditingController();
  final TextEditingController _schemeNameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _minAgeController = TextEditingController();
  final TextEditingController _maxAgeController = TextEditingController();
  final TextEditingController _maxIncomeController = TextEditingController();
  final TextEditingController _eligibilityDescController =
      TextEditingController();
  final TextEditingController _benefitsController = TextEditingController();
  final TextEditingController _applicationLinkController =
      TextEditingController();
  final TextEditingController _launchDateController = TextEditingController();
  final TextEditingController _ministryController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();

  String? _selectedTargetOccupation;
  String? _selectedCategoryEligibility;
  String? _selectedState;

  final List<String> _occupations = [
    'Any',
    'Student',
    'Farmer',
    'Teacher',
    'Engineer',
    'Government Employee',
    'Business',
    'Labourer',
    'Unemployed',
    'Women',
    'Senior Citizen'
  ];

  final List<String> _categoryOptions = ['All', 'SC', 'ST', 'OBC', 'General'];
  final List<String> _states = [
    'India',
    'Maharashtra',
    'Gujarat',
    'Karnataka',
    'Delhi',
    'Rajasthan',
    'Tamil Nadu',
    'West Bengal',
    'Uttar Pradesh',
    'Other'
  ];

  final List<TextEditingController> _documentsControllers = [
    TextEditingController()
  ];

  @override
  void dispose() {
    _passwordController.dispose();
    _schemeIdController.dispose();
    _schemeNameController.dispose();
    _categoryController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _maxIncomeController.dispose();
    _eligibilityDescController.dispose();
    _benefitsController.dispose();
    _applicationLinkController.dispose();
    _launchDateController.dispose();
    _ministryController.dispose();
    _departmentController.dispose();
    for (var controller in _documentsControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final provided = _passwordController.text.trim();

    // If admin password not configured, keep admin access disabled
    if (!AppConfig.isAdminConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin access disabled'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (provided == AppConfig.adminPassword) {
      setState(() {
        _isAuthenticated = true;
        _passwordController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Admin authenticated'),
        backgroundColor: Colors.green,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Invalid admin password'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _submitScheme() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if user is authenticated with Firebase
    final authService = AuthService();
    final isAuthenticated = authService.isAuthenticated;
    final currentUser = authService.currentUser;

    // Debug info
    debugPrint(
        '🔐 Auth Check - isFirebaseConfigured: ${authService.isFirebaseConfigured}');
    debugPrint('🔐 Auth Check - isAuthenticated: $isAuthenticated');
    debugPrint('🔐 Auth Check - currentUser: ${currentUser?.email ?? "null"}');

    if (!authService.isFirebaseConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Firebase is not configured. Please check your Firebase setup.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!isAuthenticated || currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in with Firebase to upload schemes.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // Use manual scheme ID if provided, otherwise auto-generate
      String schemeId = _schemeIdController.text.trim();
      if (schemeId.isEmpty) {
        schemeId = _schemeNameController.text
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '_')
            .substring(
                0,
                _schemeNameController.text.length > 50
                    ? 50
                    : _schemeNameController.text.length);
      }

      // Extract documents list
      final documents = _documentsControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // Build scheme data
      final schemeData = {
        'schemeId': schemeId,
        'schemeName': _schemeNameController.text.trim(),
        'category': _categoryController.text.trim(),
        'state': _selectedState ?? 'India',
        'schemeLevel': _selectedState == 'India' ? 'Central' : 'State',
        'department': _departmentController.text.trim(),
        'ministry': _ministryController.text.trim(),
        'occupationEligible': _selectedTargetOccupation ?? 'Any',
        'genderEligible': 'All', // Default
        'categoryEligible': _selectedCategoryEligibility ?? 'All',
        'casteEligible': _selectedCategoryEligibility ?? 'All',
        'minAge': _minAgeController.text.isNotEmpty
            ? int.tryParse(_minAgeController.text)
            : null,
        'maxAge': _maxAgeController.text.isNotEmpty
            ? int.tryParse(_maxAgeController.text)
            : null,
        'maxIncomeINR': _maxIncomeController.text.isNotEmpty
            ? int.tryParse(_maxIncomeController.text)
            : null,
        'incomeRuleType':
            _maxIncomeController.text.isNotEmpty ? 'EXACT' : 'NO_LIMIT',
        'maritalStatus': 'Any', // Default
        'otherEligibilityCriteria': _eligibilityDescController.text.trim(),
        'beneficiaryType': _selectedTargetOccupation ?? 'Any',
        'benefitType': 'Benefit',
        'benefitAmount': '',
        'benefitFrequency': '',
        'allBenefitsDescription': _benefitsController.text.trim(),
        'applicationMode': 'Online',
        'applicationDeadline': 'Open',
        'importantDocuments': documents,
        'officialApplyLink': _applicationLinkController.text.trim(),
        'officialSource': '',
        'remarks': _launchDateController.text.trim().isNotEmpty
            ? 'Launch Date: ${_launchDateController.text.trim()}'
            : '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await firestore.collection('schemes').doc(schemeId).set(schemeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheme uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _formKey.currentState!.reset();
        _schemeIdController.clear();
        _schemeNameController.clear();
        _categoryController.clear();
        _minAgeController.clear();
        _maxAgeController.clear();
        _maxIncomeController.clear();
        _eligibilityDescController.clear();
        _benefitsController.clear();
        _applicationLinkController.clear();
        _launchDateController.clear();
        _ministryController.clear();
        _departmentController.clear();
        _selectedTargetOccupation = null;
        _selectedCategoryEligibility = null;
        _selectedState = null;
        _documentsControllers.clear();
        _documentsControllers.add(TextEditingController());
      }
    } catch (e) {
      debugPrint('❌ Error uploading scheme: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');

      String errorMessage = 'Error uploading scheme. Please try again.';

      if (e.toString().contains('permission-denied') ||
          e.toString().contains('permission')) {
        errorMessage =
            'Permission denied. Please ensure you are logged in with Firebase.';
        debugPrint(
            '❌ Firestore permission error - User might not be authenticated');
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('unavailable')) {
        errorMessage =
            'Firestore is temporarily unavailable. Please try again later.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addDocumentField() {
    setState(() {
      _documentsControllers.add(TextEditingController());
    });
  }

  void _removeDocumentField(int index) {
    if (_documentsControllers.length > 1) {
      setState(() {
        _documentsControllers[index].dispose();
        _documentsControllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final isFirebaseAuthenticated =
        authService.isFirebaseConfigured && authService.currentUser != null;

    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Access'),
          backgroundColor: Colors.red.shade700,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Admin Access Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please enter the admin password to access the scheme upload page.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Admin Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    onSubmitted: (_) => _verifyPassword(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _verifyPassword,
                    icon: const Icon(Icons.login),
                    label: const Text('Verify Password'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Scheme (Admin)'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              setState(() => _isAuthenticated = false);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Firebase Authentication Warning
                    if (!isFirebaseAuthenticated)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Firebase Authentication Required',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Please log in with Firebase to upload schemes. Firestore requires authentication.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ), // Scheme ID (Optional - auto-generated if not provided)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scheme ID (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter a custom Scheme ID like CHD_01, PMS_02, etc. If left empty, it will be auto-generated from the scheme name.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _schemeIdController,
                            label: 'Scheme ID (e.g., CHD_01, PMS_02)',
                            icon: Icons.fingerprint,
                            hint: 'Leave empty for auto-generation',
                          ),
                        ],
                      ),
                    ), // Scheme Name
                    _buildTextField(
                      controller: _schemeNameController,
                      label: 'Scheme Name *',
                      icon: Icons.title,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter scheme name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category
                    _buildTextField(
                      controller: _categoryController,
                      label:
                          'Category (e.g., Women, Farmer, Student, Health) *',
                      icon: Icons.category,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Target Occupation
                    _buildDropdown(
                      label: 'Target Occupation(s) *',
                      value: _selectedTargetOccupation,
                      items: _occupations,
                      onChanged: (value) =>
                          setState(() => _selectedTargetOccupation = value),
                      validator: () {
                        if (_selectedTargetOccupation == null) {
                          return 'Please select target occupation';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age Range
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _minAgeController,
                            label: 'Min Age',
                            icon: Icons.cake,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _maxAgeController,
                            label: 'Max Age',
                            icon: Icons.cake,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Max Income
                    _buildTextField(
                      controller: _maxIncomeController,
                      label: 'Max Annual Income (₹)',
                      icon: Icons.account_balance_wallet,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Category Eligibility
                    _buildDropdown(
                      label: 'Category Eligibility (SC/ST/OBC/General)',
                      value: _selectedCategoryEligibility,
                      items: _categoryOptions,
                      onChanged: (value) =>
                          setState(() => _selectedCategoryEligibility = value),
                    ),
                    const SizedBox(height: 16),

                    // State
                    _buildDropdown(
                      label: 'State (Optional)',
                      value: _selectedState,
                      items: _states,
                      onChanged: (value) =>
                          setState(() => _selectedState = value),
                    ),
                    const SizedBox(height: 16),

                    // Eligibility Description
                    _buildTextField(
                      controller: _eligibilityDescController,
                      label: 'Eligibility Description',
                      icon: Icons.description,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Benefits
                    _buildTextField(
                      controller: _benefitsController,
                      label: 'Benefits *',
                      icon: Icons.card_giftcard,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter benefits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Required Documents
                    const Text(
                      'Required Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      _documentsControllers.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _documentsControllers[index],
                                decoration: InputDecoration(
                                  labelText: 'Document ${index + 1}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            if (_documentsControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red),
                                onPressed: () => _removeDocumentField(index),
                              ),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addDocumentField,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Document'),
                    ),
                    const SizedBox(height: 16),

                    // Application Link
                    _buildTextField(
                      controller: _applicationLinkController,
                      label: 'Application Link *',
                      icon: Icons.link,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter application link';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Launch Date
                    _buildTextField(
                      controller: _launchDateController,
                      label: 'Launch Date (Optional)',
                      icon: Icons.calendar_today,
                    ),
                    const SizedBox(height: 16),

                    // Ministry / Department
                    _buildTextField(
                      controller: _ministryController,
                      label: 'Ministry / Department *',
                      icon: Icons.business,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter ministry/department';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _departmentController,
                      label: 'Department (if different)',
                      icon: Icons.business_center,
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _submitScheme,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Upload Scheme',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    String? Function()? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator != null ? (_) => validator() : null,
    );
  }
}
