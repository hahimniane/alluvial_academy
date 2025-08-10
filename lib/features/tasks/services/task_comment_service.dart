import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/task_comment.dart';
import '../models/task.dart';

class TaskCommentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Add a new comment to a task
  static Future<void> addComment({
    required String taskId,
    required String comment,
    required Task task,
  }) async {
    try {
      print(
          '🔥 TaskCommentService.addComment() - Starting for taskId: $taskId');

      final user = _auth.currentUser;
      if (user == null) {
        print('🚨 TaskCommentService.addComment() - User not authenticated');
        throw Exception('User not authenticated');
      }

      print(
          '🔥 TaskCommentService.addComment() - Getting user data for uid: ${user.uid}');

      // Get user information
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final firstName = userData['first_name'] ?? '';
      final lastName = userData['last_name'] ?? '';
      final fullName = '$firstName $lastName'.trim();
      final email = userData['e-mail'] ?? user.email ?? '';

      print(
          '🔥 TaskCommentService.addComment() - User data retrieved: $fullName');

      // Create comment
      final taskComment = TaskComment(
        id: '', // Will be set by Firestore
        taskId: taskId,
        authorId: user.uid,
        authorName: fullName.isNotEmpty ? fullName : email,
        authorEmail: email,
        comment: comment,
        createdAt: DateTime.now(),
      );

      print('🔥 TaskCommentService.addComment() - Adding comment to Firestore');

      // Add to Firestore
      final docRef = await _firestore
          .collection('task_comments')
          .add(taskComment.toFirestore());

      print(
          '🔥 TaskCommentService.addComment() - Comment added with ID: ${docRef.id}');

      // Send email notifications to relevant users
      print('🔥 TaskCommentService.addComment() - Sending notifications');
      await _sendCommentNotifications(
        taskComment.copyWith(id: docRef.id),
        task,
      );

      print('✅ TaskCommentService.addComment() - Successfully completed');
    } catch (e) {
      print('🚨 TaskCommentService.addComment() - Error: $e');
      if (e is Exception) {
        print('🚨 Exception details: ${e.toString()}');
      }
      rethrow; // Re-throw to let the UI handle it
    }
  }

  /// Get comments for a specific task
  static Stream<List<TaskComment>> getTaskComments(String taskId) {
    print(
        '🔥 TaskCommentService.getTaskComments() - Getting comments for taskId: $taskId');

    return _firestore
        .collection('task_comments')
        .where('taskId', isEqualTo: taskId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      print(
          '🔥 TaskCommentService.getTaskComments() - Received ${snapshot.docs.length} comments');
      try {
        final comments =
            snapshot.docs.map((doc) => TaskComment.fromFirestore(doc)).toList();
        print(
            '✅ TaskCommentService.getTaskComments() - Successfully parsed ${comments.length} comments');
        return comments;
      } catch (e) {
        print(
            '🚨 TaskCommentService.getTaskComments() - Error parsing comments: $e');
        return <TaskComment>[];
      }
    });
  }

  /// Update an existing comment
  static Future<void> updateComment({
    required String commentId,
    required String newComment,
  }) async {
    try {
      print(
          '🔥 TaskCommentService.updateComment() - Starting for commentId: $commentId');

      final user = _auth.currentUser;
      if (user == null) {
        print('🚨 TaskCommentService.updateComment() - User not authenticated');
        throw Exception('User not authenticated');
      }

      print(
          '🔥 TaskCommentService.updateComment() - Updating comment in Firestore');

      await _firestore.collection('task_comments').doc(commentId).update({
        'comment': newComment,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'isEdited': true,
      });

      print('✅ TaskCommentService.updateComment() - Successfully completed');
    } catch (e) {
      print('🚨 TaskCommentService.updateComment() - Error: $e');
      if (e is Exception) {
        print('🚨 Exception details: ${e.toString()}');
      }
      rethrow; // Re-throw to let the UI handle it
    }
  }

  /// Delete a comment
  static Future<void> deleteComment(String commentId) async {
    try {
      print(
          '🔥 TaskCommentService.deleteComment() - Starting for commentId: $commentId');

      final user = _auth.currentUser;
      if (user == null) {
        print('🚨 TaskCommentService.deleteComment() - User not authenticated');
        throw Exception('User not authenticated');
      }

      print(
          '🔥 TaskCommentService.deleteComment() - Deleting comment from Firestore');

      await _firestore.collection('task_comments').doc(commentId).delete();

      print('✅ TaskCommentService.deleteComment() - Successfully completed');
    } catch (e) {
      print('🚨 TaskCommentService.deleteComment() - Error: $e');
      if (e is Exception) {
        print('🚨 Exception details: ${e.toString()}');
      }
      rethrow; // Re-throw to let the UI handle it
    }
  }

  /// Send email notifications when a comment is added
  static Future<void> _sendCommentNotifications(
    TaskComment comment,
    Task task,
  ) async {
    try {
      print(
          '🔥 TaskCommentService._sendCommentNotifications() - Starting notification process');
      print('🔥 Task: ${task.title} (ID: ${task.id})');
      print('🔥 Comment by: ${comment.authorName}');

      // Call HTTPS callable function to send email directly
      final functions = FirebaseFunctions.instance;
      final HttpsCallable callable =
          functions.httpsCallable('sendTaskCommentNotification');

      final payload = {
        'taskId': task.id,
        'commentAuthorId': comment.authorId,
        'commentAuthorName': comment.authorName,
        'commentText': comment.comment,
        'commentDate': comment.createdAt.toIso8601String(),
      };

      print('🔥 Calling sendTaskCommentNotification with payload:');
      print('  - taskId: ${payload['taskId']}');
      print('  - commentAuthorId: ${payload['commentAuthorId']}');
      print('  - commentAuthorName: ${payload['commentAuthorName']}');
      print('  - commentText: ${payload['commentText']}');

      final result = await callable.call(payload);
      print('✅ sendTaskCommentNotification result: ${result.data}');

      if (result.data['success'] == true) {
        final recipients = result.data['recipients'] as List?;
        print('✅ Email sent successfully to: ${recipients?.join(', ')}');
      } else {
        print('❌ Email sending failed: ${result.data['reason']}');
      }
    } catch (e) {
      print('🚨 TaskCommentService._sendCommentNotifications() - Error: $e');
      if (e is Exception) {
        print('🚨 Exception details: ${e.toString()}');
      }
      // Don't rethrow here as notification failures shouldn't block comment creation
    }
  }

  /// Get priority label for email template
  static String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  /// Get status label for email template
  static String _getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Completed';
    }
  }

  /// Get comment count for a task
  static Future<int> getCommentCount(String taskId) async {
    try {
      final snapshot = await _firestore
          .collection('task_comments')
          .where('taskId', isEqualTo: taskId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting comment count: $e');
      return 0;
    }
  }
}
