import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_audit_compliance_config.dart';

/// Loads [form_responses] for admin audit evaluation UI (CEO allowlist + submitter filter).
class AdminAuditCeoSubmissionsService {
  AdminAuditCeoSubmissionsService._();

  static final _firestore = FirebaseFirestore.instance;

  static String? _templateKey(Map<String, dynamic> data) {
    final tid = data['templateId']?.toString().trim() ?? '';
    if (tid.isNotEmpty) return tid;
    final fid = data['formId']?.toString().trim() ?? '';
    if (fid.isNotEmpty) return fid;
    return null;
  }

  /// Submissions for [adminUserId] in [yearMonth], optional [templateIds] filter (defaults to full CEO allowlist).
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> loadSubmissions({
    required String adminUserId,
    required String yearMonth,
    Set<String>? templateIds,
  }) async {
    final allow = templateIds ?? AdminAuditComplianceConfig.allCeoEvaluationTemplateIds;
    final snap = await _firestore
        .collection('form_responses')
        .where('yearMonth', isEqualTo: yearMonth)
        .get();

    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final submitter =
          data['userId'] as String? ?? data['submitted_by'] as String?;
      if (submitter != adminUserId) continue;
      final key = _templateKey(data);
      if (key == null || !allow.contains(key)) continue;
      out.add(doc);
    }

    DateTime? ts(Map<String, dynamic> data) {
      final s = data['submittedAt'];
      if (s is Timestamp) return s.toDate();
      final c = data['createdAt'];
      if (c is Timestamp) return c.toDate();
      return null;
    }

    out.sort((a, b) {
      final da = ts(a.data());
      final db = ts(b.data());
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return out;
  }

  /// Facts-finding + advance / payment request forms for the same user & month.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> loadContextSubmissions({
    required String adminUserId,
    required String yearMonth,
  }) =>
      loadSubmissions(
        adminUserId: adminUserId,
        yearMonth: yearMonth,
        templateIds: AdminAuditComplianceConfig.contextPenaltyFormTemplateIds,
      );
}
