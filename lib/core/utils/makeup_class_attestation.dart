import 'package:cloud_firestore/cloud_firestore.dart';

import 'teaching_form_classification.dart';

/// Stable keys merged into [form_responses.responses] for missed / no-timesheet makeup.
class MakeupClassAttestation {
  MakeupClassAttestation._();

  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  static const String keyOccurredAt = 'makeup_occurred_at';
  static const String keyLocation = 'makeup_location';
  static const String keyStartTime = 'makeup_start_time';
  static const String keyEndTime = 'makeup_end_time';
  static const String keyDeliveryMode = 'makeup_delivery_mode';
  static const String keyZoomHost = 'makeup_zoom_host';
  static const String keyOtherDetail = 'makeup_other_detail';
  static const String keyStudentsPresent = 'makeup_students_present';
  static const String keyNotes = 'makeup_notes';

  static bool _nonEmpty(dynamic v) =>
      v != null && v.toString().trim().isNotEmpty;

  static bool responsesHaveRequiredKeys(Map<String, dynamic> responses) {
    if (!_nonEmpty(responses[keyOccurredAt])) return false;
    if (!_nonEmpty(responses[keyStartTime])) return false;
    if (!_nonEmpty(responses[keyEndTime])) return false;
    final mode =
        responses[keyDeliveryMode]?.toString().trim().toLowerCase() ?? '';
    if (!_nonEmpty(mode)) return false;
    if (mode == 'in_person') {
      if (!_nonEmpty(responses[keyLocation])) return false;
    } else if (mode == 'zoom' || mode == 'livekit') {
      if (!_nonEmpty(responses[keyZoomHost])) return false;
    } else if (mode == 'other') {
      if (!_nonEmpty(responses[keyOtherDetail])) return false;
    } else {
      return false;
    }
    if (!_nonEmpty(responses[keyStudentsPresent])) return false;
    return true;
  }

  static bool isLegacyMakeupWorkflow(Map<String, dynamic> form) {
    final raw = form['makeupApprovalStatus'];
    if (raw == null) return true;
    return raw.toString().trim().isEmpty;
  }

  /// Same economics gate as [functions/utils/shiftSessionAggregator] for form-only pay.
  static bool formEligibleForFormOnlyMakeupEconomics(
      Map<String, dynamic> form) {
    if (isLegacyMakeupWorkflow(form)) return true;
    final status =
        form['makeupApprovalStatus']?.toString().trim().toLowerCase() ?? '';
    if (status == statusRejected) return false;
    if (status == statusPending || status == statusApproved) {
      final r = form['responses'];
      if (r is! Map) return false;
      return responsesHaveRequiredKeys(
          r.map((k, v) => MapEntry(k.toString(), v)));
    }
    return false;
  }

  static bool _timesheetRejected(Map<String, dynamic> d) =>
      (d['status'] as String?)?.toLowerCase() == 'rejected';

  /// Daily / per-session form tied to a shift: require attestation when there is
  /// no non-rejected timesheet with a full clock pair for this teacher+shift.
  static Future<bool> shiftNeedsMakeupAttestationForDailyForm(
    FirebaseFirestore fs,
    String teacherId, {
    required String shiftId,
    String? timesheetId,
  }) async {
    if (shiftId.trim().isEmpty) return false;

    bool docHasUsableClock(DocumentSnapshot<Map<String, dynamic>> d) {
      if (!d.exists || d.data() == null) return false;
      final m = d.data()!;
      if (_timesheetRejected(m)) return false;
      return timesheetDocHasClockPair(m);
    }

    if (timesheetId != null && timesheetId.isNotEmpty) {
      final ts =
          await fs.collection('timesheet_entries').doc(timesheetId).get();
      if (docHasUsableClock(ts)) return false;
    }

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> query(
        String shiftField) async {
      try {
        final a = await fs
            .collection('timesheet_entries')
            .where(shiftField, isEqualTo: shiftId)
            .where('teacher_id', isEqualTo: teacherId)
            .limit(25)
            .get();
        return a.docs;
      } catch (_) {
        return [];
      }
    }

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    docs.addAll(await query('shift_id'));
    docs.addAll(await query('shiftId'));
    final seen = <String>{};
    for (final d in docs) {
      if (!seen.add(d.id)) continue;
      if (docHasUsableClock(d)) return false;
    }
    return true;
  }
}
