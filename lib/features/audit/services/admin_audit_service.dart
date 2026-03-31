import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alluwalacademyadmin/features/audit/config/admin_audit_compliance_config.dart';
import 'package:alluwalacademyadmin/features/audit/models/admin_audit.dart';
import '../../../core/utils/app_logger.dart';

/// Service for computing and storing admin audit KPIs.
class AdminAuditService {
  static final _firestore = FirebaseFirestore.instance;

  static const int _maxLabelEntriesPerAdmin = 25;

  static String _displayNameFromUser(
      Map<String, dynamic> userData, String adminId) {
    final firstName = (userData['first_name'] ?? '').toString().trim();
    final lastName = (userData['last_name'] ?? '').toString().trim();
    final combined = '$firstName $lastName'.trim();
    if (combined.isNotEmpty) return combined;

    final name = (userData['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final displayName = (userData['displayName'] ?? '').toString().trim();
    if (displayName.isNotEmpty) return displayName;

    final email = (userData['email'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      final at = email.indexOf('@');
      return at > 0 ? email.substring(0, at) : email;
    }

    return adminId;
  }

  static int _weekdaysInMonth(DateTime monthStart) {
    final last = DateTime(monthStart.year, monthStart.month + 1, 0);
    var n = 0;
    for (var d = DateTime(monthStart.year, monthStart.month, 1);
        !d.isAfter(last);
        d = d.add(const Duration(days: 1))) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        n++;
      }
    }
    return n;
  }

  /// Approximate full/partial weeks in the month (4–5) for weekly form expectations.
  static int _approxWeeksInMonth(DateTime monthStart) {
    final last = DateTime(monthStart.year, monthStart.month + 1, 0);
    return ((last.day + monthStart.weekday - 1) / 7).ceil().clamp(4, 5);
  }

  static int _sumBreakdownForKeys(Map<String, int> bd, Set<String> keys) {
    var s = 0;
    for (final k in keys) {
      s += bd[k] ?? 0;
    }
    return s;
  }

  static double _ratio(int num, int den) =>
      den <= 0 ? 1.0 : (num / den).clamp(0.0, 1.0);

  /// Tier-1 form compliance: daily EOS, biweekly coachees, weekly reports (avg of group ratios).
  static int _computeFormComplianceScore(
      Map<String, int> bd, DateTime monthStart) {
    final weekdays = _weekdaysInMonth(monthStart);
    final weeks = _approxWeeksInMonth(monthStart);

    final dailySub = _sumBreakdownForKeys(
        bd, AdminAuditComplianceConfig.dailyEndOfShiftTemplateIds);
    final rDaily = _ratio(dailySub, weekdays);

    final bioSub =
        bd[AdminAuditComplianceConfig.biweeklyCoacheesPerformanceId] ?? 0;
    final rBio = _ratio(
        bioSub, AdminAuditComplianceConfig.expectedBiweeklyCoacheesPerMonth);

    final weeklyIds = AdminAuditComplianceConfig.weeklyReportTemplateIds;
    if (weeklyIds.isEmpty) {
      final avg = (rDaily + rBio) / 2;
      return (avg * 100).round().clamp(0, 100);
    }
    var sumWeekly = 0.0;
    for (final tid in weeklyIds) {
      sumWeekly += _ratio(bd[tid] ?? 0, weeks);
    }
    final rWeekly = sumWeekly / weeklyIds.length;

    final avg = (rDaily + rBio + rWeekly) / 3;
    return (avg * 100).round().clamp(0, 100);
  }

  static int _computeTaskEfficiencyScore({
    required int completed,
    required int assigned,
    required int overdue,
    required int created,
  }) {
    if (assigned <= 0) {
      if (created > 0) return 88;
      return 72;
    }
    final completion = completed / assigned;
    final od = (overdue / assigned).clamp(0.0, 1.0);
    var score = 100.0 * completion * (1 - 0.2 * od);
    final initiative = (created / (assigned + created + 1)) * 12;
    return (score + initiative).round().clamp(0, 100);
  }

  static int _computeOverallScore(int formScore, int taskScore) {
    final v = AdminAuditComplianceConfig.overallWeightForm * formScore +
        AdminAuditComplianceConfig.overallWeightTask * taskScore;
    return v.round().clamp(0, 100);
  }

  static Map<String, int> _capLabelMap(Map<String, int> raw) {
    final entries = raw.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries.take(_maxLabelEntriesPerAdmin));
  }

