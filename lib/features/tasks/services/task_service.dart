import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/task.dart';
import '../../../core/services/user_role_service.dart';
import 'file_attachment_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class TaskService {
  final CollectionReference _taskCollection =
      FirebaseFirestore.instance.collection('tasks');
  final FileAttachmentService _fileService = FileAttachmentService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> createTask(Task task) async {
    // Get a document reference to get the ID first
    final docRef = _taskCollection.doc();

    // Create task with the generated ID
    final taskWithId = Task(
      id: docRef.id,
      title: task.title,
      description: task.description,
      createdBy: task.createdBy,
      assignedTo: task.assignedTo,
      dueDate: task.dueDate,
      priority: task.priority,
      status: task.status,
      isRecurring: task.isRecurring,
      recurrenceType: task.recurrenceType,
      enhancedRecurrence: task.enhancedRecurrence,
      createdAt: task.createdAt,
      attachments: task.attachments,
    );

    // Save the task with the proper ID
    await docRef.set(taskWithId.toFirestore());

    // Send email notifications to assigned users
    await _sendTaskAssignmentNotifications(taskWithId);
  }

  /// Send email notifications when a task is assigned
  Future<void> _sendTaskAssignmentNotifications(Task task) async {
    try {
      // Debug logging
      AppLogger.debug('TaskService: Sending notifications for task:');
      AppLogger.debug('  - Task ID: ${task.id}');
      AppLogger.debug('  - Task Title: ${task.title}');
      AppLogger.debug('  - Assigned To: ${task.assignedTo}');
      AppLogger.debug('  - Assigned To Length: ${task.assignedTo.length}');

      // Get the current user (task creator) information
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.debug('TaskService: No current user found');
        return;
      }

      // Get the creator's name from Firestore
      String assignedByName = 'System Administrator';
      try {
        final creatorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (creatorDoc.exists) {
          final creatorData = creatorDoc.data() as Map<String, dynamic>;
          final firstName = creatorData['first_name'] ?? '';
          final lastName = creatorData['last_name'] ?? '';
          assignedByName = '$firstName $lastName'.trim();

          if (assignedByName.isEmpty) {
            assignedByName = currentUser.email ?? 'System Administrator';
          }
        }
      } catch (e) {
        AppLogger.error('Error getting creator name: $e');
        // Fall back to email or default
        assignedByName = currentUser.email ?? 'System Administrator';
      }

      // Prepare data for the Cloud Function
      final functionData = {
        'taskId': task.id,
        'taskTitle': task.title,
        'taskDescription': task.description,
        'dueDate': task.dueDate.toIso8601String(),
        'assignedUserIds': task.assignedTo, // Ensure this is a list of UIDs
        'assignedByName': assignedByName,
      };

      // Debug logging for function data
      AppLogger.debug('TaskService: Function data being sent:');
      AppLogger.debug('  - taskId: ${functionData['taskId']}');
      AppLogger.debug('  - taskTitle: ${functionData['taskTitle']}');
      AppLogger.debug('  - assignedUserIds: ${functionData['assignedUserIds']}');
      AppLogger.debug(
          '  - assignedUserIds type: ${functionData['assignedUserIds'].runtimeType}');

      // Call the Cloud Function
      final HttpsCallable callable =
          _functions.httpsCallable('sendTaskAssignmentNotification');
      final result = await callable.call(functionData);

      AppLogger.debug('Email notification result: ${result.data}');

      // Log the results
      if (result.data['success']) {
        final emailsSent = result.data['emailsSent'] ?? 0;
        final emailsFailed = result.data['emailsFailed'] ?? 0;
        AppLogger.error(
            'Task assignment notifications sent - Success: $emailsSent, Failed: $emailsFailed');
      }
    } catch (e) {
      AppLogger.error('Error sending task assignment notifications: $e');
      // Don't throw - email failure shouldn't prevent task creation
    }
  }

  /// Send notifications for task updates (when assignees change)
  Future<void> _sendTaskUpdateNotifications(Task oldTask, Task newTask) async {
    try {
      // Find new assignees (users who weren't assigned before)
      final oldAssignees = Set<String>.from(oldTask.assignedTo);
      final newAssignees = Set<String>.from(newTask.assignedTo);
      final addedAssignees = newAssignees.difference(oldAssignees).toList();

      // Only send notifications if there are new assignees
      if (addedAssignees.isEmpty) return;

      // Get the current user (task updater) information
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String assignedByName = 'System Administrator';
      try {
        final creatorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (creatorDoc.exists) {
          final creatorData = creatorDoc.data() as Map<String, dynamic>;
          final firstName = creatorData['first_name'] ?? '';
          final lastName = creatorData['last_name'] ?? '';
          assignedByName = '$firstName $lastName'.trim();

          if (assignedByName.isEmpty) {
            assignedByName = currentUser.email ?? 'System Administrator';
          }
        }
      } catch (e) {
        AppLogger.error('Error getting updater name: $e');
        assignedByName = currentUser.email ?? 'System Administrator';
      }

      // Prepare data for the Cloud Function
      final functionData = {
        'taskId': newTask.id,
        'taskTitle': newTask.title,
        'taskDescription': newTask.description,
        'dueDate': newTask.dueDate.toIso8601String(),
        'assignedUserIds': addedAssignees, // Only send to new assignees
        'assignedByName': assignedByName,
      };

      // Call the Cloud Function
      final HttpsCallable callable =
          _functions.httpsCallable('sendTaskAssignmentNotification');
      final result = await callable.call(functionData);

      AppLogger.error('Email notification result for task update: ${result.data}');
    } catch (e) {
      AppLogger.error('Error sending task update notifications: $e');
      // Don't throw - email failure shouldn't prevent task update
    }
  }

  /// Send notifications for task status updates
  Future<void> _sendTaskStatusUpdateNotification(
      Task oldTask, Task newTask) async {
    try {
      // Get the current user (task updater) information
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String updatedByName = 'Unknown User';
      try {
        final updaterDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (updaterDoc.exists) {
          final updaterData = updaterDoc.data() as Map<String, dynamic>;
          final firstName = updaterData['first_name'] ?? '';
          final lastName = updaterData['last_name'] ?? '';
          updatedByName = '$firstName $lastName'.trim();

          if (updatedByName.isEmpty) {
            updatedByName = currentUser.email ?? 'Unknown User';
          }
        }
      } catch (e) {
        AppLogger.error('Error getting updater name: $e');
        updatedByName = currentUser.email ?? 'Unknown User';
      }

      // Prepare data for the Cloud Function
      final functionData = {
        'taskId': newTask.id,
        'taskTitle': newTask.title,
        'oldStatus':
            oldTask.status.toString().split('.').last, // Convert enum to string
        'newStatus':
            newTask.status.toString().split('.').last, // Convert enum to string
        'updatedByName': updatedByName,
        'createdBy': newTask.createdBy, // Send the task creator's ID
      };

      // Call the Cloud Function
      final HttpsCallable callable =
          _functions.httpsCallable('sendTaskStatusUpdateNotification');
      final result = await callable.call(functionData);

      AppLogger.error('Status update email notification result: ${result.data}');
    } catch (e) {
      AppLogger.error('Error sending task status update notifications: $e');
      // Don't throw - email failure shouldn't prevent task update
    }
  }

  Stream<List<Task>> getTasks() {
    return _taskCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      AppLogger.debug(
          'TaskService: getTasks() found ${snapshot.docs.length} tasks in database');
      final tasks =
          snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
      AppLogger.debug('TaskService: Converted to ${tasks.length} task objects');
      return tasks;
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
    try {
      // Ensure user is authenticated before checking role
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.debug('TaskService: No authenticated user found');
        return Stream.value([]);
      }

      AppLogger.debug('TaskService: Getting tasks for user: ${currentUser.uid}');
      final isAdmin = await UserRoleService.isAdmin();
      AppLogger.debug('TaskService: User is admin: $isAdmin');

      // Admins can see all tasks
      if (isAdmin) {
        AppLogger.debug('TaskService: Returning all tasks for admin');
        return getTasks();
      }

      // Non-admins only see tasks assigned to them
      AppLogger.error('TaskService: Returning assigned tasks for non-admin');
      return getAssignedTasks();
    } catch (e) {
      AppLogger.error('TaskService: Error getting role-based tasks: $e');
      // Fallback to assigned tasks if role check fails
      return getAssignedTasks();
    }
  }

  Future<void> updateTask(String taskId, Task task) async {
    // Get the old task to compare assignees and status
    final oldTaskDoc = await _taskCollection.doc(taskId).get();
    Task? oldTask;

    if (oldTaskDoc.exists) {
      oldTask = Task.fromFirestore(oldTaskDoc);
    }

    // Update the task
    await _taskCollection.doc(taskId).update(task.toFirestore());

    // Send notifications for new assignees if this is an update
    if (oldTask != null) {
      await _sendTaskUpdateNotifications(oldTask, task);

      // Send status update notification if status changed
      if (oldTask.status != task.status) {
        await _sendTaskStatusUpdateNotification(oldTask, task);
      }
    }
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
        completedAt: task.completedAt,
        overdueDaysAtCompletion: task.overdueDaysAtCompletion,
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
        completedAt: task.completedAt,
        overdueDaysAtCompletion: task.overdueDaysAtCompletion,
      );

      await updateTask(taskId, updatedTask);
    }
  }
}
