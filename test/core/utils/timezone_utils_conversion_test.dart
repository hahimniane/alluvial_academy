import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/core/utils/timezone_utils.dart';

void main() {
  group('TimezoneUtils conversions', () {
    test('Conakry -> New York (winter) converts correctly', () {
      TimezoneUtils.initializeTimezones();

      // 7:30 PM in Conakry (UTC+0) should be 2:30 PM in New York (UTC-5) in winter.
      final localConakry = DateTime(2025, 1, 15, 19, 30);
      final utc = TimezoneUtils.convertToUtc(localConakry, 'Africa/Conakry');
      final ny = TimezoneUtils.convertToTimezone(utc, 'America/New_York');

      expect(utc.toUtc(), DateTime.utc(2025, 1, 15, 19, 30));
      expect(ny.year, 2025);
      expect(ny.month, 1);
      expect(ny.day, 15);
      expect(ny.hour, 14);
      expect(ny.minute, 30);
    });

    test('Conakry -> New York (summer) converts correctly', () {
      TimezoneUtils.initializeTimezones();

      // 7:30 PM in Conakry (UTC+0) should be 3:30 PM in New York (UTC-4) in summer.
      final localConakry = DateTime(2025, 7, 15, 19, 30);
      final utc = TimezoneUtils.convertToUtc(localConakry, 'Africa/Conakry');
      final ny = TimezoneUtils.convertToTimezone(utc, 'America/New_York');

      expect(utc.toUtc(), DateTime.utc(2025, 7, 15, 19, 30));
      expect(ny.year, 2025);
      expect(ny.month, 7);
      expect(ny.day, 15);
      expect(ny.hour, 15);
      expect(ny.minute, 30);
    });
  });
}
