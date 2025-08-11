import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

  /// Get all available roles for the current user
  static Future<List<String>> getAvailableRoles() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: currentUser.email?.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return [];

      final userData = userQuery.docs.first.data() as Map<String, dynamic>;

      // Determine available roles
      final primaryRole = userData['user_type'] as String?;
      final isAdminTeacher = userData['is_admin_teacher'] as bool? ?? false;

      final Set<String> roles = <String>{};
      if (primaryRole != null) {
        roles.add(primaryRole);
      }

      // Business rule: Any admin can switch to teacher mode
      if (primaryRole == 'admin') {
        roles.add('teacher');
      }

      // Preserve existing dual-role flag for teachers promoted to admin
      if (primaryRole == 'teacher' && isAdminTeacher) {
        roles.add('admin');
      }

      return roles.toList();
    } catch (e) {
      print('Error getting available roles: $e');
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
      print('Error getting active role: $e');
      return await getPrimaryRole();
    }
  }

  /// Get the user's primary role from Firestore
  static Future<String?> getPrimaryRole() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user found');
        return null;
      }

      print('Getting role for user: ${currentUser.uid}');
      print('User email: ${currentUser.email}');

      // Query Firestore users collection by email
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: currentUser.email?.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('No user document found for email: ${currentUser.email}');
        return null;
      }

      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      final userType = userData['user_type'] as String?;
      final title = userData['title'] as String?;

      print('Found user data:');
      print('User Type: $userType');
      print('Title: $title');

      return userType;
    } catch (e) {
      print('Error getting user role: $e');
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
        print('User does not have access to role: $newRole');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeRoleKey, newRole);

      print('Active role switched to: $newRole');
      return true;
    } catch (e) {
      print('Error switching active role: $e');
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

      // Check cache validity (5 minutes)
      final now = DateTime.now();
      if (_cachedUserData != null &&
          _cachedUserEmail == currentUser.email?.toLowerCase() &&
          _cacheTimestamp != null &&
          now.difference(_cacheTimestamp!).inMinutes < 5) {
        return _cachedUserData;
      }

      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: currentUser.email?.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;

      final userData = userQuery.docs.first.data() as Map<String, dynamic>;

      // Cache the result
      _cachedUserData = userData;
      _cachedUserEmail = currentUser.email?.toLowerCase();
      _cacheTimestamp = now;

      return userData;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Check if user has admin privileges
  static Future<bool> isAdmin() async {
    final role = await getCurrentUserRole();
    return role?.toLowerCase() == 'admin';
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
        print('User not found: $userEmail');
        return false;
      }

      final docRef = userQuery.docs.first.reference;
      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      final currentRole = userData['user_type'] as String?;

      if (currentRole != 'teacher') {
        print('Can only promote teachers to admin-teacher role');
        return false;
      }

      await docRef.update({
        'is_admin_teacher': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('Successfully promoted $userEmail to admin-teacher');
      return true;
    } catch (e) {
      print('Error promoting user to admin-teacher: $e');
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
        print('User not found: $userEmail');
        return false;
      }

      final docRef = userQuery.docs.first.reference;
      await docRef.update({
        'is_admin_teacher': false,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('Successfully revoked admin privileges for $userEmail');
      return true;
    } catch (e) {
      print('Error revoking admin privileges: $e');
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
      print('Error getting user document ID: $e');
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
      print('Error checking admin-teacher status: $e');
      return false;
    }
  }

  /// Deactivate a user account
  static Future<bool> deactivateUser(String userEmail) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: userEmail.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('User not found: $userEmail');
        return false;
      }

      final docRef = userQuery.docs.first.reference;
      await docRef.update({
        'is_active': false,
        'deactivated_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('Successfully deactivated user: $userEmail');
      return true;
    } catch (e) {
      print('Error deactivating user: $e');
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
        print('User not found: $userEmail');
        return false;
      }

      final docRef = userQuery.docs.first.reference;
      await docRef.update({
        'is_active': true,
        'activated_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'deactivated_at': FieldValue.delete(), // Remove deactivation timestamp
      });

      print('Successfully activated user: $userEmail');
      return true;
    } catch (e) {
      print('Error activating user: $e');
      return false;
    }
  }

  /// Check if user is active
  static Future<bool> isUserActive(String userEmail) async {
    try {
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: userEmail.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return false;

      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      return userData['is_active'] as bool? ??
          true; // Default to active if field doesn't exist
    } catch (e) {
      print('Error checking user active status: $e');
      return true; // Default to active on error
    }
  }

  /// Permanently delete a user account from both Firebase Auth and Firestore using Cloud Function
  static Future<bool> deleteUser(String userEmail) async {
    try {
      print(
          'UserRoleService: Calling cloud function to delete user: $userEmail');

      // Get current user's email for admin verification
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        print('UserRoleService: No authenticated user found');
        throw Exception('You must be logged in to delete users');
      }

      // Call the cloud function to handle deletion
      final callable =
          FirebaseFunctions.instance.httpsCallable('deleteUserAccount');
      final result = await callable.call({
        'email': userEmail,
        'adminEmail': currentUser.email,
      });

      final data = result.data;
      if (data['success'] == true) {
        print(
            'UserRoleService: Successfully deleted user via cloud function: $userEmail');
        print('UserRoleService: Deleted from Auth: ${data['deletedFromAuth']}');
        print(
            'UserRoleService: Deleted from Firestore: ${data['deletedFromFirestore']}');
        return true;
      } else {
        print('UserRoleService: Cloud function returned unsuccessful result');
        return false;
      }
    } catch (e) {
      print('UserRoleService: Error calling delete user cloud function: $e');

      // Check if this is a Firebase Functions error with more details
      if (e.toString().contains('failed-precondition')) {
        print('UserRoleService: User must be deactivated before deletion');
        throw Exception('User must be archived before permanent deletion');
      } else if (e.toString().contains('permission-denied')) {
        print('UserRoleService: Permission denied - user is not an admin');
        throw Exception('Only administrators can delete users');
      } else if (e.toString().contains('not-found')) {
        print('UserRoleService: User not found');
        throw Exception('User not found in the system');
      } else {
        print('UserRoleService: Unknown error: $e');
        throw Exception('Failed to delete user: ${e.toString()}');
      }
    }
  }
}
