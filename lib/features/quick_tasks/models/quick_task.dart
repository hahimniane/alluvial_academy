import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { low, medium, high }

enum RepeatInterval { none, daily, weekly, monthly }

class QuickTask {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final List<String> assigneeIds;
  final DateTime dueDate;
  final TaskPriority priority;
  final RepeatInterval repeat;
  final DateTime createdAt;
  final bool isCompleted;

  QuickTask({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.assigneeIds,
    required this.dueDate,
    required this.priority,
    required this.repeat,
    required this.createdAt,
    this.isCompleted = false,
  });

  factory QuickTask.fromMap(Map<String, dynamic> data, String id) {
    return QuickTask(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['created_by'] ?? '',
      assigneeIds: List<String>.from(data['assignees'] ?? []),
      dueDate: (data['due_date'] as Timestamp).toDate(),
      priority: TaskPriority.values.firstWhere(
          (e) => e.name == (data['priority'] ?? 'medium'),
          orElse: () => TaskPriority.medium),
      repeat: RepeatInterval.values.firstWhere(
          (e) => e.name == (data['repeat'] ?? 'none'),
          orElse: () => RepeatInterval.none),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      isCompleted: data['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'created_by': createdBy,
      'assignees': assigneeIds,
      'due_date': Timestamp.fromDate(dueDate),
      'priority': priority.name,
      'repeat': repeat.name,
      'created_at': Timestamp.fromDate(createdAt),
      'is_completed': isCompleted,
    };
  }
}
