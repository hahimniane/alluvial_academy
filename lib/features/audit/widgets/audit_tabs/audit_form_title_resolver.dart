import 'package:cloud_firestore/cloud_firestore.dart';

class AuditFormTitleResolver {
  static Future<Map<String, String>> prefetchTitles(
    List<Map<String, dynamic>> forms,
  ) async {
    final formIds = <String>{};
    for (final f in forms) {
      final fid = (f['formId'] ?? '').toString().trim();
      final tid = (f['templateId'] ?? '').toString().trim();
      if (fid.isNotEmpty) formIds.add(fid);
      if (tid.isNotEmpty) formIds.add(tid);
    }
    if (formIds.isEmpty) return {};

    final firestore = FirebaseFirestore.instance;
    final out = <String, String>{};

    Future<void> fetchChunkFrom(
      String collection,
      List<String> ids,
    ) async {
      if (ids.isEmpty) return;
      final snap = await firestore
          .collection(collection)
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final title = (data['title'] ??
                data['name'] ??
                data['formTitle'] ??
                data['formName'] ??
                '')
            .toString()
            .trim();
        if (title.isNotEmpty) {
          out[doc.id] = title;
        }
      }
    }

    final all = formIds.toList();
    for (var i = 0; i < all.length; i += 10) {
      final chunk = all.sublist(i, i + 10 > all.length ? all.length : i + 10);
      await fetchChunkFrom('form_templates', chunk);
      final missing = chunk.where((id) => !out.containsKey(id)).toList();
      await fetchChunkFrom('form', missing);
    }

    return out;
  }

  static String resolveTitle(
    Map<String, dynamic> data, {
    Map<String, String> cachedTitles = const {},
  }) {
    final formId = (data['formId'] ?? '').toString().trim();
    if (formId.isNotEmpty && cachedTitles.containsKey(formId)) {
      return cachedTitles[formId]!;
    }
    final templateId = (data['templateId'] ?? '').toString().trim();
    if (templateId.isNotEmpty && cachedTitles.containsKey(templateId)) {
      return cachedTitles[templateId]!;
    }

    final inline = (data['formName'] ?? data['formTitle'] ?? data['title'] ?? '')
        .toString()
        .trim();
    if (inline.isNotEmpty &&
        inline.toLowerCase() != 'legacy' &&
        inline.toLowerCase() != 'unknown form' &&
        inline.toLowerCase() != 'form') {
      return inline;
    }

    final formType = (data['formType'] ?? '').toString().toLowerCase();
    if (formType == 'daily') return 'Daily Class Report / Rapport quotidien';
    if (formType == 'weekly') return 'Weekly Report / Rapport hebdomadaire';
    if (formType == 'monthly') return 'Monthly Report / Rapport mensuel';
    if (formType == 'legacy') {
      return 'Readiness Form / Formulaire de préparation';
    }

    final responses = (data['responses'] as Map<String, dynamic>?) ?? const {};
    final responseText = responses.entries.map((e) => '${e.key} ${e.value}').join(' ').toLowerCase();
    if (_hasAny(responseText, const ['assessment', 'évaluation', 'grade', 'students assessment'])) {
      return 'Students Assessment / Évaluation des élèves';
    }
    if (_hasAny(responseText, const ['quiz', 'qcm'])) {
      return 'Quiz Form / Formulaire de quiz';
    }
    if (_hasAny(responseText, const ['assignment', 'devoir', 'homework'])) {
      return 'Assignment Form / Formulaire de devoir';
    }

    return 'Form';
  }

  static bool _hasAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}
