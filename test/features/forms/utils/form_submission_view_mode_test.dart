import 'package:alluwalacademyadmin/features/forms/utils/form_submission_view_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isDailyClassReportForm', () {
    test('matches Daily Class Report titles', () {
      expect(
        isDailyClassReportForm(formTitle: 'Daily Class Report'),
        isTrue,
      );
      expect(
        isDailyClassReportForm(formTitle: 'Rapport de classe quotidien'),
        isTrue,
      );
    });

    test('matches canonical daily class report template id', () {
      expect(
        isDailyClassReportForm(
          formTitle: 'Anything',
          templateId: 'daily_class_report',
        ),
        isTrue,
      );
    });

    test('does not misclassify other daily forms', () {
      expect(
        isDailyClassReportForm(formTitle: 'Daily End of Shift form - CEO'),
        isFalse,
      );
      expect(
        isDailyClassReportForm(
          formTitle: 'Daily End of Shift form - CEO',
          templateId: '4G0oKBSTA8l0780cQ2Vx',
        ),
        isFalse,
      );
    });
  });
}
