import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/core/services/join_link_service.dart';

void main() {
  group('JoinLinkService.removeJoinParameters', () {
    test('removes direct authenticated join params', () {
      final uri = Uri.parse(
        'https://alluwaleducationhub.org/?joinShift=shift_1&tab=classes',
      );

      expect(
        JoinLinkService.removeJoinParameters(uri).toString(),
        'https://alluwaleducationhub.org/?tab=classes',
      );
    });

    test('removes direct guest join params', () {
      final uri = Uri.parse(
        'https://alluwaleducationhub.org/?guestShift=shift_1',
      );

      expect(
        JoinLinkService.removeJoinParameters(uri).toString(),
        'https://alluwaleducationhub.org/',
      );
    });

    test('removes fragment join params without leaving a rejoin link behind',
        () {
      final uri = Uri.parse(
        'https://alluwaleducationhub.org/#/classes?joinShift=shift_1&tab=today',
      );

      expect(
        JoinLinkService.removeJoinParameters(uri).toString(),
        'https://alluwaleducationhub.org/#/classes?tab=today',
      );
    });
  });
}
