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

class PresenceReport {
  final String uid;
  final String? name;
  final int classes;
  final int classesWithADrop;
  final PresenceTally counted;

  /// Interruptions the classroom system caused: ours, and deliberately kept out
  /// of [counted].
  final int platformDrops;

  const PresenceReport({
    required this.uid,
    this.name,
    this.classes = 0,
    this.classesWithADrop = 0,
    this.counted = const PresenceTally(),
    this.platformDrops = 0,
  });

  bool get hasAnything => classes > 0 || counted.drops > 0;

  factory PresenceReport.fromMap(Map<dynamic, dynamic> data) {
    final byCause = data['by_cause'];
    var ours = 0;
    if (byCause is Map) {
      ours = PresenceTally.fromMap(byCause['platform'] as Map?).drops +
          PresenceTally.fromMap(byCause['simultaneous'] as Map?).drops;
    }
    return PresenceReport(
      uid: '${data['uid'] ?? ''}',
      name: data['name'] as String?,
      classes: PresenceTally._int(data['classes']),
      classesWithADrop: PresenceTally._int(data['classes_with_a_drop']),
      counted: PresenceTally.fromMap(data['counted'] as Map?),
      platformDrops: ours,
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
