import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Services/user_role_service.dart';
import 'dahboard.dart';

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
      print('Loading user role...');
      final role = await UserRoleService.getCurrentUserRole();
      final data = await UserRoleService.getCurrentUserData();

      setState(() {
        userRole = role;
        userData = data;
        isLoading = false;
      });

      print('User role loaded: $role');
    } catch (e) {
      print('Error loading user role: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
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
    switch (userRole!.toLowerCase()) {
      case 'admin':
        return const DashboardPage(); // Full admin dashboard
      case 'teacher':
        return const TeacherDashboard();
      case 'student':
        return const StudentDashboard();
      case 'parent':
        return const ParentDashboard();
      default:
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
    return const DashboardPage(); // For now, use the same dashboard
    // TODO: Create role-specific dashboard with limited features
  }
}

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardPage(); // For now, use the same dashboard
    // TODO: Create role-specific dashboard with limited features
  }
}

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardPage(); // For now, use the same dashboard
    // TODO: Create role-specific dashboard with limited features
  }
}
