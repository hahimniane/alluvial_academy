import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/services/user_role_service.dart';
import 'dashboard.dart';
import 'features/parent/screens/parent_dashboard_layout.dart';
import 'features/dashboard/screens/mobile_dashboard_screen.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Check if running on native mobile platform
bool get _isNativeMobile {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

class RoleBasedDashboard extends StatefulWidget {
  const RoleBasedDashboard({super.key});

  @override
  State<RoleBasedDashboard> createState() => _RoleBasedDashboardState();
}

class _RoleBasedDashboardState extends State<RoleBasedDashboard>
    with WidgetsBindingObserver {
  String? userRole;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? error;
  Timer? _presenceTimer;
  DateTime? _lastPresenceUpdate;
  String? _presenceUserId;

  static const Duration _presenceInterval = Duration(minutes: 1);
  static const Duration _presenceMinInterval = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPresenceTracking();
    _loadUserRole();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPresenceTracking(setOffline: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPresenceTracking();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopPresenceTracking(setOffline: true);
    }
  }

  void _startPresenceTracking() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _presenceUserId = userId;
    _presenceTimer?.cancel();
    _updatePresence(isOnline: true);
    _presenceTimer =
        Timer.periodic(_presenceInterval, (_) => _updatePresence(isOnline: true));
  }

  void _stopPresenceTracking({required bool setOffline}) {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    if (setOffline) {
      _updatePresence(isOnline: false);
    }
  }

  Future<void> _updatePresence({required bool isOnline}) async {
    final userId = _presenceUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    if (_lastPresenceUpdate != null &&
        now.difference(_lastPresenceUpdate!) < _presenceMinInterval) {
      return;
    }
    _lastPresenceUpdate = now;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {
          'is_online': isOnline,
          'last_seen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      AppLogger.error('Presence update failed: $e');
    }
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

    // Route to appropriate dashboard based on role AND platform
    AppLogger.debug('=== RoleBasedDashboard routing for role: ${userRole!.toLowerCase()}, isNativeMobile: $_isNativeMobile ===');
    
    // On native mobile (iOS/Android), use MobileDashboardScreen with bottom navigation
    if (_isNativeMobile) {
      AppLogger.debug('=== Native mobile detected - returning MobileDashboardScreen ===');
      return const MobileDashboardScreen();
    }
    
    // On web, route based on role
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
              AppLocalizations.of(context)!.loadingUserProfile,
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
              AppLocalizations.of(context)!.errorLoadingProfile,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.pleaseTrySigningOutAndSigning,
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
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.settingsSignOut),
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
              AppLocalizations.of(context)!.accountNotSetUp,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.yourAccountHasNotBeenSet,
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
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.settingsSignOut),
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
              AppLocalizations.of(context)!.unknownUserRole,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.roleUnknownMessage(
                userRole ?? AppLocalizations.of(context)!.commonUnknown,
              ),
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
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.settingsSignOut),
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
    return const DashboardPage();
  }
}

class StudentDashboard extends StatelessWidget {
  final String? userId;
  
  const StudentDashboard({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    AppLogger.debug('=== StudentDashboard.build() with userId: $userId ===');

    return const DashboardPage();
  }
}

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const ParentDashboardLayout();
  }
}
