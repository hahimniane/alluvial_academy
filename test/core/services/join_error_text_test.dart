import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/core/services/class_video_service.dart';

String text(String code, String? message) => ClassVideoService.joinErrorText(
      FirebaseFunctionsException(code: code, message: message ?? ''),
      fallbackError: 'Failed to connect to class',
      slowConnectionError: 'slow',
    );

void main() {
  test('Android timeout code becomes the slow-connection sentence', () {
    expect(text('deadline-exceeded', 'DEADLINE_EXCEEDED'), 'slow');
    expect(text('unavailable', 'UNAVAILABLE'), 'slow');
  });

  test('bare internal or empty message falls back', () {
    expect(text('internal', 'INTERNAL'), 'Failed to connect to class');
    expect(text('unknown', null), 'Failed to connect to class');
  });

  test('a message the server wrote is kept', () {
    expect(text('failed-precondition', 'This class has ended.'),
        'This class has ended.');
    expect(text('unavailable', 'The classroom is coming back.'),
        'The classroom is coming back.');
    expect(text('deadline-exceeded', 'Time is up for this question'),
        'Time is up for this question');
  });
}
