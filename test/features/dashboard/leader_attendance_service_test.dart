import 'package:alluwalacademyadmin/features/dashboard/services/leader_attendance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LeaderScheduledShiftRecord shift({
    required String id,
    required String leaderId,
    required DateTime start,
    required DateTime end,
  }) {
    return LeaderScheduledShiftRecord(
      id: id,
      leaderId: leaderId,
      leaderName: leaderId == 'leader-a' ? 'Amina Leader' : 'Binta Leader',
      start: start,
      end: end,
    );
  }

  group('LeaderAttendanceService.summarize', () {
    test('counts completed, absent, and late leader duties independently', () {
      final day = DateTime(2026, 7, 10);
      final summaries = LeaderAttendanceService.summarize(
        at: DateTime(2026, 7, 10, 18),
        shifts: [
          shift(
            id: 'completed-late',
            leaderId: 'leader-a',
            start: day.add(const Duration(hours: 9)),
            end: day.add(const Duration(hours: 10)),
          ),
          shift(
            id: 'absent',
            leaderId: 'leader-a',
            start: day.add(const Duration(hours: 11)),
            end: day.add(const Duration(hours: 12)),
          ),
        ],
        timesheets: [
          LeaderTimesheetRecord(
            shiftId: 'completed-late',
            clockIn: day.add(const Duration(hours: 9, minutes: 6)),
            clockOut: day.add(const Duration(hours: 10)),
          ),
        ],
      );

      expect(summaries, hasLength(1));
      expect(summaries.single.scheduledShifts, 2);
      expect(summaries.single.completedShifts, 1);
      expect(summaries.single.lateClockIns, 1);
      expect(summaries.single.absences, 1);
      expect(
        summaries.single.liveState,
        LeaderLiveAttendanceState.offDuty,
      );
    });

    test('marks an unclocked current duty late after the five-minute grace',
        () {
      final day = DateTime(2026, 7, 10);
      final summaries = LeaderAttendanceService.summarize(
        at: day.add(const Duration(hours: 9, minutes: 6)),
        shifts: [
          shift(
            id: 'current',
            leaderId: 'leader-a',
            start: day.add(const Duration(hours: 9)),
            end: day.add(const Duration(hours: 10)),
          ),
        ],
        timesheets: const [],
      );

      expect(
        summaries.single.liveState,
        LeaderLiveAttendanceState.lateNow,
      );
      expect(summaries.single.lateClockIns, 0);
      expect(summaries.single.absences, 0);
    });

    test('shows working leaders and keeps five-minute clock-ins on time', () {
      final day = DateTime(2026, 7, 10);
      final summaries = LeaderAttendanceService.summarize(
        at: day.add(const Duration(hours: 9, minutes: 30)),
        shifts: [
          shift(
            id: 'current',
            leaderId: 'leader-a',
            start: day.add(const Duration(hours: 9)),
            end: day.add(const Duration(hours: 10)),
          ),
          shift(
            id: 'late-current',
            leaderId: 'leader-b',
            start: day.add(const Duration(hours: 9)),
            end: day.add(const Duration(hours: 10)),
          ),
        ],
        timesheets: [
          LeaderTimesheetRecord(
            shiftId: 'current',
            clockIn: day.add(const Duration(hours: 9, minutes: 5)),
          ),
        ],
      );

      final working =
          summaries.firstWhere((summary) => summary.leaderId == 'leader-a');
      expect(working.liveState, LeaderLiveAttendanceState.working);
      expect(working.lateClockIns, 0);
      expect(summaries.first.leaderId, 'leader-b');
      expect(summaries.first.liveState, LeaderLiveAttendanceState.lateNow);
    });
  });
}
