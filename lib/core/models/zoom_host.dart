import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Zoom host account used for creating meetings.
/// Multiple hosts enable concurrent meetings without conflicts.
class ZoomHost {
  final String id;
  final String email;
  final String displayName;
  final int maxConcurrentMeetings;
  final int priority;
  final bool isActive;
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? lastUsedAt;
  final DateTime? lastValidatedAt;
  final Map<String, dynamic>? zoomUserInfo;
  final bool isEnvFallback;

  // Utilization stats (populated from API)
  final int currentMeetings;
  final int upcomingMeetings;

  ZoomHost({
    required this.id,
    required this.email,
    required this.displayName,
    this.maxConcurrentMeetings = 1,
    this.priority = 0,
    this.isActive = true,
    this.notes,
    this.createdAt,
    this.createdBy,
    this.lastUsedAt,
    this.lastValidatedAt,
    this.zoomUserInfo,
    this.isEnvFallback = false,
    this.currentMeetings = 0,
    this.upcomingMeetings = 0,
  });

  factory ZoomHost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ZoomHost.fromMap(data, id: doc.id);
  }

  factory ZoomHost.fromMap(Map<String, dynamic> data, {String? id}) {
    return ZoomHost(
      id: id ?? data['id'] ?? '',
      email: data['email'] ?? '',
      displayName: data['display_name'] ?? data['displayName'] ?? data['email'] ?? '',
      maxConcurrentMeetings: data['max_concurrent_meetings'] ?? data['maxConcurrentMeetings'] ?? 1,
      priority: data['priority'] ?? 0,
      isActive: data['is_active'] ?? data['isActive'] ?? true,
      notes: data['notes'],
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
      createdBy: data['created_by'] ?? data['createdBy'],
      lastUsedAt: _parseDateTime(data['last_used_at'] ?? data['lastUsedAt']),
      lastValidatedAt: _parseDateTime(data['last_validated_at'] ?? data['lastValidatedAt']),
      zoomUserInfo: data['zoom_user_info'] ?? data['zoomUserInfo'],
      isEnvFallback: data['isEnvFallback'] ?? false,
      currentMeetings: data['currentMeetings'] ?? 0,
      upcomingMeetings: data['upcomingMeetings'] ?? 0,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'display_name': displayName,
      'max_concurrent_meetings': maxConcurrentMeetings,
      'priority': priority,
      'is_active': isActive,
      'notes': notes,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (createdBy != null) 'created_by': createdBy,
      if (lastUsedAt != null) 'last_used_at': Timestamp.fromDate(lastUsedAt!),
      if (lastValidatedAt != null) 'last_validated_at': Timestamp.fromDate(lastValidatedAt!),
      if (zoomUserInfo != null) 'zoom_user_info': zoomUserInfo,
    };
  }

  ZoomHost copyWith({
    String? id,
    String? email,
    String? displayName,
    int? maxConcurrentMeetings,
    int? priority,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
    DateTime? lastUsedAt,
    DateTime? lastValidatedAt,
    Map<String, dynamic>? zoomUserInfo,
    bool? isEnvFallback,
    int? currentMeetings,
    int? upcomingMeetings,
  }) {
    return ZoomHost(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      maxConcurrentMeetings: maxConcurrentMeetings ?? this.maxConcurrentMeetings,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      zoomUserInfo: zoomUserInfo ?? this.zoomUserInfo,
      isEnvFallback: isEnvFallback ?? this.isEnvFallback,
      currentMeetings: currentMeetings ?? this.currentMeetings,
      upcomingMeetings: upcomingMeetings ?? this.upcomingMeetings,
    );
  }

  /// Get utilization percentage for display
  double get utilizationPercentage {
    if (maxConcurrentMeetings == 0) return 0;
    return (currentMeetings / maxConcurrentMeetings) * 100;
  }

  /// Check if the host is at capacity
  bool get isAtCapacity => currentMeetings >= maxConcurrentMeetings;

  /// Get a display status string
  String get statusDisplay {
    if (!isActive) return 'Inactive';
    if (isAtCapacity) return 'At Capacity';
    return 'Available';
  }

  @override
  String toString() {
    return 'ZoomHost(id: $id, email: $email, displayName: $displayName, '
        'maxConcurrent: $maxConcurrentMeetings, priority: $priority, '
        'isActive: $isActive, current: $currentMeetings, upcoming: $upcomingMeetings)';
  }
}

/// Represents an alternative time slot suggestion when no hosts are available
class AlternativeTimeSlot {
  final DateTime start;
  final DateTime end;

  AlternativeTimeSlot({
    required this.start,
    required this.end,
  });

  factory AlternativeTimeSlot.fromMap(Map<String, dynamic> data) {
    return AlternativeTimeSlot(
      start: DateTime.parse(data['start']),
      end: DateTime.parse(data['end']),
    );
  }

  /// Get duration in minutes
  int get durationMinutes => end.difference(start).inMinutes;
}

/// Error response when no hosts are available
class NoAvailableHostError {
  final String code;
  final String message;
  final List<AlternativeTimeSlot> alternatives;
  final String? suggestion;

  NoAvailableHostError({
    required this.code,
    required this.message,
    this.alternatives = const [],
    this.suggestion,
  });

  factory NoAvailableHostError.fromMap(Map<String, dynamic> data) {
    final alternativesList = (data['alternatives'] as List<dynamic>?)
            ?.map((a) => AlternativeTimeSlot.fromMap(a as Map<String, dynamic>))
            .toList() ??
        [];

    return NoAvailableHostError(
      code: data['code'] ?? 'UNKNOWN_ERROR',
      message: data['message'] ?? 'An unknown error occurred',
      alternatives: alternativesList,
      suggestion: data['suggestion'],
    );
  }
}
