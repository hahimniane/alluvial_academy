import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/user_role_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

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
  StreamSubscription? _userSubscription;

  @override
  void initState() {
    super.initState();
    _loadRoleData();
    _setupUserListener();
  }

  @override
  void dispose() {
    final subscription = _userSubscription;
    _userSubscription = null;

    if (subscription != null) {
      try {
        subscription.cancel().catchError((e, st) {
          AppLogger.error('RoleSwitcher: error cancelling user listener: $e');
        });
      } catch (e) {
        AppLogger.error('RoleSwitcher: error cancelling user listener: $e');
      }
    }
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

  Future<void> _setupUserListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email?.toLowerCase();
    final uid = user.uid;

    // Prefer UID doc listener (most reliable) and fallback to email query for legacy users.
    bool shouldUseUidDoc = false;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      shouldUseUidDoc = doc.exists;
    } catch (e) {
      // If UID lookup fails, we'll attempt the email query below.
      AppLogger.error('RoleSwitcher: error checking user doc by uid: $e');
    }

    if (!mounted) return;

    // Listen to changes in the user's document
    void handleUserData(Map<String, dynamic>? userData) {
      if (userData == null) return;

      final isAdminTeacher = userData['is_admin_teacher'] as bool? ?? false;
      final userType = (userData['user_type'] as String?)?.trim().toLowerCase();

      // Check if dual role status changed
      // Any admin has dual modes (admin + teacher). Teachers with is_admin_teacher also have dual roles.
      final newHasDualRoles =
          (userType == 'admin' || userType == 'super_admin') ||
          (isAdminTeacher && userType == 'teacher');

      if (newHasDualRoles != _hasDualRoles) {
        AppLogger.debug(
            'Role change detected: hasDualRoles changed from $_hasDualRoles to $newHasDualRoles');

        // Reload role data when dual role status changes
        _loadRoleData();

        // If user lost admin privileges, notify parent
        if (!newHasDualRoles && _hasDualRoles) {
          // User lost dual-role privileges - switch back to primary role
          UserRoleService.switchActiveRole(userType ?? 'teacher')
              .then((success) {
            if (success && mounted) {
              widget.onRoleChanged?.call(userType ?? 'teacher');

              // Show notification
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.info, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Admin privileges have been revoked'),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }
    }

    if (shouldUseUidDoc) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen(
        (docSnapshot) {
          handleUserData(docSnapshot.data());
        },
        onError: (error) {
          AppLogger.error('Error listening to user changes (uid doc): $error');
        },
      );
      return;
    }

    if (email == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('e-mail', isEqualTo: email)
        .limit(1)
        .snapshots()
        .listen(
      (querySnapshot) {
        if (querySnapshot.docs.isNotEmpty) {
          handleUserData(querySnapshot.docs.first.data());
        }
      },
      onError: (error) {
        AppLogger.error('Error listening to user changes (email query): $error');
      },
    );
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
                  newRole == 'admin'
                      ? Icons.admin_panel_settings
                      : Icons.school,
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
            backgroundColor: newRole == 'admin'
                ? const Color(0xffEF4444)
                : const Color(0xff0386FF),
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
          const SnackBar(
            content: Text('Failed to switch role. Please try again.'),
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
    final isAdmin = role == 'admin';
    final color = isActive
        ? (isAdmin ? const Color(0xffEF4444) : const Color(0xff0386FF))
        : Colors.grey.shade300;
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
                isAdmin ? Icons.admin_panel_settings : Icons.school,
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
