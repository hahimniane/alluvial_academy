import 'package:cloud_firestore/cloud_firestore.dart';

/// Resolves [form_templates] / legacy [form] document IDs to display titles
/// for admin audit drill-down (no dependency on [FormTemplate] parsing).
class AdminAuditFormTitleResolver {
  AdminAuditFormTitleResolver._();

  static final _firestore = FirebaseFirestore.instance;

  static String? _titleFromTemplateData(Map<String, dynamic>? d) {
    if (d == null) return null;
    for (final k in ['name', 'title', 'formName', 'label']) {
      final v = d[k]?.toString().trim();
      if (v != null && v.isNotEmpty && v != 'Untitled Form') return v;
    }
    return null;
  }

  static String? _titleFromFormData(Map<String, dynamic>? d) {
    if (d == null) return null;
    for (final k in ['title', 'formTitle', 'name', 'form_name']) {
      final v = d[k]?.toString().trim();
      if (v != null && v.isNotEmpty && v != 'Untitled Form') return v;
    }
    return null;
  }

  /// Copy of [admin_all_submissions_screen] logic: titles sometimes only exist on a response row.
  static Future<String?> _titleFromSampleResponse(String id) async {
    for (final field in ['formId', 'templateId']) {
      try {
        final snap = await _firestore
            .collection('form_responses')
            .where(field, isEqualTo: id)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache));
        if (snap.docs.isEmpty) continue;
        final d = snap.docs.first.data();
        for (final k in ['formTitle', 'form_title', 'title', 'name']) {
          final v = d[k]?.toString().trim();
          if (v != null && v.isNotEmpty && v != 'Untitled Form') return v;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Returns map id -> title; missing or empty titles are omitted (UI falls back to id).
  static Future<Map<String, String>> resolveTitles(Iterable<String> rawIds) async {
    final ids = rawIds
        .map((s) => s.trim())
        .where((id) => id.isNotEmpty && id != '_unknown')
        .toSet()
        .toList();
    if (ids.isEmpty) return {};

    final out = <String, String>{};
    const chunk = 12;
    for (var i = 0; i < ids.length; i += chunk) {
      final part = ids.skip(i).take(chunk).toList();
      await Future.wait(part.map((id) async {
        try {
          final tDoc = await _firestore
              .collection('form_templates')
              .doc(id)
              .get(const GetOptions(source: Source.serverAndCache));
          if (tDoc.exists) {
            final name = _titleFromTemplateData(tDoc.data());
            if (name != null) {
              out[id] = name;
              return;
            }
          }
          final fDoc = await _firestore
              .collection('form')
              .doc(id)
              .get(const GetOptions(source: Source.serverAndCache));
          if (fDoc.exists) {
            final title = _titleFromFormData(fDoc.data());
            if (title != null) {
              out[id] = title;
              return;
            }
          }
          final fromResp = await _titleFromSampleResponse(id);
          if (fromResp != null) out[id] = fromResp;
        } catch (_) {
          // leave unresolved
        }
      }));
    }
    return out;
  }
}
