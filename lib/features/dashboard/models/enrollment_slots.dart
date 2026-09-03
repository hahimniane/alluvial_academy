/// The scheduling vocabulary the enrollment form and the job board share.
///
/// This mirrors `apps/web/src/lib/enrollmentDomain.ts`. The two must agree:
/// a family's "Evening" and a teacher's "Evening" are the same hours, and the
/// windows a teacher ranks here are the windows the web board offers. Change
/// one, change the other.
library;

class TimeBlock {
  const TimeBlock({
    required this.id,
    required this.label,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String id;
  final String label;

  /// Minutes from midnight. End is exclusive, so a slot never crosses midnight.
  final int startMinutes;
  final int endMinutes;

  String get rangeLabel =>
      '${formatMinutes(startMinutes)} – ${formatMinutes(endMinutes - 1)}';
}

const List<TimeBlock> kTimeBlocks = [
  TimeBlock(id: 'Morning', label: 'Morning', startMinutes: 300, endMinutes: 720),
  TimeBlock(id: 'Afternoon', label: 'Afternoon', startMinutes: 720, endMinutes: 960),
  TimeBlock(id: 'Evening', label: 'Evening', startMinutes: 960, endMinutes: 1260),
  TimeBlock(id: 'Night', label: 'Night', startMinutes: 1260, endMinutes: 1440),
  TimeBlock(id: 'Late night', label: 'Late night', startMinutes: 0, endMinutes: 300),
];

TimeBlock? blockById(String? id) {
  if (id == null || id.trim().isEmpty) return null;
  for (final block in kTimeBlocks) {
    if (block.id == id.trim()) return block;
  }
  return null;
}

String formatMinutes(int minutes) {
  final total = ((minutes % 1440) + 1440) % 1440;
  final hour24 = total ~/ 60;
  final minute = total % 60;
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
}

/// Every window of [sessionMinutes] that fits inside [block], advanced by
/// [step].
///
/// The step is the point. Teachers get a **sliding** window (step 30), so
/// Evening with 2-hour classes offers 4–6, 4:30–6:30, 5–7 … 7–9. Stepping by a
/// whole session would offer only 4–6 and 6–8 and hide most of a teacher's
/// real availability.
List<String> slotsFor(TimeBlock? block, int sessionMinutes, {int step = 30}) {
  if (block == null || sessionMinutes <= 0 || step <= 0) return const [];
  final slots = <String>[];
  for (var t = block.startMinutes; t + sessionMinutes <= block.endMinutes; t += step) {
    slots.add('${formatMinutes(t)} - ${formatMinutes(t + sessionMinutes)}');
  }
  return slots;
}

bool sessionFitsBlock(TimeBlock? block, int sessionMinutes) =>
    slotsFor(block, sessionMinutes).isNotEmpty;

/// Older jobs store the class length as a label ("1 hr", "90 mins",
/// "1.5 hours"); newer ones carry `sessionMinutes`.
///
/// The previous version matched a handful of fixed strings and otherwise took
/// the first digits as minutes — so "1.5 hours" rendered as "1 min".
int minutesFromDurationLabel(String? label) {
  final text = (label ?? '').toLowerCase();
  if (text.trim().isEmpty) return 60;
  var minutes = 0;
  final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hr|hour)').firstMatch(text);
  final minuteMatch = RegExp(r'(\d+)\s*(?:min)').firstMatch(text);
  if (hourMatch != null) {
    minutes += (double.parse(hourMatch.group(1)!) * 60).round();
  }
  if (minuteMatch != null) {
    minutes += int.parse(minuteMatch.group(1)!);
  }
  return minutes > 0 ? minutes : 60;
}

/// "30 min", "1 hour", "1.5 hours" — how long each class runs.
String sessionLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes / 60;
  if (hours == hours.roundToDouble()) {
    final whole = hours.round();
    return '$whole ${whole == 1 ? 'hour' : 'hours'}';
  }
  return '${hours.toString().replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')} hours';
}
