import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { low, medium, high }

enum TaskStatus { todo, inProgress, done }

enum RecurrenceType { none, daily, weekly, monthly }

class TaskAttachment {
  final String id;
  final String fileName;
  final String originalName;
  final String downloadUrl;
  final String fileType;
  final int fileSize;
  final DateTime uploadedAt;
  final String uploadedBy;

  TaskAttachment({
    required this.id,
    required this.fileName,
    required this.originalName,
    required this.downloadUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  factory TaskAttachment.fromMap(Map<String, dynamic> map) {
    return TaskAttachment(
      id: map['id'] ?? '',
      fileName: map['fileName'] ?? '',
      originalName: map['originalName'] ?? '',
      downloadUrl: map['downloadUrl'] ?? '',
      fileType: map['fileType'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      uploadedAt: map['uploadedAt'] is Timestamp
          ? (map['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
      uploadedBy: map['uploadedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'originalName': originalName,
      'downloadUrl': downloadUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedBy': uploadedBy,
    };
  }
}

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
  final List<TaskAttachment> attachments;

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
    this.attachments = const [],
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

    // Handle attachments
    List<TaskAttachment> attachmentsList = [];
    if (data['attachments'] != null && data['attachments'] is List) {
      attachmentsList = (data['attachments'] as List)
          .map((attachmentData) =>
              TaskAttachment.fromMap(Map<String, dynamic>.from(attachmentData)))
          .toList();
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
      attachments: attachmentsList,
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
      'attachments':
          attachments.map((attachment) => attachment.toMap()).toList(),
    };
  }
}
