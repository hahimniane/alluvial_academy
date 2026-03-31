import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';

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

  static AuditActivityTotals computeTotalsFromRows(List<AuditClassLogRow> rows) {
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

    final shiftForms = <String, Map<String, dynamic>>{};
    final shiftFormsBySuffix = <String, Map<String, dynamic>>{};
    for (final form in audit.detailedForms) {
      final sid = form['shiftId'] as String?;
      if (sid == null || sid.isEmpty) continue;
      shiftForms[sid] = form;
      if (sid.length >= 8) {
        shiftFormsBySuffix[sid.substring(sid.length - 8)] = form;
      }
    }

    final timesheetByShiftId = <String, Map<String, dynamic>>{};
    final timesheetBySuffix = <String, Map<String, dynamic>>{};
    for (final ts in audit.detailedTimesheets) {
      final tsMap = ts;
      final sid = tsMap['shift_id'] as String? ?? tsMap['shiftId'] as String?;
      if (sid == null || sid.isEmpty) continue;
      timesheetByShiftId[sid] = tsMap;
      if (sid.length >= 8) {
        timesheetBySuffix[sid.substring(sid.length - 8)] = tsMap;
      }
    }

    for (final shiftData in audit.detailedShifts) {
      final shiftId = shiftData['id'] as String? ?? '';
      if (shiftId.isEmpty) continue;

      final shiftStart = (shiftData['start'] as Timestamp?)?.toDate();
      final shiftEnd = (shiftData['end'] as Timestamp?)?.toDate();
      final status = shiftData['status'] as String? ?? 'unknown';
      final subject = (shiftData['subject_display_name'] as String?) ??
          (shiftData['subject'] as String?) ??
          'N/A';

      final scheduledMinutes = (shiftData['duration_minutes'] as num?)?.toDouble() ?? 0;
      final durationHours = (shiftData['duration'] as num?)?.toDouble() ?? 0;
      final scheduledHours = scheduledMinutes > 0 ? scheduledMinutes / 60.0 : durationHours;

      final formData = shiftForms[shiftId] ??
          (shiftId.length >= 8
              ? shiftFormsBySuffix[shiftId.substring(shiftId.length - 8)]
              : null);
      final hasForm = formData != null;
      final formHours = hasForm
          ? ((formData['durationHours'] as num?)?.toDouble() ?? 0.0)
          : 0.0;

      final timesheetEntry = timesheetByShiftId[shiftId] ??
          (shiftId.length >= 8
              ? timesheetBySuffix[shiftId.substring(shiftId.length - 8)]
              : null) ??
          <String, dynamic>{};

      var workedHours = 0.0;
      if (timesheetEntry.isNotEmpty) {
        final clockInRaw = timesheetEntry['clock_in_timestamp'] ??
            timesheetEntry['clock_in_time'] ??
            timesheetEntry['clockIn'];
        final clockOutRaw = timesheetEntry['clock_out_timestamp'] ??
            timesheetEntry['effective_end_timestamp'] ??
            timesheetEntry['clock_out_time'] ??
            timesheetEntry['clockOut'];

        if (clockInRaw is Timestamp && clockOutRaw is Timestamp) {
          var start = clockInRaw.toDate();
          var end = clockOutRaw.toDate();
          if (shiftEnd != null && end.isAfter(shiftEnd)) end = shiftEnd;
          if (shiftStart != null && start.isBefore(shiftStart)) start = shiftStart;
          final dur = end.difference(start);
          if (!dur.isNegative) workedHours = dur.inSeconds / 3600.0;
        }

        if (workedHours <= 0) {
          final mins = (timesheetEntry['worked_minutes'] as num?)?.toDouble() ??
              (timesheetEntry['workedMinutes'] as num?)?.toDouble();
          if (mins != null && mins > 0) workedHours = mins / 60.0;
        }
      }

      final statusLower = status.toLowerCase();
      if (workedHours <= 0 &&
          (statusLower.contains('completed') ||
              statusLower.contains('fully') ||
              statusLower.contains('partially'))) {
        workedHours = scheduledHours;
      }

      final billedHours = workedHours > 0
          ? (workedHours > scheduledHours ? scheduledHours : workedHours)
          : 0.0;

      var paymentSource = 'None';
      var baseAmount = 0.0;
      if (timesheetEntry.isNotEmpty) {
        final paymentAmount = (timesheetEntry['payment_amount'] as num?)?.toDouble() ?? 0;
        final totalPay = (timesheetEntry['total_pay'] as num?)?.toDouble() ?? 0;
        if (paymentAmount > 0 || totalPay > 0) {
          paymentSource = 'Timesheet';
          baseAmount = paymentAmount > 0 ? paymentAmount : totalPay;
        }
      }

      final hourlyRate = (shiftData['hourly_rate'] as num?)?.toDouble() ??
          (shiftData['hourlyRate'] as num?)?.toDouble() ??
          0.0;
      final theoreticalPay =
          hourlyRate > 0 ? billedHours * hourlyRate : 0.0;
      if (baseAmount == 0 && hasForm && formHours > 0 && hourlyRate > 0) {
        paymentSource = 'Form Duration';
        baseAmount = formHours * hourlyRate;
      }
      if (!hasForm && baseAmount == 0) {
        paymentSource = 'Orphan (No Form)';
      }

      final adjustment = adjustments[shiftId] ?? 0.0;
      final finalPayment = baseAmount + adjustment;
      final lesson = hasForm ? (formData['lessonCovered'] as String? ?? '') : '';
      final quality = hasForm ? (formData['sessionQuality'] as String? ?? '') : '';

      rows.add(
        AuditClassLogRow(
          shiftId: shiftId,
          shiftStart: shiftStart,
          subject: subject,
          statusRaw: status,
          scheduledHours: scheduledHours,
          workedHours: workedHours,
          billedHours: billedHours,
          hasForm: hasForm,
          formHours: formHours,
          paymentSource: paymentSource,
          baseAmount: baseAmount,
          manualAdjustment: adjustment,
          finalPayment: finalPayment,
          hourlyRate: hourlyRate,
          theoreticalPay: theoreticalPay,
          lessonCovered: lesson,
          sessionQuality: quality,
        ),
      );
    }

    return rows;
  }
}
