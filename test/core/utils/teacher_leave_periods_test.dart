import 'package:alluwalacademyadmin/core/utils/teacher_leave_periods.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> excuse(String from, String to, {String review = 'accepted', String teacher = 't1'}) => {
      'templateId': '6YBwJQoLQ5tNU3RjDp7f',
      'userId': teacher,
      'reviewStatus': review,
      'responses': {'1754402840684': from, '1754402885007': to},
    };

bool covers(List<({DateTime start, DateTime end})> periods, DateTime at) =>
    periods.any((p) => !at.isBefore(p.start) && at.isBefore(p.end));

void main() {
  group('parseDateField', () {
    test('reads the forms\' day/month/year text', () {
      expect(TeacherLeavePeriods.parseDateField('18/6/2026'), DateTime(2026, 6, 18));
      expect(TeacherLeavePeriods.parseDateField('4/7/2026'), DateTime(2026, 7, 4));
      expect(TeacherLeavePeriods.parseDateField(' 01/03/2026 '), DateTime(2026, 3, 1));
    });

    test('a second part over 12 can only be month/day/year', () {
      expect(TeacherLeavePeriods.parseDateField('6/18/2026'), DateTime(2026, 6, 18));
    });

    test('reads ISO text and Timestamps; refuses impossible dates', () {
      expect(TeacherLeavePeriods.parseDateField('2026-06-18'), DateTime(2026, 6, 18));
      expect(TeacherLeavePeriods.parseDateField(Timestamp.fromDate(DateTime(2026, 6, 18, 9))), DateTime(2026, 6, 18, 9));
      expect(TeacherLeavePeriods.parseDateField('31/2/2026'), isNull);
      expect(TeacherLeavePeriods.parseDateField(''), isNull);
      expect(TeacherLeavePeriods.parseDateField(null), isNull);
    });
  });

  group('periodsForTeacherFromFormDocs', () {
    test('an accepted excuse covers every class from the first day to the end of the last day', () {
      final periods = TeacherLeavePeriods.periodsForTeacherFromFormDocs([excuse('18/6/2026', '19/6/2026')], 't1');
      expect(covers(periods, DateTime(2026, 6, 18, 0, 30)), isTrue);
      expect(covers(periods, DateTime(2026, 6, 19, 22)), isTrue);
      expect(covers(periods, DateTime(2026, 6, 20, 0, 1)), isFalse);
      expect(covers(periods, DateTime(2026, 6, 17, 23)), isFalse);
    });

    test('a one-day excuse covers that day', () {
      final periods = TeacherLeavePeriods.periodsForTeacherFromFormDocs([excuse('5/11/2026', '5/11/2026')], 't1');
      expect(covers(periods, DateTime(2026, 11, 5, 15)), isTrue);
    });

    test('dates entered back to front still cover the days between', () {
      final periods = TeacherLeavePeriods.periodsForTeacherFromFormDocs([excuse('12/6/2026', '3/6/2026')], 't1');
      expect(covers(periods, DateTime(2026, 6, 8, 10)), isTrue);
    });

    test('only accepted excuses of that teacher count', () {
      final docs = [
        excuse('18/6/2026', '19/6/2026', review: ''),
        excuse('18/6/2026', '19/6/2026', review: 'rejected'),
        excuse('18/6/2026', '19/6/2026', teacher: 't2'),
      ];
      expect(TeacherLeavePeriods.periodsForTeacherFromFormDocs(docs, 't1'), isEmpty);
    });
  });
}
