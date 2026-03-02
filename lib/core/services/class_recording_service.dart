import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:alluwalacademyadmin/core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ClassRecordingItem {
  final String recordingId;
  final String? shiftId;
  final String? segmentId;
  final String shiftName;
  final String subjectName;
  final String teacherName;
  final String status;
  final String? error;
  final String filePath;
  final String? bucket;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;
  final DateTime? requestedAt;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final bool canPlay;

  const ClassRecordingItem({
    required this.recordingId,
    this.shiftId,
    this.segmentId,
    required this.shiftName,
    required this.subjectName,
    required this.teacherName,
    required this.status,
    this.error,
    required this.filePath,
    this.bucket,
    this.shiftStart,
    this.shiftEnd,
    this.requestedAt,
    this.startedAt,
    this.updatedAt,
    required this.canPlay,
  });

  DateTime? get displayDate =>
      startedAt ?? requestedAt ?? shiftStart ?? updatedAt;

  factory ClassRecordingItem.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(String key) {
      final raw = data[key];
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return ClassRecordingItem(
      recordingId: data['recordingId']?.toString() ?? '',
      shiftId: data['shiftId']?.toString(),
      segmentId: data['segmentId']?.toString(),
      shiftName: data['shiftName']?.toString().trim().isNotEmpty == true
          ? data['shiftName'].toString().trim()
          : 'Class Recording',
      subjectName: data['subjectName']?.toString() ?? '',
      teacherName: data['teacherName']?.toString() ?? '',
      status: data['status']?.toString() ?? 'unknown',
      error: data['error']?.toString(),
      filePath: data['filePath']?.toString() ?? '',
      bucket: data['bucket']?.toString(),
      shiftStart: parseDate('shiftStartIso'),
      shiftEnd: parseDate('shiftEndIso'),
      requestedAt: parseDate('requestedAtIso'),
      startedAt: parseDate('startedAtIso'),
      updatedAt: parseDate('updatedAtIso'),
      canPlay: data['canPlay'] == true,
    );
  }
}

class ClassRecordingListResult {
  final bool success;
  final String? role;
  final List<ClassRecordingItem> recordings;
  final bool hasMore;
  final String? error;

  const ClassRecordingListResult({
    required this.success,
    this.role,
    this.recordings = const [],
    this.hasMore = false,
    this.error,
  });

  factory ClassRecordingListResult.error(String message) {
    return ClassRecordingListResult(
      success: false,
      recordings: const [],
      hasMore: false,
      error: message,
    );
  }
}

class ClassRecordingPlaybackResult {
  final bool success;
  final String? url;
  final DateTime? expiresAt;
  final String? error;

  const ClassRecordingPlaybackResult({
    required this.success,
    this.url,
    this.expiresAt,
    this.error,
  });

  factory ClassRecordingPlaybackResult.error(String message) {
    return ClassRecordingPlaybackResult(
      success: false,
      error: message,
    );
  }
}

class ClassRecordingService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<ClassRecordingListResult> listRecordings({
    int limit = 40,
  }) async {
    try {
      final activeRole = await UserRoleService.getCurrentUserRole();
      final callable = _functions.httpsCallable('listClassRecordings');
      final result = await callable.call({
        'limit': limit,
        if (activeRole != null && activeRole.trim().isNotEmpty)
          'activeRole': activeRole.trim().toLowerCase(),
      });
      final raw = result.data;
      if (raw is! Map) {
        return ClassRecordingListResult.error(
            'Unexpected response from server');
      }

      final data = Map<String, dynamic>.from(raw);
      final rawItems = data['recordings'];
      final recordings = <ClassRecordingItem>[];
      if (rawItems is List) {
        for (final item in rawItems) {
          if (item is Map) {
            final typed = Map<String, dynamic>.from(item);
            final parsed = ClassRecordingItem.fromMap(typed);
            if (parsed.recordingId.isNotEmpty && parsed.filePath.isNotEmpty) {
              recordings.add(parsed);
            }
          }
        }
      }

      return ClassRecordingListResult(
        success: data['success'] == true,
        role: data['role']?.toString(),
        recordings: recordings,
        hasMore: data['hasMore'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      final message = (e.message?.trim().isNotEmpty ?? false)
          ? e.message!.trim()
          : '${e.code}: failed to load recordings';
      AppLogger.error(
          'ClassRecordingService.listRecordings: ${e.code} - ${e.message}');
      return ClassRecordingListResult.error(message);
    } catch (e) {
      AppLogger.error('ClassRecordingService.listRecordings: $e');
      return ClassRecordingListResult.error('Failed to load recordings');
    }
  }

  static Future<ClassRecordingPlaybackResult> getPlaybackUrl(
    String recordingId,
  ) async {
    if (recordingId.trim().isEmpty) {
      return ClassRecordingPlaybackResult.error('Invalid recording ID');
    }

    try {
      final activeRole = await UserRoleService.getCurrentUserRole();
      final callable = _functions.httpsCallable('getClassRecordingPlaybackUrl');
      final result = await callable.call({
        'recordingId': recordingId.trim(),
        if (activeRole != null && activeRole.trim().isNotEmpty)
          'activeRole': activeRole.trim().toLowerCase(),
      });
      final raw = result.data;
      if (raw is! Map) {
        return ClassRecordingPlaybackResult.error(
            'Unexpected playback response from server');
      }

      final data = Map<String, dynamic>.from(raw);
      if (data['success'] != true) {
        return ClassRecordingPlaybackResult.error(
          data['error']?.toString() ?? 'Unable to open recording',
        );
      }

      final url = data['url']?.toString();
      if (url == null || url.trim().isEmpty) {
        return ClassRecordingPlaybackResult.error('Playback URL not available');
      }

      final expiresAt = data['expiresAtIso'] == null
          ? null
          : DateTime.tryParse(data['expiresAtIso'].toString());

      return ClassRecordingPlaybackResult(
        success: true,
        url: url.trim(),
        expiresAt: expiresAt,
      );
    } on FirebaseFunctionsException catch (e) {
      final message = (e.message?.trim().isNotEmpty ?? false)
          ? e.message!.trim()
          : '${e.code}: unable to open recording';
      AppLogger.error(
          'ClassRecordingService.getPlaybackUrl: ${e.code} - ${e.message}');
      return ClassRecordingPlaybackResult.error(message);
    } catch (e) {
      AppLogger.error('ClassRecordingService.getPlaybackUrl: $e');
      return ClassRecordingPlaybackResult.error('Failed to open recording');
    }
  }

  /// Fetches student names for a given shift by reading the teaching_shifts
  /// document and resolving user names from their IDs.
  static Future<List<String>> getStudentNamesForShift(String shiftId) async {
    if (shiftId.trim().isEmpty) return [];
    try {
      final shiftDoc = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(shiftId.trim())
          .get();
      if (!shiftDoc.exists) return [];
      final data = shiftDoc.data();
      if (data == null) return [];

      final raw = data['student_ids'];
      if (raw is! List || raw.isEmpty) return [];

      final studentIds =
          raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      if (studentIds.isEmpty) return [];

      final names = <String>[];
      for (final id in studentIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(id)
              .get();
          if (userDoc.exists) {
            final uData = userDoc.data();
            final name = (uData?['name'] ?? uData?['displayName'] ?? '')
                .toString()
                .trim();
            if (name.isNotEmpty) {
              names.add(name);
            }
          }
        } catch (_) {
          // skip individual lookup failures
        }
      }
      return names;
    } catch (e) {
      AppLogger.error('ClassRecordingService.getStudentNamesForShift: $e');
      return [];
    }
  }
}