  static String? _formKeyFromResponse(Map<String, dynamic> dataMap) {
    final tid = dataMap['templateId']?.toString().trim() ?? '';
    if (tid.isNotEmpty) return tid;
    final fid = dataMap['formId']?.toString().trim() ?? '';
    if (fid.isNotEmpty) return fid;
    return null;
  }

  /// Admins, super_admins, and teachers with [is_admin_teacher] == true (dual role).
  static Future<Map<String, Map<String, dynamic>>> loadAuditedUsersMap() async {
    final adminSnap = await _firestore
        .collection('users')
        .where('user_type', whereIn: ['admin', 'super_admin']).get();
    final dualSnap = await _firestore
        .collection('users')
        .where('user_type', isEqualTo: 'teacher')
        .where('is_admin_teacher', isEqualTo: true)
        .get();

    final map = <String, Map<String, dynamic>>{};
    for (final d in adminSnap.docs) {
      map[d.id] = d.data();
    }
    for (final d in dualSnap.docs) {
      map[d.id] = d.data();
    }
    return map;
  }

  /// Generate admin audits for a given yearMonth (e.g. '2026-03').
  static Future<List<AdminAudit>> generateAdminAudits(String yearMonth) async {
    final sw = Stopwatch()..start();
    AppLogger.info('⚙️ AdminAuditService: generating for $yearMonth');

    final adminMap = await loadAuditedUsersMap();

    if (adminMap.isEmpty) {
      AppLogger.info('AdminAuditService: no admin users found');
      return [];
    }

    final adminIds = adminMap.keys.toSet();

    final formsSnapshot = await _firestore
        .collection('form_responses')
        .where('yearMonth', isEqualTo: yearMonth)
        .get();

    final monthStart = DateTime.parse('$yearMonth-01');
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1);
    final tasksSnapshot = await _firestore
        .collection('tasks')
        .where('dueDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('dueDate', isLessThan: Timestamp.fromDate(monthEnd))
        .get();

    AppLogger.debug(
        'AdminAuditService: ${adminIds.length} admins, '
        '${formsSnapshot.docs.length} forms, '
        '${tasksSnapshot.docs.length} tasks');

    final formBreakdowns = <String, Map<String, int>>{
      for (final id in adminIds) id: <String, int>{},
    };

    for (final doc in formsSnapshot.docs) {
      final dataMap = doc.data();
      final submitter =
          dataMap['userId'] as String? ?? dataMap['submitted_by'] as String?;
      if (submitter == null || !adminIds.contains(submitter)) continue;
      final key = _formKeyFromResponse(dataMap) ?? '_unknown';
      final m = formBreakdowns[submitter]!;
      m[key] = (m[key] ?? 0) + 1;
    }

    final formCounts = <String, int>{
      for (final id in adminIds)
        id: formBreakdowns[id]!.values.fold<int>(0, (a, b) => a + b),
    };

    final totalTasks = <String, int>{};
    final completedTasks = <String, int>{};
    final overdueTasks = <String, int>{};
    final acknowledgedTasks = <String, int>{};
    final createdCount = <String, int>{};
    final completionDaysSum = <String, double>{};
    final completionDaysN = <String, int>{};
    final labelAgg = <String, Map<String, int>>{};
    // Per admin: sum of subTaskIds.length across tasks assigned to them this month.
    final subTasksSum = <String, int>{};

    for (final doc in tasksSnapshot.docs) {
      final dataMap = doc.data();
      final isDraft = dataMap['isDraft'] == true;
      final createdBy = (dataMap['createdBy'] as String?) ?? '';
      if (!isDraft &&
          createdBy.isNotEmpty &&
          adminIds.contains(createdBy)) {
        createdCount[createdBy] = (createdCount[createdBy] ?? 0) + 1;
      }

      final assignedTo =
          (dataMap['assignedTo'] as List<dynamic>?)?.cast<String>() ?? [];
      final status = dataMap['status'] as String? ?? 'todo';
      final overdueDays =
          (dataMap['overdueDaysAtCompletion'] as num?)?.toInt() ?? 0;
      final hasFirstOpened = dataMap['firstOpenedAt'] != null;
      final isDone = status == 'done' || status == 'TaskStatus.done';
      final isOverdue = !isDone || overdueDays > 0;

      final completedAt = dataMap['completedAt'];
      final createdAt = dataMap['createdAt'];
      final labels =
          (dataMap['labels'] as List<dynamic>?)?.cast<String>() ?? [];
      final subTaskIds =
          (dataMap['subTaskIds'] as List<dynamic>?)?.cast<String>() ?? [];
      final subTaskCount = subTaskIds.length;

      for (final uid in assignedTo) {
        if (!adminIds.contains(uid)) continue;
        totalTasks[uid] = (totalTasks[uid] ?? 0) + 1;
        subTasksSum[uid] = (subTasksSum[uid] ?? 0) + subTaskCount;
        if (isDone) {
          completedTasks[uid] = (completedTasks[uid] ?? 0) + 1;
        }
        if (isOverdue) {
          overdueTasks[uid] = (overdueTasks[uid] ?? 0) + 1;
        }
        if (hasFirstOpened) {
          acknowledgedTasks[uid] = (acknowledgedTasks[uid] ?? 0) + 1;
        }
        if (isDone && completedAt is Timestamp && createdAt is Timestamp) {
          final days = completedAt
                  .toDate()
                  .difference(createdAt.toDate())
                  .inHours /
              24.0;
          completionDaysSum[uid] = (completionDaysSum[uid] ?? 0) + days;
          completionDaysN[uid] = (completionDaysN[uid] ?? 0) + 1;
        }
        final lm = labelAgg.putIfAbsent(uid, () => <String, int>{});
        for (final lb in labels) {
          final t = lb.trim();
          if (t.isEmpty) continue;
          lm[t] = (lm[t] ?? 0) + 1;
        }
      }
    }

    final now = DateTime.now();
    final batch = _firestore.batch();

    for (final adminId in adminIds) {
      final userData = adminMap[adminId]!;
      final docId = '${adminId}_$yearMonth';
      final bd = Map<String, int>.from(formBreakdowns[adminId]!);
      final formScore = _computeFormComplianceScore(bd, monthStart);
      final tot = totalTasks[adminId] ?? 0;
      final comp = completedTasks[adminId] ?? 0;
      final od = overdueTasks[adminId] ?? 0;
      final cr = createdCount[adminId] ?? 0;
      final taskScore = _computeTaskEfficiencyScore(
        completed: comp,
        assigned: tot,
        overdue: od,
        created: cr,
      );
      final overall = _computeOverallScore(formScore, taskScore);

      final nDone = completionDaysN[adminId] ?? 0;
      final avgDays = nDone > 0
          ? (completionDaysSum[adminId] ?? 0) / nDone
          : 0.0;

      final cappedLabels =
          _capLabelMap(labelAgg[adminId] ?? const <String, int>{});

      // Average sub-tasks per assigned task in the month, as 0–100
      // (here: sum(subTaskIds.length) / max(1, totalAssigned) × 100, capped).
      final subSum = subTasksSum[adminId] ?? 0;
      final subTasksRatio = tot <= 0
          ? 0
          : ((subSum / tot) * 100).round().clamp(0, 100);

      final audit = AdminAudit(
        id: docId,
        adminId: adminId,
        adminName: _displayNameFromUser(userData, adminId),
        adminEmail: userData['email'] as String? ?? '',
        yearMonth: yearMonth,
        formsBreakdown: bd,
        formsSubmitted: formCounts[adminId] ?? 0,
        totalTasksAssigned: tot,
        tasksCompleted: comp,
        tasksOverdue: od,
        tasksAcknowledged: acknowledgedTasks[adminId] ?? 0,
        tasksCreatedByAdmin: cr,
        avgTaskCompletionDays: double.parse(avgDays.toStringAsFixed(2)),
        tasksByLabel: cappedLabels,
        formComplianceScore: formScore,
        taskEfficiencyScore: taskScore,
        overallScore: overall,
        subTasksRatio: subTasksRatio,
        ceoNotes: '',
        adminEvalScores: const {},
        adminEvalSectionComments: const {},
        lastUpdated: now,
      );
      batch.set(
        _firestore.collection('admin_audits').doc(docId),
        audit.toFirestoreRegenerationMap(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    AppLogger.info(
        '✅ AdminAuditService: merged metrics for ${adminIds.length} admin audits '
        'in ${sw.elapsedMilliseconds}ms (manual eval + CEO fields preserved in Firestore)');
    // Re-read so callers get ceoNotes, adminEvalScores, payment fields, etc. Merge does not remove them,
    // but in-memory [AdminAudit] placeholders above intentionally omit those fields.
    return loadAdminAudits(yearMonth);
  }

  /// Persists manual CEO evaluation draft: scores + optional per-section comments. Merge-safe.
  static Future<void> updateAdminEvalDraft(
    String auditDocId, {
    required Map<String, int> scores,
    required Map<String, String> sectionComments,
  }) async {
    await _firestore.collection('admin_audits').doc(auditDocId).set(
          {
            'adminEvalScores': scores,
            'adminEvalSectionComments': sectionComments,
          },
          SetOptions(merge: true),
        );
  }

  /// Persists CEO-written fields (notes, monthly bonus/pay cut, rationale) without touching computed audit fields.
  static Future<void> updateCeoWrittenFields(
    String auditDocId, {
    required String ceoNotes,
    required double ceoBonusMonthlyUsd,
    required double ceoPaycutMonthlyUsd,
    required String ceoAdjustmentRationale,
  }) async {
    await _firestore.collection('admin_audits').doc(auditDocId).set(
          {
            'ceoNotes': ceoNotes,
            'ceoBonusMonthlyUsd': ceoBonusMonthlyUsd,
            'ceoPaycutMonthlyUsd': ceoPaycutMonthlyUsd,
            'ceoAdjustmentRationale': ceoAdjustmentRationale,
          },
          SetOptions(merge: true),
        );
  }

  static Future<List<AdminAudit>> loadAdminAudits(String yearMonth) async {
    final snapshot = await _firestore
        .collection('admin_audits')
        .where('yearMonth', isEqualTo: yearMonth)
        .get();
    var audits = snapshot.docs
        .map((doc) => AdminAudit.fromFirestore(doc))
        .toList();

    final unresolvedIds = audits
        .where((a) =>
            a.adminId.isNotEmpty &&
            (a.adminName.trim().isEmpty || a.adminName.trim() == a.adminId))
        .map((a) => a.adminId)
        .toSet()
        .toList();
    if (unresolvedIds.isEmpty) return audits;

    final idToName = <String, String>{};
    final idToEmail = <String, String>{};
    for (var i = 0; i < unresolvedIds.length; i += 10) {
      final chunk = unresolvedIds.skip(i).take(10).toList();
      final users = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final u in users.docs) {
        final userData = u.data();
        idToName[u.id] = _displayNameFromUser(userData, u.id);
        idToEmail[u.id] = (userData['email'] ?? '').toString();
      }
    }

    audits = audits
        .map((a) => (idToName.containsKey(a.adminId) ||
                idToEmail.containsKey(a.adminId))
            ? a.copyWith(
                adminName: idToName[a.adminId] ?? a.adminName,
                adminEmail: (a.adminEmail.trim().isEmpty
                    ? (idToEmail[a.adminId] ?? a.adminEmail)
                    : a.adminEmail),
              )
            : a)
        .toList();
    return audits;
  }
}
