import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/services/user_role_service.dart';
import 'core/services/version_service.dart';
import 'dashboard.dart';
import 'features/parent/screens/parent_dashboard_layout.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class RoleBasedDashboard extends StatefulWidget {
  const RoleBasedDashboard({super.key});

  @override
  State<RoleBasedDashboard> createState() => _RoleBasedDashboardState();
}

class _RoleBasedDashboardState extends State<RoleBasedDashboard> {
  String? userRole;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      AppLogger.debug('=== Loading User Role ===');
      AppLogger.debug('Current user: ${FirebaseAuth.instance.currentUser?.uid}');
      AppLogger.debug('Current user email: ${FirebaseAuth.instance.currentUser?.email}');
      
      final role = await UserRoleService.getCurrentUserRole();
      final data = await UserRoleService.getCurrentUserData();

      if (mounted) {
        setState(() {
          userRole = role;
          userData = data;
          isLoading = false;
        });
      }

      AppLogger.debug('Role loaded successfully: $role');
    } catch (e) {
      AppLogger.error('Error loading user role: $e');
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  /// Reload user role when role switcher triggers a change
  void _onRoleChanged() {
    setState(() {
      isLoading = true;
      error = null;
    });
    _loadUserRole();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingScreen();
    }

    if (error != null) {
      return _buildErrorScreen();
    }

    if (userRole == null) {
      return _buildNoRoleScreen();
    }

    // Route to appropriate dashboard based on role
    AppLogger.debug('=== RoleBasedDashboard routing for role: ${userRole!.toLowerCase()} ===');
    switch (userRole!.toLowerCase()) {
      case 'admin':
        AppLogger.debug('=== Returning AdminDashboard ===');
        return const DashboardPage(); // Full admin dashboard
      case 'teacher':
        AppLogger.debug('=== Returning TeacherDashboard ===');
        return const TeacherDashboard();
      case 'student':
        // Get the user ID from cached data or Firebase Auth
        final userId = UserRoleService.getCurrentUserId();
        AppLogger.debug('=== Returning StudentDashboard with userId: $userId ===');
        return StudentDashboard(userId: userId);
      case 'parent':
        AppLogger.debug('=== Returning ParentDashboard ===');
        return const ParentDashboard();
      default:
        AppLogger.debug('=== Returning UnknownRoleScreen ===');
        return _buildUnknownRoleScreen();
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/Alluwal_Education_Hub_Logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading user profile...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xff6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Profile',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try signing out and signing back in',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRoleScreen() {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_off_outlined,
              color: Colors.orange,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Account Not Set Up',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account has not been set up by an administrator.\nPlease contact support.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnknownRoleScreen() {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.help_outline,
              color: Colors.orange,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Unknown User Role',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Role: ${userRole ?? "Unknown"}\nPlease contact an administrator.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder dashboards for different roles
class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardVersionOverlay(child: DashboardPage());
  }
}

class StudentDashboard extends StatelessWidget {
  final String? userId;
  
  const StudentDashboard({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    AppLogger.debug('=== StudentDashboard.build() with userId: $userId ===');

    return const _DashboardVersionOverlay(child: DashboardPage());
  }
}

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardVersionOverlay(child: ParentDashboardLayout());
  }
}

class _DashboardVersionOverlay extends StatelessWidget {
  final Widget child;

  const _DashboardVersionOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IgnorePointer(
                  child: const _AppVersionPill(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppVersionPill extends StatefulWidget {
  const _AppVersionPill();

  @override
  State<_AppVersionPill> createState() => _AppVersionPillState();
}

class _AppVersionPillState extends State<_AppVersionPill> {
  late final Future<String> _versionFuture = VersionService.getFullVersionInfo();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _versionFuture,
      builder: (context, snapshot) {
        final version = snapshot.data?.trim();
        if (version == null || version.isEmpty) {
          return const SizedBox.shrink();
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xA6000000),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              'v$version',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
