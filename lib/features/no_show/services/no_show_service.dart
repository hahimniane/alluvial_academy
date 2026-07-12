import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:alluwalacademyadmin/core/models/employee_model.dart';
import '../models/no_show_report.dart';

/// Per-teacher absence aggregate used by the No-Show Alerts patterns band.
class TeacherNoShowPattern {
  final String teacherKey;
  final String teacherName;
  final int total;
  final int teacherNoShows;
  final int studentNoShows;
  final int pending;
  final DateTime? lastOccurred;

  const TeacherNoShowPattern({
    required this.teacherKey,
    required this.teacherName,
    required this.total,
    required this.teacherNoShows,
    required this.studentNoShows,
    required this.pending,
    this.lastOccurred,
  });
}

class NoShowReviewUpdate {
  final String? reviewedBy;
  final String? reviewedByName;
  final String? reviewedByEmail;
  final DateTime reviewedAt;
  final List<String> reviewActions;
  final List<String> reviewActionLabels;
  final String? reviewNote;

  const NoShowReviewUpdate({
    required this.reviewedBy,
    required this.reviewedByName,
    required this.reviewedByEmail,
    required this.reviewedAt,
    required this.reviewActions,
    required this.reviewActionLabels,
    required this.reviewNote,
  });
}

class _ReviewerIdentity {
  final String? name;
  final String? email;

  const _ReviewerIdentity({required this.name, required this.email});
}

class _ShiftParticipant {
  final String id;
  final String name;

  const _ShiftParticipant({required this.id, required this.name});
}

class _ShiftMeta {
  final _ShiftParticipant teacher;
  final List<_ShiftParticipant> students;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;

  const _ShiftMeta({
    required this.teacher,
    required this.students,
    this.shiftStart,
    this.shiftEnd,
  });
}

class _RawPresenceWindow {
  final DateTime joinAt;
  final DateTime? leaveAt;

  const _RawPresenceWindow({required this.joinAt, this.leaveAt});
}

class _PresenceWindow {
  final DateTime start;
  final DateTime end;

  const _PresenceWindow({required this.start, required this.end});
}

