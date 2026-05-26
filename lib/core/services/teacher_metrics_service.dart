import 'package:cloud_firestore/cloud_firestore.dart';
import '../audit/readiness_form_kpi.dart';
import '../audit/teaching_form_acceptance_for_month.dart';
import '../utils/app_logger.dart';
import '../utils/shift_session_aggregator.dart';
import '../utils/teaching_form_classification.dart';
import '../utils/teacher_leave_periods.dart';

/// Basic metrics for a teacher for a specific period.
///
/// [hoursWorked] is **billable** time only: same caps as payroll when a timesheet
/// is clocked out (cannot exceed scheduled class length; clock-in/out trimmed to
/// the scheduled shift window). This matches how `payment_amount` is normally
/// computed, so hours and pay stay comparable on dashboards.
///
/// [payPending] includes pending / edited-not-yet-approved timesheets (live
/// `payment_amount` on the document). [payProjected] is the sum teachers should
/// see on dashboards unless an admin hard-rejects a timesheet.
///
/// Missed shifts with a catch-up form (`form_completed` / `form_response_id`)
/// add billable hours and pay from [reportedHours] on the shift or form, with
/// fallback to scheduled length and cap at scheduled length (same rules as product).
class TeacherBasicMetrics {
  final int scheduledClasses;
  final int completedClasses;
  final int missedClasses;
  final int cancelledClasses;
  final double hoursWorked;
  final double payApproved;
  final double payPaid;
  final double payPending;
  final int formsSubmitted;
  final int formsRequired;
  final int lateClockIns;

  const TeacherBasicMetrics({
    required this.scheduledClasses,
    required this.completedClasses,
    required this.missedClasses,
    required this.cancelledClasses,
    required this.hoursWorked,
    required this.payApproved,
    required this.payPaid,
    required this.payPending,
    required this.formsSubmitted,
    required this.formsRequired,
    required this.lateClockIns,
  });

  /// Paid + approved + pending (edited timesheets use live `payment_amount` in pending).
  double get payProjected => payPaid + payApproved + payPending;

  factory TeacherBasicMetrics.empty() {
    return const TeacherBasicMetrics(
      scheduledClasses: 0,
      completedClasses: 0,
      missedClasses: 0,
      cancelledClasses: 0,
      hoursWorked: 0.0,
      payApproved: 0.0,
      payPaid: 0.0,
      payPending: 0.0,
      formsSubmitted: 0,
      formsRequired: 0,
      lateClockIns: 0,
    );
  }
}

class MonthlyPayShiftRow {
  final String shiftId;
  final String subject;
  final double scheduledHours;
  final double workedHours;
  final double realPay;
  final double payPaid;
  final double payApproved;
  final double payPending;
  final double hourlyRate;
  final double manualAdjustment;
  final bool hasForm;
  final bool hasPunchedTimesheets;

  const MonthlyPayShiftRow({
    required this.shiftId,
    required this.subject,
    required this.scheduledHours,
    required this.workedHours,
    required this.realPay,
    required this.payPaid,
    required this.payApproved,
    required this.payPending,
    required this.hourlyRate,
    required this.manualAdjustment,
    required this.hasForm,
    required this.hasPunchedTimesheets,
  });

  double get finalPay => realPay + manualAdjustment;

  Map<String, dynamic> toMap() => {
        'shiftId': shiftId,
        'subject': subject,
        'scheduledHours': scheduledHours,
        'workedHours': workedHours,
        'realPay': realPay,
        'payPaid': payPaid,
        'payApproved': payApproved,
        'payPending': payPending,
        'hourlyRate': hourlyRate,
        'manualAdjustment': manualAdjustment,
        'finalPay': finalPay,
        'hasForm': hasForm,
        'hasPunchedTimesheets': hasPunchedTimesheets,
      };
}

class MonthlyPayComputation {
  final List<MonthlyPayShiftRow> rows;
  final Map<String, List<Map<String, dynamic>>> _timesheetsByShift;

  const MonthlyPayComputation({
    required this.rows,
    Map<String, List<Map<String, dynamic>>> timesheetsByShift = const {},
  }) : _timesheetsByShift = timesheetsByShift;

