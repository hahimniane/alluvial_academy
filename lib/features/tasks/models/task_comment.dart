import 'package:cloud_firestore/cloud_firestore.dart';

class TaskComment {
  final String id;
  final String taskId;
  final String authorId;
  final String authorName;
  final String authorEmail;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;

  TaskComment({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.authorName,
    required this.authorEmail,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
  });

  factory TaskComment.fromFirestore(DocumentSnapshot doc) {
    try {
      print('🔥 TaskComment.fromFirestore() - Parsing document: ${doc.id}');

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      print('🔥 Document data keys: ${data.keys.toList()}');

      final comment = TaskComment(
        id: doc.id,
        taskId: data['taskId'] ?? '',
        authorId: data['authorId'] ?? '',
        authorName: data['authorName'] ?? '',
        authorEmail: data['authorEmail'] ?? '',
        comment: data['comment'] ?? '',
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        updatedAt: data['updatedAt'] != null
            ? (data['updatedAt'] as Timestamp).toDate()
            : null,
        isEdited: data['isEdited'] ?? false,
      );

      print(
          '✅ TaskComment.fromFirestore() - Successfully parsed comment from ${comment.authorName}');
      return comment;
    } catch (e) {
      print(
          '🚨 TaskComment.fromFirestore() - Error parsing document ${doc.id}: $e');
      print('🚨 Document data: ${doc.data()}');
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'authorId': authorId,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isEdited': isEdited,
    };
  }

  TaskComment copyWith({
    String? id,
    String? taskId,
    String? authorId,
    String? authorName,
    String? authorEmail,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
  }) {
    return TaskComment(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}
