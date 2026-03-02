import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';

class _ShiftAttendanceWindow {
  const _ShiftAttendanceWindow({
    this.shiftStart,
    this.shiftEnd,
    this.teacherId,
    required this.studentIds,
  });

  final DateTime? shiftStart;
  final DateTime? shiftEnd;
  final String? teacherId;
  final List<String> studentIds;
}

class LiveKitSessionService {
  static const String _collectionName = 'livekit_sessions';
  static const int _lateArrivalGraceMinutes = 5;
  final FirebaseFirestore _firestore;
  final Map<String, _ShiftAttendanceWindow> _shiftCache = {};

  LiveKitSessionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String _docId({required String shiftId, required String userId}) =>
      '${shiftId}_$userId';

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  List<Map<String, dynamic>> _normalizePresenceWindows(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => <String, dynamic>{
              'join_at': item['join_at'],
              'leave_at': item['leave_at'],
            })
        .toList();
  }

  void _seedLegacyOpenWindowIfNeeded(
      Map<String, dynamic> data, List<Map<String, dynamic>> windows) {
    if (windows.isNotEmpty) return;
    final hasOpenLegacyState =
        data['last_event'] == 'join' && data['left_at'] == null;
    if (!hasOpenLegacyState) return;

    final legacyJoin = data['open_presence_since'] ?? data['joined_at'];
    if (legacyJoin == null) return;
    windows.add({
      'join_at': legacyJoin,
      'leave_at': null,
    });
  }

  int _findLastOpenWindowIndex(List<Map<String, dynamic>> windows) {
    for (int i = windows.length - 1; i >= 0; i--) {
      final leaveAt = windows[i]['leave_at'];
      if (leaveAt == null) return i;
    }
    return -1;
  }

  int _calculateClampedPresenceSeconds({
    required DateTime start,
    required DateTime end,
    DateTime? shiftStart,
    DateTime? shiftEnd,
  }) {
    if (!end.isAfter(start)) return 0;

    var effectiveStart = start;
    var effectiveEnd = end;

    if (shiftStart != null && effectiveStart.isBefore(shiftStart)) {
      effectiveStart = shiftStart;
    }
    if (shiftEnd != null && effectiveEnd.isAfter(shiftEnd)) {
      effectiveEnd = shiftEnd;
    }

    if (!effectiveEnd.isAfter(effectiveStart)) return 0;
    return effectiveEnd.difference(effectiveStart).inSeconds;
  }

  Future<_ShiftAttendanceWindow?> _loadShiftAttendanceWindow(
      String shiftId) async {
    if (shiftId.trim().isEmpty) return null;
    final cached = _shiftCache[shiftId];
    if (cached != null) return cached;

    try {
      final shiftDoc =
          await _firestore.collection('teaching_shifts').doc(shiftId).get();
      if (!shiftDoc.exists) return null;

      final data = shiftDoc.data() ?? <String, dynamic>{};
      final shiftStart = _toDate(data['shift_start'] ?? data['shiftStart']);
      final shiftEnd = _toDate(data['shift_end'] ?? data['shiftEnd']);
      final teacherId = (data['teacher_id'] ?? data['teacherId'])?.toString();
      final studentIdsRaw = data['student_ids'] ?? data['studentIds'];
      final studentIds = studentIdsRaw is List
          ? studentIdsRaw
              .map((value) => value?.toString())
              .whereType<String>()
              .toList()
          : <String>[];

      final window = _ShiftAttendanceWindow(
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        teacherId: teacherId,
        studentIds: studentIds,
      );
      _shiftCache[shiftId] = window;
      return window;
    } catch (e) {
      AppLogger.warning(
          'LiveKitSessionService: Failed to load shift window (shift=$shiftId): $e');
      return null;
    }
  }

  Future<void> recordParticipantJoin({
    required String shiftId,
    required String userId,
    required String role,
  }) async {
    if (shiftId.trim().isEmpty || userId.trim().isEmpty) return;
    final shiftWindow = await _loadShiftAttendanceWindow(shiftId);
    final nowDate = DateTime.now().toUtc();
    final nowTimestamp = Timestamp.fromDate(nowDate);

    final docRef = _firestore
        .collection(_collectionName)
        .doc(_docId(shiftId: shiftId, userId: userId));

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final existingData = snap.data() ?? <String, dynamic>{};
        final windows =
            _normalizePresenceWindows(existingData['presence_windows']);
        _seedLegacyOpenWindowIfNeeded(existingData, windows);

        final openWindowIndex = _findLastOpenWindowIndex(windows);
        if (openWindowIndex == -1) {
          windows.add({
            'join_at': nowTimestamp,
            'leave_at': null,
          });
        }

        final joinsBeforeStart = (shiftWindow?.shiftStart != null &&
                nowDate.isBefore(shiftWindow!.shiftStart!))
            ? 1
            : 0;
        final joinsLate = (shiftWindow?.shiftStart != null &&
                nowDate.isAfter(shiftWindow!.shiftStart!
                    .add(const Duration(minutes: _lateArrivalGraceMinutes))))
            ? 1
            : 0;
        final firstJoinExists = existingData['first_joined_at'] != null;
        final firstJoinOffsetMinutes = shiftWindow?.shiftStart == null
            ? null
            : nowDate.difference(shiftWindow!.shiftStart!).inMinutes;

        if (!snap.exists) {
          tx.set(docRef, {
            'shift_id': shiftId,
            'user_id': userId,
            'role': role,
            'join_count': 1,
            'leave_count': 0,
            'joined_at': nowTimestamp,
            'left_at': null,
            'disconnect_reason': null,
            'last_event': 'join',
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
            'first_joined_at': nowTimestamp,
            'open_presence_since': nowTimestamp,
            'presence_windows': windows,
            'joins_before_start_count': joinsBeforeStart,
            'joins_late_count': joinsLate,
            'total_presence_seconds': 0,
            'session_schema_version': 2,
            if (shiftWindow?.shiftStart != null)
              'shift_start': Timestamp.fromDate(shiftWindow!.shiftStart!),
            if (shiftWindow?.shiftEnd != null)
              'shift_end': Timestamp.fromDate(shiftWindow!.shiftEnd!),
            if ((shiftWindow?.teacherId ?? '').isNotEmpty)
              'teacher_id': shiftWindow!.teacherId,
            if (shiftWindow != null) 'student_ids': shiftWindow.studentIds,
            if (firstJoinOffsetMinutes != null)
              'first_join_offset_minutes': firstJoinOffsetMinutes,
            if (shiftWindow?.shiftStart != null)
              'first_join_before_start':
                  nowDate.isBefore(shiftWindow!.shiftStart!),
          });
          return;
        }

        final updateData = <String, dynamic>{
          'shift_id': shiftId,
          'user_id': userId,
          'role': role,
          'join_count': FieldValue.increment(1),
          'joined_at': nowTimestamp,
          'last_event': 'join',
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'updated_at': FieldValue.serverTimestamp(),
          'presence_windows': windows,
          'open_presence_since': nowTimestamp,
          'joins_before_start_count': FieldValue.increment(joinsBeforeStart),
          'joins_late_count': FieldValue.increment(joinsLate),
          'session_schema_version': 2,
          if (shiftWindow?.shiftStart != null)
            'shift_start': Timestamp.fromDate(shiftWindow!.shiftStart!),
          if (shiftWindow?.shiftEnd != null)
            'shift_end': Timestamp.fromDate(shiftWindow!.shiftEnd!),
          if ((shiftWindow?.teacherId ?? '').isNotEmpty)
            'teacher_id': shiftWindow!.teacherId,
          if (shiftWindow != null) 'student_ids': shiftWindow.studentIds,
        };

        if (!firstJoinExists) {
          updateData['first_joined_at'] = nowTimestamp;
          if (firstJoinOffsetMinutes != null) {
            updateData['first_join_offset_minutes'] = firstJoinOffsetMinutes;
            updateData['first_join_before_start'] = shiftWindow != null &&
                nowDate.isBefore(shiftWindow.shiftStart!);
          }
        }

        tx.update(docRef, updateData);
      });
    } catch (e) {
      AppLogger.warning(
          'LiveKitSessionService: Failed to record join (shift=$shiftId, user=$userId): $e');
    }
  }

  Future<void> recordParticipantLeave({
    required String shiftId,
    required String userId,
    String? disconnectReason,
  }) async {
    if (shiftId.trim().isEmpty || userId.trim().isEmpty) return;
    final shiftWindow = await _loadShiftAttendanceWindow(shiftId);
    final nowDate = DateTime.now().toUtc();
    final nowTimestamp = Timestamp.fromDate(nowDate);

    final docRef = _firestore
        .collection(_collectionName)
        .doc(_docId(shiftId: shiftId, userId: userId));

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final existingData = snap.data() ?? <String, dynamic>{};
        final windows =
            _normalizePresenceWindows(existingData['presence_windows']);
        _seedLegacyOpenWindowIfNeeded(existingData, windows);

        int addedPresenceSeconds = 0;
        final openWindowIndex = _findLastOpenWindowIndex(windows);
        if (openWindowIndex != -1) {
          final openJoin = _toDate(windows[openWindowIndex]['join_at']);
          if (openJoin != null) {
            addedPresenceSeconds = _calculateClampedPresenceSeconds(
              start: openJoin,
              end: nowDate,
              shiftStart: shiftWindow?.shiftStart,
              shiftEnd: shiftWindow?.shiftEnd,
            );
          }
          windows[openWindowIndex] = {
            'join_at': windows[openWindowIndex]['join_at'],
            'leave_at': nowTimestamp,
          };
        }

        final updateData = <String, dynamic>{
          'shift_id': shiftId,
          'user_id': userId,
          'leave_count': FieldValue.increment(1),
          'left_at': nowTimestamp,
          'disconnect_reason': disconnectReason,
          'last_event': 'leave',
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'updated_at': FieldValue.serverTimestamp(),
          'open_presence_since': null,
          'presence_windows': windows,
          'session_schema_version': 2,
          if (shiftWindow?.shiftStart != null)
            'shift_start': Timestamp.fromDate(shiftWindow!.shiftStart!),
          if (shiftWindow?.shiftEnd != null)
            'shift_end': Timestamp.fromDate(shiftWindow!.shiftEnd!),
          if ((shiftWindow?.teacherId ?? '').isNotEmpty)
            'teacher_id': shiftWindow!.teacherId,
          if (shiftWindow != null) 'student_ids': shiftWindow.studentIds,
        };

        if (addedPresenceSeconds > 0) {
          updateData['total_presence_seconds'] =
              FieldValue.increment(addedPresenceSeconds);
        }

        tx.set(docRef, updateData, SetOptions(merge: true));
      });
    } catch (e) {
      AppLogger.warning(
          'LiveKitSessionService: Failed to record leave (shift=$shiftId, user=$userId): $e');
    }
  }
}
