import 'package:alluwalacademyadmin/features/dashboard/models/enrollment_slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('slot windows', () {
    test('teacher slots slide by 30 minutes', () {
      // Evening is 4:00 PM – 8:59 PM. A 2-hour class must offer every
      // half-hour start, not just the non-overlapping 4–6 and 6–8.
      expect(slotsFor(blockById('Evening'), 120), [
        '4:00 PM - 6:00 PM',
        '4:30 PM - 6:30 PM',
        '5:00 PM - 7:00 PM',
        '5:30 PM - 7:30 PM',
        '6:00 PM - 8:00 PM',
        '6:30 PM - 8:30 PM',
        '7:00 PM - 9:00 PM',
      ]);
      expect(slotsFor(blockById('Evening'), 120, step: 120),
          ['4:00 PM - 6:00 PM', '6:00 PM - 8:00 PM']);
    });

    test('an afternoon of one-hour classes offers seven windows', () {
      final slots = slotsFor(blockById('Afternoon'), 60);
      expect(slots.length, 7);
      expect(slots.first, '12:00 PM - 1:00 PM');
      expect(slots.last, '3:00 PM - 4:00 PM');
    });

    test('a session that cannot fit its block yields nothing', () {
      expect(sessionFitsBlock(blockById('Night'), 180), isTrue);
      expect(sessionFitsBlock(blockById('Night'), 210), isFalse);
      expect(slotsFor(blockById('Late night'), 360), isEmpty);
    });

    test('slots never cross midnight', () {
      final night = slotsFor(blockById('Night'), 60);
      expect(night.last, '11:00 PM - 12:00 AM');
      for (final block in kTimeBlocks) {
        for (final slot in slotsFor(block, 60)) {
          expect(slot.contains('null'), isFalse);
        }
      }
    });

    test('bad input yields no slots rather than throwing', () {
      expect(slotsFor(null, 60), isEmpty);
      expect(slotsFor(blockById('Evening'), 0), isEmpty);
      expect(slotsFor(blockById('Evening'), -30), isEmpty);
      expect(slotsFor(blockById('Evening'), 60, step: 0), isEmpty);
      expect(blockById(''), isNull);
      expect(blockById('Flexible'), isNull);
    });

    test('the five blocks tile the day and label their range', () {
      expect(blockById('Evening')!.rangeLabel, '4:00 PM – 8:59 PM');
      expect(blockById('Night')!.rangeLabel, '9:00 PM – 11:59 PM');
      final sorted = [...kTimeBlocks]..sort((a, b) => a.startMinutes - b.startMinutes);
      expect(sorted.first.startMinutes, 0);
      expect(sorted.last.endMinutes, 1440);
      for (var i = 1; i < sorted.length; i++) {
        expect(sorted[i].startMinutes, sorted[i - 1].endMinutes);
      }
    });
  });

  group('duration labels', () {
    test('reads hours, minutes and fractions', () {
      // The regression: "1.5 hours" used to render as "1 min".
      expect(minutesFromDurationLabel('1.5 hours'), 90);
      expect(minutesFromDurationLabel('1 hr'), 60);
      expect(minutesFromDurationLabel('2 hrs'), 120);
      expect(minutesFromDurationLabel('30 mins'), 30);
      expect(minutesFromDurationLabel('1 hr 30 mins'), 90);
      expect(minutesFromDurationLabel('60 minutes'), 60);
      expect(minutesFromDurationLabel(''), 60);
      expect(minutesFromDurationLabel(null), 60);
    });

    test('labels read the way the web does', () {
      expect(sessionLabel(30), '30 min');
      expect(sessionLabel(60), '1 hour');
      expect(sessionLabel(90), '1.5 hours');
      expect(sessionLabel(120), '2 hours');
    });
  });
}
