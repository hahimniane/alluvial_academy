import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/forms/models/form_template.dart';
import 'package:alluwalacademyadmin/features/forms/utils/student_form_access_policy.dart';

void main() {
  FormTemplate template({
    List<String>? allowedRoles,
    bool isActive = true,
  }) {
    return FormTemplate(
      id: 'tpl',
      name: 'Bayana Attendance Form',
      frequency: FormFrequency.onDemand,
      category: FormCategory.other,
      version: 1,
      fields: const [],
      autoFillRules: const [],
      isActive: isActive,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      allowedRoles: allowedRoles,
    );
  }

  test('shows an active form aimed at students', () {
    expect(
      StudentFormAccessPolicy.allows(
          template(allowedRoles: ['student', 'parent'])),
      isTrue,
    );
    expect(
      StudentFormAccessPolicy.allows(template(allowedRoles: ['Students'])),
      isTrue,
    );
  });

  test('hides forms for other roles, with no audience, or switched off', () {
    expect(
      StudentFormAccessPolicy.allows(template(allowedRoles: ['teacher'])),
      isFalse,
    );
    expect(StudentFormAccessPolicy.allows(template()), isFalse);
    expect(
      StudentFormAccessPolicy.allows(
          template(allowedRoles: ['student'], isActive: false)),
      isFalse,
    );
  });
}
