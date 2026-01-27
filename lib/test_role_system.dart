import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/services/user_role_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
class TestRoleSystemScreen extends StatefulWidget {
  const TestRoleSystemScreen({super.key});

  @override
  State<TestRoleSystemScreen> createState() => _TestRoleSystemScreenState();
}

class _TestRoleSystemScreenState extends State<TestRoleSystemScreen> {
  String? currentUserRole;
  Map<String, dynamic>? currentUserData;
  bool isLoading = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.roleSystemTest),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.currentUserInfo,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                        'Auth User: ${FirebaseAuth.instance.currentUser?.email ?? "Not signed in"}'),
                    Text(
                        'User ID: ${FirebaseAuth.instance.currentUser?.uid ?? "N/A"}'),
                    const SizedBox(height: 8),
                    Text('Role: ${currentUserRole ?? "Not loaded"}'),
                    const SizedBox(height: 8),
                    if (currentUserData != null) ...[
                      Text(AppLocalizations.of(context)!.userData,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final entry in currentUserData!.entries)
                        Text('${entry.key}: ${entry.value}'),
                    ] else
                      Text(AppLocalizations.of(context)!.userDataNotLoaded),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(AppLocalizations.of(context)!.errorError,
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: isLoading ? null : _loadUserRole,
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppLocalizations.of(context)!.loadUserRole),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _testRoleChecks,
                  child: Text(AppLocalizations.of(context)!.testRoleChecks),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentUserRole != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Features for ${currentUserRole!.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...UserRoleService.getAvailableFeatures(currentUserRole!)
                          .map((feature) => Text(AppLocalizations.of(context)!.feature)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadUserRole() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      AppLogger.debug('=== Loading User Role ===');
      final role = await UserRoleService.getCurrentUserRole();
      final data = await UserRoleService.getCurrentUserData();

      setState(() {
        currentUserRole = role;
        currentUserData = data;
        isLoading = false;
      });

      AppLogger.info('Role loaded successfully: $role');
    } catch (e) {
      AppLogger.error('Error loading role: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _testRoleChecks() async {
    if (currentUserRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppLocalizations.of(context)!.loadUserRoleFirst)),
      );
      return;
    }

    final isAdmin = await UserRoleService.isAdmin();
    final isTeacher = await UserRoleService.isTeacher();
    final isStudent = await UserRoleService.isStudent();
    final isParent = await UserRoleService.isParent();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.roleCheckResults),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.isAdminIsadmin),
            Text(AppLocalizations.of(context)!.isTeacherIsteacher),
            Text(AppLocalizations.of(context)!.isStudentIsstudent),
            Text(AppLocalizations.of(context)!.isParentIsparent),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonOk),
          ),
        ],
      ),
    );
  }
}
