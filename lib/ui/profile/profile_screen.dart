import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_strings.dart';
import '../../services/firestore_service.dart';

/// Profile Screen with editable fields
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  // Controllers for all fields
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _incomeController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();

  String? _selectedGender;
  String? _selectedOccupation;
  String? _selectedCaste;
  String? _selectedState;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _occupations = [
    'Student',
    'Farmer',
    'Teacher',
    'Engineer',
    'Government Employee',
    'Business',
    'Labourer',
    'Unemployed',
    'Other'
  ];
  final List<String> _castes = ['SC', 'ST', 'OBC', 'General'];
  final List<String> _states = [
    'Maharashtra',
    'Gujarat',
    'Karnataka',
    'Delhi',
    'Rajasthan',
    'Tamil Nadu',
    'West Bengal',
    'Uttar Pradesh',
    'Andhra Pradesh',
    'Telangana',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final profileData = await _firestoreService.getUserProfile(user.uid);
      if (profileData != null) {
        _fullNameController.text = profileData['fullName'] ?? '';
        _phoneController.text = profileData['phoneNumber'] ?? '';
        _ageController.text = profileData['age']?.toString() ?? '';
        _incomeController.text = profileData['annualIncome']?.toString() ?? '';
        _districtController.text = profileData['district'] ?? '';
        _selectedGender = profileData['gender'];
        _selectedOccupation = profileData['occupation'];
        _selectedCaste = profileData['caste'] ?? profileData['category'];
        _selectedState = profileData['state'];
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save profile')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final profileData = {
      'fullName': _fullNameController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'age': int.tryParse(_ageController.text),
      'gender': _selectedGender,
      'occupation': _selectedOccupation,
      'caste': _selectedCaste,
      'annualIncome': int.tryParse(_incomeController.text),
      'state': _selectedState,
      'district': _districtController.text.trim(),
    };

    final success =
        await _firestoreService.saveUserProfile(user.uid, profileData);

    setState(() {
      _isLoading = false;
      _isEditing = false;
    });

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save profile. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _incomeController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.profile),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Picture
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        (_fullNameController.text.isNotEmpty
                                ? _fullNameController.text[0]
                                : (user?.displayName?.isNotEmpty == true
                                    ? user!.displayName![0]
                                    : 'U'))
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Email (Read-only)
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Full Name
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      enabled: _isEditing,
                      validator: (value) {
                        if (_isEditing &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (_isEditing &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter your phone number';
                        }
                        if (_isEditing && value != null && value.length != 10) {
                          return 'Please enter a valid 10-digit phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age
                    _buildTextField(
                      controller: _ageController,
                      label: 'Age',
                      icon: Icons.cake,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_isEditing &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter your age';
                        }
                        if (_isEditing && value != null) {
                          final age = int.tryParse(value);
                          if (age == null || age < 1 || age > 120) {
                            return 'Please enter a valid age (1-120)';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    _buildDropdown(
                      label: 'Gender',
                      icon: Icons.person_outline,
                      value: _selectedGender,
                      items: _genders,
                      enabled: _isEditing,
                      onChanged: (value) =>
                          setState(() => _selectedGender = value),
                      validator: () {
                        if (_isEditing && _selectedGender == null) {
                          return 'Please select your gender';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Occupation
                    _buildDropdown(
                      label: 'Occupation',
                      icon: Icons.work_outline,
                      value: _selectedOccupation,
                      items: _occupations,
                      enabled: _isEditing,
                      onChanged: (value) =>
                          setState(() => _selectedOccupation = value),
                      validator: () {
                        if (_isEditing && _selectedOccupation == null) {
                          return 'Please select your occupation';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Caste / Category
                    _buildDropdown(
                      label: 'Caste / Category',
                      icon: Icons.category_outlined,
                      value: _selectedCaste,
                      items: _castes,
                      enabled: _isEditing,
                      onChanged: (value) =>
                          setState(() => _selectedCaste = value),
                      validator: () {
                        if (_isEditing && _selectedCaste == null) {
                          return 'Please select your caste/category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Annual Income
                    _buildTextField(
                      controller: _incomeController,
                      label: 'Annual Family Income (₹)',
                      icon: Icons.account_balance_wallet,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (_isEditing &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter your annual income';
                        }
                        if (_isEditing && value != null) {
                          final income = int.tryParse(value);
                          if (income == null || income < 0) {
                            return 'Please enter a valid income amount';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // State
                    _buildDropdown(
                      label: 'State',
                      icon: Icons.location_on_outlined,
                      value: _selectedState,
                      items: _states,
                      enabled: _isEditing,
                      onChanged: (value) =>
                          setState(() => _selectedState = value),
                      validator: () {
                        if (_isEditing && _selectedState == null) {
                          return 'Please select your state';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // District
                    _buildTextField(
                      controller: _districtController,
                      label: 'District',
                      icon: Icons.location_city,
                      enabled: _isEditing,
                      validator: (value) {
                        if (_isEditing &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter your district';
                        }
                        return null;
                      },
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
    required bool enabled,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required bool enabled,
    required Function(String?) onChanged,
    String? Function()? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator != null ? (_) => validator() : null,
    );
  }
}
