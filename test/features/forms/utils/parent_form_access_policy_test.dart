import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/forms/models/form_template.dart';
import 'package:alluwalacademyadmin/features/forms/utils/parent_form_access_policy.dart';

void main() {
  FormTemplate template({required String id, required String name}) {
    return FormTemplate(
      id: id,
      name: name,
      frequency: FormFrequency.onDemand,
      category: FormCategory.feedback,
      version: 1,
      fields: const [],
      autoFillRules: const [],
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
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

  test('allows the built-in parent feedback template', () {
    expect(
      ParentFormAccessPolicy.allows(
        template(id: 'parent_feedback', name: 'Parent/Guardian Feedback'),
      ),
      isTrue,
    );
  });

  test('does not expose unrelated teacher or administrative forms', () {
    expect(
      ParentFormAccessPolicy.allows(
        template(id: 'daily', name: 'Daily Class Report'),
      ),
      isFalse,
    );
    expect(
      ParentFormAccessPolicy.allows(
        template(id: 'complaint', name: 'Teacher Complaints form - CEO'),
      ),
      isFalse,
    );
    expect(
      ParentFormAccessPolicy.allows(
        template(
          id: 'staff_excuse',
          name: 'Excuse Form for teachers & leaders',
        ),
      ),
      isFalse,
    );
  });
}
