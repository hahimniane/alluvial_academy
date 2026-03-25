import 'package:alluwalacademyadmin/features/forms/utils/form_response_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormResponseGrouping', () {
    test('merges legacy and template definitions with the same visible title',
        () {
      final groups = FormResponseGrouping.buildGroups(
        definitions: const [
          FormDefinitionRecord(
            id: 'legacy_daily',
            source: FormDefinitionSource.legacy,
            data: {
              'title': 'Daily Class Report',
              'createdAt': null,
            },
          ),
          FormDefinitionRecord(
            id: 'daily_class_report',
            source: FormDefinitionSource.template,
            data: {
              'name': 'Daily Class Report',
              'isActive': true,
            },
          ),
        ],
        responses: const [
          FormResponseRecord(
            id: 'r1',
            data: {
              'formId': 'legacy_daily',
              'formName': 'Daily Class Report',
            },
          ),
          FormResponseRecord(
            id: 'r2',
            data: {
              'formId': 'daily_class_report',
              'templateId': 'daily_class_report',
              'formName': 'Daily Class Report',
            },
          ),
          FormResponseRecord(
            id: 'r3',
            data: {
              'formId': 'daily_class_report',
              'templateId': 'daily_class_report',
              'formName': 'Daily Class Report',
            },
          ),
        ],
      );

      expect(groups, hasLength(1));
      expect(groups.single.title, 'Daily Class Report');
      expect(groups.single.entries, 3);
      expect(groups.single.representativeFormId, 'daily_class_report');
      expect(groups.single.responseFormIds,
          containsAll(<String>['legacy_daily', 'daily_class_report']));
    });

    test(
        'keeps response-visible groups even when no definition document exists',
        () {
      final groups = FormResponseGrouping.buildGroups(
        definitions: const [],
        responses: const [
          FormResponseRecord(
            id: 'r1',
            data: {
              'formId': 'orphan_form',
              'formName': 'CEO Shift Review',
            },
          ),
        ],
      );

      expect(groups, hasLength(1));
      expect(groups.single.title, 'CEO Shift Review');
      expect(groups.single.entries, 1);
      expect(groups.single.responseFormIds, <String>['orphan_form']);
    });

    test('uses form activity flags to resolve archive state', () {
      expect(
        FormResponseGrouping.isArchived({'status': 'inactive'}),
        isTrue,
      );
      expect(
        FormResponseGrouping.isArchived({'isActive': false}),
        isTrue,
      );
      expect(
        FormResponseGrouping.resolveStatus({'isActive': false}),
        'inactive',
      );
    });
  });
}
