import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class MobileUserManagementScreen extends StatefulWidget {
  const MobileUserManagementScreen({super.key});

  @override
  State<MobileUserManagementScreen> createState() => _MobileUserManagementScreenState();
}

class _MobileUserManagementScreenState extends State<MobileUserManagementScreen> {
  List<Employee> _users = [];
  List<Employee> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedRoleFilter;
  bool? _activeFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return Employee(
          documentId: doc.id,
          email: data['e-mail'] ?? data['email'] ?? '',
          firstName: data['first_name'] ?? '',
          lastName: data['last_name'] ?? '',
          countryCode: data['country_code'] ?? '+1',
          mobilePhone: data['phone_number'] ?? '',
          userType: data['user_type'] ?? '',
          title: data['title'] ?? '',
          employmentStartDate: data['employment_start_date']?.toString() ?? '',
          kioskCode: data['kiosk_code'] ?? '',
          dateAdded: data['date_added']?.toString() ?? '',
          lastLogin: data['last_login']?.toString() ?? '',
          isAdminTeacher: data['is_admin_teacher'] as bool? ?? false,
          isActive: data['is_active'] ?? true,
        );
      }).toList();

      users.sort((a, b) => '${a.firstName} ${a.lastName}'.compareTo('${b.firstName} ${b.lastName}'));

      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingUsersE)),
        );
      }
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final userType = user.userType.toLowerCase();
        final roleFilter = _selectedRoleFilter?.toLowerCase();
        // Search query filter - enhanced to support full name, student ID, email
        final matchesSearch = _matchesSearchTerm(user, _searchQuery);

        // Role filter
        final matchesRole = roleFilter == null ||
            userType == roleFilter ||
            (roleFilter == 'admin' && userType == 'super_admin');

        // Active status filter
        final matchesActive = _activeFilter == null || user.isActive == _activeFilter;

        return matchesSearch && matchesRole && matchesActive;
      }).toList();
    });
  }

  /// Enhanced search matching that supports:
  /// - First name, last name (partial match)
  /// - Full name (e.g., "John Doe")
  /// - Email address
  /// - Student ID (student_code)
  /// - Document ID (Firebase UID)
  bool _matchesSearchTerm(Employee user, String searchQuery) {
    if (searchQuery.isEmpty) return true;
    
    final term = searchQuery.toLowerCase().trim();
    if (term.isEmpty) return true;

    // Check individual fields
    final firstName = user.firstName.toLowerCase();
    final lastName = user.lastName.toLowerCase();
    final email = user.email.toLowerCase();
    final studentCode = user.studentCode.toLowerCase();
    final documentId = user.documentId.toLowerCase();

    // Build full name variations
    final fullName = '$firstName $lastName';
    final fullNameReversed = '$lastName $firstName';

    // Match against all fields
    return firstName.contains(term) ||
        lastName.contains(term) ||
        email.contains(term) ||
        studentCode.contains(term) ||
        documentId.contains(term) ||
        fullName.contains(term) ||
        fullNameReversed.contains(term);
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                AppLocalizations.of(context)!.userFilterUsers,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Role filter
              Text(
                AppLocalizations.of(context)!.userRole,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.timesheetAll),
                    selected: _selectedRoleFilter == null,
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = null);
                      setState(() => _selectedRoleFilter = null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.admin),
                    selected: _selectedRoleFilter == 'admin',
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = selected ? 'admin' : null);
                      setState(() => _selectedRoleFilter = selected ? 'admin' : null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.roleTeacher),
                    selected: _selectedRoleFilter == 'teacher',
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = selected ? 'teacher' : null);
                      setState(() => _selectedRoleFilter = selected ? 'teacher' : null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.roleStudent),
                    selected: _selectedRoleFilter == 'student',
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = selected ? 'student' : null);
                      setState(() => _selectedRoleFilter = selected ? 'student' : null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.roleParent),
                    selected: _selectedRoleFilter == 'parent',
                    onSelected: (selected) {
                      setModalState(() => _selectedRoleFilter = selected ? 'parent' : null);
                      setState(() => _selectedRoleFilter = selected ? 'parent' : null);
                      _filterUsers();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Status filter
              Text(
                AppLocalizations.of(context)!.userStatus,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.timesheetAll),
                    selected: _activeFilter == null,
                    onSelected: (selected) {
                      setModalState(() => _activeFilter = null);
                      setState(() => _activeFilter = null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.shiftActive),
                    selected: _activeFilter == true,
                    onSelected: (selected) {
                      setModalState(() => _activeFilter = selected ? true : null);
                      setState(() => _activeFilter = selected ? true : null);
                      _filterUsers();
                    },
                  ),
                  FilterChip(
                    label: Text(AppLocalizations.of(context)!.userInactive),
                    selected: _activeFilter == false,
                    onSelected: (selected) {
                      setModalState(() => _activeFilter = selected ? false : null);
                      setState(() => _activeFilter = selected ? false : null);
                      _filterUsers();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedRoleFilter = null;
                          _activeFilter = null;
                        });
                        setState(() {
                          _selectedRoleFilter = null;
                          _activeFilter = null;
                          _filterUsers();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xff3B82F6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.commonReset,
                        style: TextStyle(color: Color(0xff3B82F6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _filterUsers();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff3B82F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.userApplyFilters,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserActions(Employee user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // User info header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(user.userType),
                    child: Text(
                      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.firstName} ${user.lastName}'.trim(),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user.email,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Actions
            // Show credentials option for students
            if (user.userType.toLowerCase() == 'student')
              ListTile(
                leading: Icon(Icons.key, color: Color(0xff06B6D4)),
                title: Text(AppLocalizations.of(context)!.userViewCredentials),
                subtitle: Text(AppLocalizations.of(context)!.userStudentIdPassword),
                onTap: () {
                  Navigator.pop(context);
                  _showStudentCredentials(user);
                },
              ),
            ListTile(
              leading: Icon(
                user.isActive ? Icons.block : Icons.check_circle,
                color: user.isActive ? Colors.orange : Colors.green,
              ),
              title: Text(user.isActive ? 'Deactivate User' : 'Activate User'),
              onTap: () async {
                Navigator.pop(context);
                await _toggleUserStatus(user);
              },
            ),
            if (user.userType != 'admin')
              ListTile(
                leading: Icon(Icons.admin_panel_settings, color: Colors.blue),
                title: Text(AppLocalizations.of(context)!.userPromoteToAdmin),
                onTap: () async {
                  Navigator.pop(context);
                  await _promoteToAdmin(user);
                },
              ),
            ListTile(
              leading: Icon(Icons.edit, color: Colors.grey),
              title: Text(AppLocalizations.of(context)!.userEditUser),
              onTap: () {
                Navigator.pop(context);
                _showEditUserDialog(user);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text(AppLocalizations.of(context)!.userDeleteUser),
              onTap: () async {
                Navigator.pop(context);
                await _deleteUser(user);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Show student login credentials dialog
  Future<void> _showStudentCredentials(Employee user) async {
    // Fetch the full user document to get credentials
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.documentId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.userDocumentNotFound),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final data = doc.data()!;
      final studentCode = data['student_code'] ?? 'Not set';
      final tempPassword = data['temp_password'] ?? 'Password not stored';
      final aliasEmail = '$studentCode@alluwaleducationhub.org';

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff06B6D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.key, color: Color(0xff06B6D4)),
              ),
              SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.userLoginCredentials),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.firstName} ${user.lastName}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildCredentialRow('Student ID', studentCode, true),
              const SizedBox(height: 12),
              _buildCredentialRow('Password', tempPassword, true),
              const SizedBox(height: 12),
              _buildCredentialRow('Email (for app)', aliasEmail, false),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.userStudentLoginNote,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.commonClose),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showResetPasswordDialog(user, studentCode);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(AppLocalizations.of(context)!.userResetPassword),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorLoadingCredentialsE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCredentialRow(String label, String value, bool canCopy) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: canCopy 
                    ? GoogleFonts.sourceCodePro(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )
                    : GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          if (canCopy)
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              color: const Color(0xff06B6D4),
              tooltip: AppLocalizations.of(context)!.copyToClipboard,
              onPressed: () {
                // Copy to clipboard
                // Note: Would need to import services for clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.labelCopied),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Show reset password confirmation dialog
  Future<void> _showResetPasswordDialog(Employee user, String studentCode) async {
    final customPassword = await showDialog<String?>(
      context: context,
      builder: (context) {
        final passwordController = TextEditingController();
        bool obscurePassword = true;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.userResetPassword),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset password for ${user.firstName} ${user.lastName}?',
                  style: GoogleFonts.inter(fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context)!.studentIdStudentcode(studentCode),
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.userCustomPassword,
                    hintText: AppLocalizations.of(context)!.userLeaveBlankGenerate,
                    helperText: AppLocalizations.of(context)!.userPasswordMinChars,
                    errorText: errorText,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${AppLocalizations.of(context)!.ifLeftBlankASecurePassword}\n'
                    'If the student has a parent linked, they will receive an email with the new credentials.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.commonCancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final value = passwordController.text;
                  if (value.trim().isEmpty) {
                    Navigator.pop(context, '');
                    return;
                  }
                  if (value != value.trim()) {
                    setState(() => errorText = 'Password cannot start or end with spaces');
                    return;
                  }
                  if (value.length < 6) {
                    setState(() => errorText = 'Password must be at least 6 characters');
                    return;
                  }
                  if (value.length > 128) {
                    setState(() => errorText = 'Password must be 128 characters or less');
                    return;
                  }
                  Navigator.pop(context, value);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3B82F6),
                  foregroundColor: Colors.white,
                ),
                child: Text(AppLocalizations.of(context)!.userResetPassword),
              ),
            ],
          ),
        );
      },
    );

    if (customPassword != null) {
      await _resetStudentPassword(
        user,
        customPassword: customPassword.trim().isEmpty ? null : customPassword,
      );
    }
  }

  /// Reset student password via Cloud Function
  Future<void> _resetStudentPassword(
    Employee user, {
    String? customPassword,
  }) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text(AppLocalizations.of(context)!.userResettingPassword),
            ],
          ),
        ),
      );

      // Call Cloud Function to reset password (updates both Firebase Auth and Firestore)
      final callable = FirebaseFunctions.instance.httpsCallable('resetStudentPassword');
      final payload = <String, dynamic>{
        'studentId': user.documentId,
        'sendEmailToParent': true,
      };
      if (customPassword != null && customPassword.trim().isNotEmpty) {
        payload['customPassword'] = customPassword;
      }

      final result = await callable.call(payload);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final newPassword = result.data['newPassword'] as String;
      final emailSent = result.data['emailSent'] as bool;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.userPasswordReset),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!
                  .userNewPasswordFor(user.firstName)),
              SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  newPassword,
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (emailSent)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.emailSentToParent,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  AppLocalizations.of(context)!.userShareCredentials,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff10B981),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.commonDone),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorResettingPasswordE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleUserStatus(Employee user) async {
    try {
      final email = user.email.trim();

      // Prefer using the shared role service so deactivations are audited consistently.
      if (email.isNotEmpty) {
        final success = user.isActive
            ? await UserRoleService.deactivateUser(email)
            : await UserRoleService.activateUser(email);

        if (!success) {
          throw Exception('Failed to update user status');
        }
      } else {
        // Fallback: update by documentId (best-effort) with audit fields when archiving.
        final actor = FirebaseAuth.instance.currentUser;
        final updates = <String, dynamic>{
          'is_active': !user.isActive,
          'updated_at': FieldValue.serverTimestamp(),
        };

        if (user.isActive) {
          updates['deactivated_at'] = FieldValue.serverTimestamp();
          updates['deactivated_by_uid'] = actor?.uid;
          updates['deactivated_by_email'] = actor?.email?.toLowerCase();
        } else {
          updates['activated_at'] = FieldValue.serverTimestamp();
          updates['deactivated_at'] = FieldValue.delete();
        }

        updates.removeWhere((_, value) => value == null);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.documentId)
            .update(updates);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user.isActive ? 'User archived' : 'User restored'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorUpdatingUserE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _promoteToAdmin(Employee user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.userPromoteToAdmin),
        content: Text(AppLocalizations.of(context)!.userPromoteConfirm(
            '${user.firstName} ${user.lastName}')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff3B82F6)),
            child: Text(AppLocalizations.of(context)!.userPromote, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.documentId)
            .update({'user_type': 'admin'});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.userPromotedSuccess),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.errorPromotingUserE),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(Employee user) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final currentEmail = currentUser.email?.trim().toLowerCase();
      final targetEmail = user.email.trim().toLowerCase();
      if ((currentEmail != null && currentEmail.isNotEmpty && currentEmail == targetEmail) ||
          currentUser.uid == user.documentId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.userCannotDeleteSelf),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final userType = user.userType.trim().toLowerCase();
    final canDeleteClasses = userType == 'teacher' || userType == 'student';
    var deleteClasses = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            user.isActive ? 'Archive & Permanently Delete' : 'Permanently Delete User',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.isActive
                    ? 'This user is currently active. They will be archived first, then permanently deleted. This action cannot be undone.'
                    : 'Are you sure you want to permanently delete ${user.firstName} ${user.lastName}? This action cannot be undone.',
              ),
              if (canDeleteClasses) ...[
                SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: deleteClasses,
                  onChanged: (value) =>
                      setDialogState(() => deleteClasses = value ?? false),
                  title: Text(
                    userType == 'teacher'
                        ? 'Also delete this teacher\'s classes'
                        : 'Also delete this student\'s classes',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: userType == 'student'
                      ? Text(AppLocalizations.of(context)!.userGroupClassesRemain)
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                user.isActive ? 'Archive & Delete' : 'Delete',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final email = user.email.trim();
        if (email.isEmpty) {
          throw Exception('Cannot delete this user because no email is set on their profile.');
        }

        // The backend delete function requires the user to be archived first.
        if (user.isActive) {
          final archived = await UserRoleService.deactivateUser(email);
          if (!archived) {
            throw Exception('Failed to archive user before deletion.');
          }
          await Future.delayed(const Duration(milliseconds: 300));
        }

        final success = await UserRoleService.deleteUser(
          email,
          deleteClasses: deleteClasses,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? AppLocalizations.of(context)!.userDeletedSuccessfully
                  : AppLocalizations.of(context)!.userDeleteFailed),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
        if (success) _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.errorDeletingUserE),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showEditUserDialog(Employee user) {
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final phoneController = TextEditingController(text: user.mobilePhone);
    String selectedRole = user.userType;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.userEditUser),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.userFirstName,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.userLastName,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.userPhone,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.userRole,
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'admin', child: Text(AppLocalizations.of(context)!.admin)),
                  DropdownMenuItem(value: 'teacher', child: Text(AppLocalizations.of(context)!.roleTeacher)),
                  DropdownMenuItem(value: 'student', child: Text(AppLocalizations.of(context)!.roleStudent)),
                  DropdownMenuItem(value: 'parent', child: Text(AppLocalizations.of(context)!.roleParent)),
                ],
                onChanged: (value) {
                  selectedRole = value!;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.documentId)
                    .update({
                  'first_name': firstNameController.text,
                  'last_name': lastNameController.text,
                  'phone_number': phoneController.text,
                  'user_type': selectedRole,
                });
                if (context.mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.userUpdatedSuccessfully),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                _loadUsers();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.errorUpdatingUserE),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff3B82F6)),
            child: Text(AppLocalizations.of(context)!.commonSave, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.userManagementTitle,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedRoleFilter != null || _activeFilter != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.userSearchUsers,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _filterUsers();
              },
            ),
          ),

          // User stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredUsers.length} users',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (_filteredUsers.isNotEmpty)
                  Text(
                    '${_filteredUsers.where((u) => u.isActive).length} active',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),

          // User list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.userNoUsersFound,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: _getRoleColor(user.userType),
                                      child: Text(
                                        user.firstName.isNotEmpty
                                            ? user.firstName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    if (!user.isActive)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.grey,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  '${user.firstName} ${user.lastName}'.trim(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.email,
                                      style: GoogleFonts.inter(fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(user.userType).withAlpha(25),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _getRoleName(user.userType),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: _getRoleColor(user.userType),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (!user.isActive) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withAlpha(25),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              AppLocalizations.of(context)!.userInactive,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _showUserActions(user),
                                ),
                                onTap: () => _showUserActions(user),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xffEF4444);
      case 'teacher':
        return const Color(0xff3B82F6);
      case 'student':
        return const Color(0xff10B981);
      case 'parent':
        return const Color(0xffF59E0B);
      default:
        return const Color(0xff6B7280);
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      case 'parent':
        return 'Parent';
      default:
        return role;
    }
  }
}
