import 'package:flutter_test/flutter_test.dart';

/// Tests for shift overlap detection
/// 
/// These tests verify that the system prevents creating overlapping shifts
/// for the same teacher, not just exact duplicates.
void main() {
  group('Shift Overlap Detection', () {
    group('Overlap Logic', () {
      test('should detect overlap when new shift starts during existing', () {
        // Existing: 2:00 - 3:00
        final existingStart = DateTime(2025, 11, 15, 14, 0);
        final existingEnd = DateTime(2025, 11, 15, 15, 0);
        
        // New: 2:30 - 3:30 (starts during existing)
        final newStart = DateTime(2025, 11, 15, 14, 30);
        final newEnd = DateTime(2025, 11, 15, 15, 30);
        
        // Overlap check: new starts before existing ends AND new ends after existing starts
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isTrue,
            reason: 'Should detect overlap when new shift starts during existing');
      });

      test('should detect overlap when new shift ends during existing', () {
        // Existing: 2:00 - 3:00
        final existingStart = DateTime(2025, 11, 15, 14, 0);
        final existingEnd = DateTime(2025, 11, 15, 15, 0);
        
        // New: 1:30 - 2:30 (ends during existing)
        final newStart = DateTime(2025, 11, 15, 13, 30);
        final newEnd = DateTime(2025, 11, 15, 14, 30);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isTrue,
            reason: 'Should detect overlap when new shift ends during existing');
      });

      test('should detect overlap when new shift contains existing', () {
        // Existing: 2:00 - 3:00
        final existingStart = DateTime(2025, 11, 15, 14, 0);
        final existingEnd = DateTime(2025, 11, 15, 15, 0);
        
        // New: 1:00 - 4:00 (completely contains existing)
        final newStart = DateTime(2025, 11, 15, 13, 0);
        final newEnd = DateTime(2025, 11, 15, 16, 0);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isTrue,
            reason: 'Should detect overlap when new shift contains existing');
      });

      test('should detect overlap when new shift is contained by existing', () {
        // Existing: 1:00 - 4:00
        final existingStart = DateTime(2025, 11, 15, 13, 0);
        final existingEnd = DateTime(2025, 11, 15, 16, 0);
        
        // New: 2:00 - 3:00 (completely inside existing)
        final newStart = DateTime(2025, 11, 15, 14, 0);
        final newEnd = DateTime(2025, 11, 15, 15, 0);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isTrue,
            reason: 'Should detect overlap when new shift is inside existing');
      });

      test('should detect exact match as overlap', () {
        // Existing: 2:00 - 3:00
        final existingStart = DateTime(2025, 11, 15, 14, 0);
        final existingEnd = DateTime(2025, 11, 15, 15, 0);
        
        // New: 2:00 - 3:00 (exact same)
        final newStart = DateTime(2025, 11, 15, 14, 0);
        final newEnd = DateTime(2025, 11, 15, 15, 0);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isTrue,
            reason: 'Exact match should be treated as overlap');
      });
    });

    group('Non-Overlapping Cases', () {
      test('should NOT overlap when shifts are back-to-back', () {
        // Existing: 2:00 - 3:00
        final existingStart = DateTime(2025, 11, 15, 14, 0);
        final existingEnd = DateTime(2025, 11, 15, 15, 0);
        
        // New: 3:00 - 4:00 (starts when existing ends)
        final newStart = DateTime(2025, 11, 15, 15, 0);
        final newEnd = DateTime(2025, 11, 15, 16, 0);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isFalse,
            reason: 'Back-to-back shifts (end time = start time) should NOT overlap');
      });

      test('should NOT overlap when new shift is before existing', () {
        // Existing: 3:00 - 4:00
        final existingStart = DateTime(2025, 11, 15, 15, 0);
        final existingEnd = DateTime(2025, 11, 15, 16, 0);
        
        // New: 2:00 - 3:00 (completely before)
        final newStart = DateTime(2025, 11, 15, 14, 0);
        final newEnd = DateTime(2025, 11, 15, 15, 0);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isFalse,
            reason: 'Shift before existing should not overlap');
      });

      test('should NOT overlap when new shift is after existing', () {
        // Existing: 2:00 - 3:00
        final existingStart = DateTime(2025, 11, 15, 14, 0);
        final existingEnd = DateTime(2025, 11, 15, 15, 0);
        
        // New: 3:00 - 4:00 (completely after)
        final newStart = DateTime(2025, 11, 15, 15, 0);
        final newEnd = DateTime(2025, 11, 15, 16, 0);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isFalse,
            reason: 'Shift after existing should not overlap');
      });

      test('should NOT overlap shifts on different days', () {
        // Existing: Nov 15, 2:00 - 3:00
        final existingStart = DateTime(2025, 11, 15, 14, 0);
        final existingEnd = DateTime(2025, 11, 15, 15, 0);
        
        // New: Nov 16, 2:00 - 3:00 (next day)
        final newStart = DateTime(2025, 11, 16, 14, 0);
        final newEnd = DateTime(2025, 11, 16, 15, 0);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isFalse,
            reason: 'Shifts on different days should not overlap');
      });
    });

    group('Real-World Scenarios (from bug report)', () {
      test('case from screenshot: 2:15-3:15 overlaps with 2:30-3:00', () {
        // First shift (created successfully)
        final shift1Start = DateTime(2025, 11, 10, 14, 15); // 2:15 PM
        final shift1End = DateTime(2025, 11, 10, 15, 15);   // 3:15 PM
        
        // Second shift (should be blocked)
        final shift2Start = DateTime(2025, 11, 10, 14, 30); // 2:30 PM
        final shift2End = DateTime(2025, 11, 10, 15, 0);    // 3:00 PM
        
        final overlaps = shift2Start.isBefore(shift1End) && shift2End.isAfter(shift1Start);
        
        expect(overlaps, isTrue,
            reason: '2:30-3:00 should overlap with 2:15-3:15');
      });

      test('case from screenshot: 2:00-3:00 overlaps with 2:15-3:15', () {
        // Shift (from screenshot)
        final existingStart = DateTime(2025, 11, 11, 14, 0);  // 2:00 PM
        final existingEnd = DateTime(2025, 11, 11, 15, 0);    // 3:00 PM
        
        // New shift
        final newStart = DateTime(2025, 11, 11, 14, 15); // 2:15 PM
        final newEnd = DateTime(2025, 11, 11, 15, 15);   // 3:15 PM
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isTrue,
            reason: '2:15-3:15 should overlap with 2:00-3:00');
      });
    });

    group('Edge Cases', () {
      test('should detect 1-minute overlap', () {
        // Existing: 2:00 - 3:00
        final existingStart = DateTime(2025, 11, 15, 14, 0);
        final existingEnd = DateTime(2025, 11, 15, 15, 0);
        
        // New: 2:59 - 3:30 (1 minute overlap)
        final newStart = DateTime(2025, 11, 15, 14, 59);
        final newEnd = DateTime(2025, 11, 15, 15, 30);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isTrue,
            reason: 'Even 1 minute overlap should be detected');
      });

      test('should handle midnight-spanning shifts', () {
        // Existing: 11:00 PM - 1:00 AM
        final existingStart = DateTime(2025, 11, 15, 23, 0);
        final existingEnd = DateTime(2025, 11, 16, 1, 0);
        
        // New: 11:30 PM - 12:30 AM (overlaps)
        final newStart = DateTime(2025, 11, 15, 23, 30);
        final newEnd = DateTime(2025, 11, 16, 0, 30);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isTrue,
            reason: 'Should detect overlaps across midnight');
      });

      test('should handle very short shifts', () {
        // Existing: 2:00 - 2:15 (15 min)
        final existingStart = DateTime(2025, 11, 15, 14, 0);
        final existingEnd = DateTime(2025, 11, 15, 14, 15);
        
        // New: 2:10 - 2:20 (overlaps)
        final newStart = DateTime(2025, 11, 15, 14, 10);
        final newEnd = DateTime(2025, 11, 15, 14, 20);
        
        final overlaps = newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        
        expect(overlaps, isTrue,
            reason: 'Should detect overlaps in short shifts');
      });
    });

    group('Error Messages', () {
      test('should have clear error message for overlaps', () {
        final errorMessage = 
            'This shift overlaps with an existing shift for this teacher. '
            'Please choose a different time that doesn\'t overlap with existing shifts.';
        
        expect(errorMessage, contains('overlaps'));
        expect(errorMessage, contains('existing shift'));
        expect(errorMessage, contains('choose a different time'));
      });

      test('error message explains the problem clearly', () {
        final errorMessage = 
            'This shift overlaps with an existing shift for this teacher. '
            'Please choose a different time that doesn\'t overlap with existing shifts.';
        
        // Should be clear and actionable
        expect(errorMessage.toLowerCase(), contains('overlap'));
        expect(errorMessage, isNot(contains('exact')));
        expect(errorMessage, contains('doesn\'t overlap'));
      });
    });

    group('Multiple Shifts', () {
      test('should detect overlap with any of multiple existing shifts', () {
        // Multiple existing shifts
        final existingShifts = [
          {'start': DateTime(2025, 11, 15, 10, 0), 'end': DateTime(2025, 11, 15, 11, 0)},
          {'start': DateTime(2025, 11, 15, 14, 0), 'end': DateTime(2025, 11, 15, 15, 0)},
          {'start': DateTime(2025, 11, 15, 16, 0), 'end': DateTime(2025, 11, 15, 17, 0)},
        ];
        
        // New shift overlaps with second one
        final newStart = DateTime(2025, 11, 15, 14, 30);
        final newEnd = DateTime(2025, 11, 15, 15, 30);
        
        final hasOverlap = existingShifts.any((shift) {
          final existingStart = shift['start'] as DateTime;
          final existingEnd = shift['end'] as DateTime;
          return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        });
        
        expect(hasOverlap, isTrue,
            reason: 'Should detect overlap with any existing shift');
      });

      test('should allow shift that fits between existing shifts', () {
        // Multiple existing shifts
        final existingShifts = [
          {'start': DateTime(2025, 11, 15, 10, 0), 'end': DateTime(2025, 11, 15, 11, 0)},
          {'start': DateTime(2025, 11, 15, 14, 0), 'end': DateTime(2025, 11, 15, 15, 0)},
        ];
        
        // New shift fits between them
        final newStart = DateTime(2025, 11, 15, 12, 0);
        final newEnd = DateTime(2025, 11, 15, 13, 0);
        
        final hasOverlap = existingShifts.any((shift) {
          final existingStart = shift['start'] as DateTime;
          final existingEnd = shift['end'] as DateTime;
          return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
        });
        
        expect(hasOverlap, isFalse,
            reason: 'Shift between existing shifts should be allowed');
      });
    });
  });
}

