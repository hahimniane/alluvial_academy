import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teacher_audit_full.dart';
import '../../../core/utils/shift_session_aggregator.dart';

class AuditClassLogRow {
  final String shiftId;
  final DateTime? shiftStart;
  final String subject;
  final String statusRaw;
  final double scheduledHours;
  final double workedHours;
  final double billedHours;
  final bool hasForm;
  final double formHours;
  final String paymentSource;
  final double baseAmount;
  final double manualAdjustment;
  final double finalPayment;
  final double hourlyRate;

  /// [billedHours] × [hourlyRate] when rate > 0; for display vs recorded [baseAmount].
  final double theoreticalPay;
  final String lessonCovered;
  final String sessionQuality;

  const AuditClassLogRow({
    required this.shiftId,
    required this.shiftStart,
    required this.subject,
    required this.statusRaw,
    required this.scheduledHours,
    required this.workedHours,
    required this.billedHours,
    required this.hasForm,
    required this.formHours,
    required this.paymentSource,
    required this.baseAmount,
    required this.manualAdjustment,
    required this.finalPayment,
    required this.hourlyRate,
    required this.theoreticalPay,
    this.lessonCovered = '',
    this.sessionQuality = '',
  });
}

class AuditActivityTotals {
  final double totalWorkedFromTs;
  final double totalFormHours;
  final double payFromTs;
  final double payFromForm;
  final double grossBySource;
  final double sumFinalPay;
  final Map<double, double> rateHoursByRate;

  const AuditActivityTotals({
    required this.totalWorkedFromTs,
    required this.totalFormHours,
    required this.payFromTs,
    required this.payFromForm,
    required this.grossBySource,
    required this.sumFinalPay,
    required this.rateHoursByRate,
  });
}

class AuditClassLogRowBuilder {
  static AuditActivityTotals computeTotals(TeacherAuditFull audit) {
    return computeTotalsFromRows(buildRows(audit));
  }

  static AuditActivityTotals computeTotalsFromRows(
      List<AuditClassLogRow> rows) {
    var totalWorkedFromTs = 0.0;
    var totalFormHours = 0.0;
    var payFromTs = 0.0;
    var payFromForm = 0.0;
    var sumFinalPay = 0.0;
    final rateHoursByRate = <double, double>{};

    for (final row in rows) {
      sumFinalPay += row.finalPayment;

      if (row.paymentSource == 'Timesheet') {
        totalWorkedFromTs += row.workedHours;
        payFromTs += row.baseAmount;
        if (row.hourlyRate > 0 && row.workedHours > 0) {
          rateHoursByRate[row.hourlyRate] =
              (rateHoursByRate[row.hourlyRate] ?? 0) + row.workedHours;
        }
      } else if (row.paymentSource == 'Form Duration') {
        totalFormHours += row.formHours;
        payFromForm += row.baseAmount;
        if (row.hourlyRate > 0 && row.formHours > 0) {
          rateHoursByRate[row.hourlyRate] =
              (rateHoursByRate[row.hourlyRate] ?? 0) + row.formHours;
        }
      }
    }

    return AuditActivityTotals(
      totalWorkedFromTs: totalWorkedFromTs,
      totalFormHours: totalFormHours,
      payFromTs: payFromTs,
      payFromForm: payFromForm,
      grossBySource: payFromTs + payFromForm,
      sumFinalPay: sumFinalPay,
      rateHoursByRate: rateHoursByRate,
    );
  }

  static List<String> consistencyWarnings(
    TeacherAuditFull audit, {
    double epsilon = 0.01,
  }) {
    final warnings = <String>[];
    final totals = computeTotals(audit);
    final ps = audit.paymentSummary;
    if (ps == null) return warnings;

    if ((totals.grossBySource - ps.totalGrossPayment).abs() > epsilon) {
      warnings.add(
        'Gross mismatch: rows=${totals.grossBySource.toStringAsFixed(2)} vs paymentSummary=${ps.totalGrossPayment.toStringAsFixed(2)}',
      );
    }
    final expectedNet = totals.sumFinalPay + ps.adminAdjustment;
    if ((expectedNet - ps.totalNetPayment).abs() > 0.5) {
      warnings.add(
        'Net mismatch: rows+admin=${expectedNet.toStringAsFixed(2)} vs paymentSummary=${ps.totalNetPayment.toStringAsFixed(2)}',
      );
    }
    return warnings;
  }

