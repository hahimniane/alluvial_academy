import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/form_review_status.dart';

/// What happened when a decision was sent to the teacher.
enum FormDecisionDelivery { pushed, visibleOnly, failed, noTeacher }

/// The admin side of a submitted form: its review status, the admin's note on
/// what was done, and telling the teacher about an accept/reject decision.
///
/// Every screen that shows a single submission to an admin writes through
/// here, so two leaders looking at the same form see the same state.
class FormReviewService {
  FormReviewService._();

  static DocumentReference<Map<String, dynamic>> _doc(String responseId) =>
      FirebaseFirestore.instance.collection('form_responses').doc(responseId);

  static Future<void> setStatus(String responseId, String status) async {
    final reviewerId = FirebaseAuth.instance.currentUser?.uid;
    final cleared = status.isEmpty;
    await _doc(responseId).update({
      'reviewStatus': cleared ? FieldValue.delete() : status,
      'reviewedAt': cleared ? FieldValue.delete() : FieldValue.serverTimestamp(),
      'reviewedBy':
          cleared || reviewerId == null ? FieldValue.delete() : reviewerId,
      'reviewNotifiedAt': FieldValue.delete(),
      'reviewNotifiedBy': FieldValue.delete(),
      'reviewNotifiedStatus': FieldValue.delete(),
    });
  }

  static Future<void> saveNote(String responseId, String note) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    final trimmed = note.trim();
    await _doc(responseId).update({
      'adminNote': trimmed.isEmpty ? FieldValue.delete() : trimmed,
      'adminNoteAt':
          trimmed.isEmpty ? FieldValue.delete() : FieldValue.serverTimestamp(),
      'adminNoteBy':
          trimmed.isEmpty || adminId == null ? FieldValue.delete() : adminId,
    });
  }

  /// The uid of whoever submitted the form, under any of the field names the
  /// form screens have used over time.
  static String submitterOf(Map<String, dynamic> submission) =>
      (submission['userId'] ??
              submission['submittedBy'] ??
              submission['teacherId'] ??
              submission['teacher_id'] ??
              '')
          .toString()
          .trim();

  /// Sends the accept/reject decision to the teacher as a push notification.
  /// The decision itself is already visible in their submissions list either
  /// way; this only records whether the push reached a device.
  static Future<FormDecisionDelivery> notifySubmitter({
    required String responseId,
    required Map<String, dynamic> submission,
    required String status,
    required String title,
    required String body,
  }) async {
    final teacherId = submitterOf(submission);
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (teacherId.isEmpty || adminId == null) {
      return FormDecisionDelivery.noTeacher;
    }
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendAdminNotification')
          .call<Map<String, dynamic>>({
        'recipientType': 'selected',
        'recipientIds': [teacherId],
        'notificationTitle': title,
        'notificationBody': body,
        'notificationData': {
          'type': 'form_decision',
          'formResponseId': responseId,
          'formId': (submission['formId'] ?? submission['templateId'] ?? '')
              .toString(),
          'reviewStatus': FormReviewStatus.normalize(status),
          'yearMonth': (submission['yearMonth'] ?? '').toString(),
        },
        'sendEmail': false,
        'adminId': adminId,
      });
      final results = result.data['results'] as Map?;
      final pushed = (results?['fcmSuccess'] as num? ?? 0) > 0;
      await _doc(responseId).update({
        'reviewNotificationAttemptedAt': FieldValue.serverTimestamp(),
        'reviewNotifiedStatus': FormReviewStatus.normalize(status),
        if (pushed) ...{
          'reviewNotifiedAt': FieldValue.serverTimestamp(),
          'reviewNotifiedBy': adminId,
        },
      });
      return pushed ? FormDecisionDelivery.pushed : FormDecisionDelivery.visibleOnly;
    } catch (_) {
      return FormDecisionDelivery.failed;
    }
  }
}
