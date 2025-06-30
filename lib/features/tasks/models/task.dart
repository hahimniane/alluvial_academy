import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { low, medium, high }

enum TaskStatus { todo, inProgress, done }

enum RecurrenceType { none, daily, weekly, monthly }

class Task {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final List<String> assignedTo;
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final bool isRecurring;
  final RecurrenceType recurrenceType;
  final Timestamp createdAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.assignedTo,
    required this.dueDate,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.isRecurring = false,
    this.recurrenceType = RecurrenceType.none,
    required this.createdAt,
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    // Handle both old format (String) and new format (List<String>) for assignedTo
    List<String> assignedToList = [];
    if (data['assignedTo'] != null) {
      if (data['assignedTo'] is List) {
        // New format: already a list
        assignedToList = List<String>.from(data['assignedTo']);
      } else if (data['assignedTo'] is String) {
        // Old format: single string, convert to list
        assignedToList = [data['assignedTo'] as String];
      }
    }

    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      assignedTo: assignedToList,
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      priority: TaskPriority.values.firstWhere(
          (e) => e.toString() == data['priority'],
          orElse: () => TaskPriority.medium),
      status: TaskStatus.values.firstWhere(
          (e) => e.toString() == data['status'],
          orElse: () => TaskStatus.todo),
      isRecurring: data['isRecurring'] ?? false,
      recurrenceType: RecurrenceType.values.firstWhere(
          (e) => e.toString() == data['recurrenceType'],
          orElse: () => RecurrenceType.none),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'assignedTo': assignedTo,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority.toString(),
      'status': status.toString(),
      'isRecurring': isRecurring,
      'recurrenceType': recurrenceType.toString(),
      'createdAt': createdAt,
    };
  }
}
