import 'package:alluwalacademyadmin/features/time_clock/utils/timesheet_hh_mm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse HH:MM and HH:MM:SS to seconds', () {
    expect(timesheetParseDurationToSeconds('00:03'), 180);
    expect(timesheetParseDurationToSeconds('01:05'), 3900);
    expect(timesheetParseDurationToSeconds('00:00:12'), 12);
    expect(timesheetParseDurationToSeconds('00:00:27'), 27);
    expect(timesheetParseDurationToSeconds('00:03:10'), 190);
  });

  test('parse and format round-trip (minute precision)', () {
    expect(timesheetParseHhMmToMinutes('00:03'), 3);
    expect(timesheetParseHhMmToMinutes('01:05'), 65);
    expect(timesheetFormatMinutesAsHhMm(3), '00:03');
    expect(timesheetFormatMinutesAsHhMm(65), '01:05');
  });

  test('sumChildrenMinutes sums HH:MM strings', () {
    expect(
      timesheetSumChildrenMinutes(['00:01', '00:02', '00:02']),
      5,
    );
    expect(
      timesheetFormatMinutesAsHhMm(
        timesheetSumChildrenMinutes(['00:01', '00:02', '00:02']),
      ),
      '00:05',
    );
  });

  test('sumChildrenSeconds matches HH:MM:SS rows (admin consolidated dialog)',
      () {
    const rows = ['00:00:12', '00:00:27', '00:03:10'];
    expect(timesheetSumChildrenSeconds(rows), 12 + 27 + 190);
    expect(
      timesheetFormatSecondsAsHhMmSs(timesheetSumChildrenSeconds(rows)),
      '00:03:49',
    );
  });
}
