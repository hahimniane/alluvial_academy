import 'package:alluwalacademyadmin/core/utils/firebase_error_message.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _WebStyleWrapper {
  _WebStyleWrapper(this.error);
  final Object error;
}

void main() {
  test('messageFromFirebaseException uses message or code', () {
    expect(
      messageFromFirebaseError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      'permission-denied',
    );
    expect(
      messageFromFirebaseError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing permission',
        ),
      ),
      'Missing permission',
    );
  });

  test('unwraps .error like Flutter web interop wrapper', () {
    final inner = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
    expect(
      messageFromFirebaseError(_WebStyleWrapper(inner)),
      'Missing or insufficient permissions.',
    );
  });

  test('generic web wrapper without inner detail gets actionable text', () {
    final s = messageFromFirebaseError(
      'Dart exception thrown from converted Future. Use the properties',
    );
    expect(s, contains('Could not complete'));
    expect(s, isNot(contains('Something went wrong')));
  });

  test('permission hint embedded in wrapper string', () {
    final s = messageFromFirebaseError(
      'Dart exception thrown from converted Future. cloud_firestore permission-denied',
    );
    expect(s, contains('Permission denied'));
  });
}