class NoShowService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = NoShowReport.manualCollection;
  static const String _attendanceAlertCollection =
      NoShowReport.attendanceAlertCollection;
  static const String _sessionCollection = 'livekit_sessions';
  static const String _shiftCollection = 'teaching_shifts';
  static const String _usersCollection = 'users';

  static Future<List<Employee>> fetchAvailableTeachers() =>
      _fetchAvailablePeople('teacher');

  static Future<List<Employee>> fetchAvailableStudents() =>
      _fetchAvailablePeople('student');

  /// Most recent no-show alerts. This merges the older participant-created
  /// reports with the scheduled attendance alerts that power admin notifications.
  static Future<List<NoShowReport>> fetchReports({
    int limitN = 120,
    bool enrich = true,
    int enrichLimit = 80,
  }) async {
    final snapshots = await Future.wait([
      _db
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .limit(limitN)
          .get(),
      _db
          .collection(_attendanceAlertCollection)
          .orderBy('first_detected_at', descending: true)
          .limit(limitN)
          .get(),
    ]);
    final manualSnap = snapshots[0];
    final attendanceSnap = snapshots[1];

    final reports = <NoShowReport>[
      ...manualSnap.docs.map(NoShowReport.fromFirestore),
      ...attendanceSnap.docs.map(NoShowReport.fromAttendanceAlertFirestore),
    ];
    reports.sort((a, b) {
      final aWhen = a.when;
      final bWhen = b.when;
      if (aWhen == null && bWhen == null) return 0;
      if (aWhen == null) return 1;
      if (bWhen == null) return -1;
      return bWhen.compareTo(aWhen);
    });
    final limited = reports.take(limitN).toList(growable: false);
    if (!enrich) return limited;

    final detailCount = enrichLimit.clamp(0, limited.length);
    final enriched =
        await enrichReports(limited.take(detailCount).toList(growable: false));
    if (detailCount == limited.length) return enriched;
    return [
      ...enriched,
      ...limited.skip(detailCount),
    ];
  }

  /// Mark a report reviewed in whichever alert collection produced it.
  static Future<NoShowReviewUpdate> markReviewed(
    NoShowReport report, {
    List<String> actionKeys = const [],
    List<String> actionLabels = const [],
    String? note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final reviewer = await _reviewerIdentity(user);
    final cleanActionKeys = _cleanStrings(actionKeys);
    final cleanActionLabels = _cleanStrings(actionLabels);
    final cleanNote = _cleanString(note);
    final reviewedAt = DateTime.now();

    final update = <String, dynamic>{
      'status': 'reviewed',
      'reviewed_at': FieldValue.serverTimestamp(),
      'review_actions': cleanActionKeys,
      'review_action_labels': cleanActionLabels,
    };
    if (uid != null && uid.isNotEmpty) update['reviewed_by'] = uid;
    if (reviewer.name != null) update['reviewed_by_name'] = reviewer.name;
    if (reviewer.email != null) update['reviewed_by_email'] = reviewer.email;
    if (cleanNote.isNotEmpty) {
      update['review_note'] = cleanNote;
    } else {
      update['review_note'] = FieldValue.delete();
    }

    await _db.collection(report.sourceCollection).doc(report.id).update(update);
    return NoShowReviewUpdate(
      reviewedBy: uid,
      reviewedByName: reviewer.name,
      reviewedByEmail: reviewer.email,
      reviewedAt: reviewedAt,
      reviewActions: cleanActionKeys,
      reviewActionLabels: cleanActionLabels,
      reviewNote: cleanNote.isEmpty ? null : cleanNote,
    );
  }

  /// Pure aggregation: group reports by the class's teacher and rank by
  /// teacher no-shows (the "absent teacher" signal), then by total.
  static List<TeacherNoShowPattern> computeTeacherPatterns(
    List<NoShowReport> reports,
  ) {
    final byTeacher = <String, List<NoShowReport>>{};
    for (final r in reports) {
      final key = r.teacherKey;
      if (key.isEmpty) continue;
      byTeacher.putIfAbsent(key, () => []).add(r);
    }

    final patterns = byTeacher.entries.map((entry) {
      final rs = entry.value;
      final teacherNoShows = rs.where((r) => r.isTeacherNoShow).length;
      final studentNoShows = rs.where((r) => r.isStudentNoShow).length;
      final pending = rs.where((r) => !r.isReviewed).length;
      DateTime? last;
      for (final r in rs) {
        final w = r.when;
        if (w != null && (last == null || w.isAfter(last))) last = w;
      }
      final name = rs
          .map((r) => r.teacherName)
          .firstWhere((n) => n.isNotEmpty, orElse: () => entry.key);
      return TeacherNoShowPattern(
        teacherKey: entry.key,
        teacherName: name,
        total: rs.length,
        teacherNoShows: teacherNoShows,
        studentNoShows: studentNoShows,
        pending: pending,
        lastOccurred: last,
      );
    }).toList();

    patterns.sort((a, b) {
      final byTeacherAbsence = b.teacherNoShows.compareTo(a.teacherNoShows);
      if (byTeacherAbsence != 0) return byTeacherAbsence;
      return b.total.compareTo(a.total);
    });
    return patterns;
  }

  static Future<List<NoShowReport>> enrichReports(
    List<NoShowReport> reports,
  ) async {
    final shiftIds = reports
        .map((r) => r.shiftId)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (shiftIds.isEmpty) return reports;

    final details = await Future.wait([
      _fetchShiftMeta(shiftIds),
      _fetchSessions(shiftIds),
    ]);
    final shiftMetaById = details[0] as Map<String, _ShiftMeta>;
    final sessionsByShiftId =
        details[1] as Map<String, List<Map<String, dynamic>>>;

    return reports
        .map((report) => _enrichReport(
              report,
              shiftMetaById[report.shiftId],
              sessionsByShiftId[report.shiftId] ?? const [],
            ))
        .toList(growable: false);
  }

  static Future<Map<String, _ShiftMeta>> _fetchShiftMeta(
    List<String> shiftIds,
  ) async {
    final result = <String, _ShiftMeta>{};
    final snapshots = await Future.wait(
      _chunks(shiftIds, 10).map((chunk) {
        return _db
            .collection(_shiftCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
      }),
    );
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        result[doc.id] = _shiftMetaFromMap(doc.data());
      }
    }
    return result;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> _fetchSessions(
    List<String> shiftIds,
  ) async {
    final result = <String, List<Map<String, dynamic>>>{};
    final snapshots = await Future.wait(
      _chunks(shiftIds, 10).map((chunk) {
        return _db
            .collection(_sessionCollection)
            .where('shift_id', whereIn: chunk)
            .get();
      }),
    );
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        final data = doc.data();
        final shiftId = _cleanString(data['shift_id']).isNotEmpty
            ? _cleanString(data['shift_id'])
            : _cleanString(data['shiftId']);
        if (shiftId.isEmpty) continue;
        result.putIfAbsent(shiftId, () => []).add(data);
      }
    }
    return result;
  }

  static NoShowReport _enrichReport(
    NoShowReport report,
    _ShiftMeta? meta,
    List<Map<String, dynamic>> sessions,
  ) {
    final shiftStart = meta?.shiftStart ?? report.shiftStart;
    final shiftEnd = meta?.shiftEnd ?? report.shiftEnd;
    final detectedAfterMinutes = report.detectedAfterMinutes ??
        _minutesAfterStart(report.when, shiftStart);
    final teacher = _ShiftParticipant(
      id: meta?.teacher.id ?? report.teacherId ?? '',
      name: _firstNonEmpty([
        meta?.teacher.name,
        report.teacherName,
        report.shiftName.split(' - ').first,
      ]),
    );
    final students = meta?.students.isNotEmpty == true
        ? meta!.students
        : report.studentNames
            .map((name) => _ShiftParticipant(id: '', name: name))
            .toList(growable: false);

    return report.copyWith(
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      detectedAfterMinutes: detectedAfterMinutes,
      teacherPresence: teacher.name.isNotEmpty || teacher.id.isNotEmpty
          ? _presenceForParticipant(
              role: 'teacher',
              participant: teacher,
              sessions: sessions,
              shiftStart: shiftStart,
              shiftEnd: shiftEnd,
            )
          : null,
      studentPresences: students
          .map((student) => _presenceForParticipant(
                role: 'student',
                participant: student,
                sessions: sessions,
                shiftStart: shiftStart,
                shiftEnd: shiftEnd,
              ))
          .toList(growable: false),
    );
  }

  static NoShowParticipantPresence _presenceForParticipant({
    required String role,
    required _ShiftParticipant participant,
    required List<Map<String, dynamic>> sessions,
    required DateTime? shiftStart,
    required DateTime? shiftEnd,
  }) {
    final matching = sessions.where((session) {
      final userId = _cleanString(session['user_id']).isNotEmpty
          ? _cleanString(session['user_id'])
          : _cleanString(session['userId']);
      if (participant.id.isNotEmpty) return userId == participant.id;

      final sessionRole = _cleanString(session['role']).toLowerCase();
      if (role == 'teacher') return sessionRole == 'teacher';
      return sessionRole == 'student' || sessionRole == 'participant';
    }).toList(growable: false);

    final rawWindows = <_RawPresenceWindow>[];
    var joinCount = 0;
    for (final session in matching) {
      final windows = _rawWindowsForSession(session);
      rawWindows.addAll(windows);
      joinCount += _toInt(session['join_count']) ?? windows.length;
    }
    rawWindows.sort((a, b) => a.joinAt.compareTo(b.joinAt));

    final firstJoinedAt = rawWindows.isEmpty ? null : rawWindows.first.joinAt;
    DateTime? lastLeftAt;
    for (final window in rawWindows) {
      final leaveAt = window.leaveAt;
      if (leaveAt != null &&
          (lastLeftAt == null || leaveAt.isAfter(lastLeftAt))) {
        lastLeftAt = leaveAt;
      }
    }

    final clippedWindows = rawWindows
        .map((window) => _clipWindow(
              window,
              shiftStart: shiftStart,
              shiftEnd: shiftEnd,
            ))
        .whereType<_PresenceWindow>()
        .toList(growable: false);
    final totalSeconds = _mergedWindows(clippedWindows).fold<int>(
      0,
      (total, window) => total + window.end.difference(window.start).inSeconds,
    );
    final totalMinutes = totalSeconds <= 0 ? 0 : (totalSeconds / 60).ceil();

    return NoShowParticipantPresence(
      role: role,
      name: participant.name,
      userId: participant.id.isEmpty ? null : participant.id,
      firstJoinedAt: firstJoinedAt,
      lastLeftAt: lastLeftAt,
      joinOffsetMinutes: firstJoinedAt == null || shiftStart == null
          ? null
          : firstJoinedAt.difference(shiftStart).inMinutes,
      totalPresentMinutes: totalMinutes,
      joinCount: joinCount,
    );
  }

  static _ShiftMeta _shiftMetaFromMap(Map<String, dynamic> data) {
    final studentIds = _stringList(data['student_ids']).isNotEmpty
        ? _stringList(data['student_ids'])
        : _stringList(data['studentIds']);
    final studentNames = _stringList(data['student_names']).isNotEmpty
        ? _stringList(data['student_names'])
        : _stringList(data['studentNames']);
    final studentCount = studentIds.length > studentNames.length
        ? studentIds.length
        : studentNames.length;
    final students = <_ShiftParticipant>[];
    for (var i = 0; i < studentCount; i++) {
      final id = i < studentIds.length ? studentIds[i] : '';
      final name = i < studentNames.length ? studentNames[i] : '';
      if (id.isEmpty && name.isEmpty) continue;
      students.add(_ShiftParticipant(id: id, name: name));
    }

    return _ShiftMeta(
      teacher: _ShiftParticipant(
        id: _cleanString(data['teacher_id']).isNotEmpty
            ? _cleanString(data['teacher_id'])
            : _cleanString(data['teacherId']),
        name: _cleanString(data['teacher_name']).isNotEmpty
            ? _cleanString(data['teacher_name'])
            : _cleanString(data['teacherName']),
      ),
      students: students,
      shiftStart: _toDate(data['shift_start']) ?? _toDate(data['shiftStart']),
      shiftEnd: _toDate(data['shift_end']) ?? _toDate(data['shiftEnd']),
    );
  }

  static List<_RawPresenceWindow> _rawWindowsForSession(
    Map<String, dynamic> session,
  ) {
    final sessionLeftAt =
        _toDate(session['left_at']) ?? _toDate(session['leftAt']);
    final rawWindows = session['presence_windows'];
    if (rawWindows is List && rawWindows.isNotEmpty) {
      return rawWindows
          .whereType<Map>()
          .map((raw) {
            final joinAt = _toDate(raw['join_at']) ?? _toDate(raw['joinAt']);
            if (joinAt == null) return null;
            var leaveAt = _toDate(raw['leave_at']) ?? _toDate(raw['leaveAt']);
            if (leaveAt == null || !leaveAt.isAfter(joinAt)) {
              leaveAt = sessionLeftAt != null && sessionLeftAt.isAfter(joinAt)
                  ? sessionLeftAt
                  : null;
            }
            return _RawPresenceWindow(joinAt: joinAt, leaveAt: leaveAt);
          })
          .whereType<_RawPresenceWindow>()
          .toList(growable: false);
    }

    final joinedAt =
        _toDate(session['joined_at']) ?? _toDate(session['joinedAt']);
    if (joinedAt == null) return const [];
    final leftAt = sessionLeftAt != null && sessionLeftAt.isAfter(joinedAt)
        ? sessionLeftAt
        : null;
    return [_RawPresenceWindow(joinAt: joinedAt, leaveAt: leftAt)];
  }

  static _PresenceWindow? _clipWindow(
    _RawPresenceWindow window, {
    required DateTime? shiftStart,
    required DateTime? shiftEnd,
  }) {
    final now = DateTime.now();
    var start = window.joinAt;
    var end = window.leaveAt ?? now;
    if (shiftStart != null && start.isBefore(shiftStart)) start = shiftStart;
    if (shiftEnd != null && end.isAfter(shiftEnd)) end = shiftEnd;
    if (!end.isAfter(start)) return null;
    return _PresenceWindow(start: start, end: end);
  }

  static List<_PresenceWindow> _mergedWindows(List<_PresenceWindow> windows) {
    if (windows.length < 2) return windows;
    final sorted = [...windows]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <_PresenceWindow>[];
    var current = sorted.first;
    for (final next in sorted.skip(1)) {
      if (!next.start.isAfter(current.end)) {
        if (next.end.isAfter(current.end)) {
          current = _PresenceWindow(start: current.start, end: next.end);
        }
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return merged;
  }

  static int? _minutesAfterStart(DateTime? detectedAt, DateTime? shiftStart) {
    if (detectedAt == null || shiftStart == null) return null;
    final minutes = detectedAt.difference(shiftStart).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  static Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
    for (var i = 0; i < values.length; i += size) {
      final end = i + size > values.length ? values.length : i + size;
      yield values.sublist(i, end);
    }
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String && value.isNotEmpty) return int.tryParse(value);
    return null;
  }

  static String _cleanString(dynamic value) => (value ?? '').toString().trim();

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => _cleanString(item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _cleanStrings(Iterable<String> values) {
    return values
        .map(_cleanString)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final clean = _cleanString(value);
      if (clean.isNotEmpty) return clean;
    }
    return '';
  }

  static Future<_ReviewerIdentity> _reviewerIdentity(User? user) async {
    if (user == null) return const _ReviewerIdentity(name: null, email: null);

    var email = _cleanString(user.email);
    var name = _cleanString(user.displayName);

    try {
      final doc = await _db.collection(_usersCollection).doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        final firstName = _firstNonEmpty([
          data['first_name']?.toString(),
          data['firstName']?.toString(),
        ]);
        final lastName = _firstNonEmpty([
          data['last_name']?.toString(),
          data['lastName']?.toString(),
        ]);
        name = _firstNonEmpty([
          data['display_name']?.toString(),
          data['displayName']?.toString(),
          '$firstName $lastName',
          data['name']?.toString(),
          name,
        ]);
        email = _firstNonEmpty([
          data['email']?.toString(),
          data['personal_email']?.toString(),
          data['personalEmail']?.toString(),
          email,
        ]);
      }
    } catch (_) {}

    final cleanEmail = _cleanString(email);
    final cleanName = _firstNonEmpty([
      name,
      cleanEmail,
      user.uid,
    ]);
    return _ReviewerIdentity(
      name: cleanName.isEmpty ? null : cleanName,
      email: cleanEmail.isEmpty ? null : cleanEmail,
    );
  }

  static Future<List<Employee>> _fetchAvailablePeople(String role) async {
    final people = <Employee>[];
    final seen = <String>{};

    Future<void> addSnapshot(QuerySnapshot snapshot) async {
      for (final employee
          in EmployeeDataSource.mapSnapshotToEmployeeList(snapshot)) {
        if (seen.add(employee.documentId)) people.add(employee);
      }
    }

    try {
      final primary = await _db
          .collection(_usersCollection)
          .where('user_type', isEqualTo: role)
          .where('is_active', isEqualTo: true)
          .get();
      await addSnapshot(primary);
      if (people.isEmpty) {
        final fallback = await _db
            .collection(_usersCollection)
            .where('user_type', isEqualTo: role)
            .get();
        await addSnapshot(fallback);
      }
    } catch (_) {
      try {
        final fallback = await _db
            .collection(_usersCollection)
            .where('user_type', isEqualTo: role)
            .get();
        await addSnapshot(fallback);
      } catch (_) {}
    }

    try {
      final secondary = await _db
          .collection(_usersCollection)
          .where('secondary_roles', arrayContains: role)
          .where('is_active', isEqualTo: true)
          .get();
      await addSnapshot(secondary);
    } catch (_) {
      try {
        final secondary = await _db
            .collection(_usersCollection)
            .where('secondary_roles', arrayContains: role)
            .get();
        await addSnapshot(secondary);
      } catch (_) {}
    }

    people.sort((a, b) {
      final aName = '${a.firstName} ${a.lastName}'.trim().toLowerCase();
      final bName = '${b.firstName} ${b.lastName}'.trim().toLowerCase();
      return aName.compareTo(bName);
    });
    return people;
  }
}
