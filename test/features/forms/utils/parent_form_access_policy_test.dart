import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/forms/models/form_template.dart';
import 'package:alluwalacademyadmin/features/forms/utils/form_audience.dart';
import 'package:alluwalacademyadmin/features/forms/utils/parent_form_access_policy.dart';

void main() {
  FormTemplate template({
    required String id,
    required String name,
    List<String>? allowedRoles,
    bool isActive = true,
  }) {
    return FormTemplate(
      id: id,
      name: name,
      frequency: FormFrequency.onDemand,
      category: FormCategory.feedback,
      version: 1,
      fields: const [],
      autoFillRules: const [],
      isActive: isActive,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      allowedRoles: allowedRoles,
    );
  }

  test('allows the parent excuse and production leader feedback templates', () {
    expect(
      ParentFormAccessPolicy.allows(
        template(
          id: 'parent_student_excuse',
          name: 'Student Absence / Excuse Request',
        ),
      ),
      isTrue,
    );
    expect(
      ParentFormAccessPolicy.allows(
        template(
          id: 'feedback',
          name:
              'Feedback for Leaders/Commentaires pour les dirigeants All Leaders',
        ),
      ),
      isTrue,
    );
  });

  test('allows the built-in parent feedback template by id', () {
    expect(
      ParentFormAccessPolicy.allows(
        template(id: 'parent_feedback', name: 'Feedback'),
      ),
      isTrue,
    );
  });

  test('shows forms whose audience includes parents, in any spelling', () {
    for (final roles in [
      ['parent'],
      ['admin', 'Parent'],
      ['parents'],
      [' PARENTS '],
      ['guardians'],
    ]) {
      expect(
        ParentFormAccessPolicy.allows(template(
          id: 'x',
          name: 'Parents Feedback on Teachers',
          allowedRoles: roles,
        )),
        isTrue,
        reason: roles.join(','),
      );
    }
  });

  test('fails closed: no audience, or an audience without parents, is hidden',
      () {
    expect(
      ParentFormAccessPolicy.allows(
        template(id: 'daily', name: 'Daily Class Report'),
      ),
      isFalse,
    );
    expect(
      ParentFormAccessPolicy.allows(
        template(
          id: 'complaint',
          name: 'Teacher Complaints form - CEO',
          allowedRoles: const [],
        ),
      ),
      isFalse,
    );
    expect(
      ParentFormAccessPolicy.allows(
        template(
          id: 'staff_excuse',
          name: 'Excuse Form for teachers & leaders',
          allowedRoles: const ['teacher', 'admin'],
        ),
      ),
      isFalse,
    );
  });

  test('an inactive parent form is hidden', () {
    expect(
      ParentFormAccessPolicy.allows(template(
        id: 'old',
        name: 'Bayana Attendance Form',
        allowedRoles: const ['parent'],
        isActive: false,
      )),
      isFalse,
    );
  });

  group('FormAudience.parse', () {
    test('reads allowedRoles as a list, a map of flags, a map or a string', () {
      expect(
          FormAudience.parse({
            'allowedRoles': ['admin', 'parent']
          }),
          ['admin', 'parent']);
      expect(
          FormAudience.parse({
            'allowedRoles': {'parent': true, 'teacher': false}
          }),
          ['parent']);
      expect(
          FormAudience.parse({
            'allowedRoles': {'0': 'parent', '1': 'admin'}
          }),
          ['parent', 'admin']);
      expect(FormAudience.parse({'allowedRoles': 'Parents, Admin'}),
          ['Parents', 'Admin']);
    });

    test('falls back to audience, targetRoles and legacy permissions', () {
      expect(
          FormAudience.parse({
            'audience': ['Parent']
          }),
          ['Parent']);
      expect(FormAudience.parse({'targetRoles': 'parents'}), ['parents']);
      expect(
          FormAudience.parse({
            'permissions': {'type': 'restricted', 'role': 'parents'}
          }),
          ['parents']);
      expect(
          FormAudience.parse({
            'permissions': {'type': 'public', 'role': 'parents'}
          }),
          isNull);
    });

    test('no audience data at all is null; an explicit empty list is empty',
        () {
      expect(FormAudience.parse({'name': 'x'}), isNull);
      expect(FormAudience.parse({'allowedRoles': []}), isEmpty);
    });
  });
}
