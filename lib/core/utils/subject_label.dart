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
