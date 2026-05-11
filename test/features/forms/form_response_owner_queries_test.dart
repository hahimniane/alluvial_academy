import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/features/forms/utils/form_response_owner_queries.dart';

void main() {
  test('no-form-id group key matches admin export grouping semantics', () {
    expect(kMySubmissionsNoFormIdGroupKey, '__no_form_id__');
  });
}
