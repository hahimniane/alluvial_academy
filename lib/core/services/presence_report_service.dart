import 'package:cloud_functions/cloud_functions.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// How often somebody dropped out of class, and for how long.
///
/// The figures come from the hub bot watching each room from the inside — the
/// only signal that sees teachers, who join through the Zoom desktop app and so
/// never run the browser heartbeat.
///
/// Only drops we could not trace to ourselves reach [drops]. A hub handover or
/// a bot restart is our doing and is counted in [platformDrops] instead, so a
/// teacher never reads our fault as their connection failing.
class PresenceTally {
  final int drops;
  final int secondsLost;
  final int longestSeconds;
  final int neverReturned;

  const PresenceTally({
    this.drops = 0,
    this.secondsLost = 0,
    this.longestSeconds = 0,
    this.neverReturned = 0,
  });

  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

  factory PresenceTally.fromMap(Map<dynamic, dynamic>? data) {
    if (data == null) return const PresenceTally();
    return PresenceTally(
      drops: _int(data['drops']),
      secondsLost: _int(data['secondsLost']),
      longestSeconds: _int(data['longestSeconds']),
      neverReturned: _int(data['neverReturned']),
    );
  }
}

/// One absence, with the clock times it is claiming.
class PresenceSpell {
  final DateTime? from;
  final int? seconds;
  final bool returned;
  final String cause;

  /// Who was left sitting in the room while this person was gone.
  ///
  /// This is what separates a teacher dropping out from a class simply
  /// ending. A student waiting alone is a lesson going wrong; the same
  /// minutes with nobody there is a class that had already finished, or that
  /// both sides left together.
  final List<String> studentsWaiting;
  final bool roomWasEmpty;

  const PresenceSpell({
    this.from,
    this.seconds,
    this.returned = true,
    this.cause = 'individual',
    this.studentsWaiting = const [],
    this.roomWasEmpty = false,
  });

  /// Ours rather than theirs — a hub handover or a bot restart.
  bool get isOurs => cause != 'individual';

  static DateTime? _time(dynamic value) {
    final ms = value is num ? value.toInt() : int.tryParse('${value ?? ''}');
    return ms == null || ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  factory PresenceSpell.fromMap(Map<dynamic, dynamic> data) {
    final seconds = data['seconds'];
    final waiting = data['studentsWaiting'];
    return PresenceSpell(
      from: _time(data['from']),
      seconds: seconds is num ? seconds.toInt() : int.tryParse('${seconds ?? ''}'),
      returned: data['returned'] != false,
      cause: '${data['cause'] ?? 'individual'}',
      studentsWaiting: waiting is List
          ? waiting.map((s) => '$s').where((s) => s.isNotEmpty).toList()
          : const [],
      roomWasEmpty: data['roomWasEmpty'] == true,
    );
  }
}

/// An administrator's verdict on one class's drop-outs.
class PresenceReview {
  final String? reviewedByName;
  final String? reviewedByEmail;
  final List<String> actionKeys;
  final List<String> actionLabels;
  final String? note;

  const PresenceReview({
    this.reviewedByName,
    this.reviewedByEmail,
    this.actionKeys = const [],
    this.actionLabels = const [],
    this.note,
  });

  String get reviewer =>
      reviewedByName?.trim().isNotEmpty == true
          ? reviewedByName!.trim()
          : (reviewedByEmail?.trim() ?? '');

  static List<String> _strings(dynamic value) => value is List
      ? value.map((s) => '$s').where((s) => s.isNotEmpty).toList()
      : const [];

  static PresenceReview? fromMap(dynamic data) {
    if (data is! Map) return null;
    if ('${data['status'] ?? ''}'.toLowerCase() != 'reviewed') return null;
    final note = '${data['review_note'] ?? ''}'.trim();
    return PresenceReview(
      reviewedByName: data['reviewed_by_name']?.toString(),
      reviewedByEmail: data['reviewed_by_email']?.toString(),
      actionKeys: _strings(data['review_actions']),
      actionLabels: _strings(data['review_action_labels']),
      note: note.isEmpty ? null : note,
    );
  }
}

/// One class somebody dropped out of: the day, the class, and who it was with.
///
/// This is what answers a teacher who says a figure is wrong. It is kept with
/// the summary rather than read back from the raw events, which are deleted
/// with the class after sixty days.
class PresenceOccasion {
  final String? shiftId;
  final String? className;
  final List<String> students;

  /// The hours the class was scheduled to run. A drop at 9:52 reads very
  /// differently once you know the lesson was due to end at 10:00.
  final DateTime? startedAt;
  final DateTime? endedAt;

  final int drops;
  final int secondsLost;
  final int neverReturned;
  final List<PresenceSpell> spells;

  /// Null until somebody has looked at it and said what happened.
  final PresenceReview? review;

  const PresenceOccasion({
    this.shiftId,
    this.className,
    this.students = const [],
    this.startedAt,
    this.endedAt,
    this.drops = 0,
    this.secondsLost = 0,
    this.neverReturned = 0,
    this.spells = const [],
    this.review,
  });

  bool get isReviewed => review != null;

  /// Somebody was left sitting there, in at least one of these absences.
  bool get someoneWasWaiting =>
      spells.any((spell) => spell.studentsWaiting.isNotEmpty);

  PresenceOccasion copyWith({PresenceReview? review}) => PresenceOccasion(
        shiftId: shiftId,
        className: className,
        students: students,
        startedAt: startedAt,
        endedAt: endedAt,
        drops: drops,
        secondsLost: secondsLost,
        neverReturned: neverReturned,
        spells: spells,
        review: review ?? this.review,
      );

