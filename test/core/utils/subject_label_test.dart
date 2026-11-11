import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/core/utils/subject_label.dart';

void main() {
  test('uses the display name, then the subject', () {
    expect(classSubjectLabel({'subject_display_name': 'Quran', 'subject': 'q'}), 'Quran');
    expect(classSubjectLabel({'subject': 'Arabic'}), 'Arabic');
  });

  test('a blank name never becomes an empty key', () {
    expect(classSubjectLabel({'subject_display_name': '', 'subject': ''}), 'Other');
    expect(classSubjectLabel({'subject_display_name': '  ', 'subject': 'Math'}), 'Math');
    expect(classSubjectLabel({}), 'Other');
  });
}
