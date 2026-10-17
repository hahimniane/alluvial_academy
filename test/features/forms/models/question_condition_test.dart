import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/forms/models/question_condition.dart';
import 'package:alluwalacademyadmin/features/forms/screens/form_builder.dart';

void main() {
  test('a stored rule round-trips in the shape the form screen reads', () {
    final stored = {
      'dependsOnFieldId': '1759083998172',
      'condition': 'not_equals',
      'expectedValue': 'A student',
      'expectedValues': null,
      'isVisible': true,
    };
    final question = FormQuestion.fromFirestore('1754651430169', {
      'type': 'text',
      'label': 'Duties',
      'required': true,
      'order': 7,
      'conditionalLogic': stored,
    });
    expect(question.condition, isNotNull);
    expect(question.toFirestore(6)['conditionalLogic'], stored);
  });

  test('multi-select rules keep their expected values and hide-when flag', () {
    final rule = QuestionCondition.fromFirestore({
      'dependsOnFieldId': 'subjects',
      'condition': 'contains_all',
      'expectedValue': null,
      'expectedValues': ['Quran', 'Arabic'],
      'isVisible': false,
    })!;
    expect(rule.toFirestore(), {
      'dependsOnFieldId': 'subjects',
      'condition': 'contains_all',
      'expectedValue': null,
      'expectedValues': ['Quran', 'Arabic'],
      'isVisible': false,
    });
    expect(rule.isComplete, isTrue);
  });

  test('the empty placeholder older forms saved is no rule', () {
    expect(
      QuestionCondition.fromFirestore({
        'dependsOnFieldId': null,
        'condition': null,
        'expectedValue': null,
        'expectedValues': null,
        'isVisible': true,
      }),
      isNull,
    );
    expect(QuestionCondition.fromFirestore(null), isNull);
    final question = FormQuestion.fromFirestore('q', {'type': 'text'});
    expect(question.toFirestore(0).containsKey('conditionalLogic'), isFalse);
  });

  test('a comparison with no answer to compare is incomplete', () {
    expect(
      QuestionCondition(dependsOnFieldId: 'a', condition: 'equals').isComplete,
      isFalse,
    );
    expect(
      QuestionCondition(
              dependsOnFieldId: 'a', condition: 'equals', expectedValue: ' ')
          .isComplete,
      isFalse,
    );
    expect(
      QuestionCondition(dependsOnFieldId: 'a', condition: 'is_empty')
          .isComplete,
      isTrue,
    );
  });

  test('a saved template field carries the rule as conditionalLogic', () {
    final question = FormQuestion.fromFirestore('child', {
      'type': 'radio',
      'label': 'Level',
      'options': ['Low', 'High'],
      'conditionalLogic': {
        'dependsOnFieldId': 'parent',
        'condition': 'equals',
        'expectedValue': 'Yes',
        'expectedValues': null,
        'isVisible': true,
      },
    });
    final copy = question.condition!.copy()..expectedValue = 'No';
    expect(question.condition!.expectedValue, 'Yes');
    expect(copy.toFirestore()['expectedValue'], 'No');
  });
}