  factory PresenceOccasion.fromMap(Map<dynamic, dynamic> data) {
    final students = data['students'];
    final spells = data['spells'];
    return PresenceOccasion(
      shiftId: data['shiftId']?.toString(),
      className: data['className']?.toString(),
      students: students is List
          ? students.map((s) => '$s').where((s) => s.isNotEmpty).toList()
          : const [],
      startedAt: PresenceSpell._time(data['startedAt']),
      endedAt: PresenceSpell._time(data['endedAt']),
      drops: PresenceTally._int(data['drops']),
      secondsLost: PresenceTally._int(data['secondsLost']),
      neverReturned: PresenceTally._int(data['neverReturned']),
      spells: spells is List
          ? spells.whereType<Map>().map(PresenceSpell.fromMap).toList()
          : const [],
      review: PresenceReview.fromMap(data['review']),
    );
  }

  /// Who the class was with, as a reader would say it. Empty when unrecorded,
  /// so a caller can leave the line out rather than print an empty label.
  String get studentLine {
    if (students.isEmpty) return '';
    if (students.length <= 2) return students.join(' and ');
    return '${students.take(2).join(', ')} and ${students.length - 2} more';
  }
}

class PresenceReport {
  final String uid;
  final String? name;
  final int classes;
  final int classesWithADrop;
  final PresenceTally counted;

  /// Interruptions the classroom system caused: ours, and deliberately kept out
  /// of [counted].
  final int platformDrops;

  /// The classes the totals are made of, newest first.
  final List<PresenceOccasion> occasions;

  const PresenceReport({
    required this.uid,
    this.name,
    this.classes = 0,
    this.classesWithADrop = 0,
    this.counted = const PresenceTally(),
    this.platformDrops = 0,
    this.occasions = const [],
  });

  bool get hasAnything => classes > 0 || counted.drops > 0;

  factory PresenceReport.fromMap(Map<dynamic, dynamic> data) {
    final byCause = data['by_cause'];
    var ours = 0;
    if (byCause is Map) {
      ours = PresenceTally.fromMap(byCause['platform'] as Map?).drops +
          PresenceTally.fromMap(byCause['simultaneous'] as Map?).drops;
    }
    final occasions = data['occasions'];
    return PresenceReport(
      uid: '${data['uid'] ?? ''}',
      name: data['name'] as String?,
      classes: PresenceTally._int(data['classes']),
      classesWithADrop: PresenceTally._int(data['classes_with_a_drop']),
      counted: PresenceTally.fromMap(data['counted'] as Map?),
      platformDrops: ours,
      occasions: occasions is List
          ? occasions.whereType<Map>().map(PresenceOccasion.fromMap).toList()
          : const [],
    );
  }
}

/// Reads connection reports. A teacher may read their own; an administrator may
/// read anybody's, and the overview.
class PresenceReportService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Null when nothing has been recorded for that period yet — which is not an
  /// error, and must not be shown as one.
  static Future<PresenceReport?> forPerson({
    String? uid,
    String periodType = 'weekly',
  }) async {
    try {
      final result = await _functions.httpsCallable('getPresenceReport').call({
        if (uid != null) 'uid': uid,
        'periodType': periodType,
      });
      final data = result.data;
      if (data is! Map) return null;
      final report = data['report'];
      if (report is! Map) return null;
      return PresenceReport.fromMap(report);
    } catch (e) {
      AppLogger.error('PresenceReportService: could not load report: $e');
      return null;
    }
  }

  /// Every teacher for a period, worst first. Administrators only.
  static Future<List<PresenceReport>> overview({
    String periodType = 'weekly',
  }) async {
    try {
      final result = await _functions.httpsCallable('getPresenceOverview').call({
        'periodType': periodType,
      });
      final data = result.data;
      if (data is! Map) return const [];
      final teachers = data['teachers'];
      if (teachers is! List) return const [];
      return teachers
          .whereType<Map>()
          .map(PresenceReport.fromMap)
          .toList(growable: false);
    } catch (e) {
      AppLogger.error('PresenceReportService: could not load overview: $e');
      return const [];
    }
  }

  /// Record what an administrator decided about one class's drop-outs.
  ///
  /// Returns the verdict as stored so the row can show it without a reload;
  /// throws on refusal, so a failure is never mistaken for a saved review.
  static Future<PresenceReview> review({
    required String shiftId,
    required String reviewerName,
    List<String> actionKeys = const [],
    List<String> actionLabels = const [],
    String note = '',
  }) async {
    await _functions.httpsCallable('reviewPresenceDrop').call({
      'shiftId': shiftId,
      'reviewerName': reviewerName,
      'actions': actionKeys,
      'actionLabels': actionLabels,
      'note': note,
    });
    return PresenceReview(
      reviewedByName: reviewerName,
      actionKeys: actionKeys,
      actionLabels: actionLabels,
      note: note.trim().isEmpty ? null : note.trim(),
    );
  }

  /// A duration the way a person says it. Under a minute keeps its seconds,
  /// because "0m" for a forty-second drop reads as nothing having happened.
  static String formatDuration(int totalSeconds) {
    final seconds = totalSeconds < 0 ? 0 : totalSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      final rest = seconds % 60;
      return rest == 0 ? '${minutes}m' : '${minutes}m ${rest}s';
    }
    final hours = minutes ~/ 60;
    final restMinutes = minutes % 60;
    return restMinutes == 0 ? '${hours}h' : '${hours}h ${restMinutes}m';
  }
}
