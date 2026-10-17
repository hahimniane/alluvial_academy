import '../models/form_template.dart';
import 'form_audience.dart';

/// Which forms a parent sees.
///
/// A form is shown to parents when it is active and its audience ("Who can see
/// this") includes parents. The built-in parent forms — the absence excuse
/// request, the parent feedback form and the leaders feedback form — are shown
/// whatever audience they carry. Anything else with no audience is not shown:
/// a form nobody aimed at parents stays hidden from them.
class ParentFormAccessPolicy {
  const ParentFormAccessPolicy._();

  static bool allows(FormTemplate template) {
    if (!template.isActive) return false;
    if (isBuiltInParentForm(template)) return true;
    return FormAudience.includes(template.allowedRoles, 'parent');
  }

  static bool isBuiltInParentForm(FormTemplate template) {
    final id = template.id.trim().toLowerCase();
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
