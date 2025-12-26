// ignore_for_file: library_private_types_in_public_api
import 'features/dashboard/screens/admin_dashboard_screen.dart';
import 'features/chat/screens/chat_page.dart';
import 'form_screen.dart';
import 'features/forms/screens/form_responses_screen.dart';
import 'job_scheduling.dart';
import 'features/time_clock/screens/time_clock_screen.dart';
import 'features/time_clock/screens/admin_timesheet_review.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'core/services/user_role_service.dart';
import 'core/constants/app_constants.dart';
import 'shared/widgets/role_switcher.dart';
import 'features/user_management/screens/user_management_screen.dart';
import 'admin/form_builder.dart';
import 'test_role_system.dart';
import 'firestore_debug_screen.dart';
import 'features/tasks/screens/quick_tasks_screen.dart';
import 'features/shift_management/screens/shift_management_screen.dart';
import 'features/shift_management/screens/teacher_shift_screen.dart';
import 'features/website_management/screens/website_management_screen.dart';
import 'features/zoom/screens/zoom_screen.dart';
import 'features/zoom/screens/admin_zoom_screen.dart';
import 'features/notifications/screens/send_notification_screen.dart';
import 'features/enrollment_management/screens/enrollment_management_screen.dart';
import 'features/teacher_applications/screens/teacher_application_management_screen.dart';
import 'features/settings/screens/admin_settings_screen.dart';
import 'screens/landing_page.dart';
import 'role_based_dashboard.dart';

import 'features/dashboard/widgets/custom_sidebar.dart';

import 'core/constants/dashboard_constants.dart';

