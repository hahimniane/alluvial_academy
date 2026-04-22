import 'package:alluwalacademyadmin/core/services/public_site_cms_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PublicSiteDirectoryUser.fromJson maps callable payload', () {
    final u = PublicSiteDirectoryUser.fromJson({
      'uid': 'abc123',
      'docId': 'doc1',
      'email': 'a@b.com',
      'displayName': 'Ada Lovelace',
      'userType': 'teacher',
    });
    expect(u.uid, 'abc123');
    expect(u.docId, 'doc1');
    expect(u.email, 'a@b.com');
    expect(u.displayName, 'Ada Lovelace');
    expect(u.userType, 'teacher');
  });

  test('PublicSiteCmsValidationException carries code', () {
    final e = PublicSiteCmsValidationException('duplicate_linked_user');
    expect(e.code, 'duplicate_linked_user');
    expect(e.toString(), contains('duplicate_linked_user'));
  });
}
