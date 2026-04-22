import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

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

/// Service for aggregating teacher metrics from live Firestore data.
/// This is the canonical source of truth for teacher metrics across web, mobile, and audit.
class TeacherMetricsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Billable hours for one shift + clock pair — same rules as timesheet
  /// clock-out payment (scheduled window + max scheduled duration).
  static double billableHoursForShiftClock({
    required Map<String, dynamic> shift,
    required DateTime clockIn,
    required DateTime clockOut,
  }) {
    final startTs = shift['shift_start'] as Timestamp?;
    final endTs = shift['shift_end'] as Timestamp?;
    if (startTs == null || endTs == null) return 0.0;

    final shiftStart = startTs.toDate();
    final shiftEnd = endTs.toDate();

    var effectiveEnd = clockOut;
    if (clockOut.isAfter(shiftEnd)) {
      effectiveEnd = shiftEnd;
    }

    var effectiveStart = clockIn;
    if (clockIn.isBefore(shiftStart)) {
      effectiveStart = shiftStart;
    }

    final raw = effectiveEnd.difference(effectiveStart);
    final scheduledDuration = shiftEnd.difference(shiftStart);
    final valid = raw > scheduledDuration
        ? scheduledDuration
        : (raw.isNegative ? Duration.zero : raw);
    return valid.inSeconds / 3600.0;
  }

  static double _scheduledHoursFromShift(Map<String, dynamic> shift) {
    final startTs = shift['shift_start'] as Timestamp?;
    final endTs = shift['shift_end'] as Timestamp?;
    if (startTs == null || endTs == null) return 0.0;
    final sec = endTs.toDate().difference(startTs.toDate()).inSeconds;
    if (sec <= 0) return 0.0;
    return sec / 3600.0;
  }

  /// Missed shift compensated via form: reported hours (shift or form doc),
  /// fallback scheduled length, cap at scheduled length.
  static double catchUpBillableHoursForMissedShift({
    required Map<String, dynamic> shift,
    Map<String, dynamic>? formDocData,
  }) {
    final status = (shift['status'] as String?)?.toLowerCase();
    if (status != 'missed') return 0.0;

    final formDone = shift['form_completed'] == true ||
        (shift['form_response_id'] != null &&
            shift['form_response_id'].toString().isNotEmpty);
    if (!formDone) return 0.0;

    final scheduledH = _scheduledHoursFromShift(shift);
    if (scheduledH <= 0) return 0.0;

    double? reported = (shift['reported_hours'] as num?)?.toDouble();
    if (reported == null && formDocData != null) {
      reported = (formDocData['reportedHours'] as num?)?.toDouble();
    }
    final raw = reported ?? scheduledH;
    final capped = raw > scheduledH ? scheduledH : raw;
    return capped < 0 ? 0.0 : capped;
  }

  static double catchUpPayForMissedShift({
    required Map<String, dynamic> shift,
    Map<String, dynamic>? formDocData,
  }) {
    final hours =
        catchUpBillableHoursForMissedShift(shift: shift, formDocData: formDocData);
    final rate = (shift['hourly_rate'] as num?)?.toDouble() ?? 0.0;
    return hours * rate;
  }

  static bool _timesheetRowRejected(Map<String, dynamic> data) {
    return (data['status'] as String?)?.toLowerCase() == 'rejected';
  }

  static bool _hasNonRejectedPunchedTimesheet(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> timesheetDocs,
    String shiftId,
  ) {
    for (final doc in timesheetDocs) {
      final data = doc.data();
      if (_timesheetRowRejected(data)) continue;
      final sid = data['shift_id'] ?? data['shiftId'];
      if (sid?.toString() != shiftId) continue;
      final ci = data['clock_in_time'] ?? data['clock_in_timestamp'];
      final co = data['clock_out_time'] ?? data['clock_out_timestamp'];
      if (ci != null && co != null) return true;
    }
    return false;
  }

  /// Aggregates metrics for a specific teacher within a date range.
  /// This function is pure and deterministic given the Firestore state.
  static Future<TeacherBasicMetrics> aggregate({
    required String teacherId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      AppLogger.debug('TeacherMetricsService: Aggregating for $teacherId from $start to $end');

      // 1. Fetch all timesheet entries for this teacher
      // We fetch all and filter in memory to handle different timestamp field names
      final timesheetQuery = await _firestore
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: teacherId)
          .get();

      // 2. Fetch all shifts for this teacher in the range
      final shiftQuery = await _firestore
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: teacherId)
          .where('shift_start', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('shift_start', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final shifts = shiftQuery.docs.map((doc) => doc.data()).toList();
      final shiftIds = shiftQuery.docs.map((doc) => doc.id).toSet();
      final shiftById = <String, Map<String, dynamic>>{
        for (final d in shiftQuery.docs) d.id: d.data(),
      };

      int scheduledClasses = shifts.length;
      int completedClasses = 0;
      int missedClasses = 0;
      int cancelledClasses = 0;
      double hoursWorked = 0.0;
      double payApproved = 0.0;
      double payPaid = 0.0;
      double payPending = 0.0;
      int formsSubmitted = 0;
      int formsRequired = 0;
      int lateClockIns = 0;

      // Process shifts — completion must match [TeachingShift] Firestore `status.name`
      // (includes partially completed sessions, same as audit / shift cards).
      for (final shift in shifts) {
        final status = shift['status'] as String?;
        if (status == 'missed') {
          missedClasses++;
          formsRequired++;
        }
        if (status == 'cancelled') cancelledClasses++;
        if (status == 'completed' ||
            status == 'fullyCompleted' ||
            status == 'partiallyCompleted') {
          completedClasses++;
          formsRequired++;
        }
      }

      final tsDocs = timesheetQuery.docs;

      // Process timesheets (rejected rows do not count toward hours or pay)
      for (final doc in tsDocs) {
        final data = doc.data();
        if (_timesheetRowRejected(data)) continue;

        final shiftId = data['shift_id'] ?? data['shiftId'];

        // Only count timesheets for shifts in our range
        if (shiftId == null || !shiftIds.contains(shiftId)) continue;

        final clockIn = (data['clock_in_time'] ?? data['clock_in_timestamp']) as Timestamp?;
        final clockOut = (data['clock_out_time'] ?? data['clock_out_timestamp']) as Timestamp?;
        final status = data['status'] as String? ?? 'pending';
        final paymentAmount = (data['payment_amount'] as num?)?.toDouble() ??
            (data['total_pay'] as num?)?.toDouble() ??
            0.0;
        final formCompleted = data['form_completed'] as bool? ?? false;

        if (clockIn != null && clockOut != null) {
          final shiftData = shiftById[shiftId];
          if (shiftData != null) {
            hoursWorked += billableHoursForShiftClock(
              shift: shiftData,
              clockIn: clockIn.toDate(),
              clockOut: clockOut.toDate(),
            );

            final scheduledStartTs = shiftData['shift_start'] as Timestamp?;
            if (scheduledStartTs != null &&
                clockIn.toDate().difference(scheduledStartTs.toDate()).inMinutes > 5) {
              lateClockIns++;
            }
          }

          if (formCompleted) formsSubmitted++;
        }

        // Pay aggregation — pending includes edited rows with updated payment_amount
        if (status == 'paid') {
          payPaid += paymentAmount;
        } else if (status == 'approved') {
          payApproved += paymentAmount;
        } else {
          payPending += paymentAmount;
        }
      }

      // Missed shifts with catch-up form (no double-count if a punched timesheet exists)
      for (final shiftDoc in shiftQuery.docs) {
        final shift = shiftDoc.data();
        final sid = shiftDoc.id;
        if ((shift['status'] as String?)?.toLowerCase() != 'missed') continue;

        final formDone = shift['form_completed'] == true ||
            (shift['form_response_id'] != null &&
                shift['form_response_id'].toString().isNotEmpty);
        if (!formDone) continue;

        if (_hasNonRejectedPunchedTimesheet(tsDocs, sid)) continue;

        Map<String, dynamic>? formData;
        if ((shift['reported_hours'] == null) &&
            shift['form_response_id'] != null &&
            shift['form_response_id'].toString().isNotEmpty) {
          try {
            final fd = await _firestore
                .collection('form_responses')
                .doc(shift['form_response_id'].toString())
                .get();
            if (fd.exists) formData = fd.data();
          } catch (_) {}
        }

        final catchH =
            catchUpBillableHoursForMissedShift(shift: shift, formDocData: formData);
        final catchPay = catchUpPayForMissedShift(shift: shift, formDocData: formData);
        if (catchH > 0) {
          hoursWorked += catchH;
        }
        if (catchPay > 0) {
          payPending += catchPay;
        }
        formsSubmitted++;
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

  /// Helper to get the year-month string for a date (yyyy-MM)
  static String getYearMonth(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}";
  }
}
