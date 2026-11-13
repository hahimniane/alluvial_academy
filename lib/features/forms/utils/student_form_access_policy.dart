import '../models/form_template.dart';
import 'form_audience.dart';

/// Which forms a student sees.
///
/// A form is shown to students when it is active and its audience ("Who can
/// see this") includes students. A form nobody aimed at students stays hidden
/// from them.
class StudentFormAccessPolicy {
  const StudentFormAccessPolicy._();

  static bool allows(FormTemplate template) {
    if (!template.isActive) return false;
    return FormAudience.includes(template.allowedRoles, 'student');
  }
}
