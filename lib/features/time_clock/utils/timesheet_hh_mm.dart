/// Parse duration strings as stored on timesheet rows: `HH:MM` or `HH:MM:SS`.
int timesheetParseDurationToSeconds(String formatted) {
  final p = formatted.trim().split(':');
  if (p.length >= 3) {
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    final s = int.tryParse(p[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  }
  if (p.length == 2) {
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    return h * 3600 + m * 60;
  }
  return 0;
}

/// Whole minutes (floor) — prefer [timesheetParseDurationToSeconds] when summing mixed SS precision.
int timesheetParseHhMmToMinutes(String formatted) {
  return timesheetParseDurationToSeconds(formatted) ~/ 60;
}

String timesheetFormatMinutesAsHhMm(int totalMinutes) {
  if (totalMinutes < 0) totalMinutes = 0;
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String timesheetFormatSecondsAsHhMmSs(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;
  final h = totalSeconds ~/ 3600;
  final rem = totalSeconds % 3600;
  final m = rem ~/ 60;
  final s = rem % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

int timesheetSumChildrenSeconds(Iterable<String> childTotalHours) {
  var sum = 0;
  for (final s in childTotalHours) {
    sum += timesheetParseDurationToSeconds(s);
  }
  return sum;
}

int timesheetSumChildrenMinutes(Iterable<String> childTotalHours) {
  return timesheetSumChildrenSeconds(childTotalHours) ~/ 60;
}
