import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/forms/utils/form_answer_order.dart';

void main() {
  group('FormAnswerOrder.fieldOrder', () {
    test('ranks map-shaped fields by stored order, not key order', () {
      final order = FormAnswerOrder.fieldOrder({
        'zeta': {'label': 'Third', 'order': 3},
        'alpha': {'label': 'Second', 'order': 2},
        'mid': {'label': 'First', 'order': 1},
      });
      expect(order, {'mid': 0, 'alpha': 1, 'zeta': 2});
    });

    test('treats order 0 as a real order', () {
      final order = FormAnswerOrder.fieldOrder({
        'b': {'order': 1},
        'a': {'order': 0},
      });
      expect(order, {'a': 0, 'b': 1});
      expect(FormAnswerOrder.storedOrder(0), 0);
      expect(FormAnswerOrder.storedOrder('2'), 2);
      expect(FormAnswerOrder.storedOrder(null), isNull);
    });

    test('list-shaped fields without an order keep their position', () {
      final order = FormAnswerOrder.fieldOrder([
        {'id': 'q1'},
        {'id': 'q2'},
        {'label': 'no id'},
      ]);
      expect(order, {'q1': 0, 'q2': 1, 'field_2': 2});
    });

    test('equal orders fall back to stored position', () {
      final order = FormAnswerOrder.fieldOrder([
        {'id': 'first', 'order': 1},
        {'id': 'second', 'order': 1},
      ]);
      expect(order, {'first': 0, 'second': 1});
    });
  });

  test('orderEntries sorts answers by question order, unknown answers last',
      () {
    final order = FormAnswerOrder.fieldOrder({
      'q_late': {'order': 5},
      'q_early': {'order': 1},
      'q_mid': {'order': 3},
    });
    final responses = <String, dynamic>{
      'orphan_b': 'x',
      'q_late': 'c',
      'orphan_a': 'y',
      'q_early': 'a',
      'q_mid': 'b',
    };
    expect(
      FormAnswerOrder.orderEntries(responses, order).map((e) => e.key),
      ['q_early', 'q_mid', 'q_late', 'orphan_b', 'orphan_a'],
    );
  });

  test('orderEntries keeps stored order when there is no template order', () {
    final responses = <String, dynamic>{'b': 1, 'a': 2};
    expect(
      FormAnswerOrder.orderEntries(responses, const {}).map((e) => e.key),
      ['b', 'a'],
    );
  });
}
