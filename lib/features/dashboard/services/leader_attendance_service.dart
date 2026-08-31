import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaderLiveAttendanceState {
  working,
  lateNow,
  awaitingClockIn,
  scheduledLater,
  offDuty,
}

class LeaderScheduledShiftRecord {
  final String id;
  final String leaderId;
  final String leaderName;
  final DateTime start;
  final DateTime end;

  const LeaderScheduledShiftRecord({
    required this.id,
    required this.leaderId,
    required this.leaderName,
    required this.start,
    required this.end,
  });
}

class LeaderTimesheetRecord {
  final String shiftId;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String? clockInStatus;

  const LeaderTimesheetRecord({
    required this.shiftId,
    this.clockIn,
    this.clockOut,
    this.clockInStatus,
  });
}

class LeaderAttendanceSummary {
  final String leaderId;
  final String leaderName;
  final int scheduledShifts;
  final int completedShifts;
  final int absences;
  final int lateClockIns;
  final LeaderLiveAttendanceState liveState;
  final DateTime? relevantShiftStart;
  final DateTime? relevantShiftEnd;

  const LeaderAttendanceSummary({
    required this.leaderId,
    required this.leaderName,
    required this.scheduledShifts,
    required this.completedShifts,
    required this.absences,
    required this.lateClockIns,
    required this.liveState,
    this.relevantShiftStart,
    this.relevantShiftEnd,
  });
}

