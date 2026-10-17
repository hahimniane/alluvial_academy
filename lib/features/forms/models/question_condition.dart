/// A "show only if" rule on a form question, stored on the field as
/// `conditionalLogic` in exactly the shape the form screen evaluates
/// (`FormScreen._shouldShowField`):
///
/// `{dependsOnFieldId, condition, expectedValue, expectedValues, isVisible}`
class QuestionCondition {
  String dependsOnFieldId;
  String condition;
  dynamic expectedValue;
  List<dynamic>? expectedValues;

  /// true: show the question when the condition is met; false: hide it then.
  bool isVisible;

  QuestionCondition({
    required this.dependsOnFieldId,
    required this.condition,
    this.expectedValue,
    this.expectedValues,
    this.isVisible = true,
  });

  static const String equals = 'equals';
  static const String notEquals = 'not_equals';
  static const String contains = 'contains';
  static const String containsAll = 'contains_all';
  static const String containsExactly = 'contains_exactly';
  static const String isEmpty = 'is_empty';
  static const String isNotEmpty = 'is_not_empty';

  /// Conditions the form screen understands.
  static const List<String> all = [
    equals,
    notEquals,
    contains,
    containsAll,
    containsExactly,
    isEmpty,
    isNotEmpty,
  ];

  /// Whether [condition] compares against a list of picked answers.
  static bool usesExpectedValues(String condition,
      {required bool multiSelect}) {
    if (condition == containsAll || condition == containsExactly) return true;
    return condition == contains && multiSelect;
  }

  static bool needsValue(String condition) =>
      condition != isEmpty && condition != isNotEmpty;

  /// Null when [raw] holds no rule (absent, or the empty placeholder older
  /// forms saved with every key null).
  static QuestionCondition? fromFirestore(dynamic raw) {
    if (raw is! Map) return null;
    final dependsOn = raw['dependsOnFieldId'];
    final condition = raw['condition'];
    if (dependsOn == null || condition == null) return null;
    final dependsOnId = dependsOn.toString().trim();
    final conditionName = condition.toString().trim();
    if (dependsOnId.isEmpty || conditionName.isEmpty) return null;
    final expectedValues = raw['expectedValues'];
    final isVisible = raw['isVisible'];
    return QuestionCondition(
      dependsOnFieldId: dependsOnId,
      condition: conditionName,
      expectedValue: raw['expectedValue'],
      expectedValues: expectedValues is List ? List.of(expectedValues) : null,
      isVisible: isVisible is bool ? isVisible : true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'dependsOnFieldId': dependsOnFieldId,
        'condition': condition,
        'expectedValue': expectedValue,
        'expectedValues': expectedValues,
        'isVisible': isVisible,
      };

  QuestionCondition copy() => QuestionCondition(
        dependsOnFieldId: dependsOnFieldId,
        condition: condition,
        expectedValue: expectedValue,
        expectedValues:
            expectedValues == null ? null : List.of(expectedValues!),
        isVisible: isVisible,
      );

  /// A rule that names a comparison but no answer to compare with cannot be
  /// what the author meant, so it is not saved as-is.
  bool get isComplete {
    if (!needsValue(condition)) return true;
    final values = expectedValues;
    if (values != null && values.isNotEmpty) return true;
    final value = expectedValue;
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    return true;
  }
}
