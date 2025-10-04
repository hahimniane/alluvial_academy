import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/enhanced_recurrence.dart';

enum TaskPriority { low, medium, high }

enum TaskStatus { todo, inProgress, done }

// Keep old enum for backward compatibility
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
  final RecurrenceType recurrenceType; // Keep for backward compatibility
  final EnhancedRecurrence enhancedRecurrence; // New enhanced recurrence
  final Timestamp createdAt;
  final List<TaskAttachment> attachments;
  // Completion tracking
  final Timestamp? completedAt; // when status first moved to done
  final int? overdueDaysAtCompletion; // freeze overdue days at completion

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
    this.enhancedRecurrence = const EnhancedRecurrence(),
    required this.createdAt,
    this.attachments = const [],
    this.completedAt,
    this.overdueDaysAtCompletion,
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

    // Handle enhanced recurrence (new format) or fallback to old format
    EnhancedRecurrence enhancedRecurrence;
    if (data['enhancedRecurrence'] != null) {
      enhancedRecurrence = EnhancedRecurrence.fromFirestore(
          Map<String, dynamic>.from(data['enhancedRecurrence']));
    } else {
      // Convert old recurrence format to enhanced format for backward compatibility
      final oldRecurrenceType = RecurrenceType.values.firstWhere(
        (e) => e.toString() == data['recurrenceType'],
        orElse: () => RecurrenceType.none,
      );
      enhancedRecurrence = _convertOldRecurrenceToEnhanced(oldRecurrenceType);
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
      enhancedRecurrence: enhancedRecurrence,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      attachments: attachmentsList,
      completedAt: data['completedAt'],
      overdueDaysAtCompletion: data['overdueDaysAtCompletion'],
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
      'recurrenceType':
          recurrenceType.toString(), // Keep for backward compatibility
      'enhancedRecurrence':
          enhancedRecurrence.toFirestore(), // New enhanced recurrence
      'createdAt': createdAt,
      'attachments':
          attachments.map((attachment) => attachment.toMap()).toList(),
      if (completedAt != null) 'completedAt': completedAt,
      if (overdueDaysAtCompletion != null)
        'overdueDaysAtCompletion': overdueDaysAtCompletion,
    };
  }

  /// Convert old RecurrenceType to EnhancedRecurrence for backward compatibility
  static EnhancedRecurrence _convertOldRecurrenceToEnhanced(
      RecurrenceType oldType) {
    switch (oldType) {
      case RecurrenceType.none:
        return const EnhancedRecurrence(type: EnhancedRecurrenceType.none);
      case RecurrenceType.daily:
        return const EnhancedRecurrence(type: EnhancedRecurrenceType.daily);
      case RecurrenceType.weekly:
        // Default to weekdays for weekly old format
        return const EnhancedRecurrence(
          type: EnhancedRecurrenceType.weekly,
          selectedWeekdays: [
            WeekDay.monday,
            WeekDay.tuesday,
            WeekDay.wednesday,
            WeekDay.thursday,
            WeekDay.friday
          ],
        );
      case RecurrenceType.monthly:
        // Default to 1st of the month for monthly old format
        return const EnhancedRecurrence(
          type: EnhancedRecurrenceType.monthly,
          selectedMonthDays: [1],
        );
    }
  }
}
