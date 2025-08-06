import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing form drafts in Firestore
class FormDraft {
  final String id;
  final String title;
  final String description;
  final Map<String, dynamic> fields;
  final String createdBy;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
  final String? originalFormId; // If editing an existing form
  final Map<String, dynamic>? originalFormData; // Original form data if editing
  
  FormDraft({
    required this.id,
    required this.title,
    required this.description,
    required this.fields,
    required this.createdBy,
    required this.createdAt,
    required this.lastModifiedAt,
    this.originalFormId,
    this.originalFormData,
  });

  /// Factory constructor from Firestore document
  factory FormDraft.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FormDraft(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      fields: data['fields'] ?? {},
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastModifiedAt: (data['lastModifiedAt'] as Timestamp).toDate(),
      originalFormId: data['originalFormId'],
      originalFormData: data['originalFormData'],
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'fields': fields,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastModifiedAt': Timestamp.fromDate(lastModifiedAt),
      if (originalFormId != null) 'originalFormId': originalFormId,
      if (originalFormData != null) 'originalFormData': originalFormData,
    };
  }

  /// Create a copy with updated fields
  FormDraft copyWith({
    String? title,
    String? description,
    Map<String, dynamic>? fields,
    DateTime? lastModifiedAt,
    String? originalFormId,
    Map<String, dynamic>? originalFormData,
  }) {
    return FormDraft(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      fields: fields ?? this.fields,
      createdBy: createdBy,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      originalFormId: originalFormId ?? this.originalFormId,
      originalFormData: originalFormData ?? this.originalFormData,
    );
  }

  /// Get formatted last modified time for display
  String get lastModifiedFormatted {
    final now = DateTime.now();
    final difference = now.difference(lastModifiedAt);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${lastModifiedAt.day}/${lastModifiedAt.month}/${lastModifiedAt.year}';
    }
  }

  @override
  String toString() {
    return 'FormDraft(id: $id, title: $title, lastModified: $lastModifiedFormatted)';
  }
}