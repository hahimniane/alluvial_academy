import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/enrollment_management/utils/family_class.dart';

void main() {
  Map<String, dynamic> doc({String type = 'Exclusive Family Class', String? link = 'L1', String subject = 'Adlam'}) => {
        'program': {'classType': type},
        'metadata': {'parentLinkId': link},
        'subject': subject,
      };

  test('siblings from one submission and subject share a key', () {
    expect(familyClassKey(doc()), familyClassKey(doc(subject: 'adlam ')));
  });

  test('a different subject, submission or class type is its own class', () {
    expect(familyClassKey(doc()), isNot(familyClassKey(doc(subject: 'Quran'))));
    expect(familyClassKey(doc()), isNot(familyClassKey(doc(link: 'L2'))));
    expect(familyClassKey(doc(type: 'Group')), isNull);
    expect(familyClassKey(doc(link: null)), isNull);
    expect(familyClassKey(doc(link: '')), isNull);
  });

  test('names read naturally', () {
    expect(listNames(['test 1']), 'test 1');
    expect(listNames(['test 1', 'test 2']), 'test 1 and test 2');
    expect(listNames(['a', 'b', ' c ']), 'a, b and c');
    expect(listNames(['', ' ']), '');
  });
}
