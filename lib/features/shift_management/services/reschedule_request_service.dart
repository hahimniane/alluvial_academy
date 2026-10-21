import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Makeup requests for missed classes (`reschedule_requests`).
///
/// Teachers file a request straight into Firestore; admins review it through
/// the `reviewRescheduleRequest` callable, which builds the makeup class from
/// the original shift. The Next.js console uses the same callable.
class RescheduleRequestService {
  RescheduleRequestService._();

  static const String collection = 'reschedule_requests';

  static HttpsCallable get _review =>
      FirebaseFunctions.instance.httpsCallable('reviewRescheduleRequest');

  /// Schedules the makeup. [startTime] replaces the teacher's proposed start;
  /// the class keeps the missed class's length. Returns the new shift id.
  static Future<String?> approve(String requestId,
      {DateTime? startTime}) async {
    final result = await _review.call(<String, dynamic>{
      'requestId': requestId,
      'decision': 'approve',
      if (startTime != null) 'startTime': startTime.toUtc().toIso8601String(),
    });
    final data = result.data;
    if (data is Map) return data['createdShiftId'] as String?;
    return null;
  }

  static Future<void> decline(String requestId, {String reason = ''}) async {
    await _review.call(<String, dynamic>{
      'requestId': requestId,
      'decision': 'decline',
      'reason': reason,
    });
  }

  /// The teacher's most recent request for [shiftId], or null.
  ///
  /// The teacher filter is what lets a teacher's query pass the rules, which
  /// only show a teacher their own requests.
  static Future<Map<String, dynamic>?> latestForShift({
    required String shiftId,
    required String teacherId,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('original_shift_id', isEqualTo: shiftId)
        .where('teacher_id', isEqualTo: teacherId)
        .get();
    if (snap.docs.isEmpty) return null;
    final docs = snap.docs.map((d) => d.data()).toList()
      ..sort((a, b) => _createdMillis(b).compareTo(_createdMillis(a)));
    return docs.first;
  }

  static int _createdMillis(Map<String, dynamic> data) {
    final value = data['created_at'];
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    // A request still waiting on its server timestamp is the newest one.
    return 8640000000000000;
  }

  /// A readable message for a refused review.
  static String errorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? error.code;
    }
    return error.toString();
  }
}
