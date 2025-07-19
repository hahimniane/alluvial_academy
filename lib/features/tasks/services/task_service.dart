import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import '../../../core/services/user_role_service.dart';
import 'file_attachment_service.dart';

class TaskService {
  final CollectionReference _taskCollection =
      FirebaseFirestore.instance.collection('tasks');
  final FileAttachmentService _fileService = FileAttachmentService();

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
        .snapshots()
        .map((snapshot) {
      // Sort on the client side to avoid needing a composite index
      final tasks =
          snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tasks;
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
    // Get task to delete its attachments
    final taskDoc = await _taskCollection.doc(taskId).get();
    if (taskDoc.exists) {
      final task = Task.fromFirestore(taskDoc);
      // Delete all attachments from storage
      for (final attachment in task.attachments) {
        await _fileService.deleteFile(attachment, taskId);
      }
    }

    await _taskCollection.doc(taskId).delete();
  }

  /// Add attachment to task
  Future<void> addAttachmentToTask(
      String taskId, TaskAttachment attachment) async {
    final taskDoc = await _taskCollection.doc(taskId).get();
    if (taskDoc.exists) {
      final task = Task.fromFirestore(taskDoc);
      final updatedAttachments = [...task.attachments, attachment];

      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        createdBy: task.createdBy,
        assignedTo: task.assignedTo,
        dueDate: task.dueDate,
        priority: task.priority,
        status: task.status,
        isRecurring: task.isRecurring,
        recurrenceType: task.recurrenceType,
        createdAt: task.createdAt,
        attachments: updatedAttachments,
      );

      await updateTask(taskId, updatedTask);
    }
  }

  /// Remove attachment from task
  Future<void> removeAttachmentFromTask(
      String taskId, String attachmentId) async {
    final taskDoc = await _taskCollection.doc(taskId).get();
    if (taskDoc.exists) {
      final task = Task.fromFirestore(taskDoc);

      // Find the attachment to delete
      final attachmentToDelete = task.attachments.firstWhere(
        (attachment) => attachment.id == attachmentId,
        orElse: () => throw Exception('Attachment not found'),
      );

      // Delete from storage
      await _fileService.deleteFile(attachmentToDelete, taskId);

      // Remove from task
      final updatedAttachments = task.attachments
          .where((attachment) => attachment.id != attachmentId)
          .toList();

      final updatedTask = Task(
        id: task.id,
        title: task.title,
        description: task.description,
        createdBy: task.createdBy,
        assignedTo: task.assignedTo,
        dueDate: task.dueDate,
        priority: task.priority,
        status: task.status,
        isRecurring: task.isRecurring,
        recurrenceType: task.recurrenceType,
        createdAt: task.createdAt,
        attachments: updatedAttachments,
      );

      await updateTask(taskId, updatedTask);
    }
  }
}
