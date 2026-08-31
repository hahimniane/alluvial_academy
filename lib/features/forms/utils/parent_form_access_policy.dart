import '../models/form_template.dart';

class ParentFormAccessPolicy {
  const ParentFormAccessPolicy._();

  static bool allows(FormTemplate template) {
    final id = _normalize(template.id);
    final name = _normalize(template.name);

    return id == 'parent_feedback' ||
        id == 'parent_student_excuse' ||
        name.contains('parent guardian feedback') ||
        name.contains('student absence excuse request') ||
        name.contains('demande d excuse d absence de l eleve') ||
        name.contains('feedback for leaders') ||
        name.contains('commentaires pour les dirigeants');
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
