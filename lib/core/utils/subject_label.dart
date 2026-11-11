/// The subject name used to group a class's hours and pay. A blank name is
/// treated like a missing one, so the audit never groups under "" (Firestore
/// rejects an empty map key and the whole audit save fails).
String classSubjectLabel(Map<String, dynamic> data) {
  for (final key in const ['subject_display_name', 'subject']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return 'Other';
}

/// The key a subject is stored under in an audit map. Firestore refuses an
/// empty map key, so a blank subject is stored as "Other".
String subjectMapKey(String key) => key.trim().isEmpty ? 'Other' : key;

/// [values] with any blank subject key folded into "Other" (amounts added).
Map<String, double> withSafeSubjectKeys(Map<String, double> values) {
  final out = <String, double>{};
  values.forEach((key, value) {
    final safe = subjectMapKey(key);
    out[safe] = (out[safe] ?? 0) + value;
  });
  return out;
}
