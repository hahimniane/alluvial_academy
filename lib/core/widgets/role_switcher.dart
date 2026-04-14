import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/user_role_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class RoleSwitcher extends StatefulWidget {
  final Function(String)? onRoleChanged;
  final EdgeInsets? padding;

  const RoleSwitcher({
    super.key,
    this.onRoleChanged,
    this.padding,
  });

  @override
  State<RoleSwitcher> createState() => _RoleSwitcherState();
}

class _RoleSwitcherState extends State<RoleSwitcher> {
  List<String> _availableRoles = [];
  String? _currentRole;
  bool _isLoading = true;
  bool _hasDualRoles = false;
  bool _isSwitching = false;
  Timer? _userPollTimer;
  bool _isPollingUserData = false;

  static const Duration _userPollInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _loadRoleData();
    _startUserPolling();
  }

  @override
  void dispose() {
    _userPollTimer?.cancel();
    _userPollTimer = null;
    super.dispose();
  }

  Future<void> _loadRoleData() async {
    setState(() => _isLoading = true);

    try {
      final roles = await UserRoleService.getAvailableRoles();
      final currentRole = await UserRoleService.getCurrentUserRole();
      final hasDual = await UserRoleService.hasDualRoles();

      if (mounted) {
        setState(() {
          _availableRoles = roles;
          _currentRole = currentRole;
          _hasDualRoles = hasDual;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading role data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startUserPolling() {
    _pollUserData();
    _userPollTimer?.cancel();
    _userPollTimer = Timer.periodic(
      _userPollInterval,
      (_) => _pollUserData(),
    );
  }

  Future<void> _pollUserData() async {
    if (!mounted || _isPollingUserData) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isPollingUserData = true;
    final email = user.email?.toLowerCase();
    final uid = user.uid;

    try {
      final uidDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;

      if (uidDoc.exists) {
        _handleUserData(uidDoc.data());
        return;
      }

      if (email == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('e-mail', isEqualTo: email)
          .limit(1)
          .get();
      if (!mounted) return;

      if (querySnapshot.docs.isNotEmpty) {
        _handleUserData(querySnapshot.docs.first.data());
      }
    } catch (e) {
      AppLogger.error('RoleSwitcher: error polling user changes: $e');
    } finally {
      _isPollingUserData = false;
    }
  }

  void _handleUserData(Map<String, dynamic>? userData) {
    if (!mounted || userData == null) return;

    final isAdminTeacher = userData['is_admin_teacher'] as bool? ?? false;
    final userType = (userData['user_type'] as String?)?.trim().toLowerCase();
    final secondaryRoles = List<String>.from(userData['secondary_roles'] ?? []);

    final newHasDualRoles =
        (userType == 'admin' || userType == 'super_admin') ||
            (isAdminTeacher && userType == 'teacher') ||
            secondaryRoles.isNotEmpty;

    if (newHasDualRoles == _hasDualRoles) return;

    AppLogger.debug(
        'Role change detected: hasDualRoles changed from $_hasDualRoles to $newHasDualRoles');

    _loadRoleData();

    if (!newHasDualRoles && _hasDualRoles) {
      UserRoleService.switchActiveRole(userType ?? 'teacher').then((success) {
        if (success && mounted) {
          widget.onRoleChanged?.call(userType ?? 'teacher');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!
                        .adminPrivilegesHaveBeenRevoked,
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'super_admin':
        return const Color(0xffEF4444);
      case 'teacher':
        return const Color(0xff0386FF);
      case 'parent':
        return const Color(0xffF59E0B);
      case 'student':
        return const Color(0xff10B981);
      default:
        return const Color(0xff6B7280);
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'super_admin':
        return Icons.admin_panel_settings;
      case 'teacher':
        return Icons.school;
      case 'parent':
        return Icons.family_restroom;
      case 'student':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  Future<void> _switchRole(String newRole) async {
    if (_isSwitching || newRole == _currentRole) return;

    setState(() => _isSwitching = true);

    try {
      final success = await UserRoleService.switchActiveRole(newRole);

      if (success && mounted) {
        setState(() {
          _currentRole = newRole;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _roleIcon(newRole),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Switched to ${UserRoleService.getRoleDisplayName(newRole)} mode',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: _roleColor(newRole),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Notify parent widget
        widget.onRoleChanged?.call(newRole);
      }
    } catch (e) {
      AppLogger.error('Error switching role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.failedToSwitchRolePleaseTry),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitching = false);
      }
    }
  }

  Widget _buildRoleChip(String role, bool isActive) {
    final color = isActive ? _roleColor(role) : Colors.grey.shade300;
    final textColor = isActive ? Colors.white : Colors.grey.shade600;

    return Material(
      elevation: isActive ? 2 : 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _isSwitching ? null : () => _switchRole(role),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: isActive ? null : Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _roleIcon(role),
                size: 16,
                color: textColor,
              ),
              const SizedBox(width: 6),
              Text(
                UserRoleService.getRoleDisplayName(role),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (_isSwitching && isActive) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(textColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: widget.padding ?? const EdgeInsets.all(8),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!_hasDualRoles || _availableRoles.length <= 1) {
      // Single role user - show simple badge
      return Container(
        padding: widget.padding ?? const EdgeInsets.all(8),
        child: _buildRoleChip(_currentRole ?? 'user', true),
      );
    }

    // Dual role user - show switcher
    return Container(
      padding: widget.padding ?? const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _availableRoles.map((role) {
            final isActive = role == _currentRole;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildRoleChip(role, isActive),
            );
          }).toList(),
        ),
      ),
    );
  }
}