class LeaderAttendanceService {
  static const Duration lateTolerance = Duration(minutes: 5);
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<LeaderAttendanceSummary>> loadMonthly({
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    final shiftSnapshot = await _firestore
        .collection('teaching_shifts')
        .where(
          'shift_start',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where('shift_start', isLessThan: Timestamp.fromDate(monthEnd))
        .get();

    final shifts = <LeaderScheduledShiftRecord>[];
    for (final doc in shiftSnapshot.docs) {
      final data = doc.data();
      final category = data['category']?.toString() ?? 'teaching';
      final status = data['status']?.toString();
      if (category == 'teaching' || status == 'cancelled') continue;

      final leaderId = data['teacher_id']?.toString().trim() ?? '';
      final start = _dateFrom(data['shift_start']);
      final end = _dateFrom(data['shift_end']);
      if (leaderId.isEmpty || start == null || end == null) continue;

      shifts.add(
        LeaderScheduledShiftRecord(
          id: doc.id,
          leaderId: leaderId,
          leaderName: _leaderName(data, leaderId),
          start: start,
          end: end,
        ),
      );
    }

    final timesheets = <LeaderTimesheetRecord>[];
    final shiftIds = shifts.map((shift) => shift.id).toList();
    for (var index = 0; index < shiftIds.length; index += 10) {
      final batch = shiftIds.skip(index).take(10).toList();
      final snapshot = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', whereIn: batch)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final shiftId = data['shift_id']?.toString() ?? '';
        if (shiftId.isEmpty) continue;
        timesheets.add(
          LeaderTimesheetRecord(
            shiftId: shiftId,
            clockIn: _dateFrom(
              data['clock_in_timestamp'] ?? data['clock_in_time'],
            ),
            clockOut: _dateFrom(
              data['clock_out_timestamp'] ?? data['clock_out_time'],
            ),
            clockInStatus: data['clock_in_status']?.toString(),
          ),
        );
      }
    }

    return summarize(shifts: shifts, timesheets: timesheets, at: now);
  }

  static List<LeaderAttendanceSummary> summarize({
    required Iterable<LeaderScheduledShiftRecord> shifts,
    required Iterable<LeaderTimesheetRecord> timesheets,
    required DateTime at,
  }) {
    final timesheetsByShift = <String, List<LeaderTimesheetRecord>>{};
    for (final timesheet in timesheets) {
      timesheetsByShift.putIfAbsent(timesheet.shiftId, () => []).add(timesheet);
    }

    final shiftsByLeader = <String, List<LeaderScheduledShiftRecord>>{};
    for (final shift in shifts) {
      shiftsByLeader.putIfAbsent(shift.leaderId, () => []).add(shift);
    }

    final summaries = <LeaderAttendanceSummary>[];
    for (final entry in shiftsByLeader.entries) {
      final leaderShifts = entry.value
        ..sort((a, b) => a.start.compareTo(b.start));
      var completed = 0;
      var absences = 0;
      var lateClockIns = 0;
      LeaderScheduledShiftRecord? workingShift;
      LeaderScheduledShiftRecord? lateShift;
      LeaderScheduledShiftRecord? awaitingShift;
      LeaderScheduledShiftRecord? nextShift;

      for (final shift in leaderShifts) {
        final shiftTimesheets = timesheetsByShift[shift.id] ?? const [];
        final clockIns = shiftTimesheets
            .where((row) => row.clockIn != null)
            .toList()
          ..sort((a, b) => a.clockIn!.compareTo(b.clockIn!));
        final firstClockIn = clockIns.isEmpty ? null : clockIns.first;
        final hasOpenClock = shiftTimesheets.any(
          (row) => row.clockIn != null && row.clockOut == null,
        );
        final hasClockOut = shiftTimesheets.any((row) => row.clockOut != null);

        if (firstClockIn != null &&
            (firstClockIn.clockInStatus == 'late' ||
                firstClockIn.clockIn!
                    .isAfter(shift.start.add(lateTolerance)))) {
          lateClockIns++;
        }

        if (hasClockOut) completed++;
        if (!at.isBefore(shift.end) && firstClockIn == null) absences++;

        final isCurrent = !at.isBefore(shift.start) && at.isBefore(shift.end);
        if (hasOpenClock && isCurrent) {
          workingShift = shift;
        } else if (isCurrent && firstClockIn == null) {
          if (at.isAfter(shift.start.add(lateTolerance))) {
            lateShift = shift;
          } else {
            awaitingShift = shift;
          }
        } else if (shift.start.isAfter(at) &&
            (nextShift == null || shift.start.isBefore(nextShift.start))) {
          nextShift = shift;
        }
      }

      final relevant = workingShift ?? lateShift ?? awaitingShift ?? nextShift;
      final liveState = workingShift != null
          ? LeaderLiveAttendanceState.working
          : lateShift != null
              ? LeaderLiveAttendanceState.lateNow
              : awaitingShift != null
                  ? LeaderLiveAttendanceState.awaitingClockIn
                  : nextShift != null
                      ? LeaderLiveAttendanceState.scheduledLater
                      : LeaderLiveAttendanceState.offDuty;

      summaries.add(
        LeaderAttendanceSummary(
          leaderId: entry.key,
          leaderName: leaderShifts.first.leaderName,
          scheduledShifts: leaderShifts.length,
          completedShifts: completed,
          absences: absences,
          lateClockIns: lateClockIns,
          liveState: liveState,
          relevantShiftStart: relevant?.start,
          relevantShiftEnd: relevant?.end,
        ),
      );
    }

    summaries.sort((a, b) {
      final severity = _liveSeverity(b.liveState) - _liveSeverity(a.liveState);
      if (severity != 0) return severity;
      return a.leaderName.toLowerCase().compareTo(b.leaderName.toLowerCase());
    });
    return summaries;
  }

  static int _liveSeverity(LeaderLiveAttendanceState state) {
    switch (state) {
      case LeaderLiveAttendanceState.lateNow:
        return 5;
      case LeaderLiveAttendanceState.awaitingClockIn:
        return 4;
      case LeaderLiveAttendanceState.working:
        return 3;
      case LeaderLiveAttendanceState.scheduledLater:
        return 2;
      case LeaderLiveAttendanceState.offDuty:
        return 1;
    }
  }

  static DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _leaderName(Map<String, dynamic> data, String fallback) {
    final name =
        (data['teacher_name'] ?? data['teacherName'])?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return fallback;
  }
}
