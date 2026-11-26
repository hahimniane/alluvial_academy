import 'package:alluwalacademyadmin/features/forms/widgets/form_share_link_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a form is shared by the website /form/ link with its template id', () {
    expect(formShareLink('abc123'),
        'https://alluwaleducationhub.org/form/?id=abc123');
    expect(formShareLink('a b&c'),
        'https://alluwaleducationhub.org/form/?id=a+b%26c');
  });

  test('file questions are found in list and map shaped fields', () {
    expect(
        formHasFileQuestions([
          {'type': 'text'},
          {'type': 'image_upload'},
        ]),
        isTrue);
    expect(
        formHasFileQuestions({
          'q1': {'type': 'signature'},
        }),
        isTrue);
    expect(
        formHasFileQuestions({
          'q1': {'type': 'dropdown'},
          'q2': {'type': 'image'},
        }),
        isFalse);
    expect(formHasFileQuestions(null), isFalse);
  });
}