  static List<AuditClassLogRow> buildRows(TeacherAuditFull audit) {
    final rows = <AuditClassLogRow>[];
    final adjustments = audit.paymentSummary?.shiftPaymentAdjustments ?? {};

    // Group timesheets by shift ID
    final timesheetsByShift = <String, List<Map<String, dynamic>>>{};
    for (final ts in audit.detailedTimesheets) {
      final sid = ts['shift_id'] ?? ts['shiftId'];
      if (sid != null) {
        for (final key
            in ShiftSessionAggregator.getShiftIdIndexKeys(sid.toString())) {
          timesheetsByShift.putIfAbsent(key, () => []).add(ts);
        }
      }
    }

    // Group forms by shift ID
    final formsByShift = <String, List<Map<String, dynamic>>>{};
    for (final form in audit.detailedForms) {
      final sid = form['shiftId'];
      if (sid != null) {
        for (final key
            in ShiftSessionAggregator.getShiftIdIndexKeys(sid.toString())) {
          formsByShift.putIfAbsent(key, () => []).add(form);
        }
      }
    }

    for (final shiftData in audit.detailedShifts) {
      final shiftId = shiftData['id'] as String? ?? '';
      if (shiftId.isEmpty) continue;

      final shiftStart = (shiftData['start'] as Timestamp?)?.toDate() ??
          (shiftData['shift_start'] as Timestamp?)?.toDate();
      final status = shiftData['status'] as String? ?? 'unknown';
      final subject = (shiftData['subject_display_name'] as String?) ??
          (shiftData['subject'] as String?) ??
          'N/A';

      final shiftTimesheets = timesheetsByShift[shiftId] ?? [];
      final shiftForms = formsByShift[shiftId] ?? [];

      final result = ShiftSessionAggregator.computeSession(
          shiftData, shiftTimesheets, shiftForms);

      final scheduledHours =
          ShiftSessionAggregator.getScheduledHours(shiftData);
      final hasForm = result.hasForm;

      // Determine payment source
      String paymentSource = 'None';
      if (result.hasPunchedTimesheets) {
        paymentSource = 'Timesheet';
      } else if (hasForm) {
        paymentSource = 'Form Duration';
      }

      final baseAmount = result.realPay;
      final manualAdjustment = adjustments[shiftId] ?? 0.0;
      final finalPayment = baseAmount + manualAdjustment;

      double hourlyRate = (shiftData['hourly_rate'] as num?)?.toDouble() ?? 0.0;
      if (hourlyRate <= 0)
        hourlyRate = (shiftData['hourlyRate'] as num?)?.toDouble() ?? 0.0;

      final theoreticalPay = result.workedHours * hourlyRate;

      // Get form details for display
      String lessonCovered = '';
      String sessionQuality = '';
      if (shiftForms.isNotEmpty) {
        final form = shiftForms.first;
        final responses = form['responses'];
        if (responses is Map) {
          lessonCovered =
              (responses['lessonCovered'] ?? responses['topic'] ?? '')
                  .toString();
          sessionQuality =
              (responses['sessionQuality'] ?? responses['rating'] ?? '')
                  .toString();
        }
      }

      rows.add(AuditClassLogRow(
        shiftId: shiftId,
        shiftStart: shiftStart,
        subject: subject,
        statusRaw: status,
        scheduledHours: scheduledHours,
        workedHours: result.hasPunchedTimesheets ? result.workedHours : 0.0,
        billedHours: result.workedHours,
        hasForm: hasForm,
        formHours:
            !result.hasPunchedTimesheets && hasForm ? result.workedHours : 0.0,
        paymentSource: paymentSource,
        baseAmount: baseAmount,
        manualAdjustment: manualAdjustment,
        finalPayment: finalPayment,
        hourlyRate: hourlyRate,
        theoreticalPay: theoreticalPay,
        lessonCovered: lessonCovered,
        sessionQuality: sessionQuality,
      ));
    }

    final visible = rows
        .where((r) => !_shouldHideClassLogRowWithNoPaidActivity(r))
        .toList();
    visible.sort((a, b) {
      if (a.shiftStart == null && b.shiftStart == null) return 0;
      if (a.shiftStart == null) return 1;
      if (b.shiftStart == null) return -1;
      return a.shiftStart!.compareTo(b.shiftStart!);
    });

    return visible;
  }

  /// Hides “scheduled only” rows (no timesheet/form pay) so the class log matches
  /// payable activity. Missed/cancelled rows stay visible for follow-up.
  static bool _shouldHideClassLogRowWithNoPaidActivity(AuditClassLogRow row) {
    const eps = 1e-6;
    final s = row.statusRaw.toLowerCase();
    if (s.contains('miss')) return false;
    if (s.contains('cancel')) return false;
    if (row.finalPayment.abs() > eps) return false;
    if (row.workedHours > eps) return false;
    if (row.formHours > eps) return false;
    if (row.hasForm) return false;
    if (row.baseAmount.abs() > eps) return false;
    return true;
  }
}
