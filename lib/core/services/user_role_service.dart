import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRoleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the current user's role from Firestore
  static Future<String?> getCurrentUserRole() async {
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

  /// Get complete user data from Firestore
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: currentUser.email?.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return null;

      return userQuery.docs.first.data() as Map<String, dynamic>;
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
}
