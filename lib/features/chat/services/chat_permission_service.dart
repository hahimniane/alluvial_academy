import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_user.dart';
import '../../../core/utils/app_logger.dart';

/// Relationship type between two users for chat permissions
enum ChatRelationshipType {
  teacherStudent,
  teacherParent,
  adminUser,
  none,
}

/// Service to manage role-based chat permissions
/// 
/// Permission Matrix:
/// - Students can message: their assigned teachers, admins
/// - Teachers can message: their students, students' parents, admins
/// - Parents can message: teachers of their children, admins
/// - Admins can message: everyone
class ChatPermissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// How many days in the past to consider shifts for chat eligibility
  static const int _shiftLookbackDays = 30;
  
  String? get currentUserId => _auth.currentUser?.uid;
  
  /// Check if user1 can message user2
  Future<bool> canMessage(String userId1, String userId2) async {
    if (userId1 == userId2) return false;
    
    try {
      // Get both users' data
      final user1Doc = await _firestore.collection('users').doc(userId1).get();
      final user2Doc = await _firestore.collection('users').doc(userId2).get();
      
      if (!user1Doc.exists || !user2Doc.exists) return false;
      
      final user1Data = user1Doc.data()!;
      final user2Data = user2Doc.data()!;
      
      final user1Role = (user1Data['user_type'] as String?)?.toLowerCase() ?? '';
      final user2Role = (user2Data['user_type'] as String?)?.toLowerCase() ?? '';
      
      // Rule 1: Admins can message everyone
      if (user1Role == 'admin' || user1Role == 'super_admin') return true;
      if (user2Role == 'admin' || user2Role == 'super_admin') return true;
      
      // Rule 2: Student messaging
      if (user1Role == 'student') {
        if (user2Role == 'teacher') {
          return await hasActiveTeachingRelationship(userId2, userId1);
        }
        // Students can't message other students or parents directly
        return false;
      }
      
      // Rule 3: Teacher messaging
      if (user1Role == 'teacher') {
        if (user2Role == 'student') {
          return await hasActiveTeachingRelationship(userId1, userId2);
        }
        if (user2Role == 'parent') {
          return await canTeacherMessageParent(userId1, userId2);
        }
        // Teachers can't message other teachers directly (unless admin)
        return false;
      }
      
      // Rule 4: Parent messaging
      if (user1Role == 'parent') {
        if (user2Role == 'teacher') {
          return await canTeacherMessageParent(userId2, userId1);
        }
        // Parents can't message students or other parents directly
        return false;
      }
      
      return false;
    } catch (e) {
      AppLogger.error('ChatPermissionService: Error checking canMessage: $e');
      return false;
    }
  }
  
  /// Get all users that currentUser can message
  Future<List<ChatUser>> getEligibleContacts(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];
      
      final userData = userDoc.data()!;
      final userRole = (userData['user_type'] as String?)?.toLowerCase() ?? '';
      
      List<ChatUser> contacts = [];
      
      // Always add admins
      final admins = await _getAdminUsers();
      contacts.addAll(admins);
      
      switch (userRole) {
        case 'admin':
        case 'super_admin':
          // Admins can message everyone
          contacts = await _getAllUsersExceptCurrent(userId);
          break;
          
        case 'student':
          // Students can message their teachers
          final teachers = await _getStudentTeachers(userId);
          contacts.addAll(teachers);
          break;
          
        case 'teacher':
          // Teachers can message their students and students' parents
          final students = await _getTeacherStudents(userId);
          contacts.addAll(students);
          
          final parents = await _getTeacherStudentParents(userId);
          contacts.addAll(parents);
          break;
          
        case 'parent':
          // Parents can message teachers of their children
          final childrenTeachers = await _getParentChildrenTeachers(userId);
          contacts.addAll(childrenTeachers);
          break;
      }
      
      // Remove duplicates based on user ID
      final uniqueContacts = <String, ChatUser>{};
      for (final contact in contacts) {
        if (contact.id != userId) {
          uniqueContacts[contact.id] = contact;
        }
      }
      
      return uniqueContacts.values.toList();
    } catch (e) {
      AppLogger.error('ChatPermissionService: Error getting eligible contacts: $e');
      return [];
    }
  }
  
  /// Get eligible contacts grouped by relationship type
  Future<Map<String, List<ChatUser>>> getEligibleContactsGrouped(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return {};
      
      final userData = userDoc.data()!;
      final userRole = (userData['user_type'] as String?)?.toLowerCase() ?? '';
      
      final groupedContacts = <String, List<ChatUser>>{
        'Administrators': [],
        'Teachers': [],
        'Students': [],
        'Parents': [],
      };
      
      // Always add admins
      final admins = await _getAdminUsers();
      groupedContacts['Administrators'] = admins.where((a) => a.id != userId).toList();
      
      switch (userRole) {
        case 'admin':
        case 'super_admin':
          // Admins can message everyone - get all users grouped by role
          final allUsers = await _getAllUsersExceptCurrent(userId);
          for (final user in allUsers) {
            final role = user.role?.toLowerCase() ?? '';
            if (role == 'teacher') {
              groupedContacts['Teachers']!.add(user);
            } else if (role == 'student') {
              groupedContacts['Students']!.add(user);
            } else if (role == 'parent') {
              groupedContacts['Parents']!.add(user);
            }
          }
          break;
          
        case 'student':
          // Students can message their teachers
          final teachers = await _getStudentTeachers(userId);
          groupedContacts['Teachers'] = teachers;
          break;
          
        case 'teacher':
          // Teachers can message their students and students' parents
          final students = await _getTeacherStudents(userId);
          groupedContacts['Students'] = students;
          
          final parents = await _getTeacherStudentParents(userId);
          groupedContacts['Parents'] = parents;
          break;
          
        case 'parent':
          // Parents can message teachers of their children
          final childrenTeachers = await _getParentChildrenTeachers(userId);
          groupedContacts['Teachers'] = childrenTeachers;
          break;
      }
      
      // Remove empty groups
      groupedContacts.removeWhere((key, value) => value.isEmpty);
      
      return groupedContacts;
    } catch (e) {
      AppLogger.error('ChatPermissionService: Error getting grouped contacts: $e');
      return {};
    }
  }
  
  /// Check if teacher has an active teaching relationship with student
  Future<bool> hasActiveTeachingRelationship(String teacherId, String studentId) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: _shiftLookbackDays));
      
      // Query shifts where this teacher teaches this student
      final shiftsQuery = await _firestore
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: teacherId)
          .where('student_ids', arrayContains: studentId)
          .get();
      
      // Check if any shift is recent or upcoming
      for (final doc in shiftsQuery.docs) {
        final data = doc.data();
        final shiftEnd = (data['shift_end'] as Timestamp?)?.toDate();
        final status = data['status'] as String?;
        
        // Skip cancelled shifts
        if (status == 'cancelled') continue;
        
        // Check if shift is recent (within lookback period) or in the future
        if (shiftEnd != null && shiftEnd.isAfter(cutoffDate)) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      AppLogger.error('ChatPermissionService: Error checking teaching relationship: $e');
      return false;
    }
  }
  
  /// Check if teacher can message a parent (via teaching their children)
  Future<bool> canTeacherMessageParent(String teacherId, String parentId) async {
    try {
      // Get parent's children
      final parentDoc = await _firestore.collection('users').doc(parentId).get();
      if (!parentDoc.exists) return false;
      
      final parentData = parentDoc.data()!;
      final childrenIds = List<String>.from(parentData['children_ids'] ?? []);
      
      if (childrenIds.isEmpty) {
        // Also check if any students have this parent as guardian
        final studentsQuery = await _firestore
            .collection('users')
            .where('user_type', isEqualTo: 'student')
            .where('guardian_ids', arrayContains: parentId)
            .get();
        
        for (final doc in studentsQuery.docs) {
          childrenIds.add(doc.id);
        }
      }
      
      // Check if teacher teaches any of these children
      for (final childId in childrenIds) {
        if (await hasActiveTeachingRelationship(teacherId, childId)) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      AppLogger.error('ChatPermissionService: Error checking teacher-parent permission: $e');
      return false;
    }
  }
  
  /// Get the relationship type between two users
  Future<ChatRelationshipType> getRelationshipType(String userId1, String userId2) async {
    try {
      final user1Doc = await _firestore.collection('users').doc(userId1).get();
      final user2Doc = await _firestore.collection('users').doc(userId2).get();
      
      if (!user1Doc.exists || !user2Doc.exists) return ChatRelationshipType.none;
      
      final user1Role = (user1Doc.data()!['user_type'] as String?)?.toLowerCase() ?? '';
      final user2Role = (user2Doc.data()!['user_type'] as String?)?.toLowerCase() ?? '';
      
      // Check for admin relationship
      if (user1Role == 'admin' || user1Role == 'super_admin' ||
          user2Role == 'admin' || user2Role == 'super_admin') {
        return ChatRelationshipType.adminUser;
      }
      
      // Check for teacher-student relationship
      if ((user1Role == 'teacher' && user2Role == 'student') ||
          (user1Role == 'student' && user2Role == 'teacher')) {
        final teacherId = user1Role == 'teacher' ? userId1 : userId2;
        final studentId = user1Role == 'student' ? userId1 : userId2;
        if (await hasActiveTeachingRelationship(teacherId, studentId)) {
          return ChatRelationshipType.teacherStudent;
        }
      }
      
      // Check for teacher-parent relationship
      if ((user1Role == 'teacher' && user2Role == 'parent') ||
          (user1Role == 'parent' && user2Role == 'teacher')) {
        final teacherId = user1Role == 'teacher' ? userId1 : userId2;
        final parentId = user1Role == 'parent' ? userId1 : userId2;
        if (await canTeacherMessageParent(teacherId, parentId)) {
          return ChatRelationshipType.teacherParent;
        }
      }
      
      return ChatRelationshipType.none;
    } catch (e) {
      AppLogger.error('ChatPermissionService: Error getting relationship type: $e');
      return ChatRelationshipType.none;
    }
  }
  
  /// Get relationship context string for display
  Future<String?> getRelationshipContext(String userId1, String userId2) async {
    final relationship = await getRelationshipType(userId1, userId2);
    
    switch (relationship) {
      case ChatRelationshipType.teacherStudent:
        return 'Your teacher';
      case ChatRelationshipType.teacherParent:
        return 'Parent of your student';
      case ChatRelationshipType.adminUser:
        return 'Administrator';
      case ChatRelationshipType.none:
        return null;
    }
  }
  
  // Private helper methods
  
  Future<List<ChatUser>> _getAdminUsers() async {
    final adminsQuery = await _firestore
        .collection('users')
        .where('user_type', whereIn: ['admin', 'super_admin'])
        .get();
    
    return adminsQuery.docs.map((doc) => _docToChatUser(doc)).toList();
  }
  
  Future<List<ChatUser>> _getAllUsersExceptCurrent(String currentUserId) async {
    final usersQuery = await _firestore.collection('users').get();
    
    return usersQuery.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => _docToChatUser(doc))
        .toList();
  }
  
  Future<List<ChatUser>> _getStudentTeachers(String studentId) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: _shiftLookbackDays));
    final teacherIds = <String>{};
    
    // Get shifts where this student is assigned
    final shiftsQuery = await _firestore
        .collection('teaching_shifts')
        .where('student_ids', arrayContains: studentId)
        .get();
    
    for (final doc in shiftsQuery.docs) {
      final data = doc.data();
      final shiftEnd = (data['shift_end'] as Timestamp?)?.toDate();
      final status = data['status'] as String?;
      final teacherId = data['teacher_id'] as String?;
      
      if (status == 'cancelled' || teacherId == null) continue;
      
      if (shiftEnd != null && shiftEnd.isAfter(cutoffDate)) {
        teacherIds.add(teacherId);
      }
    }
    
    if (teacherIds.isEmpty) return [];
    
    // Fetch teacher user data
    final teacherDocs = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: teacherIds.toList())
        .get();
    
    return teacherDocs.docs.map((doc) => _docToChatUser(doc)).toList();
  }
  
  Future<List<ChatUser>> _getTeacherStudents(String teacherId) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: _shiftLookbackDays));
    final studentIds = <String>{};
    
    // Get shifts where this teacher is assigned
    final shiftsQuery = await _firestore
        .collection('teaching_shifts')
        .where('teacher_id', isEqualTo: teacherId)
        .get();
    
    for (final doc in shiftsQuery.docs) {
      final data = doc.data();
      final shiftEnd = (data['shift_end'] as Timestamp?)?.toDate();
      final status = data['status'] as String?;
      final shiftStudentIds = List<String>.from(data['student_ids'] ?? []);
      
      if (status == 'cancelled') continue;
      
      if (shiftEnd != null && shiftEnd.isAfter(cutoffDate)) {
        studentIds.addAll(shiftStudentIds);
      }
    }
    
    if (studentIds.isEmpty) return [];
    
    // Fetch student user data (Firestore whereIn limit is 30)
    final students = <ChatUser>[];
    final studentIdList = studentIds.toList();
    
    for (var i = 0; i < studentIdList.length; i += 30) {
      final batch = studentIdList.skip(i).take(30).toList();
      final studentDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      
      students.addAll(studentDocs.docs.map((doc) => _docToChatUser(doc)));
    }
    
    return students;
  }
  
  Future<List<ChatUser>> _getTeacherStudentParents(String teacherId) async {
    // First get all students this teacher teaches
    final students = await _getTeacherStudents(teacherId);
    final parentIds = <String>{};
    
    // Get parent IDs for each student
    for (final student in students) {
      final studentDoc = await _firestore.collection('users').doc(student.id).get();
      if (studentDoc.exists) {
        final guardianIds = List<String>.from(studentDoc.data()!['guardian_ids'] ?? []);
        parentIds.addAll(guardianIds);
      }
    }
    
    if (parentIds.isEmpty) return [];
    
    // Fetch parent user data
    final parents = <ChatUser>[];
    final parentIdList = parentIds.toList();
    
    for (var i = 0; i < parentIdList.length; i += 30) {
      final batch = parentIdList.skip(i).take(30).toList();
      final parentDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      
      parents.addAll(parentDocs.docs.map((doc) => _docToChatUser(doc)));
    }
    
    return parents;
  }
  
  Future<List<ChatUser>> _getParentChildrenTeachers(String parentId) async {
    final parentDoc = await _firestore.collection('users').doc(parentId).get();
    if (!parentDoc.exists) return [];
    
    final parentData = parentDoc.data()!;
    var childrenIds = List<String>.from(parentData['children_ids'] ?? []);
    
    // Also check for students with this parent as guardian
    if (childrenIds.isEmpty) {
      final studentsQuery = await _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'student')
          .where('guardian_ids', arrayContains: parentId)
          .get();
      
      childrenIds = studentsQuery.docs.map((doc) => doc.id).toList();
    }
    
    if (childrenIds.isEmpty) return [];
    
    // Get teachers for each child
    final teacherIds = <String>{};
    final cutoffDate = DateTime.now().subtract(Duration(days: _shiftLookbackDays));
    
    for (final childId in childrenIds) {
      final shiftsQuery = await _firestore
          .collection('teaching_shifts')
          .where('student_ids', arrayContains: childId)
          .get();
      
      for (final doc in shiftsQuery.docs) {
        final data = doc.data();
        final shiftEnd = (data['shift_end'] as Timestamp?)?.toDate();
        final status = data['status'] as String?;
        final teacherId = data['teacher_id'] as String?;
        
        if (status == 'cancelled' || teacherId == null) continue;
        
        if (shiftEnd != null && shiftEnd.isAfter(cutoffDate)) {
          teacherIds.add(teacherId);
        }
      }
    }
    
    if (teacherIds.isEmpty) return [];
    
    // Fetch teacher user data
    final teacherDocs = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: teacherIds.toList())
        .get();
    
    return teacherDocs.docs.map((doc) => _docToChatUser(doc)).toList();
  }
  
  ChatUser _docToChatUser(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatUser(
      id: doc.id,
      name: '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
      email: data['email'] ?? data['e-mail'] ?? '',
      profilePicture: data['profile_picture'],
      role: data['user_type'],
      isOnline: _isUserOnline(data['last_login']),
      lastSeen: (data['last_login'] as Timestamp?)?.toDate(),
    );
  }
  
  bool _isUserOnline(dynamic lastLogin) {
    if (lastLogin == null) return false;
    try {
      DateTime lastLoginTime;
      if (lastLogin is Timestamp) {
        lastLoginTime = lastLogin.toDate();
      } else if (lastLogin is String) {
        lastLoginTime = DateTime.parse(lastLogin);
      } else {
        return false;
      }
      return DateTime.now().difference(lastLoginTime).inMinutes < 5;
    } catch (e) {
      return false;
    }
  }
}
