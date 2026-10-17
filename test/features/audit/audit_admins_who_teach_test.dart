import 'package:alluwalacademyadmin/features/audit/services/audit_performance_optimizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isTaughtClass', () {
    test('a teaching shift with students is a class to audit', () {
      expect(isTaughtClass({'shift_category': 'teaching', 'student_ids': ['s1']}), isTrue);
      // older shifts carry no category; they default to teaching
      expect(isTaughtClass({'student_ids': ['s1', 's2']}), isTrue);
    });

    test('leadership shifts are not audited', () {
      expect(isTaughtClass({'shift_category': 'leadership', 'leader_role': 'admin', 'student_ids': []}), isFalse);
      expect(isTaughtClass({'shift_category': 'meeting', 'student_ids': ['s1']}), isFalse);
    });

    test('a teaching shift with no students is not a class', () {
      expect(isTaughtClass({'shift_category': 'teaching', 'student_ids': []}), isFalse);
      expect(isTaughtClass({'shift_category': 'teaching'}), isFalse);
    });
  });
}
