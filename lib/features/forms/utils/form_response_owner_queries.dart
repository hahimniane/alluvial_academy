import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Internal group key for submissions with no [formId] in Firestore.
const String kMySubmissionsNoFormIdGroupKey = '__no_form_id__';

int _submittedAtMillis(Map<String, dynamic> data) {
  final t = data['submittedAt'];
  if (t is Timestamp) return t.millisecondsSinceEpoch;
  return 0;
}

/// Merges `form_responses` loaded by [userId], [submittedBy], and [teacher_id]
/// so legacy rows remain visible even when only one ownership field is set.
///
/// Aligns with [submissionOwnerFromData] in [firestore.rules].
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    queryFormResponsesForOwner(
  FirebaseFirestore db,
  String uid,
) async {
  final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

  Future<void> pull(
    Query<Map<String, dynamic>> query,
    String label,
  ) async {
    try {
      final snap = await query.get();
      for (final d in snap.docs) {
        byId.putIfAbsent(d.id, () => d);
      }
    } catch (e, st) {
      AppLogger.warning(
        'FormResponseOwnerQueries: $label query failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  final col = db.collection('form_responses');
  await pull(
    col
        .where('userId', isEqualTo: uid)
        .orderBy('submittedAt', descending: true),
    'userId',
  );
  await pull(
    col
        .where('submittedBy', isEqualTo: uid)
        .orderBy('submittedAt', descending: true),
    'submittedBy',
  );
  await pull(
    col
        .where('teacher_id', isEqualTo: uid)
        .orderBy('submittedAt', descending: true),
    'teacher_id',
  );
  await pull(
    col
        .where('teacherId', isEqualTo: uid)
        .orderBy('submittedAt', descending: true),
    'teacherId',
  );

  final list = byId.values.toList()
    ..sort((a, b) => _submittedAtMillis(b.data()).compareTo(
          _submittedAtMillis(a.data()),
        ));
  return list;
}
