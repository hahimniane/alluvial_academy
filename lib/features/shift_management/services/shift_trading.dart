import '../enums/shift_enums.dart';
import '../models/teaching_shift.dart';

/// The rules of shift trading that need no Firestore, so they can be tested.
///
/// A class or duty is "offered" while `is_published` is true. Whoever takes it
/// becomes its teacher. A shift whose category is not teaching is a leadership
/// duty, and only a leader may take one.
class ShiftTrading {
  ShiftTrading._();

  /// How far ahead the days of a recurring class can be offered together.
  static const int seriesWindowDays = 30;

  /// The `setShiftOffers` callable takes at most this many classes per call.
  static const int maxOffersPerCall = 60;

  /// A leadership duty or meeting, as opposed to a class that is taught.
  static bool isLeadershipDuty(TeachingShift shift) =>
      shift.category != ShiftCategory.teaching;

  /// A leader is an admin, an admin-teacher, or anyone who already holds a
  /// leadership duty of their own.
  static bool isLeader({
    String? primaryRole,
    String? activeRole,
    bool isAdminTeacher = false,
    bool holdsLeadershipDuty = false,
  }) {
    bool isAdminRole(String? role) {
      final r = role?.trim().toLowerCase();
      return r == 'admin' || r == 'super_admin';
    }

    return isAdminRole(primaryRole) ||
        isAdminRole(activeRole) ||
        isAdminTeacher ||
        holdsLeadershipDuty;
  }

  /// The offered shifts this person may see: everyone sees classes, leaders
  /// also see leadership duties. Never their own, never one that has ended.
  static List<TeachingShift> visibleOffers({
    required Iterable<TeachingShift> offered,
    required String viewerUid,
    required bool viewerIsLeader,
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    return offered
        .where((s) => s.teacherId != viewerUid)
        .where((s) => !at.isAfter(s.shiftEnd.toUtc()))
        .where((s) => viewerIsLeader || !isLeadershipDuty(s))
        .toList();
  }

  /// Whether this class can be offered right now: scheduled and not started.
  static bool canBeOffered(TeachingShift shift, {DateTime? now}) {
    final at = now ?? DateTime.now();
    return shift.status == ShiftStatus.scheduled &&
        shift.shiftStart.isAfter(at);
  }

  /// The days of a recurring class that can be offered together with
  /// [opened]: the same teacher's scheduled, not-started classes of the same
  /// series within [windowDays] from [now], earliest first. [opened] is always
  /// in the list. A one-off class (no series) yields only itself.
  static List<TeachingShift> seriesOfferChoices({
    required TeachingShift opened,
    required Iterable<TeachingShift> candidates,
    DateTime? now,
    int windowDays = seriesWindowDays,
  }) {
    final at = now ?? DateTime.now();
    final until = at.add(Duration(days: windowDays));
    final templateId = opened.templateId?.trim() ?? '';
    final byId = <String, TeachingShift>{opened.id: opened};
    if (templateId.isNotEmpty) {
      for (final s in candidates) {
        if (s.id == opened.id) continue;
        if ((s.templateId?.trim() ?? '') != templateId) continue;
        if (s.teacherId != opened.teacherId) continue;
        if (!canBeOffered(s, now: at)) continue;
        if (s.shiftStart.isAfter(until)) continue;
        byId[s.id] = s;
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
    return list;
  }

  /// Quick pick "Only this class".
  static Set<String> pickOnlyThis(TeachingShift opened) => {opened.id};

  /// Quick pick "Next N": the opened class and the ones right after it, [count]
  /// in all. Classes that are already offered do not use up a place.
  static Set<String> pickNext({
    required TeachingShift opened,
    required List<TeachingShift> choices,
    int count = 3,
  }) {
    final picked = <String>{opened.id};
    for (final s in choices) {
      if (picked.length >= count) break;
      if (s.id == opened.id || s.isPublished) continue;
      if (s.shiftStart.isBefore(opened.shiftStart)) continue;
      picked.add(s.id);
    }
    return picked;
  }

  /// Quick pick "This week": every class in the same Monday-to-Sunday week as
  /// the opened one.
  static Set<String> pickSameWeek({
    required TeachingShift opened,
    required List<TeachingShift> choices,
  }) {
    final start = _weekStart(opened.shiftStart);
    final end = start.add(const Duration(days: 7));
    final picked = <String>{opened.id};
    for (final s in choices) {
      if (s.isPublished) continue;
      if (s.shiftStart.isBefore(start) || !s.shiftStart.isBefore(end)) continue;
      picked.add(s.id);
    }
    return picked;
  }

  static DateTime _weekStart(DateTime day) {
    final midnight = DateTime(day.year, day.month, day.day);
    return midnight.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// The ids to send to `setShiftOffers`: what is ticked, minus the classes
  /// that are already offered.
  static List<String> idsToOffer({
    required Set<String> ticked,
    required List<TeachingShift> choices,
  }) {
    return choices
        .where((s) => ticked.contains(s.id) && !s.isPublished)
        .map((s) => s.id)
        .toList();
  }

  /// Reads the `results` of the `setShiftOffers` callable.
  static List<ShiftOfferResult> parseResults(dynamic data) {
    if (data is! Map) return const [];
    final raw = data['results'];
    if (raw is! List) return const [];
    final out = <ShiftOfferResult>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final id = (item['shiftId'] ?? '').toString();
      if (id.isEmpty) continue;
      final ok = item['ok'] == true;
      out.add(ShiftOfferResult(
        shiftId: id,
        ok: ok,
        failure: ok ? null : failureFromReason(item['reason']?.toString()),
      ));
    }
    return out;
  }

  /// Turns the server's reason into something the app can say in the
  /// person's own language.
  static ShiftOfferFailure failureFromReason(String? reason) {
    final r = (reason ?? '').toLowerCase();
    if (r.contains('already started')) return ShiftOfferFailure.alreadyStarted;
    if (r.contains('has not started')) return ShiftOfferFailure.notScheduled;
    if (r.contains('not your')) return ShiftOfferFailure.notYours;
    if (r.contains('not found')) return ShiftOfferFailure.notFound;
    return ShiftOfferFailure.other;
  }
}

/// Why one class could not be offered or taken back.
enum ShiftOfferFailure {
  /// The class has started or is over.
  alreadyStarted,

  /// The class is no longer simply scheduled (cancelled, completed, missed).
  notScheduled,

  /// The class belongs to another teacher.
  notYours,

  /// The class no longer exists.
  notFound,

  /// Anything else.
  other,
}

/// The outcome for one class of a `setShiftOffers` call.
class ShiftOfferResult {
  final String shiftId;
  final bool ok;
  final ShiftOfferFailure? failure;

  const ShiftOfferResult({
    required this.shiftId,
    required this.ok,
    this.failure,
  });
}