  Map<String, MonthlyPayShiftRow> get rowsByShiftId => {
        for (final row in rows) row.shiftId: row,
      };

  List<Map<String, dynamic>> timesheetsForShift(String shiftId) =>
      _timesheetsByShift[shiftId] ?? const [];

  double get hoursWorked =>
      rows.fold(0.0, (total, row) => total + row.workedHours);
  double get payPaid => rows.fold(0.0, (total, row) => total + row.payPaid);
  double get payApproved =>
      rows.fold(0.0, (total, row) => total + row.payApproved);
  double get payPending =>
      rows.fold(0.0, (total, row) => total + row.payPending);
  double get payProjected => payPaid + payApproved + payPending;
  double get totalRealPay =>
      rows.fold(0.0, (total, row) => total + row.realPay);
  double get totalFinalPay =>
      rows.fold(0.0, (total, row) => total + row.finalPay);
}

/// Service for aggregating teacher metrics from live Firestore data.
/// This is the canonical source of truth for teacher metrics across web, mobile, and audit.
class TeacherMetricsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _subjectRatesCollection = 'subject_hourly_rates';

  static Map<String, dynamic> _snapshotMap(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw is Map<String, dynamic>) return raw;
    return Map<String, dynamic>.from(raw as Map);
  }

  /// When [start]/[end] are exactly one calendar month (same convention as
  /// teacher home / audits), returns `yyyy-MM` for readiness KPI alignment.
  static String? _calendarYearMonthForRange(DateTime start, DateTime end) {
    if (start.day != 1 ||
        start.hour != 0 ||
        start.minute != 0 ||
        start.second != 0 ||
        start.millisecond != 0 ||
        start.microsecond != 0) {
      return null;
    }
    final monthEnd = DateTime(start.year, start.month + 1, 0, 23, 59, 59);
    if (end.year != monthEnd.year ||
        end.month != monthEnd.month ||
        end.day != monthEnd.day ||
        end.hour != 23 ||
        end.minute != 59 ||
        end.second != 59) {
      return null;
    }
    return '${start.year}-${start.month.toString().padLeft(2, '0')}';
  }

  /// Aggregates metrics for a specific teacher within a date range.
  /// This function is pure and deterministic given the Firestore state.
  static Future<TeacherBasicMetrics> aggregate({
    required String teacherId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      AppLogger.debug(
          'TeacherMetricsService: Aggregating for $teacherId from $start to $end');

      final now = DateTime.now();
      final shiftWindowEnd = end.isBefore(now) ? end : now;

      var timesheetDocs = <QueryDocumentSnapshot>[];
      try {
        final snap = await _firestore
            .collection('timesheet_entries')
            .where('teacher_id', isEqualTo: teacherId)
            .get();
        timesheetDocs = snap.docs;
      } catch (e, st) {
        AppLogger.error(
          'TeacherMetricsService: timesheet_entries failed for $teacherId: $e',
          error: e,
          stackTrace: st,
        );
      }

      var shiftDocs = <QueryDocumentSnapshot>[];
      try {
        final snap = await _firestore
            .collection('teaching_shifts')
            .where('teacher_id', isEqualTo: teacherId)
            .where('shift_start',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('shift_start',
                isLessThanOrEqualTo: Timestamp.fromDate(shiftWindowEnd))
            .get();
        shiftDocs = snap.docs;
      } catch (e, st) {
        AppLogger.error(
          'TeacherMetricsService: teaching_shifts failed for $teacherId: $e',
          error: e,
          stackTrace: st,
        );
      }

      var formDocs = <QueryDocumentSnapshot>[];
      try {
        final snap = await _firestore
            .collection('form_responses')
            .where('userId', isEqualTo: teacherId)
            .get();
        formDocs = snap.docs;
      } catch (e, st) {
        AppLogger.error(
          'TeacherMetricsService: form_responses failed for $teacherId: $e',
          error: e,
          stackTrace: st,
        );
      }

      final subjectRates = await _fetchSubjectHourlyRates();
      final monthlyPay = computeMonthlyPayForTeacher(
        shifts: shiftDocs.map((doc) => MapEntry(doc.id, _snapshotMap(doc))),
        timesheets: timesheetDocs.map(_snapshotMap),
        forms: formDocs.map(_snapshotMap),
        subjectHourlyRatesByName: subjectRates,
      );

      final formMapsForLeave = <Map<String, dynamic>>[];
      for (final d in formDocs) {
        formMapsForLeave.add(_snapshotMap(d));
      }
      final leavePeriods = TeacherLeavePeriods.periodsForTeacherFromFormDocs(
        formMapsForLeave,
        teacherId,
      );

      final validShiftIds = shiftDocs.map((d) => d.id).toSet();
      final validShiftIdSuffixes = <String>{};
      for (final sid in validShiftIds) {
        if (sid.length >= 8) {
          validShiftIdSuffixes.add(sid.substring(sid.length - 8));
        }
      }
      final timesheetMaps = <Map<String, dynamic>>[];
      for (final d in timesheetDocs) {
        timesheetMaps.add(_snapshotMap(d));
      }
      final proofFormIds = formResponseIdsWithTimesheetProof(timesheetMaps);

      int scheduledClasses = shiftDocs.length;
      int completedClasses = 0;
      int missedClasses = 0;
      int cancelledClasses = 0;
      double hoursWorked = 0.0;
      double payApproved = 0.0;
      double payPaid = 0.0;
      double payPending = 0.0;
      int formsRequired = 0;
      int lateClockIns = 0;

      final calendarYm = _calendarYearMonthForRange(start, end);
      final int formsSubmitted;
      if (calendarYm != null) {
        final monthFormDocs = <QueryDocumentSnapshot>[];
        for (final d in formDocs) {
          final ymField = _snapshotMap(d)['yearMonth']?.toString();
          if (ymField == calendarYm) {
            monthFormDocs.add(d);
          }
        }
        final acceptance = TeachingFormAcceptanceForMonth.compute(
          forms: monthFormDocs,
          shifts: shiftDocs,
          timesheets: timesheetDocs,
          startDate: start,
          endDate: end,
          yearMonth: calendarYm,
        );
        formsSubmitted =
            ReadinessFormKpi.submittedCountForAcceptedTeachingForms(
          shifts: shiftDocs,
          acceptedTeachingForms: acceptance.acceptedForms,
          startDate: start,
          endDate: end,
        );
      } else {
        final linkedReadinessFormIds = <String>{};
        for (final formDoc in formDocs) {
          final data = _snapshotMap(formDoc);
          if (!TeachingFormClassification.isTeachingFormData(data)) continue;
          final submittedAt = data['submittedAt'] as Timestamp?;
          if (submittedAt != null) {
            final sd = submittedAt.toDate();
            if (sd.isBefore(start) || sd.isAfter(end)) continue;
          }
          final shiftId = data['shiftId'] as String?;
          final linkedByExact =
              shiftId != null && validShiftIds.contains(shiftId);
          final linkedBySuffix = shiftId != null &&
              shiftId.length >= 8 &&
              validShiftIdSuffixes.contains(shiftId.length > 8
                  ? shiftId.substring(shiftId.length - 8)
                  : shiftId);
          if (!linkedByExact && !linkedBySuffix) continue;

          if (TeachingFormClassification
              .requiresTimesheetProofForTeachingAcceptance(data)) {
            if (proofFormIds.contains(formDoc.id)) {
              linkedReadinessFormIds.add(formDoc.id);
              continue;
            }
            if (_formLinksToMissedShift(
              shiftId,
              shiftDocs,
              start,
              end,
            )) {
              linkedReadinessFormIds.add(formDoc.id);
            }
            continue;
          }
          linkedReadinessFormIds.add(formDoc.id);
        }
        formsSubmitted = linkedReadinessFormIds.length;
      }

      // Process shifts — completion must match [TeachingShift] Firestore `status.name`
      for (final shiftDoc in shiftDocs) {
        final shift = _snapshotMap(shiftDoc);
        final sid = shiftDoc.id;
        final status = shift['status'] as String?;
        final startTs = shift['shift_start'] as Timestamp?;
        final shiftStart = startTs?.toDate();

        if (status == 'cancelled') {
          cancelledClasses++;
        } else if (status == 'missed' && shiftStart != null) {
          if (leavePeriods.any((lp) =>
              !shiftStart.isBefore(lp.start) && shiftStart.isBefore(lp.end))) {
          } else {
            missedClasses++;
            formsRequired++;
          }
        } else if (status == 'completed' ||
            status == 'fullyCompleted' ||
            status == 'partiallyCompleted') {
          completedClasses++;
          formsRequired++;
        }

        final payRow = monthlyPay.rowsByShiftId[sid];

        if (payRow != null) {
          hoursWorked += payRow.workedHours;
          payPaid += payRow.payPaid;
          payApproved += payRow.payApproved;
          payPending += payRow.payPending;
        }

        // Calculate late clock-ins
        for (final ts in monthlyPay.timesheetsForShift(sid)) {
          final clockIn =
              (ts['clock_in_time'] ?? ts['clock_in_timestamp']) as Timestamp?;
          final scheduledStartTs = shift['shift_start'] as Timestamp?;
          if (clockIn != null &&
              scheduledStartTs != null &&
              clockIn.toDate().difference(scheduledStartTs.toDate()).inMinutes >
                  5) {
            lateClockIns++;
            break; // Count once per shift
          }
        }
      }

      return TeacherBasicMetrics(
        scheduledClasses: scheduledClasses,
        completedClasses: completedClasses,
        missedClasses: missedClasses,
        cancelledClasses: cancelledClasses,
        hoursWorked: hoursWorked,
        payApproved: payApproved,
        payPaid: payPaid,
        payPending: payPending,
        formsSubmitted: formsSubmitted,
        formsRequired: formsRequired,
        lateClockIns: lateClockIns,
      );
    } catch (e) {
      AppLogger.error('TeacherMetricsService: Error aggregating metrics: $e');
      return TeacherBasicMetrics.empty();
    }
  }

  static Future<Map<String, double>> _fetchSubjectHourlyRates() async {
    try {
      final snap = await _firestore.collection(_subjectRatesCollection).get();
      final rates = <String, double>{};
      for (final doc in snap.docs) {
        final data = _snapshotMap(doc);
        if (data['isActive'] == false) continue;
        final subject = data['subjectName']?.toString();
        final rate = (data['hourlyRate'] as num?)?.toDouble() ?? 0.0;
        if (subject != null && subject.trim().isNotEmpty && rate > 0) {
          rates[_subjectRateKey(subject)] = rate;
        }
      }
      return rates;
    } catch (e, st) {
      AppLogger.error(
        'TeacherMetricsService: subject_hourly_rates read failed (rules must allow signed-in read, or deploy firestore.rules): $e',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  static MonthlyPayComputation computeMonthlyPayForTeacher({
    required Iterable<MapEntry<String, Map<String, dynamic>>> shifts,
    required Iterable<Map<String, dynamic>> timesheets,
    required Iterable<Map<String, dynamic>> forms,
    Map<String, double> subjectHourlyRatesByName = const {},
    Map<String, double> shiftPaymentAdjustments = const {},
  }) {
    final timesheetsByShift = <String, List<Map<String, dynamic>>>{};
    for (final ts in timesheets) {
      final sid = ts['shift_id'] ?? ts['shiftId'];
      if (sid == null) continue;
      for (final key
          in ShiftSessionAggregator.getShiftIdIndexKeys(sid.toString())) {
        timesheetsByShift.putIfAbsent(key, () => []).add(ts);
      }
    }

    final formsByShift = <String, List<Map<String, dynamic>>>{};
    for (final form in forms) {
      final sid = form['shiftId'];
      if (sid == null) continue;
      for (final key
          in ShiftSessionAggregator.getShiftIdIndexKeys(sid.toString())) {
        formsByShift.putIfAbsent(key, () => []).add(form);
      }
    }

    final rows = <MonthlyPayShiftRow>[];
    for (final shiftEntry in shifts) {
      final shiftId = shiftEntry.key;
      final shift = Map<String, dynamic>.from(shiftEntry.value);
      final subject =
          (shift['subject_display_name'] ?? shift['subject'] ?? 'Other')
              .toString();
      final rate = _resolvedHourlyRate(
        shift,
        subject,
        subjectHourlyRatesByName,
      );
      if (rate > 0) {
        shift['hourly_rate'] = rate;
      }

      final shiftTimesheets = timesheetsByShift[shiftId] ?? const [];
      final shiftForms = formsByShift[shiftId] ?? const [];
      final result = ShiftSessionAggregator.computeSession(
        shift,
        shiftTimesheets.map((e) => Map<String, dynamic>.from(e)).toList(),
        shiftForms.map((e) => Map<String, dynamic>.from(e)).toList(),
      );

      final isIncluded =
          result.realPay > 0 || result.hasForm || result.hasPunchedTimesheets;
      if (!isIncluded) continue;

      rows.add(
        MonthlyPayShiftRow(
          shiftId: shiftId,
          subject: subject,
          scheduledHours: ShiftSessionAggregator.getScheduledHours(shift),
          workedHours: result.workedHours,
          realPay: result.realPay,
          payPaid: result.payPaid,
          payApproved: result.payApproved,
          payPending: result.payPending,
          hourlyRate: rate,
          manualAdjustment: shiftPaymentAdjustments[shiftId] ?? 0.0,
          hasForm: result.hasForm,
          hasPunchedTimesheets: result.hasPunchedTimesheets,
        ),
      );
    }

    return MonthlyPayComputation(
      rows: rows,
      timesheetsByShift: timesheetsByShift,
    );
  }

  static double _resolvedHourlyRate(
    Map<String, dynamic> shift,
    String subject,
    Map<String, double> subjectHourlyRatesByName,
  ) {
    final shiftRate = _toDouble(shift['hourly_rate']);
    if (shiftRate > 0) return shiftRate;
    final camelRate = _toDouble(shift['hourlyRate']);
    if (camelRate > 0) return camelRate;

    final subjectKey = _subjectRateKey(subject);
    final exact = subjectHourlyRatesByName[subjectKey] ??
        subjectHourlyRatesByName[subject.toLowerCase().trim()];
    if (exact != null && exact > 0) return exact;

    for (final entry in subjectHourlyRatesByName.entries) {
      if (subjectKey.contains(entry.key) || entry.key.contains(subjectKey)) {
        return entry.value;
      }
    }
    return 0.0;
  }

  static String _subjectRateKey(String subject) =>
      subject.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Billable hours for one clock-in/out pair against [shift] window (trim + cap to scheduled).
  /// Delegates to [ShiftSessionAggregator] so dialogs match dashboards and payroll.
  static double billableHoursForShiftClock({
    required Map<String, dynamic> shift,
    required DateTime clockIn,
    required DateTime clockOut,
  }) {
    final ts = <String, dynamic>{
      'clock_in_timestamp': Timestamp.fromDate(clockIn),
      'clock_out_timestamp': Timestamp.fromDate(clockOut),
      'status': 'approved',
    };
    return ShiftSessionAggregator.computeSession(shift, [ts], []).workedHours;
  }

  /// Helper to get the year-month string for a date (yyyy-MM)
  static String getYearMonth(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}";
  }

  static bool _shiftStartInWindow(
    Map<String, dynamic> shiftData,
    DateTime start,
    DateTime end,
  ) {
    final ts = shiftData['shift_start'] as Timestamp?;
    if (ts == null) return false;
    final t = ts.toDate();
    return !t.isBefore(start) && !t.isAfter(end);
  }

  static bool _formLinksToMissedShift(
    String? formShiftId,
    List<QueryDocumentSnapshot> shifts,
    DateTime start,
    DateTime end,
  ) {
    if (formShiftId == null || formShiftId.trim().isEmpty) return false;
    final fid = formShiftId.trim();
    for (final s in shifts) {
      final raw = _snapshotMap(s);
      if (raw['isBanned'] == true) continue;
      if (!_shiftStartInWindow(raw, start, end)) continue;
      if (s.id == fid ||
          (fid.length >= 8 &&
              s.id.length >= 8 &&
              s.id.endsWith(fid.substring(fid.length - 8)))) {
        final st = raw['status'] ?? 'scheduled';
        return st.toString() == 'missed';
      }
    }
    return false;
  }
}
