import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class UserRoleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache keys for role management
  static const String _activeRoleKey = 'active_user_role';
  static const String _availableRolesKey = 'available_user_roles';

  // In-memory cache to reduce repeated Firestore calls
  static Map<String, dynamic>? _cachedUserData;
  static String? _cachedUserEmail;
  static DateTime? _cacheTimestamp;

  static bool _looksLikeFirestoreWebInternalError(Object error) {
    if (!kIsWeb) return false;
    final text = error.toString();
    return text.contains('FIRESTORE') &&
        text.contains('INTERNAL ASSERTION FAILED') &&
        text.contains('Unexpected state');
  }

  /// Get all available roles for the current user
  static Future<List<String>> getAvailableRoles() async {
    try {
      final userData = await getCurrentUserData();

      if (userData == null) return [];

      // Determine available roles
      final primaryRole =
          (userData['user_type'] as String?)?.trim().toLowerCase();
      final isAdminTeacher = userData['is_admin_teacher'] as bool? ?? false;

      final Set<String> roles = <String>{};
      if (primaryRole != null && primaryRole.isNotEmpty) {
        roles.add(primaryRole);
      }

      // Business rule: Any admin can switch to teacher mode
      if (primaryRole == 'admin' || primaryRole == 'super_admin') {
        roles.add('teacher');
      }

      // Preserve existing dual-role flag for teachers promoted to admin
      if (primaryRole == 'teacher' && isAdminTeacher) {
        roles.add('admin');
      }

      return roles.toList();
    } catch (e) {
      if (_looksLikeFirestoreWebInternalError(e)) {
        AppLogger.debug(
            'UserRoleService: Firestore web internal error while getting available roles');
        return [];
      }
      AppLogger.error('Error getting available roles: $e');
      return [];
    }
  }

  /// Get the currently active role (may be different from primary role)
  static Future<String?> getActiveRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeRole = prefs.getString(_activeRoleKey);

      if (activeRole != null) {
        // Verify the user still has this role
        final availableRoles = await getAvailableRoles();
        if (availableRoles.contains(activeRole)) {
          return activeRole;
        }
      }

      // Fallback to primary role
      return await getPrimaryRole();
    } catch (e) {
      AppLogger.error('Error getting active role: $e');
      return await getPrimaryRole();
    }
  }

  /// Get the user's primary role from Firestore
  static Future<String?> getPrimaryRole() async {
    try {
      final userData = await getCurrentUserData();
      final userType = userData?['user_type'] as String?;
      if (userType == null || userType.isEmpty) {
        return null;
      }
      return userType;
    } catch (e) {
      if (_looksLikeFirestoreWebInternalError(e)) {
        AppLogger.debug(
            'UserRoleService: Firestore web internal error while getting primary role');
        // Best-effort fallback to cached data if present.
        final cachedRole = _cachedUserData?['user_type'] as String?;
        return cachedRole;
      }
      AppLogger.error('Error getting user role: $e');
      return null;
    }
  }

  /// Get the current user's role (uses active role for dual-role users)
  static Future<String?> getCurrentUserRole() async {
    return await getActiveRole();
  }

  /// Switch active role for dual-role users
  static Future<bool> switchActiveRole(String newRole) async {
    try {
      final availableRoles = await getAvailableRoles();
      if (!availableRoles.contains(newRole)) {
        AppLogger.debug('User does not have access to role: $newRole');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeRoleKey, newRole);

      AppLogger.error('Active role switched to: $newRole');
      return true;
    } catch (e) {
      AppLogger.error('Error switching active role: $e');
      return false;
    }
  }

  /// Check if user has dual roles (admin-teacher)
  static Future<bool> hasDualRoles() async {
    final roles = await getAvailableRoles();
    return roles.length > 1;
  }

  /// Get complete user data from Firestore with caching
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Check cache validity (5 minutes) - use UID for cache key
      final now = DateTime.now();
      if (_cachedUserData != null &&
          _cachedUserEmail == currentUser.uid &&
          _cacheTimestamp != null &&
          now.difference(_cacheTimestamp!).inMinutes < 5) {
        return _cachedUserData;
      }

      // First try to get user document by UID (most reliable)
      final userDocByUid = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      Map<String, dynamic>? userData;

      if (userDocByUid.exists) {
        userData = userDocByUid.data() as Map<String, dynamic>;
      } else {
        // Fallback 1: Some deployments store user documents keyed by email.
        final email = currentUser.email?.toLowerCase();
        if (email != null && email.isNotEmpty) {
          final userDocByEmailId =
              await _firestore.collection('users').doc(email).get();
          if (userDocByEmailId.exists) {
            userData = userDocByEmailId.data() as Map<String, dynamic>;
          }
        }

        // Fallback: Query by email field (try both 'email' and 'e-mail' variants)
        if (userData == null) {
          // First try 'email' field (standard)
          QuerySnapshot userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: currentUser.email?.toLowerCase())
              .limit(1)
              .get();

          // If not found, try 'e-mail' field (legacy)
          if (userQuery.docs.isEmpty) {
            userQuery = await _firestore
                .collection('users')
                .where('e-mail', isEqualTo: currentUser.email?.toLowerCase())
                .limit(1)
                .get();
          }

          if (userQuery.docs.isEmpty) return null;

          userData = userQuery.docs.first.data() as Map<String, dynamic>;
        }
      }

      // Cache the result (use UID as cache key)
      _cachedUserData = userData;
      _cachedUserEmail = currentUser.uid;
      _cacheTimestamp = now;

      return userData;
    } catch (e) {
      if (_looksLikeFirestoreWebInternalError(e)) {
        AppLogger.debug(
            'UserRoleService: Firestore web internal error while getting user data');
        return _cachedUserData;
      }
      AppLogger.error('Error getting user data: $e');
      return null;
    }
  }

  /// Check if user has admin privileges
  static Future<bool> isAdmin() async {
    final role = await getCurrentUserRole();
    final lower = role?.toLowerCase();
    return lower == 'admin' || lower == 'super_admin';
  }

  /// Check if user has teacher privileges
  static Future<bool> isTeacher() async {
    final role = await getCurrentUserRole();
    return role?.toLowerCase() == 'teacher';
  }

  /// Check if user is a student
  static Future<bool> isStudent() async {
    final role = await getCurrentUserRole();
    return role?.toLowerCase() == 'student';
  }

  /// Clear cached user data (call on sign out)
  static void clearCache() {
    _cachedUserData = null;
    _cachedUserEmail = null;
    _cacheTimestamp = null;
  }

  /// Get the current user ID - checks cache first, then FirebaseAuth
  /// This is useful when FirebaseAuth.instance.currentUser might be null temporarily on web
  static String? getCurrentUserId() {
    // First try FirebaseAuth
    final user = _auth.currentUser;
    if (user != null) {
      return user.uid;
    }
    // Fall back to cached UID if available
    return _cachedUserEmail;
  }

  /// Check if user is a parent
  static Future<bool> isParent() async {
    final role = await getCurrentUserRole();
    return role?.toLowerCase() == 'parent';
  }

  /// Get user's display name based on role
  static String getRoleDisplayName(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'super_admin':
        return 'Super Administrator';
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      case 'parent':
        return 'Parent';
      default:
        return 'User';
    }
  }

  /// Get available features/screens based on user role
  static List<String> getAvailableFeatures(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
      case 'super_admin':
        return [
          'dashboard',
          'user_management',
          'chat',
          'forms',
          'form_builder',
          'tasks',
          'reports'
        ];
      case 'teacher':
        return ['dashboard', 'chat', 'time_clock', 'forms', 'tasks'];
      case 'student':
        return ['dashboard', 'chat', 'forms', 'tasks'];
      case 'parent':
        return ['dashboard', 'chat', 'forms'];
      default:
        return ['dashboard'];
    }
  }

  /// Promote a teacher to admin-teacher (dual role)
  static Future<bool> promoteToAdminTeacher(String userEmail) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: userEmail.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        AppLogger.debug('User not found: $userEmail');
        return false;
      }

      final docRef = userQuery.docs.first.reference;
      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      final currentRole = userData['user_type'] as String?;

      if (currentRole != 'teacher') {
        AppLogger.debug('Can only promote teachers to admin-teacher role');
        return false;
      }

      await docRef.update({
        'is_admin_teacher': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      AppLogger.error('Successfully promoted $userEmail to admin-teacher');
      return true;
    } catch (e) {
      AppLogger.error('Error promoting user to admin-teacher: $e');
      return false;
    }
  }

  /// Revoke admin privileges from admin-teacher
  static Future<bool> revokeAdminPrivileges(String userEmail) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: userEmail.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        AppLogger.debug('User not found: $userEmail');
        return false;
      }

      final docRef = userQuery.docs.first.reference;
      await docRef.update({
        'is_admin_teacher': false,
        'updated_at': FieldValue.serverTimestamp(),
      });

      AppLogger.error('Successfully revoked admin privileges for $userEmail');
      return true;
    } catch (e) {
      AppLogger.error('Error revoking admin privileges: $e');
      return false;
    }
  }

  /// Get user document ID by email
  static Future<String?> getUserDocumentId(String userEmail) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: userEmail.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;
      return userQuery.docs.first.id;
    } catch (e) {
      AppLogger.error('Error getting user document ID: $e');
      return null;
    }
  }

  /// Check if user has admin-teacher privileges
  static Future<bool> isAdminTeacher(String userEmail) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: userEmail.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return false;

      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      return userData['is_admin_teacher'] as bool? ?? false;
    } catch (e) {
      AppLogger.error('Error checking admin-teacher status: $e');
      return false;
    }
  }

  /// Deactivate a user account
  static Future<bool> deactivateUser(String userEmail) async {
    try {
      final actor = _auth.currentUser;
      if (actor == null) {
        AppLogger.debug('UserRoleService: No authenticated user found');
        return false;
      }

      final normalizedEmail = userEmail.trim().toLowerCase();
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        AppLogger.debug('User not found: $normalizedEmail');
        return false;
      }

      final docRef = userQuery.docs.first.reference;
      final updates = <String, dynamic>{
        'is_active': false,
        'deactivated_at': FieldValue.serverTimestamp(),
        'deactivated_by_uid': actor.uid,
        'deactivated_by_email': actor.email?.toLowerCase(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      updates.removeWhere((_, value) => value == null);
      await docRef.update(updates);

      AppLogger.info(
          'Successfully deactivated user: $normalizedEmail (by uid=${actor.uid})');
      return true;
    } catch (e) {
      AppLogger.error('Error deactivating user: $e');
      return false;
    }
  }

  /// Activate a user account
  static Future<bool> activateUser(String userEmail) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: userEmail.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        AppLogger.debug('User not found: $userEmail');
        return false;
      }

      final docRef = userQuery.docs.first.reference;
      await docRef.update({
        'is_active': true,
        'activated_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'deactivated_at': FieldValue.delete(), // Remove deactivation timestamp
      });

      AppLogger.error('Successfully activated user: $userEmail');
      return true;
    } catch (e) {
      AppLogger.error('Error activating user: $e');
      return false;
    }
  }

  /// Check if user is active
  static Future<bool> isUserActive(String userEmail) async {
    try {
      // First try to get user by UID if we have currentUser
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDocByUid = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDocByUid.exists) {
          final userData = userDocByUid.data() as Map<String, dynamic>;
          return userData['is_active'] as bool? ?? true;
        }
      }

      // Fallback: Query by email
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: userEmail.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        // If not found by email, return true (default to active)
        // This prevents students with alias emails from being blocked
        AppLogger.debug('User not found by email in isUserActive, defaulting to active');
        return true;
      }

      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      return userData['is_active'] as bool? ??
          true; // Default to active if field doesn't exist
    } catch (e) {
      AppLogger.error('Error checking user active status: $e');
      return true; // Default to active on error
    }
  }

  /// Permanently delete a user account from both Firebase Auth and Firestore using Cloud Function.
  ///
  /// If `deleteClasses` is true and the user is a teacher or student, the backend will also
  /// delete/detach the user's classes (teaching shifts) safely.
  static Future<bool> deleteUser(String userEmail, {bool deleteClasses = false}) async {
    try {
      AppLogger.debug(
          'UserRoleService: Calling cloud function to delete user: $userEmail');

      // Get current user's email for admin verification
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        AppLogger.debug('UserRoleService: No authenticated user found');
        throw Exception('You must be logged in to delete users');
      }

      String? idToken;
      // Ensure the callable request is sent with a fresh token (helps on web when tokens stale).
      try {
        idToken = await currentUser.getIdToken(true);
      } catch (e) {
        AppLogger.debug('UserRoleService: Failed to refresh ID token before deleteUser: $e');
      }

      // Call the cloud function to handle deletion
      final callable =
          FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('deleteUserAccount');
      final payload = <String, dynamic>{
        'email': userEmail.trim(),
        'deleteClasses': deleteClasses,
      };
      if (idToken != null && idToken.isNotEmpty) {
        payload['authToken'] = idToken;
      }
      final adminEmail = currentUser.email?.trim();
      if (adminEmail != null && adminEmail.isNotEmpty) {
        // Backward compatibility: some older function versions expected this field.
        payload['adminEmail'] = adminEmail;
      }
      final result = await callable.call(payload);

      final data = result.data;
      if (data['success'] == true) {
        AppLogger.info(
            'UserRoleService: Successfully deleted user via cloud function: $userEmail');
        AppLogger.info('UserRoleService: Deleted from Auth: ${data['deletedFromAuth']}');
        AppLogger.info(
            'UserRoleService: Deleted from Firestore: ${data['deletedFromFirestore']}');
        return true;
      } else {
        AppLogger.error('UserRoleService: Cloud function returned unsuccessful result');
        return false;
      }
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
        'UserRoleService: deleteUserAccount failed (code=${e.code}, message=${e.message}, details=${e.details})',
      );

      switch (e.code) {
        case 'failed-precondition':
          throw Exception('User must be archived before permanent deletion');
        case 'unauthenticated':
          throw Exception(e.message ?? 'You must be logged in to delete users');
        case 'permission-denied':
          throw Exception(e.message ?? 'Only administrators can delete users');
        case 'not-found':
          throw Exception(e.message ?? 'User not found in the system');
        default:
          throw Exception(e.message ?? 'Failed to delete user (code=${e.code})');
      }
    } catch (e) {
      AppLogger.error('UserRoleService: Error calling delete user cloud function: $e');

      // Check if this is a Firebase Functions error with more details
      if (e.toString().contains('failed-precondition')) {
        AppLogger.debug('UserRoleService: User must be deactivated before deletion');
        throw Exception('User must be archived before permanent deletion');
      } else if (e.toString().contains('permission-denied')) {
        AppLogger.debug('UserRoleService: Permission denied - user is not an admin');
        throw Exception('Only administrators can delete users');
      } else if (e.toString().contains('not-found')) {
        AppLogger.debug('UserRoleService: User not found');
        throw Exception('User not found in the system');
      } else {
        AppLogger.error('UserRoleService: Unknown error: $e');
        throw Exception('Failed to delete user: ${e.toString()}');
      }
    }
  }
}
