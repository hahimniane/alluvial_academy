import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_logger.dart';

/// Reads teaching shifts for a period from the live collection AND the
/// archive, as one list.
///
/// Classes whose window ended more than 60 days ago are moved nightly from
/// `teaching_shifts` to `teaching_shifts_archive`. Anything that counts a
/// period — worked hours, pay, attendance, audits — must read both, or the
/// early days of the month silently disappear once they age out (July 2026:
/// a teacher who clocked 55.25 h was shown 40.40 h). A guard test refuses new
/// range queries on the live collection outside this reader.
///
/// The archive is admin-read only. When the read is refused, the live rows are
/// returned on their own and the gap is logged.
class ShiftArchiveReader {
  static const String liveCollection = 'teaching_shifts';
  static const String archiveCollection = 'teaching_shifts_archive';

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> inRange({
    required Timestamp start,
    required Timestamp end,
    bool endInclusive = true,
    String? teacherId,
    GetOptions options = const GetOptions(),
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    Query<Map<String, dynamic>> build(String collection) {
      Query<Map<String, dynamic>> q = db.collection(collection);
      if (teacherId != null) q = q.where('teacher_id', isEqualTo: teacherId);
      q = q.where('shift_start', isGreaterThanOrEqualTo: start);
      return endInclusive
          ? q.where('shift_start', isLessThanOrEqualTo: end)
          : q.where('shift_start', isLessThan: end);
    }

    final live = await build(liveCollection).get(options);
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[...live.docs];
    final seen = docs.map((d) => d.id).toSet();
    try {
      final archived = await build(archiveCollection).get(options);
      for (final d in archived.docs) {
        if (seen.add(d.id)) docs.add(d);
      }
      if (archived.docs.isNotEmpty) {
        AppLogger.debug(
            'ShiftArchiveReader: ${live.docs.length} live + ${archived.docs.length} archived shifts');
      }
    } catch (e) {
      AppLogger.debug('ShiftArchiveReader: archive not readable here: $e');
    }
    return docs;
  }
}
