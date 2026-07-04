import 'package:cloud_firestore/cloud_firestore.dart';

class NoShowParticipantPresence {
  final String role;
  final String name;
  final String? userId;
  final DateTime? firstJoinedAt;
  final DateTime? lastLeftAt;
  final int? joinOffsetMinutes;
  final int totalPresentMinutes;
  final int joinCount;

  const NoShowParticipantPresence({
    required this.role,
    required this.name,
    this.userId,
    this.firstJoinedAt,
    this.lastLeftAt,
    this.joinOffsetMinutes,
    required this.totalPresentMinutes,
    required this.joinCount,
  });

  bool get joined =>
      firstJoinedAt != null || totalPresentMinutes > 0 || joinCount > 0;

  bool get joinedLate =>
      joined && joinOffsetMinutes != null && joinOffsetMinutes! > 0;
}

/// A single no-show report written by the `reportNoShow` callable into the
/// `no_show_reports` Firestore collection. See functions/handlers/no_show.js.
class NoShowReport {
  static const manualCollection = 'no_show_reports';
  static const attendanceAlertCollection = 'class_attendance_alerts';

  final String id;
  final String sourceCollection;
  final String shiftId;
  final String shiftName;
  final bool isTeacherNoShow;
  final bool isStudentNoShow;
  final String reportedBy;
  final String reporterName;
  final String? reporterRole;
  final String? teacherId;
  final String teacherName;
  final List<String> studentNames;
  final DateTime? occurredAt;
  final DateTime? createdAt;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;
  final int? detectedAfterMinutes;
  final String status;
  final bool hasDiagnostics;
  final String? reviewedBy;
  final String? reviewedByName;
  final String? reviewedByEmail;
  final DateTime? reviewedAt;
  final List<String> reviewActions;
  final List<String> reviewActionLabels;
  final String? reviewNote;
  final NoShowParticipantPresence? teacherPresence;
  final List<NoShowParticipantPresence> studentPresences;

  const NoShowReport({
    required this.id,
    this.sourceCollection = manualCollection,
    required this.shiftId,
    required this.shiftName,
    required this.isTeacherNoShow,
    required this.isStudentNoShow,
    required this.reportedBy,
    required this.reporterName,
    this.reporterRole,
    this.teacherId,
    required this.teacherName,
    required this.studentNames,
    this.occurredAt,
    this.createdAt,
    this.shiftStart,
    this.shiftEnd,
    this.detectedAfterMinutes,
    required this.status,
    required this.hasDiagnostics,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedByEmail,
    this.reviewedAt,
    this.reviewActions = const [],
    this.reviewActionLabels = const [],
    this.reviewNote,
    this.teacherPresence,
    this.studentPresences = const [],
  });

  bool get isReviewed => status.toLowerCase() == 'reviewed';

  String get reviewKey => '$sourceCollection/$id';

  /// Best available timestamp for display/sorting.
  DateTime? get when => occurredAt ?? createdAt;

  List<NoShowParticipantPresence> get relevantPresences => [
        if (isTeacherNoShow && teacherPresence != null) teacherPresence!,
        if (isStudentNoShow) ...studentPresences,
      ];

