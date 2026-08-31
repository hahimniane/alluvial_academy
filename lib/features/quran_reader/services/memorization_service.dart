/// Memorization progress + goal plan, stored in `quran_memorization/{uid}`.
///
/// SCHEMA IS SHARED WITH THE WEB STUDENT DASHBOARD (StudentQuranPage.tsx) so
/// progress syncs across devices — do not change field names here without
/// changing them there:
///   memorized: { "`surahId`": [ayahNumbers...] }
///   plan: { scope: "quran" | "surah:`id`" | "juz:`id`", perDay, startDate "YYYY-MM-DD" }
///   daily_log: { "YYYY-MM-DD": count }
///   updated_at: serverTimestamp
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'quran_api.dart' show Chapter, juzStart;

class AyahRef {
  final int surahId;
  final int ayah;
  const AyahRef(this.surahId, this.ayah);
}

enum ScopeKind { quran, surah, juz }

class PlanScope {
  final ScopeKind kind;
  final int id;
  const PlanScope(this.kind, this.id);

  static PlanScope parse(String value) {
    if (value == 'quran') return const PlanScope(ScopeKind.quran, 0);
    final parts = value.split(':');
    final id = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    return PlanScope(parts.first == 'juz' ? ScopeKind.juz : ScopeKind.surah, id);
  }

  String serialize() => kind == ScopeKind.quran
      ? 'quran'
      : '${kind == ScopeKind.juz ? 'juz' : 'surah'}:$id';
}

class MemorizationPlan {
  final PlanScope scope;
  final int perDay;
  final String startDate;
  const MemorizationPlan(this.scope, this.perDay, this.startDate);
}

String todayStr() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Ordered ayah list for a plan scope (same as the web scopeSequence).
List<AyahRef> scopeSequence(PlanScope scope, List<Chapter> chapters) {
  int versesOf(int id) {
    for (final c in chapters) {
      if (c.id == id) return c.versesCount;
    }
    return 0;
  }

  final out = <AyahRef>[];
  if (scope.kind == ScopeKind.surah) {
    for (var a = 1; a <= versesOf(scope.id); a++) {
      out.add(AyahRef(scope.id, a));
    }
    return out;
  }
  if (scope.kind == ScopeKind.juz) {
    final start = scope.id - 1 < juzStart.length ? juzStart[scope.id - 1] : [1, 1];
    final end = scope.id < juzStart.length ? juzStart[scope.id] : [115, 1];
    for (var s = start[0]; s <= end[0]; s++) {
      final count = versesOf(s);
      final from = s == start[0] ? start[1] : 1;
      final to = s == end[0] ? end[1] - 1 : count;
      for (var a = from; a <= (to < count ? to : count); a++) {
        out.add(AyahRef(s, a));
      }
    }
    return out;
  }
  for (var s = 1; s <= 114; s++) {
    for (var a = 1; a <= versesOf(s); a++) {
      out.add(AyahRef(s, a));
    }
  }
  return out;
}

class GoalReminder {
  final bool enabled;
  final int hour;
  final int minute;
  const GoalReminder(this.enabled, this.hour, this.minute);
}

class MemorizationState {
  final Map<int, Set<int>> memorized; // surahId -> memorized ayah numbers
  final MemorizationPlan? plan;
  final Map<String, int> dailyLog;
  final GoalReminder? reminder;
  const MemorizationState(this.memorized, this.plan, this.dailyLog,
      [this.reminder]);

  int get totalMemorized => memorized.values.fold(0, (s, v) => s + v.length);
  bool isMemorized(int surahId, int ayah) =>
      memorized[surahId]?.contains(ayah) ?? false;

  /// Consecutive days (ending today or yesterday) with at least one ayah done.
  int get streak {
    var day = DateTime.now();
    if ((dailyLog[_key(day)] ?? 0) <= 0) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while ((dailyLog[_key(day)] ?? 0) > 0) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class MemorizationService {
  final FirebaseFirestore _db;
  MemorizationService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _uid;
    return uid == null ? null : _db.collection('quran_memorization').doc(uid);
  }

  Future<MemorizationState> load() async {
    final ref = _doc;
    if (ref == null) return const MemorizationState({}, null, {});
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final memorized = <int, Set<int>>{};
    final raw = (data['memorized'] as Map?) ?? {};
    raw.forEach((k, v) {
      final surah = int.tryParse('$k');
      if (surah == null || v is! List) return;
      memorized[surah] = v.map((a) => (a as num).toInt()).toSet();
    });
    MemorizationPlan? plan;
    final rawPlan = data['plan'];
    if (rawPlan is Map && rawPlan['scope'] != null) {
      plan = MemorizationPlan(
        PlanScope.parse('${rawPlan['scope']}'),
        ((rawPlan['perDay'] as num?) ?? 1).toInt(),
        '${rawPlan['startDate'] ?? todayStr()}',
      );
    }
    final dailyLog = <String, int>{};
    final rawLog = (data['daily_log'] as Map?) ?? {};
    rawLog.forEach((k, v) => dailyLog['$k'] = ((v as num?) ?? 0).toInt());
    GoalReminder? reminder;
    final rawReminder = data['reminder'];
    if (rawReminder is Map) {
      reminder = GoalReminder(
        rawReminder['enabled'] == true,
        ((rawReminder['hour'] as num?) ?? 20).toInt(),
        ((rawReminder['minute'] as num?) ?? 0).toInt(),
      );
    }
    return MemorizationState(memorized, plan, dailyLog, reminder);
  }

  Future<void> saveReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final ref = _doc;
    if (ref == null) return;
    await ref.set({
      'reminder': {'enabled': enabled, 'hour': hour, 'minute': minute},
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Toggle one ayah; also counts toward today's goal (unmark undoes it).
  Future<void> toggle(int surahId, int ayah, {required bool nowMemorized}) async {
    final ref = _doc;
    if (ref == null) return;
    final day = todayStr();
    await ref.set({
      'memorized': {
        '$surahId': nowMemorized
            ? FieldValue.arrayUnion([ayah])
            : FieldValue.arrayRemove([ayah]),
      },
      'daily_log': {day: FieldValue.increment(nowMemorized ? 1 : -1)},
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> savePlan(PlanScope scope, int perDay) async {
    final ref = _doc;
    if (ref == null) return;
    await ref.set({
      'plan': {
        'scope': scope.serialize(),
        'perDay': perDay,
        'startDate': todayStr(),
      },
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearPlan() async {
    final ref = _doc;
    if (ref == null) return;
    await ref.set({
      'plan': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
