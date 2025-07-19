import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import '../../../core/services/user_role_service.dart';

class TaskService {
  final CollectionReference _taskCollection =
      FirebaseFirestore.instance.collection('tasks');

  Future<void> createTask(Task task) async {
    await _taskCollection.add(task.toFirestore());
  }

  Stream<List<Task>> getTasks() {
    return _taskCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  /// Get tasks assigned to the current user (for teachers/students)
  Stream<List<Task>> getAssignedTasks() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _taskCollection
        .where('assignedTo', arrayContains: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  /// Get role-appropriate tasks based on user role
  Future<Stream<List<Task>>> getRoleBasedTasks() async {
    final isAdmin = await UserRoleService.isAdmin();

    // Admins can see all tasks
    if (isAdmin) {
      return getTasks();
    }

    // Non-admins only see tasks assigned to them
    return getAssignedTasks();
  }

  Future<void> updateTask(String taskId, Task task) async {
    await _taskCollection.doc(taskId).update(task.toFirestore());
  }

  Future<void> deleteTask(String taskId) async {
    await _taskCollection.doc(taskId).delete();
  }
}
