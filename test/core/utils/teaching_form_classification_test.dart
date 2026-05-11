import 'package:alluwalacademyadmin/core/utils/teaching_form_classification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily formType is teaching', () {
    expect(
      TeachingFormClassification.isTeachingFormData({
        'formType': 'daily',
        'shiftId': '',
        'responses': <String, dynamic>{},
      }),
      true,
    );
  });

  test('grade assessment template is not teaching', () {
    expect(
      TeachingFormClassification.isTeachingFormData({
        'templateId':
            TeachingFormClassification.studentGradeAssessmentTemplateId,
        'formType': 'onDemand',
        'shiftId': 's1',
        'responses': <String, dynamic>{},
      }),
      false,
    );
  });
}