/// Main Dashboard widget that serves as the app's primary navigation interface
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // State variables
  bool _isHovered = false;
  bool _isSideMenuCollapsed = false;
  int _selectedIndex = 0;
  String? _userRole;
  Map<String, dynamic>? _userData;
  int _refreshTrigger = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSidebarState();
  }

  Future<void> _loadUserData() async {
    try {
      final role = await UserRoleService.getCurrentUserRole();
      final data = await UserRoleService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userRole = role;
          _userData = data;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadSidebarState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCollapsed = prefs.getBool('sidebar_collapsed') ?? false;
      if (mounted) {
        setState(() {
          _isSideMenuCollapsed = isCollapsed;
        });
      }
    } catch (e) {
      print('Error loading sidebar state: $e');
    }
  }

  Future<void> _saveSidebarState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sidebar_collapsed', _isSideMenuCollapsed);
    } catch (e) {
      print('Error saving sidebar state: $e');
    }
  }

  // Get screens available in the dashboard (built dynamically to include refresh trigger)
  List<Widget> get _screens => [
        AdminDashboard(refreshTrigger: _refreshTrigger),
        const UserManagementScreen(),
        const WebsiteManagementScreen(),
        const ShiftManagementScreen(),
        const TeacherShiftScreen(),
        const ChatPage(),
        const TimeClockScreen(),
        const AdminTimesheetReview(),
        const FormScreen(),
        FormResponsesScreen(key: ValueKey(_refreshTrigger)),
        const FormBuilder(),
        const QuickTasksScreen(),
        // Zoom screen - show admin version for admin users
        _userRole == 'admin' || _userRole == 'super_admin'
            ? const AdminZoomScreen()
            : const ZoomScreen(),
        const TestRoleSystemScreen(),
        const FirestoreDebugScreen(),
        const SendNotificationScreen(),
        const EnrollmentManagementScreen(),
        const TeacherApplicationManagementScreen(),
        const AdminSettingsScreen(),
      ];

  /// Updates the selected index when a navigation item is tapped
  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
        // Trigger refresh for FormResponsesScreen (index 9) when navigated to
        if (index == 9) {
          _refreshTrigger++;
        }
      });
    }
  }

  /// Shows sign out confirmation dialog
  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.logout,
                color: Color(0xff0386FF),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out? You\'ll need to log in again to access your account.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xff6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff6B7280),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _handleSignOut(); // Perform sign out
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Handles user sign out
  Future<void> _handleSignOut() async {
    try {
      // Clear user role cache
      UserRoleService.clearCache();

      // Navigate immediately to prevent further stream access
      if (mounted) {
        // Navigate to root and remove all previous routes BEFORE signing out
        // This closes all dashboard screens and their streams
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingPage()),
          (route) => false,
        );
      }

      // Wait for navigation to complete and streams to close
      await Future.delayed(const Duration(milliseconds: 100));

      // Now sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();

      print('Sign out completed successfully');
    } catch (e) {
      print('Sign out error: $e');
      // Even if there's an error, ensure we're on the landing page
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingPage()),
          (route) => false,
        );
      }
    }
  }

  /// Shows change password dialog
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isChangingPassword = false;
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lock,
                      color: Color(0xff0386FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Change Password',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please enter your current password and choose a new one.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Current Password
                      Text(
                        'Current Password',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrentPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your current password';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter current password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrentPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xff6B7280),
                            ),
                            onPressed: () {
                              setState(() {
                                obscureCurrentPassword =
                                    !obscureCurrentPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xff0386FF), width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xffF9FAFB),
                        ),
                        style: GoogleFonts.inter(fontSize: 16),
                      ),
                      const SizedBox(height: 16),

                      // New Password
                      Text(
                        'New Password',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a new password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter new password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xff6B7280),
                            ),
                            onPressed: () {
                              setState(() {
                                obscureNewPassword = !obscureNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xff0386FF), width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xffF9FAFB),
                        ),
                        style: GoogleFonts.inter(fontSize: 16),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      Text(
                        'Confirm New Password',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your new password';
                          }
                          if (value != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Confirm new password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xff6B7280),
                            ),
                            onPressed: () {
                              setState(() {
                                obscureConfirmPassword =
                                    !obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xff0386FF), width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xffF9FAFB),
                        ),
                        style: GoogleFonts.inter(fontSize: 16),
                      ),
                      const SizedBox(height: 16),

                      // Password requirements
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff0386FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xff0386FF).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password Requirements:',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff0386FF),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• At least 6 characters long\n• Use a strong, unique password\n• Consider using a mix of letters, numbers, and symbols',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xff374151),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isChangingPassword
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          currentPasswordController.dispose();
                          newPasswordController.dispose();
                          confirmPasswordController.dispose();
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff6B7280),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isChangingPassword
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() {
                              isChangingPassword = true;
                            });

                            final success = await _changePassword(
                              currentPasswordController.text,
                              newPasswordController.text,
                            );

                            if (success) {
                              if (mounted) {
                                Navigator.of(context).pop();
                                currentPasswordController.dispose();
                                newPasswordController.dispose();
                                confirmPasswordController.dispose();

                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Password changed successfully!',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xff10B981),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            } else {
                              setState(() {
                                isChangingPassword = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isChangingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Change Password',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Changes the user's password
  Future<bool> _changePassword(
      String currentPassword, String newPassword) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _showErrorSnackBar('Authentication error. Please log in again.');
        return false;
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Current password is incorrect.';
          break;
        case 'weak-password':
          errorMessage = 'The new password is too weak.';
          break;
        case 'requires-recent-login':
          errorMessage =
              'Please log out and log in again before changing your password.';
          break;
        default:
          errorMessage = 'Failed to change password: ${e.message}';
      }
      _showErrorSnackBar(errorMessage);
      return false;
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred. Please try again.');
      return false;
    }
  }

  /// Shows delete account confirmation dialog
  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isDeleting = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete Account',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Confirm Password',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xff6B7280),
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Colors.red, width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xffF9FAFB),
                        ),
                        style: GoogleFonts.inter(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          passwordController.dispose();
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff6B7280),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() {
                              isDeleting = true;
                            });

                            final success = await _deleteAccount(
                              passwordController.text,
                            );

                            if (!success && mounted) {
                              setState(() {
                                isDeleting = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Delete Account',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Deletes the user account
  Future<bool> _deleteAccount(String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _showErrorSnackBar('Authentication error. Please log in again.');
        return false;
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Delete user
      await user.delete();

      // Navigate to landing page
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingPage()),
          (route) => false,
        );
      }

      return true;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log out and log in again.';
          break;
        default:
          errorMessage = 'Failed to delete account: ${e.message}';
      }
      _showErrorSnackBar(errorMessage);
      return false;
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred.');
      return false;
    }
  }

  /// Shows error snackbar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// Builds the main body of the dashboard
  Widget _buildBody() {
    return Row(
      children: [
        _buildSideMenu(),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),
      ],
    );
  }

  /// Builds the app bar with logo, search, and user profile
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildLogoAndSearch(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  /// Builds the logo section of the app bar
  Widget _buildLogoAndSearch() {
    return _buildAnimatedLogo();
  }

  /// Builds the animated logo with hover effect
  Widget _buildAnimatedLogo() {
    return GestureDetector(
      onTap: () => print('Logo clicked'),
      child: MouseRegion(
        onEnter: (_) {
          if (mounted) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (mounted) setState(() => _isHovered = false);
        },
        child: AnimatedContainer(
          duration: DashboardConstants.hoverAnimationDuration,
          child: Image.asset(
            'assets/logo_navigation_bar.PNG',
            height: _isHovered
                ? DashboardConstants.logoHoverHeight
                : DashboardConstants.logoNormalHeight,
          ),
        ),
      ),
    );
  }

  /// Builds the actions section of the app bar (notifications and profile)
  Row _buildActions() {
    return Row(
      children: [
        // Role switcher for dual-role users
        RoleSwitcher(
          onRoleChanged: (newRole) {
            // Reload user data when role changes to update UI
            _loadUserData();

            // Reset to dashboard view to see role-appropriate content
            setState(() {
              _selectedIndex = 0;
              _refreshTrigger++; // Trigger refresh of child widgets
            });
          },
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        const SizedBox(width: 16),
        _buildNotificationIcon(),
        const SizedBox(width: 20),
        _buildUserProfile(),
      ],
    );
  }

  /// Builds the user profile section
  Widget _buildUserProfile() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'logout') {
          _showSignOutConfirmation();
        } else if (value == 'change_password') {
          _showChangePasswordDialog();
        } else if (value == 'delete_account') {
          _showDeleteAccountDialog();
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            value: 'change_password',
            child: Row(
              children: [
                const Icon(Icons.lock, color: Color(0xff0386FF)),
                const SizedBox(width: 8),
                Text(
                  'Change Password',
                  style: openSansHebrewTextStyle.copyWith(
                    color: const Color(0xff374151),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete_account',
            child: Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Delete Account',
                  style: openSansHebrewTextStyle.copyWith(
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                const Icon(Icons.logout, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Sign Out',
                  style: openSansHebrewTextStyle.copyWith(color: Colors.red),
                ),
              ],
            ),
          ),
        ];
      },
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getUserName(),
                style: openSansHebrewTextStyle.copyWith(
                  color: Colors.blueAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_userRole != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _userRole!.toUpperCase(),
                    style: openSansHebrewTextStyle.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: Colors.teal,
            child: Text(
              _getInitials(),
              style: openSansHebrewTextStyle.copyWith(color: Colors.white),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
        ],
      ),
    );
  }

  /// Get user initials for avatar
  String _getInitials() {
    if (_userData != null) {
      final firstName = _userData!['first_name'] ?? '';
      final lastName = _userData!['last_name'] ?? '';
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '${firstName[0]}${lastName[0]}'.toUpperCase();
      }
    }
    return 'U'; // Default fallback
  }

  /// Get user's full name
  String _getUserName() {
    if (_userData != null) {
      final firstName = _userData!['first_name'] ?? '';
      final lastName = _userData!['last_name'] ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '$firstName $lastName'.trim();
      }
    }
    return 'User';
  }

  /// Get role-specific color
  Color _getRoleColor() {
    switch (_userRole?.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'teacher':
        return Colors.blue;
      case 'student':
        return Colors.green;
      case 'parent':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Builds the notification icon with badge
  Stack _buildNotificationIcon() {
    return Stack(
      children: <Widget>[
        const Icon(Icons.notifications, color: Colors.grey),
        Positioned(
          right: 0,
          child: _buildNotificationBadge(),
        ),
      ],
    );
  }

  /// Builds the notification badge with count
  Widget _buildNotificationBadge() {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      constraints: const BoxConstraints(
        minWidth: 12,
        minHeight: 12,
      ),
      child: Text(
        '1',
        style:
            openSansHebrewTextStyle.copyWith(fontSize: 10, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Builds the side navigation menu
  Widget _buildSideMenu() {
    return CustomSidebar(
      selectedIndex: _selectedIndex,
      onItemSelected: _onItemTapped,
      isCollapsed: _isSideMenuCollapsed,
      onToggleCollapse: () {
        setState(() {
          _isSideMenuCollapsed = !_isSideMenuCollapsed;
        });
        _saveSidebarState();
      },
      userRole: _userRole,
    );
  }
}
