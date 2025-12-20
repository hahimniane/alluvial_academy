import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/employee_model.dart';

class EditUserScreen extends StatefulWidget {
  final Employee employee;

  const EditUserScreen({super.key, required this.employee});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _countryCodeController;
  late TextEditingController _titleController;
  late TextEditingController _kioskCodeController;

  String? _selectedUserType;
  bool _isLoading = false;
  bool _hasChanges = false;

  final List<Map<String, dynamic>> _userTypes = [
    {
      'id': 'student',
      'name': 'Student',
      'icon': Icons.school,
      'color': const Color(0xff10B981)
    },
    {
      'id': 'teacher',
      'name': 'Teacher',
      'icon': Icons.person_outline,
      'color': const Color(0xff3B82F6)
    },
    {
      'id': 'parent',
      'name': 'Parent',
      'icon': Icons.family_restroom,
      'color': const Color(0xffF59E0B)
    },
    {
      'id': 'admin',
      'name': 'Admin',
      'icon': Icons.admin_panel_settings,
      'color': const Color(0xffEF4444)
    },
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Initialize controllers with existing data
    _firstNameController =
        TextEditingController(text: widget.employee.firstName);
    _lastNameController = TextEditingController(text: widget.employee.lastName);
    _emailController = TextEditingController(text: widget.employee.email);
    _phoneController = TextEditingController(text: widget.employee.mobilePhone);
    _countryCodeController =
        TextEditingController(text: widget.employee.countryCode);
    _titleController = TextEditingController(text: widget.employee.title);
    _kioskCodeController =
        TextEditingController(text: widget.employee.kioskCode);
    _selectedUserType = widget.employee.userType;

    // Add listeners to track changes
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    // Email and kiosk code are read-only, so no change listeners needed
    _phoneController.addListener(_onFieldChanged);
    _countryCodeController.addListener(_onFieldChanged);
    _titleController.addListener(_onFieldChanged);

    _animationController.forward();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _countryCodeController.dispose();
    _titleController.dispose();
    _kioskCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare updated user data
      final updatedData = {
        'first_name': _firstNameController.text.trim(),
        // Use consistent Firestore key with underscore
        'last_name': _lastNameController.text.trim(),
        // Email and kiosk_code are read-only and cannot be changed
        'phone_number': _phoneController.text.trim(),
        'country_code': _countryCodeController.text.trim(),
        'title': _titleController.text.trim(),
        'user_type': _selectedUserType,
        'updated_at': Timestamp.now(),
      };

      // Find and update user document by email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('e-mail', isEqualTo: widget.employee.email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('User not found');
      }

      await userQuery.docs.first.reference.update(updatedData);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'User updated successfully!',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: const Color(0xff10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // Return to previous screen with success result
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error updating user: $e',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xffEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildUserInfoCard(),
                        const SizedBox(height: 24),
                        _buildPersonalInfoSection(),
                        const SizedBox(height: 24),
                        _buildContactInfoSection(),
                        const SizedBox(height: 24),
                        _buildRoleSection(),
                        const SizedBox(height: 24),
                        _buildAdditionalInfoSection(),
                        const SizedBox(height: 32),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Color(0xff6B7280),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.edit,
                color: Color(0xff3B82F6),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Edit User',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                      if (_hasChanges) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xffF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Unsaved',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xffF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    'Update user information and settings',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(12),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xff3B82F6)),
                  ),
                ),
              )
            else
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(
                      'Cancel',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff6B7280),
                      side: const BorderSide(color: Color(0xffE2E8F0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _hasChanges ? _saveUser : null,
                    icon: const Icon(Icons.save, size: 16),
                    label: Text(
                      'Save Changes',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      elevation: 0,
                      disabledBackgroundColor: const Color(0xffF3F4F6),
                      disabledForegroundColor: const Color(0xff9CA3AF),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    final userTypeData = _userTypes.firstWhere(
      (type) => type['id'] == widget.employee.userType,
      orElse: () => _userTypes[0],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            userTypeData['color'].withOpacity(0.1),
            userTypeData['color'].withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: userTypeData['color'].withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: userTypeData['color'],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              userTypeData['icon'],
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.employee.firstName} ${widget.employee.lastName}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: userTypeData['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        userTypeData['name'],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: userTypeData['color'],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      widget.employee.isActive
                          ? Icons.check_circle
                          : Icons.pause_circle,
                      size: 16,
                      color: widget.employee.isActive
                          ? const Color(0xff10B981)
                          : const Color(0xffF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.employee.isActive ? 'Active' : 'Inactive',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: widget.employee.isActive
                            ? const Color(0xff10B981)
                            : const Color(0xffF59E0B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.employee.email,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      title: 'Personal Information',
      icon: Icons.person,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFormField(
                'First Name',
                _firstNameController,
                'Enter first name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFormField(
                'Last Name',
                _lastNameController,
                'Enter last name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildFormField(
          'Job Title',
          _titleController,
          'Enter job title or role',
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSection(
      title: 'Contact Information',
      icon: Icons.contact_mail,
      children: [
        _buildReadOnlyField(
          'Email Address',
          _emailController.text,
          'This email cannot be changed as it\'s used for login',
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: _buildFormField(
                'Country Code',
                _countryCodeController,
                '+1',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFormField(
                'Phone Number',
                _phoneController,
                'Enter phone number',
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleSection() {
    return _buildSection(
      title: 'User Role',
      icon: Icons.security,
      children: [
        Text(
          'Select the appropriate role for this user',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff6B7280),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _userTypes.map((userType) {
            final isSelected = _selectedUserType == userType['id'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedUserType = userType['id'];
                  _hasChanges = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? userType['color'].withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? userType['color']
                        : const Color(0xffE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      userType['icon'],
                      color: isSelected
                          ? userType['color']
                          : const Color(0xff6B7280),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userType['name'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? userType['color']
                            : const Color(0xff6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedUserType == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select a user role',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xffEF4444),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection() {
    return _buildSection(
      title: 'Additional Information',
      icon: Icons.settings,
      children: [
        _buildReadOnlyField(
          'Kiosk Access Code',
          _kioskCodeController.text.isEmpty ? 'Not assigned' : _kioskCodeController.text,
          'Kiosk codes cannot be modified once assigned',
          icon: Icons.lock_outline,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xff3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller,
    String hintText, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xff9CA3AF),
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xff3B82F6), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffEF4444), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xffFAFAFA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff111827),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(
    String label,
    String value,
    String helpText, {
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff374151),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(
                icon,
                size: 16,
                color: const Color(0xff6B7280),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xffF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff111827),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                helpText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 18),
              label: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff6B7280),
                side: const BorderSide(color: Color(0xffE2E8F0)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (_isLoading || !_hasChanges) ? null : _saveUser,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(
                _isLoading ? 'Saving...' : 'Save Changes',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                disabledBackgroundColor: const Color(0xffF3F4F6),
                disabledForegroundColor: const Color(0xff9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
