import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'core/services/user_role_service.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String? selectedFormId;
  Map<String, dynamic>? selectedFormData;
  Map<String, TextEditingController> fieldControllers = {};
  Map<String, dynamic> fieldValues =
      {}; // For non-text values like images, booleans
  String searchQuery = '';
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, bool> _userFormSubmissions = {}; // Track user form submissions
  String? _currentUserRole;
  String? _currentUserId;
  Map<String, dynamic>? _currentUserData;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Add debugging for production
    print(
        'FormScreen: Initializing in ${kDebugMode ? 'debug' : 'production'} mode');
    print('FormScreen: Auth state - ${FirebaseAuth.instance.currentUser?.uid}');

    _loadUserFormSubmissions();
    _loadCurrentUserData();
  }

  Future<void> _loadUserFormSubmissions() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final submissions = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      if (mounted) {
        setState(() {
          _userFormSubmissions.clear();
          for (var doc in submissions.docs) {
            final formId = doc.data()['formId'] as String?;
            if (formId != null) {
              _userFormSubmissions[formId] = true;
            }
          }
        });
      }
    } catch (e) {
      print('Error loading user form submissions: $e');
    }
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('FormScreen: No authenticated user found');
        if (mounted) {
          setState(() {
            _currentUserId = null;
            _currentUserRole = null;
            _currentUserData = null;
          });
        }
        return;
      }

      print('FormScreen: Loading data for user: ${currentUser.uid}');

      // Get user role and data with timeout and retry logic
      String? userRole;
      Map<String, dynamic>? userData;

      try {
        // Try to get user role with timeout
        userRole = await UserRoleService.getCurrentUserRole()
            .timeout(const Duration(seconds: 15));
        print('FormScreen: User role loaded: $userRole');
      } catch (e) {
        print('FormScreen: Error getting user role: $e');
        userRole = 'student'; // Safe fallback
      }

      try {
        // Try to get user data with timeout
        userData = await UserRoleService.getCurrentUserData()
            .timeout(const Duration(seconds: 15));
        print('FormScreen: User data loaded: ${userData?.keys}');
      } catch (e) {
        print('FormScreen: Error getting user data: $e');
        // Continue without user data
      }

      if (mounted) {
        setState(() {
          _currentUserId = currentUser.uid;
          _currentUserRole = userRole;
          _currentUserData = userData;
        });
      }

      print('FormScreen: Current user loaded successfully:');
      print('- User ID: $_currentUserId');
      print('- User Role: $_currentUserRole');
      print('- User Data keys: ${_currentUserData?.keys}');
    } catch (e) {
      print('FormScreen: Critical error loading current user data: $e');
      // Set safe fallback state
      if (mounted) {
        setState(() {
          _currentUserId = FirebaseAuth.instance.currentUser?.uid;
          _currentUserRole = 'student'; // Safe fallback
          _currentUserData = null;
        });
      }
    }
  }

  /// Helper method to check if roles match (handles both singular and plural forms)
  bool _roleMatches(String allowedRole, String? userRole) {
    if (userRole == null) return false;

    // Direct match
    if (allowedRole == userRole) return true;

    // Handle plural to singular conversion
    Map<String, String> pluralToSingular = {
      'admins': 'admin',
      'teachers': 'teacher',
      'students': 'student',
      'parents': 'parent',
    };

    String singularAllowedRole = pluralToSingular[allowedRole] ?? allowedRole;
    return singularAllowedRole == userRole;
  }

  /// Check if the current user can access a specific form
  bool _canAccessForm(Map<String, dynamic> formData) {
    // If user data is not loaded yet, don't show any forms
    if (_currentUserId == null || _currentUserRole == null) {
      return false;
    }

    final formTitle = formData['title'] ?? 'Untitled Form';

    // Get form permissions
    final permissions = formData['permissions'] as Map<String, dynamic>?;

    // If no permissions are set or permissions is null, it's a public form
    if (permissions == null || permissions.isEmpty) {
      print('Form "$formTitle": Public access (no permissions set)');
      return true;
    }

    final permissionType = permissions['type'] as String?;

    // Public forms are accessible to everyone
    if (permissionType == null || permissionType == 'public') {
      print('Form "$formTitle": Public access');
      return true;
    }

    // For restricted forms, check access
    if (permissionType == 'restricted') {
      final allowedRole = permissions['role'] as String?;
      final allowedUsers = permissions['users'] as List<dynamic>?;

      print('Form "$formTitle": Restricted access - checking permissions');
      print('- User role: $_currentUserRole, Required role: $allowedRole');
      print('- User ID: $_currentUserId, Allowed users: $allowedUsers');

      // Check if user's role matches the allowed role
      if (allowedRole != null && _roleMatches(allowedRole, _currentUserRole)) {
        print('Form "$formTitle": Access granted by role match');
        return true;
      }

      // Check if user is specifically allowed
      if (allowedUsers != null && allowedUsers.contains(_currentUserId)) {
        print('Form "$formTitle": Access granted by user ID match');
        return true;
      }

      // If neither role nor specific user access matches, deny access
      print('Form "$formTitle": Access denied - no role or user match');
      return false;
    }

    // Unknown permission type, deny access by default
    print(
        'Form "$formTitle": Access denied - unknown permission type: $permissionType');
    return false;
  }

  /// Build a small permission indicator widget for admin users
  Widget _buildPermissionIndicator(Map<String, dynamic> formData) {
    final permissions = formData['permissions'] as Map<String, dynamic>?;

    if (permissions == null ||
        permissions.isEmpty ||
        permissions['type'] == 'public') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xff10B981).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Public',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: const Color(0xff10B981),
          ),
        ),
      );
    }

    if (permissions['type'] == 'restricted') {
      final role = permissions['role'] as String?;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xffF59E0B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          role != null
              ? '${role[0].toUpperCase()}${role.substring(1)}'
              : 'Restricted',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: const Color(0xffF59E0B),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Row(
        children: [
          // Left sidebar with form list
          Container(
            width: 320,
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F000000),
                  offset: Offset(2, 0),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xff0386FF),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.description,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Active Forms',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search active forms...',
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xff6B7280),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xff6B7280),
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: GoogleFonts.inter(fontSize: 14),
                          onChanged: (value) {
                            if (mounted) {
                              setState(() {
                                searchQuery = value.toLowerCase();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Forms list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('form')
                        .snapshots(),
                    builder: (context, snapshot) {
                      // Enhanced error handling
                      if (snapshot.hasError) {
                        print('FormScreen: Firestore error: ${snapshot.error}');
                        return _buildErrorState(
                            'Error loading forms: ${snapshot.error}');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState();
                      }

                      if (!snapshot.hasData) {
                        print('FormScreen: No snapshot data received');
                        return _buildErrorState(
                            'No forms data received. Please check your connection.');
                      }

                      // Show loading state if user data is not loaded yet
                      if (_currentUserId == null || _currentUserRole == null) {
                        print(
                            'FormScreen: User data not loaded yet - userId: $_currentUserId, role: $_currentUserRole');
                        return _buildLoadingState();
                      }

                      print(
                          'FormScreen: Processing ${snapshot.data!.docs.length} forms from Firestore');

                      final forms = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        // First check if the form is active
                        final status = data['status'] ?? 'active';
                        if (status != 'active') {
                          return false;
                        }

                        // Then check if user can access this form
                        if (!_canAccessForm(data)) {
                          return false;
                        }

                        // Finally check if it matches the search query
                        return data['title']
                            .toString()
                            .toLowerCase()
                            .contains(searchQuery);
                      }).toList();

                      if (forms.isEmpty) {
                        return _buildEmptyState();
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('form_responses')
                            .where('userId',
                                isEqualTo:
                                    FirebaseAuth.instance.currentUser?.uid)
                            .snapshots(),
                        builder: (context, responsesSnapshot) {
                          // Check auth state before processing
                          if (FirebaseAuth.instance.currentUser == null) {
                            return const Center(
                              child: Text('Please sign in to view forms'),
                            );
                          }

                          if (responsesSnapshot.hasError) {
                            // Handle permission errors gracefully
                            if (responsesSnapshot.error
                                .toString()
                                .contains('permission-denied')) {
                              return const Center(
                                child: Text('Please sign in to access forms'),
                              );
                            }
                            return Center(
                              child: Text('Error: ${responsesSnapshot.error}'),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: forms.length,
                            itemBuilder: (context, index) {
                              final form =
                                  forms[index].data() as Map<String, dynamic>;
                              final isSelected =
                                  forms[index].id == selectedFormId;
                              final formId = forms[index].id;

                              // Check if user has submitted this form
                              final hasSubmitted =
                                  _userFormSubmissions[formId] ?? false;

                              return _buildFormCard(
                                  form, formId, isSelected, hasSubmitted);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: selectedFormData == null
                ? _buildWelcomeScreen()
                : _buildFormView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(
      Map<String, dynamic> form, String formId, bool isSelected,
      [bool hasSubmitted = false]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleFormSelection(formId, form),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xff0386FF).withOpacity(0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xff0386FF)
                    : const Color(0xffE5E7EB),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xff0386FF).withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
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
                        color: isSelected
                            ? const Color(0xff0386FF)
                            : hasSubmitted
                                ? const Color(0xff10B981)
                                : const Color(0xffF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasSubmitted ? Icons.check : Icons.description,
                        size: 16,
                        color: isSelected || hasSubmitted
                            ? Colors.white
                            : const Color(0xff6B7280),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            form['title'] ?? 'Untitled Form',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xff0386FF)
                                  : const Color(0xff111827),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasSubmitted) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Submitted',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff10B981),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasSubmitted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xff10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xff10B981).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          'Completed',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (form['description'] != null &&
                    form['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    form['description'],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: const Color(0xff6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getFormFieldCount(form),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                    const Spacer(),
                    // Show permission indicator for admin users
                    if (_currentUserRole == 'admin')
                      _buildPermissionIndicator(form),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 64,
                color: Color(0xff0386FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a Form to Get Started',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose a form from the sidebar to fill out and submit.\nYour responses will be saved automatically.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xff6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff0386FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.description,
                              color: Color(0xff0386FF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFormData!['title'] ?? 'Untitled Form',
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff111827),
                                  ),
                                ),
                                if (selectedFormData!['description'] != null &&
                                    selectedFormData!['description']
                                        .toString()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    selectedFormData!['description'],
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: const Color(0xff6B7280),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submission status banner (if already submitted)
                if (_userFormSubmissions[selectedFormId] ?? false) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xff10B981).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xff10B981),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Form Already Submitted',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff047857),
                                ),
                              ),
                              Text(
                                'You have already submitted this form. You can submit it again if needed.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xff059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Form fields card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Form Fields',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff111827),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Debug: Check if fields exist
                        if (_getVisibleFields().isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xffFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xffF59E0B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info,
                                        color: Color(0xffF59E0B)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No form fields are currently visible',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xffB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Possible causes:\n'
                                  '• This form may not have any fields configured\n'
                                  '• There may be a network connection issue\n'
                                  '• Your user permissions may have changed\n'
                                  '• The form data may be corrupted',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xffB45309),
                                  ),
                                ),
                                if (kDebugMode) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Debug info:\n'
                                    'Form ID: $selectedFormId\n'
                                    'User ID: $_currentUserId\n'
                                    'User Role: $_currentUserRole\n'
                                    'Form has data: ${selectedFormData != null}\n'
                                    'Form keys: ${selectedFormData?.keys.join(", ") ?? "null"}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xffB45309),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          ..._getVisibleFields().map((fieldEntry) {
                            try {
                              final fieldKey = fieldEntry.key;
                              final controller = fieldControllers[fieldKey];

                              // Safety check: if controller doesn't exist, create one
                              if (controller == null) {
                                print(
                                    'FormScreen: Missing controller for field $fieldKey, creating one');
                                fieldControllers[fieldKey] =
                                    TextEditingController();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _buildModernFormField(
                                  fieldEntry.value['label'] ?? 'Untitled Field',
                                  fieldEntry.value['placeholder'] ??
                                      'Enter value',
                                  fieldControllers[fieldKey]!,
                                  fieldEntry.value['required'] ?? false,
                                  fieldEntry.value['type'] ?? 'text',
                                  fieldKey,
                                  options:
                                      (fieldEntry.value['type'] == 'select' ||
                                              fieldEntry.value['type'] ==
                                                  'dropdown' ||
                                              fieldEntry.value['type'] ==
                                                  'multi_select')
                                          ? (fieldEntry.value['options']
                                                  is List)
                                              ? List<String>.from(
                                                  fieldEntry.value['options'])
                                              : (fieldEntry.value['options']
                                                      is String)
                                                  ? (fieldEntry.value['options']
                                                          as String)
                                                      .split(',')
                                                      .map((e) => e.trim())
                                                      .toList()
                                                  : []
                                          : null,
                                ),
                              );
                            } catch (e) {
                              // Fallback for any field rendering errors
                              print(
                                  'FormScreen: Error rendering field ${fieldEntry.key}: $e');
                              return Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: const Color(0xffFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xffEF4444)),
                                ),
                                child: Text(
                                  'Error rendering field: ${fieldEntry.key}. Error: $e',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xffDC2626),
                                  ),
                                ),
                              );
                            }
                          }),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff0386FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Submitting...',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.send, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Submit Form',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: _isSubmitting ? null : _resetForm,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff6B7280),
                          side: const BorderSide(color: Color(0xffE5E7EB)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Reset',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernFormField(
    String label,
    String hintText,
    TextEditingController controller,
    bool required,
    String type,
    String fieldKey, {
    List<String>? options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required indicator
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'This field is required',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xffEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      color: Color(0xffEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Field input based on type
        if (type == 'select' || type == 'dropdown') ...[
          _buildDropdownField(controller, hintText, options, required, label),
        ] else if (type == 'multi_select') ...[
          _buildMultiSelectField(
              controller, hintText, options, required, label, fieldKey),
        ] else if (type == 'multiline' ||
            type == 'long_text' ||
            type == 'description') ...[
          _buildTextAreaField(controller, hintText, required, label),
        ] else if (type == 'date') ...[
          _buildDateField(controller, hintText, required, label),
        ] else if (type == 'boolean' ||
            type == 'yes_no' ||
            type == 'radio' ||
            type == 'yesNo') ...[
          _buildBooleanField(controller, label, fieldKey),
        ] else if (type == 'number') ...[
          _buildNumberField(controller, hintText, required, label),
        ] else if (type == 'image_upload' || type == 'imageUpload') ...[
          _buildImageField(controller, hintText, required, label),
        ] else if (type == 'signature') ...[
          _buildSignatureField(controller, hintText, required, label),
        ] else ...[
          _buildTextInputField(controller, hintText, required, label, type),
        ],
      ],
    );
  }

  Widget _buildTextInputField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
    String type,
  ) {
    return TextFormField(
      controller: controller,
      maxLines:
          type == 'text' ? null : 1, // Allow text wrapping for text fields
      minLines: 1,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xff9CA3AF),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffEF4444), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        prefixIcon: _getFieldIcon(type),
        alignLabelWithHint: true,
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
      ),
      keyboardType: _getKeyboardType(type),
      textInputAction: TextInputAction.done,
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          return 'Please enter $label';
        }
        if (type == 'email' && value != null && value.isNotEmpty) {
          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
            return 'Please enter a valid email address';
          }
        }
        if (type == 'phone' && value != null && value.isNotEmpty) {
          if (!RegExp(r'^\+?[\d\s-]+$').hasMatch(value)) {
            return 'Please enter a valid phone number';
          }
        }
        return null;
      },
    );
  }

  Widget _buildDropdownField(
    TextEditingController controller,
    String hintText,
    List<String>? options,
    bool required,
    String label,
  ) {
    return DropdownButtonFormField<String>(
      value: controller.text.isEmpty ? null : controller.text,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xff9CA3AF),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        prefixIcon: const Icon(
          Icons.arrow_drop_down_circle_outlined,
          color: Color(0xff6B7280),
        ),
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
      ),
      dropdownColor: Colors.white,
      isExpanded: true, // Allow dropdown to expand to full width
      items: options
              ?.map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: GoogleFonts.inter(fontSize: 14),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ))
              .toList() ??
          [],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            controller.text = value;
          });
        }
      },
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a $label';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildMultiSelectField(
    TextEditingController controller,
    String hintText,
    List<String>? options,
    bool required,
    String label,
    String fieldKey,
  ) {
    // Parse selected values from controller text (stored as comma-separated string)
    List<String> selectedValues = controller.text.isEmpty
        ? []
        : controller.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hidden TextFormField for validation
        SizedBox(
          height: 0,
          child: TextFormField(
            controller: controller,
            validator: required
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select at least one option for $label';
                    }
                    return null;
                  }
                : null,
            style: const TextStyle(height: 0),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xffF9FAFB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.checklist,
                      color: Color(0xff6B7280),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedValues.isEmpty
                            ? hintText.isEmpty
                                ? 'Select multiple options...'
                                : hintText
                            : '${selectedValues.length} option(s) selected: ${selectedValues.join(', ')}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: selectedValues.isEmpty
                              ? const Color(0xff9CA3AF)
                              : const Color(0xff111827),
                          fontWeight: selectedValues.isEmpty
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (options != null && options.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      children: options.map((option) {
                        final isSelected = selectedValues.contains(option);
                        return CheckboxListTile(
                          title: Text(
                            option,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xff111827),
                            ),
                          ),
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                if (!selectedValues.contains(option)) {
                                  selectedValues.add(option);
                                }
                              } else {
                                selectedValues.remove(option);
                              }
                              // Update controller with comma-separated values
                              controller.text = selectedValues.join(', ');
                              // Store as list for conditional logic evaluation
                              fieldValues[fieldKey] = selectedValues.toList();
                            });
                          },
                          activeColor: const Color(0xff0386FF),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        );
                      }).toList(),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xff6B7280),
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No options available',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The form creator has not added any options for this field.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff9CA3AF),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (required && selectedValues.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xffEF4444),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Please select at least one option for $label',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xffEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextAreaField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      maxLines: null, // Allow unlimited lines
      minLines: 3, // Start with 3 lines minimum
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xff9CA3AF),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffEF4444), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        alignLabelWithHint: true,
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
        height: 1.5, // Better line spacing for readability
      ),
      textInputAction: TextInputAction.newline,
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDateField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xff9CA3AF),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        prefixIcon: const Icon(
          Icons.calendar_today,
          color: Color(0xff6B7280),
        ),
        suffixIcon: const Icon(
          Icons.arrow_drop_down,
          color: Color(0xff6B7280),
        ),
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xff0386FF),
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          controller.text = "${date.day}/${date.month}/${date.year}";
        }
      },
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a date';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildBooleanField(
      TextEditingController controller, String label, String fieldKey) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Row(
        children: [
          Radio<String>(
            value: 'Yes',
            groupValue: controller.text,
            onChanged: (value) {
              setState(() {
                controller.text = value ?? '';
                // Store as boolean for conditional logic evaluation
                fieldValues[fieldKey] = value == 'Yes';
              });
            },
            activeColor: const Color(0xff0386FF),
          ),
          Text(
            'Yes',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(width: 24),
          Radio<String>(
            value: 'No',
            groupValue: controller.text,
            onChanged: (value) {
              setState(() {
                controller.text = value ?? '';
                // Store as boolean for conditional logic evaluation
                fieldValues[fieldKey] = value == 'Yes';
              });
            },
            activeColor: const Color(0xff0386FF),
          ),
          Text(
            'No',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: const Color(0xff9CA3AF),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffEF4444), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        prefixIcon: const Icon(
          Icons.numbers_outlined,
          color: Color(0xff6B7280),
        ),
      ),
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xff111827),
      ),
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          return 'Please enter $label';
        }
        if (value != null && value.isNotEmpty) {
          if (double.tryParse(value) == null) {
            return 'Please enter a valid number';
          }
        }
        return null;
      },
    );
  }

  Widget _buildImageField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
  ) {
    final fieldKey = selectedFormData!['fields'].keys.firstWhere(
          (key) => selectedFormData!['fields'][key]['label'] == label,
          orElse: () => '',
        );

    final hasImage = fieldValues[fieldKey] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage) ...[
          // Image preview
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff0386FF), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.memory(
                    Uint8List.fromList(fieldValues[fieldKey]['bytes']),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                  // Delete button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          fieldValues.remove(fieldKey);
                          controller.text = '';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xffEF4444),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // File info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xff10B981).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xff10B981),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fieldValues[fieldKey]['fileName'],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                      Text(
                        _formatFileSize(fieldValues[fieldKey]['size']),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _pickImage(fieldKey, controller),
                  child: Text(
                    'Change',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff0386FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Upload button
          GestureDetector(
            onTap: () => _pickImage(fieldKey, controller),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xffF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xffE5E7EB),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      size: 32,
                      color: Color(0xff0386FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Click to upload image',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'JPG, PNG, GIF up to 10MB',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (required && !hasImage) ...[
          const SizedBox(height: 8),
          Text(
            'This field is required',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xffEF4444),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignatureField(
    TextEditingController controller,
    String hintText,
    bool required,
    String label,
  ) {
    final fieldKey = selectedFormData!['fields'].keys.firstWhere(
          (key) => selectedFormData!['fields'][key]['label'] == label,
          orElse: () => '',
        );

    final hasSignature = fieldValues[fieldKey] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSignature) ...[
          // Signature preview
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff0386FF), width: 2),
              color: Colors.white,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    Uint8List.fromList(fieldValues[fieldKey]['bytes']),
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
                // Delete button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        fieldValues.remove(fieldKey);
                        controller.text = '';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xffEF4444),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xff10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xff10B981).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xff10B981),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Signature captured',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _pickSignature(fieldKey, controller),
                child: Text(
                  'Change',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff0386FF),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // Signature upload button
          GestureDetector(
            onTap: () => _pickSignature(fieldKey, controller),
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xffF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xffE5E7EB),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff9b51e0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.draw_outlined,
                      size: 24,
                      color: Color(0xff9b51e0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click to add signature',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  Text(
                    'Upload image or use signature pad',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (required && !hasSignature) ...[
          const SizedBox(height: 8),
          Text(
            'This field is required',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xffEF4444),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading forms...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(0xffEF4444),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xff6B7280).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 48,
              color: Color(0xff6B7280),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No active forms found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              searchQuery.isNotEmpty
                  ? 'No active forms matching your search criteria that you have access to'
                  : 'There are currently no active forms available for your role (${UserRoleService.getRoleDisplayName(_currentUserRole)})',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  searchQuery = '';
                });
              },
              icon: const Icon(Icons.clear, size: 16),
              label: Text(
                'Clear search',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff0386FF),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Icon? _getFieldIcon(String type) {
    switch (type) {
      case 'email':
        return const Icon(Icons.email_outlined, color: Color(0xff6B7280));
      case 'phone':
        return const Icon(Icons.phone_outlined, color: Color(0xff6B7280));
      case 'number':
        return const Icon(Icons.numbers_outlined, color: Color(0xff6B7280));
      default:
        return const Icon(Icons.text_fields_outlined, color: Color(0xff6B7280));
    }
  }

  String _getFormFieldCount(Map<String, dynamic> form) {
    final fields = form['fields'] as Map<String, dynamic>? ?? {};
    final count = fields.length;
    return '$count field${count != 1 ? 's' : ''}';
  }

  void _handleFormSelection(String formId, Map<String, dynamic> formData) {
    if (mounted) {
      setState(() {
        selectedFormId = formId;
        selectedFormData = formData;

        // Clear existing controllers and values
        for (var controller in fieldControllers.values) {
          controller.dispose();
        }
        fieldControllers.clear();
        fieldValues.clear();

        // Create new controllers for form fields
        final fields = formData['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          print('FormScreen: Creating controllers for ${fields.length} fields');
          fields.forEach((fieldId, fieldData) {
            print(
                'FormScreen: Creating controller for field: $fieldId (type: ${fieldId.runtimeType})');
            fieldControllers[fieldId] = TextEditingController();
          });
          print(
              'FormScreen: Controllers created for keys: ${fieldControllers.keys.toList()}');
        } else {
          print(
              'FormScreen: No fields found in form data for controller creation');
        }
      });
    }

    _animationController.forward();
  }

  // Get fields that should be visible based on conditional logic
  List<MapEntry<String, dynamic>> _getVisibleFields() {
    if (selectedFormData == null) {
      print('FormScreen: No form data selected');
      return [];
    }

    print('FormScreen: Selected form data keys: ${selectedFormData!.keys}');

    final fields = selectedFormData!['fields'];
    if (fields == null) {
      print('FormScreen: No fields found in form data');
      print('FormScreen: Form data structure: $selectedFormData');
      return [];
    }

    if (fields is! Map<String, dynamic>) {
      print(
          'FormScreen: Fields is not a Map<String, dynamic>, type: ${fields.runtimeType}');
      print('FormScreen: Fields content: $fields');
      return [];
    }

    final fieldsMap = fields as Map<String, dynamic>;
    final visibleFields = <MapEntry<String, dynamic>>[];

    print('FormScreen: Found ${fieldsMap.length} total fields');
    print('FormScreen: Field keys: ${fieldsMap.keys.toList()}');

    // Sort fields by order first
    final sortedEntries = fieldsMap.entries.toList()
      ..sort((a, b) {
        final aOrder = (a.value as Map<String, dynamic>)['order'] as int? ?? 0;
        final bOrder = (b.value as Map<String, dynamic>)['order'] as int? ?? 0;
        print(
            'FormScreen: Field ${a.key} has order $aOrder, Field ${b.key} has order $bOrder');
        return aOrder.compareTo(bOrder);
      });

    print('FormScreen: Final field order after sorting:');
    for (var i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final order = (entry.value as Map<String, dynamic>)['order'] as int? ?? 0;
      final label =
          (entry.value as Map<String, dynamic>)['label'] ?? 'No label';
      print('  ${i + 1}. ${entry.key}: "$label" (order: $order)');
    }

    for (var fieldEntry in sortedEntries) {
      try {
        if (_shouldShowField(fieldEntry.key, fieldEntry.value)) {
          visibleFields.add(fieldEntry);
          print('FormScreen: Field ${fieldEntry.key} is visible');
        } else {
          print(
              'FormScreen: Field ${fieldEntry.key} is hidden by conditional logic');
        }
      } catch (e) {
        print('FormScreen: Error processing field ${fieldEntry.key}: $e');
      }
    }

    print('FormScreen: ${visibleFields.length} fields are visible');
    return visibleFields;
  }

  // Check if a field should be visible based on its conditional logic
  bool _shouldShowField(String fieldId, Map<String, dynamic> fieldData) {
    final conditionalLogic = fieldData['conditionalLogic'];

    // If no conditional logic, always show
    if (conditionalLogic == null) {
      // print('FormScreen: Field $fieldId has no conditional logic, showing');
      return true;
    }

    final dependsOnFieldId = conditionalLogic['dependsOnFieldId'];
    final condition = conditionalLogic['condition'];
    final expectedValue = conditionalLogic['expectedValue'];
    final expectedValues = conditionalLogic['expectedValues'];
    final isVisible = conditionalLogic['isVisible'] ?? true;

    // If no dependency set up yet, show the field
    if (dependsOnFieldId == null || condition == null) return true;

    // Get the current value of the dependent field
    final dependentValue = _getCurrentFieldValue(dependsOnFieldId);

    // Check the condition
    bool conditionMet = false;
    switch (condition) {
      case 'equals':
        conditionMet = dependentValue == expectedValue;
        break;
      case 'not_equals':
        conditionMet = dependentValue != expectedValue;
        break;
      case 'contains':
        if (expectedValues != null && expectedValues.isNotEmpty) {
          // Check if dependent value contains ANY of the expected values
          if (dependentValue is List) {
            conditionMet = expectedValues
                .any((expectedVal) => dependentValue.contains(expectedVal));
          }
        } else {
          // Fallback to single value check for backwards compatibility
          if (dependentValue is List) {
            conditionMet = dependentValue.contains(expectedValue);
          } else if (dependentValue is String) {
            conditionMet =
                dependentValue.contains(expectedValue?.toString() ?? '');
          }
        }
        break;
      case 'contains_all':
        if (expectedValues != null && expectedValues.isNotEmpty) {
          // Check if dependent value contains ALL of the expected values
          if (dependentValue is List) {
            conditionMet = expectedValues
                .every((expectedVal) => dependentValue.contains(expectedVal));
          }
        }
        break;
      case 'contains_exactly':
        if (expectedValues != null && expectedValues.isNotEmpty) {
          // Check if dependent value contains EXACTLY the expected values (same set)
          if (dependentValue is List) {
            final dependentSet = Set.from(dependentValue);
            final expectedSet = Set.from(expectedValues);
            conditionMet = dependentSet.length == expectedSet.length &&
                dependentSet.containsAll(expectedSet);
          }
        }
        break;
      case 'is_empty':
        conditionMet = dependentValue == null ||
            dependentValue == '' ||
            (dependentValue is List && dependentValue.isEmpty);
        break;
      case 'is_not_empty':
        conditionMet = dependentValue != null &&
            dependentValue != '' &&
            !(dependentValue is List && dependentValue.isEmpty);
        break;
      default:
        conditionMet = false;
    }

    // Return whether field should be visible based on condition and isVisible setting
    return isVisible ? conditionMet : !conditionMet;
  }

  // Get the current value of a field (from controller or fieldValues)
  dynamic _getCurrentFieldValue(String fieldId) {
    // Check if it's stored in fieldValues (for multi-select, boolean, etc.)
    if (fieldValues.containsKey(fieldId)) {
      return fieldValues[fieldId];
    }

    // Check text controller
    if (fieldControllers.containsKey(fieldId)) {
      final text = fieldControllers[fieldId]!.text.trim();
      return text.isEmpty ? null : text;
    }

    return null;
  }

  Future<String?> _uploadImageToStorage(
      Uint8List imageBytes, String fileName) async {
    const maxRetries = 3;

    // Test basic Firebase Storage connectivity
    try {
      print('=== Testing Firebase Storage Connectivity ===');
      final storage = FirebaseStorage.instance;
      print('Storage bucket: ${storage.bucket}');

      // Test with a tiny file first
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]); // 5 bytes
      final testRef = storage
          .ref()
          .child('test_${DateTime.now().millisecondsSinceEpoch}.txt');

      print('Attempting small test upload...');
      final uploadTask = testRef.putData(testData);

      // Monitor the upload task state
      uploadTask.snapshotEvents.listen((snapshot) {
        print('Test upload state: ${snapshot.state}');
        print(
            'Test upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
      });

      final testUpload = await uploadTask.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Test upload task final state: ${uploadTask.snapshot.state}');
          print(
              'Test upload bytes transferred: ${uploadTask.snapshot.bytesTransferred}');
          throw Exception('Test upload timeout');
        },
      );

      print('Test upload successful! Cleaning up...');
      await testRef.delete().catchError((e) => print('Cleanup error: $e'));
      print('=== Storage connectivity test PASSED ===');
    } catch (e) {
      print('=== Storage connectivity test FAILED ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('XMLHttpRequest')) {
        print(
            'CORS/Network issue detected - this is common in web development');
      } else if (e.toString().contains('permission')) {
        print('Permission issue detected');
      } else if (e.toString().contains('network')) {
        print('Network connectivity issue detected');
      }
      print('This indicates a fundamental connectivity issue');
      print('Possible solutions:');
      print('1. Check Firebase Storage is enabled in Firebase Console');
      print('2. Check network/firewall settings');
      print('3. Try from a different network');
      print('4. Check CORS configuration');
      return null;
    }

    // Verify authentication status
    final currentUser = FirebaseAuth.instance.currentUser;
    print('=== Authentication Status ===');
    print('User logged in: ${currentUser != null}');
    print('User ID: ${currentUser?.uid}');
    print('User email: ${currentUser?.email}');
    print(
        'Auth token: ${currentUser?.refreshToken != null ? "Available" : "Missing"}');
    print('=============================');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
            'Starting image upload for: $fileName (attempt $attempt/$maxRetries)');

        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          print('Error: User not logged in');
          throw Exception('User not logged in');
        }

        print('User ID: ${currentUser.uid}');
        print(
            'Original image size: ${imageBytes.length} bytes (${(imageBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB)');

        // Compress image if it's larger than 500KB
        Uint8List finalImageBytes = imageBytes;
        if (imageBytes.length > 500 * 1024) {
          print('Compressing image...');
          finalImageBytes = await _compressImage(imageBytes, fileName);
          print(
              'Compressed image size: ${finalImageBytes.length} bytes (${(finalImageBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB)');
        }

        // Create a unique filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('form_images')
            .child(currentUser.uid)
            .child('${timestamp}_$fileName');

        print('Storage path: ${storageRef.fullPath}');

        // Set metadata to improve upload reliability
        final metadata = SettableMetadata(
          contentType: _getContentType(fileName),
          customMetadata: {
            'uploadedBy': currentUser.uid,
            'originalFileName': fileName,
            'attempt': attempt.toString(),
          },
        );

        // Upload the file with reduced timeout and metadata
        final uploadTask = storageRef.putData(finalImageBytes, metadata);

        // Dynamic timeout based on final file size (minimum 60 seconds, +30 seconds per MB)
        final timeoutSeconds =
            60 + (finalImageBytes.length / (1024 * 1024) * 30).ceil();
        print(
            'Setting timeout to $timeoutSeconds seconds for ${(finalImageBytes.length / (1024 * 1024)).toStringAsFixed(1)}MB file');

        final snapshot = await uploadTask.timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () {
            print(
                'Upload timeout after $timeoutSeconds seconds (attempt $attempt)');
            throw Exception('Upload timeout on attempt $attempt');
          },
        );

        print('Upload completed, getting download URL...');

        // Get the download URL
        final downloadURL = await snapshot.ref.getDownloadURL();
        print('Download URL obtained: $downloadURL');

        return downloadURL;
      } catch (e) {
        print('Error uploading image (attempt $attempt): $e');

        if (attempt == maxRetries) {
          print('All upload attempts failed');
          return null;
        }

        // Wait before retrying
        await Future.delayed(Duration(seconds: attempt * 2));
        print('Retrying upload...');
      }
    }

    return null;
  }

  String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<Uint8List> _compressImage(
      Uint8List imageBytes, String fileName) async {
    try {
      // For web, we'll use a simple quality reduction approach
      // This is a basic implementation - in production you might want to use image package

      // If the image is very large, we'll reduce quality significantly
      if (imageBytes.length > 2 * 1024 * 1024) {
        // > 2MB
        print(
            'Image is very large (${(imageBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB), applying maximum compression');
        // For very large images, we'll return a significantly reduced version
        // This is a simplified approach - you might want to integrate image compression library
        return _reduceImageSize(imageBytes, 0.3); // 30% quality
      } else if (imageBytes.length > 1024 * 1024) {
        // > 1MB
        print(
            'Image is large (${(imageBytes.length / (1024 * 1024)).toStringAsFixed(2)}MB), applying medium compression');
        return _reduceImageSize(imageBytes, 0.6); // 60% quality
      } else {
        print('Image size is acceptable, applying light compression');
        return _reduceImageSize(imageBytes, 0.8); // 80% quality
      }
    } catch (e) {
      print('Error compressing image: $e');
      print('Returning original image');
      return imageBytes;
    }
  }

  Uint8List _reduceImageSize(Uint8List imageBytes, double quality) {
    // This is a simplified size reduction
    // In a real implementation, you would use image processing libraries
    // For now, we'll just return the original bytes with a warning
    print(
        'Note: Image compression not fully implemented. Consider using image processing library.');
    print('Returning original image bytes for now.');
    return imageBytes;
  }

  Future<void> _pickImage(
      String fieldKey, TextEditingController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null && file.size <= 10 * 1024 * 1024) {
          // 10MB limit
          setState(() {
            fieldValues[fieldKey] = {
              'fileName': file.name,
              'bytes': file.bytes!,
              'size': file.size,
              'isUploaded': false, // Track upload status
            };
            controller.text = file.name;
          });
        } else {
          _showSnackBar('File size must be less than 10MB', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _pickSignature(
      String fieldKey, TextEditingController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null && file.size <= 5 * 1024 * 1024) {
          // 5MB limit for signatures
          setState(() {
            fieldValues[fieldKey] = {
              'fileName': file.name,
              'bytes': file.bytes!,
              'size': file.size,
              'isUploaded': false, // Track upload status
            };
            controller.text = file.name;
          });
        } else {
          _showSnackBar('Signature file size must be less than 5MB',
              isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Error picking signature: $e', isError: true);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  TextInputType _getKeyboardType(String type) {
    switch (type) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'number':
        return TextInputType.number;
      case 'multiline':
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (var controller in fieldControllers.values) {
      controller.clear();
    }
    setState(() {
      fieldValues.clear();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    // Check if user has already submitted this form
    final hasAlreadySubmitted = _userFormSubmissions[selectedFormId] ?? false;
    if (hasAlreadySubmitted) {
      final shouldResubmit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Form Already Submitted',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          content: Text(
            'You have already submitted this form. Do you want to submit it again? This will create a new response.',
            style: GoogleFonts.inter(
              color: const Color(0xff6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xff6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Submit Again',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldResubmit != true) {
        print('User cancelled resubmission');
        return;
      }
    }

    print('Starting form submission...');
    if (mounted) {
      setState(() => _isSubmitting = true);
    }

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _showSnackBar('You must be logged in to submit forms', isError: true);
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
        return;
      }

      final responses = <String, dynamic>{};

      print('Processing form fields...');
      print('Field controllers: ${fieldControllers.keys.toList()}');
      print('Field values: ${fieldValues.keys.toList()}');

      // Process each field and upload images to Firebase Storage
      for (var entry in fieldControllers.entries) {
        final fieldId = entry.key;
        final controller = entry.value;

        print('Processing field: $fieldId');

        if (fieldValues.containsKey(fieldId)) {
          final fieldValue = fieldValues[fieldId];

          // Handle non-map values (like booleans from conditional logic)
          if (fieldValue is! Map<String, dynamic>) {
            responses[fieldId] = fieldValue;
            continue;
          }

          final fieldData = fieldValue as Map<String, dynamic>;
          print('Field $fieldId has data: ${fieldData.keys.toList()}');

          // Check if this is an image/signature field with bytes
          if (fieldData.containsKey('bytes') && fieldData['bytes'] != null) {
            print('Uploading image for field: $fieldId');
            _showSnackBar(
                'Uploading ${fieldData['fileName']} (${(fieldData['size'] / (1024 * 1024)).toStringAsFixed(1)}MB)...',
                isError: false);

            // Upload image to Firebase Storage
            final downloadURL = await _uploadImageToStorage(
              Uint8List.fromList(fieldData['bytes']),
              fieldData['fileName'],
            );

            if (downloadURL != null) {
              print('Image uploaded successfully for field: $fieldId');
              responses[fieldId] = {
                'fileName': fieldData['fileName'],
                'downloadURL': downloadURL,
                'size': fieldData['size'],
                'type': 'image',
                'uploadedAt': FieldValue.serverTimestamp(),
              };
            } else {
              print('Failed to upload image for field: $fieldId');

              // Show dialog asking user what to do
              if (mounted) {
                final shouldContinue = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Image Upload Failed',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff111827),
                      ),
                    ),
                    content: Text(
                      'Failed to upload "${fieldData['fileName']}". Would you like to submit the form without this image or try again?',
                      style: GoogleFonts.inter(
                        color: const Color(0xff6B7280),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'Try Again',
                          style: GoogleFonts.inter(
                            color: const Color(0xff6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0386FF),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          'Submit Without Image',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (shouldContinue == true) {
                  // Submit without the image
                  print(
                      'User chose to submit without image for field: $fieldId');
                  responses[fieldId] = {
                    'fileName': fieldData['fileName'],
                    'uploadFailed': true,
                    'size': fieldData['size'],
                    'type': 'image',
                    'failureReason': 'Upload timeout/retry limit exceeded',
                  };
                } else {
                  // User wants to try again, cancel submission
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                  }
                  return;
                }
              } else {
                if (mounted) {
                  setState(() => _isSubmitting = false);
                }
                return;
              }
            }
          } else {
            // For other field values
            print('Field $fieldId: storing non-image data');
            responses[fieldId] = fieldData;
          }
        } else {
          // For text fields, store the text value
          // Check if this is a multi-select field and convert to array
          final fieldData = selectedFormData!['fields'] as Map<String, dynamic>;
          final fieldInfo = fieldData[fieldId];

          if (fieldInfo != null &&
              fieldInfo['type'] == 'multi_select' &&
              controller.text.isNotEmpty) {
            // Convert comma-separated values to array for multi-select fields
            final selectedValues = controller.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            print(
                'Field $fieldId: storing multi-select values: $selectedValues');
            responses[fieldId] = selectedValues;
          } else {
            print('Field $fieldId: storing text value: ${controller.text}');
            responses[fieldId] = controller.text;
          }
        }
      }

      print('All fields processed, submitting to Firestore...');
      print('Form data to submit:');
      print('- FormId: $selectedFormId');
      print('- UserId: ${currentUser.uid}');
      print('- UserEmail: ${currentUser.email}');
      print('- Responses: ${responses.keys.toList()}');
      print('- Response data: $responses');

      // Get user data for names
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userFirstName = userData.data()?['first_name'] as String? ?? '';
      final userLastName = userData.data()?['last_name'] as String? ?? '';

      final docRef =
          await FirebaseFirestore.instance.collection('form_responses').add({
        'formId': selectedFormId,
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'userFirstName': userFirstName,
        'userLastName': userLastName,
        'responses': responses,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'lastUpdated': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('Firestore submission timeout after 30 seconds');
          throw Exception('Firestore submission timeout');
        },
      );

      print(
          'Form submitted to Firestore successfully! Document ID: ${docRef.id}');
      _showSnackBar('Form submitted successfully!', isError: false);

      // Update the submissions tracker
      if (mounted) {
        setState(() {
          _userFormSubmissions[selectedFormId!] = true;
        });
      }

      print('Clearing form...');
      // Clear form
      _resetForm();
      print('Form cleared successfully!');
    } catch (e) {
      print('Error in form submission: $e');
      print('Stack trace: ${StackTrace.current}');
      _showSnackBar('Error submitting form: ${e.toString()}', isError: true);
    } finally {
      print('Resetting submission state...');
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      print('Submission state reset complete');
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    // Check if widget is still mounted before showing snackbar
    if (!mounted) {
      print('Widget not mounted, skipping snackbar: $message');
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor:
              isError ? const Color(0xffEF4444) : const Color(0xff10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      print('Error showing snackbar: $e');
      print('Message was: $message');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