  /// The teacher grouping key for absence patterns (id preferred, name fallback).
  String get teacherKey =>
      (teacherId != null && teacherId!.isNotEmpty) ? teacherId! : teacherName;

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String && v.isNotEmpty) return int.tryParse(v);
    return null;
  }

  static List<String> _toStringList(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  static String _cleanString(dynamic v) => (v ?? '').toString().trim();

  static String? _optionalString(dynamic v) {
    final clean = _cleanString(v);
    return clean.isEmpty ? null : clean;
  }

  static List<String> _firstStringList(List<dynamic> values) {
    for (final value in values) {
      final list = _toStringList(value);
      if (list.isNotEmpty) return list;
    }
    return const [];
  }

  static String _classTeacherName(String className) {
    final parts = className.split(' - ').map((p) => p.trim()).toList();
    return parts.isNotEmpty ? parts.first : '';
  }

  static List<String> _classStudentNames(String className) {
    final parts = className.split(' - ').map((p) => p.trim()).toList();
    if (parts.length < 3) return const [];
    return parts
        .sublist(2)
        .join(' - ')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  factory NoShowReport.fromMap(String id, Map<String, dynamic> data) {
    final isTeacherNoShow = data['isTeacherNoShow'] == true;
    final isStudentNoShow = data['isStudentNoShow'] == true || !isTeacherNoShow;
    return NoShowReport(
      id: id,
      sourceCollection: _cleanString(data['sourceCollection']).isNotEmpty
          ? _cleanString(data['sourceCollection'])
          : manualCollection,
      shiftId: _cleanString(data['shiftId']),
      shiftName: _cleanString(data['shiftName']).isNotEmpty
          ? _cleanString(data['shiftName'])
          : 'Unknown Class',
      isTeacherNoShow: isTeacherNoShow,
      isStudentNoShow: isStudentNoShow,
      reportedBy: _cleanString(data['reportedBy']),
      reporterName: _cleanString(data['reporterName']),
      reporterRole: data['reporterRole']?.toString(),
      teacherId: data['teacherId']?.toString(),
      teacherName: _cleanString(data['teacherName']),
      studentNames: _toStringList(data['studentNames']),
      occurredAt: _toDate(data['timestamp']),
      createdAt: _toDate(data['createdAt']),
      shiftStart: _toDate(data['shiftStart']) ?? _toDate(data['shift_start']),
      shiftEnd: _toDate(data['shiftEnd']) ?? _toDate(data['shift_end']),
      detectedAfterMinutes: _toInt(data['minutesSinceStart']) ??
          _toInt(data['minutes_since_start']),
      status: _cleanString(data['status']).isNotEmpty
          ? _cleanString(data['status'])
          : 'pending',
      hasDiagnostics: data['hasDiagnostics'] == true,
      reviewedBy: _optionalString(data['reviewed_by']) ??
          data['reviewedBy']?.toString(),
      reviewedByName: _optionalString(data['reviewed_by_name']) ??
          _optionalString(data['reviewedByName']),
      reviewedByEmail: _optionalString(data['reviewed_by_email']) ??
          _optionalString(data['reviewedByEmail']),
      reviewedAt: _toDate(data['reviewed_at']) ?? _toDate(data['reviewedAt']),
      reviewActions: _firstStringList([
        data['review_actions'],
        data['reviewActions'],
      ]),
      reviewActionLabels: _firstStringList([
        data['review_action_labels'],
        data['reviewActionLabels'],
      ]),
      reviewNote: _optionalString(data['review_note']) ??
          _optionalString(data['reviewNote']),
    );
  }

  factory NoShowReport.fromAttendanceAlertMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final missing = _cleanString(data['missing']).toLowerCase();
    final className = _cleanString(data['class_name']).isNotEmpty
        ? _cleanString(data['class_name'])
        : _cleanString(data['className']);
    final reviewedAt =
        _toDate(data['reviewed_at']) ?? _toDate(data['reviewedAt']);
    final status = _cleanString(data['status']);
    final isReviewed = status.toLowerCase() == 'reviewed' || reviewedAt != null;

    return NoShowReport(
      id: id,
      sourceCollection: attendanceAlertCollection,
      shiftId: _cleanString(data['shift_id']).isNotEmpty
          ? _cleanString(data['shift_id'])
          : _cleanString(data['shiftId']),
      shiftName: className.isNotEmpty ? className : 'Unknown Class',
      isTeacherNoShow: missing == 'teacher' || missing == 'both',
      isStudentNoShow:
          missing == 'students' || missing == 'student' || missing == 'both',
      reportedBy: '',
      reporterName: '',
      reporterRole: 'system',
      teacherId: _cleanString(data['teacher_id']).isNotEmpty
          ? _cleanString(data['teacher_id'])
          : data['teacherId']?.toString(),
      teacherName: _cleanString(data['teacher_name']).isNotEmpty
          ? _cleanString(data['teacher_name'])
          : _classTeacherName(className),
      studentNames: _toStringList(data['student_names']).isNotEmpty
          ? _toStringList(data['student_names'])
          : _classStudentNames(className),
      occurredAt: _toDate(data['first_detected_at']) ??
          _toDate(data['last_alert_at']) ??
          _toDate(data['updated_at']),
      createdAt: _toDate(data['updated_at']),
      detectedAfterMinutes: _toInt(data['minutes_since_start']) ??
          _toInt(data['minutesSinceStart']),
      status: isReviewed ? 'reviewed' : 'pending',
      hasDiagnostics: false,
      reviewedBy: _optionalString(data['reviewed_by']) ??
          data['reviewedBy']?.toString(),
      reviewedByName: _optionalString(data['reviewed_by_name']) ??
          _optionalString(data['reviewedByName']),
      reviewedByEmail: _optionalString(data['reviewed_by_email']) ??
          _optionalString(data['reviewedByEmail']),
      reviewedAt: reviewedAt,
      reviewActions: _firstStringList([
        data['review_actions'],
        data['reviewActions'],
      ]),
      reviewActionLabels: _firstStringList([
        data['review_action_labels'],
        data['reviewActionLabels'],
      ]),
      reviewNote: _optionalString(data['review_note']) ??
          _optionalString(data['reviewNote']),
    );
  }

  factory NoShowReport.fromFirestore(DocumentSnapshot doc) {
    return NoShowReport.fromMap(
      doc.id,
      (doc.data() as Map<String, dynamic>?) ?? const {},
    );
  }

  factory NoShowReport.fromAttendanceAlertFirestore(DocumentSnapshot doc) {
    return NoShowReport.fromAttendanceAlertMap(
      doc.id,
      (doc.data() as Map<String, dynamic>?) ?? const {},
    );
  }

  NoShowReport copyWith({
    String? status,
    String? reviewedBy,
    String? reviewedByName,
    String? reviewedByEmail,
    DateTime? reviewedAt,
    List<String>? reviewActions,
    List<String>? reviewActionLabels,
    String? reviewNote,
    DateTime? shiftStart,
    DateTime? shiftEnd,
    int? detectedAfterMinutes,
    NoShowParticipantPresence? teacherPresence,
    List<NoShowParticipantPresence>? studentPresences,
  }) {
    return NoShowReport(
      id: id,
      sourceCollection: sourceCollection,
      shiftId: shiftId,
      shiftName: shiftName,
      isTeacherNoShow: isTeacherNoShow,
      isStudentNoShow: isStudentNoShow,
      reportedBy: reportedBy,
      reporterName: reporterName,
      reporterRole: reporterRole,
      teacherId: teacherId,
      teacherName: teacherName,
      studentNames: studentNames,
      occurredAt: occurredAt,
      createdAt: createdAt,
      shiftStart: shiftStart ?? this.shiftStart,
      shiftEnd: shiftEnd ?? this.shiftEnd,
      detectedAfterMinutes: detectedAfterMinutes ?? this.detectedAfterMinutes,
      status: status ?? this.status,
      hasDiagnostics: hasDiagnostics,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewedByEmail: reviewedByEmail ?? this.reviewedByEmail,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewActions: reviewActions ?? this.reviewActions,
      reviewActionLabels: reviewActionLabels ?? this.reviewActionLabels,
      reviewNote: reviewNote ?? this.reviewNote,
      teacherPresence: teacherPresence ?? this.teacherPresence,
      studentPresences: studentPresences ?? this.studentPresences,
    );
  }
}
