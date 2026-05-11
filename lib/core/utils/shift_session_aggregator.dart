import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

import 'makeup_class_attestation.dart';

/// Aggregated result for a single shift session.
class ShiftSessionResult {
  final double workedHours;
  final double realPay;
  final double payPaid;
  final double payApproved;
  final double payPending;
  final bool hasPunchedTimesheets;
  final bool hasForm;

  const ShiftSessionResult({
    required this.workedHours,
    required this.realPay,
    required this.payPaid,
    required this.payApproved,
    required this.payPending,
    required this.hasPunchedTimesheets,
    required this.hasForm,
  });

  static const empty = ShiftSessionResult(
    workedHours: 0.0,
    realPay: 0.0,
    payPaid: 0.0,
    payApproved: 0.0,
    payPending: 0.0,
    hasPunchedTimesheets: false,
    hasForm: false,
  );
}

/// Standardized aggregator for shift hours and pay.
/// Implements the "Smart Detect" logic (Rules R1-R6) to resolve
/// contradictions between multi-segment shifts and duplicate writes.
class ShiftSessionAggregator {
  /// Extract a DateTime from a dynamic value (Timestamp, String, etc.)
  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Extract a double from a dynamic value
  static double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  /// One key per logical shift for UI grouping (e.g. merge timesheet rows).
  /// [tpl_tpl_abc] and [tpl_abc] map to the same canonical id.
  static String canonicalShiftIdForGrouping(String? rawSid) {
    final sid = rawSid?.trim() ?? '';
    if (sid.isEmpty) return '';
    if (sid.startsWith('tpl_tpl_')) return 'tpl_${sid.substring(8)}';
    return sid;
  }

  /// Normalize shift ID matching (handles tpl_ and tpl_tpl_ prefixes)
  static List<String> getShiftIdIndexKeys(String? rawSid) {
    final sid = rawSid?.trim() ?? '';
    if (sid.isEmpty) return [];

    final keys = <String>{sid};
    String canonical = sid;
    if (sid.startsWith('tpl_tpl_')) {
      canonical = 'tpl_${sid.substring(8)}';
    }
    keys.add(canonical);

    if (sid.startsWith('tpl_tpl_')) {
      keys.add('tpl_${sid.substring(8)}');
    } else if (sid.startsWith('tpl_')) {
      keys.add('tpl_tpl_${sid.substring(4)}');
    }

    return keys.toList();
  }

  static bool _isRejected(Map<String, dynamic> data) {
    return (data['status'] as String?)?.toLowerCase() == 'rejected';
  }

  /// True only when two [clock in, clock out) ranges share **positive** overlap.
  /// Touching endpoints (end == next start) or a gap are **not** merged — those are separate segments.
  static bool _clockIntervalsOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final latestStart = aStart.isAfter(bStart) ? aStart : bStart;
    final earliestEnd = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    return latestStart.isBefore(earliestEnd);
  }

  /// Calculate scheduled hours for a shift
  static double getScheduledHours(Map<String, dynamic> shift) {
    final sStart = _toDate(shift['shift_start'] ?? shift['start']);
    final sEnd = _toDate(shift['shift_end'] ?? shift['end']);

    if (sStart != null && sEnd != null && sEnd.isAfter(sStart)) {
      return sEnd.difference(sStart).inSeconds / 3600.0;
    }

    final mins = _toDouble(shift['duration_minutes'], 0);
    if (mins > 0) return mins / 60.0;

    return _toDouble(shift['duration'], 0);
  }

  /// Parse duration from a form response
  static double _parseFormDuration(Map<String, dynamic> form) {
    double reported = _toDouble(form['durationHours'], -1);
    if (reported >= 0) return reported;

    reported = _toDouble(form['reportedHours'], -1);
    if (reported >= 0) return reported;

    // Try to parse from responses map
    final responses = form['responses'];
    if (responses is Map) {
      for (final key in responses.keys) {
        final k = key.toString().toLowerCase();
        if (k.contains('duration') ||
            k.contains('hours') ||
            k.contains('time')) {
          final val = _toDouble(responses[key], -1);
          if (val >= 0) return val;
        }
      }
    }
    return 0.0;
  }

  /// Main aggregation function.
  /// [shift] is the teaching_shifts document data.
  /// [timesheets] are all timesheet_entries documents for this shift.
  /// [forms] are all form_responses documents for this shift.
  static ShiftSessionResult computeSession(
    Map<String, dynamic> shift,
    List<Map<String, dynamic>> timesheets,
    List<Map<String, dynamic>> forms,
  ) {
    final scheduledHours = getScheduledHours(shift);
    final shiftRate = _toDouble(shift['hourly_rate'], 0.0);

    final shiftStart = _toDate(shift['shift_start'] ?? shift['start']);
    final shiftEnd = _toDate(shift['shift_end'] ?? shift['end']);

    // 1. Filter out rejected timesheets and those without full clock pairs
    final validTimesheets = <Map<String, dynamic>>[];
    for (final ts in timesheets) {
      if (_isRejected(ts)) continue;

      final ci = _toDate(ts['clock_in_time'] ?? ts['clock_in_timestamp']);
      final co = _toDate(ts['clock_out_time'] ?? ts['clock_out_timestamp']);

      if (ci != null && co != null && co.isAfter(ci)) {
        validTimesheets.add(ts);
      }
    }

    // If no valid timesheets, check for form-only path
    if (validTimesheets.isEmpty) {
      final eligibleForms = forms
          .where(MakeupClassAttestation.formEligibleForFormOnlyMakeupEconomics)
          .toList();
      final shiftClaimsForm = shift['form_completed'] == true ||
          (shift['form_response_id'] != null &&
              shift['form_response_id'].toString().isNotEmpty);

      if (eligibleForms.isEmpty && forms.isNotEmpty) {
        return ShiftSessionResult(
          workedHours: 0.0,
          realPay: 0.0,
          payPaid: 0.0,
          payApproved: 0.0,
          payPending: 0.0,
          hasPunchedTimesheets: false,
          hasForm: true,
        );
      }

      final formDone =
          eligibleForms.isNotEmpty || (shiftClaimsForm && forms.isEmpty);

      if (formDone) {
        double formHours = 0.0;
        if (eligibleForms.isNotEmpty) {
          eligibleForms.sort((a, b) {
            final ta = _toDate(a['submittedAt'] ?? a['created_at']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final tb = _toDate(b['submittedAt'] ?? b['created_at']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return tb.compareTo(ta);
          });
          formHours = _parseFormDuration(eligibleForms.first);
        } else {
          formHours = _toDouble(shift['reported_hours'], -1);
          if (formHours < 0) formHours = _toDouble(shift['reportedHours'], 0);
        }

        if (formHours <= 0) formHours = scheduledHours;

        final cappedHours = math.min(formHours, scheduledHours);
        final pay = cappedHours * shiftRate;

        return ShiftSessionResult(
          workedHours: cappedHours,
          realPay: pay,
          payPaid: 0.0,
          payApproved: 0.0,
          payPending: pay,
          hasPunchedTimesheets: false,
          hasForm: forms.isNotEmpty || shiftClaimsForm,
        );
      }

      return ShiftSessionResult.empty;
    }

    // 2. Group by **strict** time overlap only: duplicate writes covering the same minutes merge;
    // adjacent clock-out / clock-in pairs stay in separate groups and their minutes **add**.
    // Sort by clock_in ascending
    validTimesheets.sort((a, b) {
      final ciA = _toDate(a['clock_in_time'] ?? a['clock_in_timestamp'])!;
      final ciB = _toDate(b['clock_in_time'] ?? b['clock_in_timestamp'])!;
      return ciA.compareTo(ciB);
    });

    final groups = <List<Map<String, dynamic>>>[];
    for (final ts in validTimesheets) {
      final ci = _toDate(ts['clock_in_time'] ?? ts['clock_in_timestamp'])!;
      final co = _toDate(ts['clock_out_time'] ?? ts['clock_out_timestamp'])!;

      bool addedToGroup = false;
      for (final group in groups) {
        // Check overlap with any member of the group
        bool overlaps = false;
        for (final member in group) {
          final mCi =
              _toDate(member['clock_in_time'] ?? member['clock_in_timestamp'])!;
          final mCo = _toDate(
              member['clock_out_time'] ?? member['clock_out_timestamp'])!;
          if (_clockIntervalsOverlap(ci, co, mCi, mCo)) {
            overlaps = true;
            break;
          }
        }

        if (overlaps) {
          group.add(ts);
          addedToGroup = true;
          break;
        }
      }

      if (!addedToGroup) {
        groups.add([ts]);
      }
    }

    // 3. Resolve each group to a single survivor and sum them up
    double totalWorkedHours = 0.0;
    double totalPay = 0.0;
    double payPaid = 0.0;
    double payApproved = 0.0;
    double payPending = 0.0;

    for (final group in groups) {
      Map<String, dynamic>? survivor;
      double survivorWorked = 0.0;

      for (final ts in group) {
        final ci = _toDate(ts['clock_in_time'] ?? ts['clock_in_timestamp'])!;
        final co = _toDate(ts['clock_out_time'] ?? ts['clock_out_timestamp'])!;

        // Clip to shift window
        var effectiveStart = ci;
        var effectiveEnd = co;

        if (shiftStart != null && effectiveStart.isBefore(shiftStart)) {
          effectiveStart = shiftStart;
        }
        if (shiftEnd != null && effectiveEnd.isAfter(shiftEnd)) {
          effectiveEnd = shiftEnd;
        }

        double worked = 0.0;
        if (effectiveEnd.isAfter(effectiveStart)) {
          worked = effectiveEnd.difference(effectiveStart).inSeconds / 3600.0;
        }

        if (survivor == null) {
          survivor = ts;
          survivorWorked = worked;
        } else {
          // Survivor selection rule: longest worked -> highest stored pay -> newest activity
          if (worked > survivorWorked + 0.01) {
            // Add epsilon for float comparison
            survivor = ts;
            survivorWorked = worked;
          } else if ((worked - survivorWorked).abs() <= 0.01) {
            final payA = _getStoredPay(ts);
            final payB = _getStoredPay(survivor);
            if (payA > payB) {
              survivor = ts;
              survivorWorked = worked;
            } else if (payA == payB) {
              // Fallback to newest activity
              final actA = _toDate(ts['updated_at'] ?? ts['created_at']) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final actB =
                  _toDate(survivor['updated_at'] ?? survivor['created_at']) ??
                      DateTime.fromMillisecondsSinceEpoch(0);
              if (actA.isAfter(actB)) {
                survivor = ts;
                survivorWorked = worked;
              }
            }
          }
        }
      }

      if (survivor != null) {
        totalWorkedHours += survivorWorked;

        // Calculate pay for this segment
        double rate = _toDouble(survivor['hourly_rate'], 0.0);
        if (rate <= 0) rate = _toDouble(survivor['hourlyRate'], 0.0);
        if (rate <= 0) rate = shiftRate;

        final paymentAmount = _toDouble(survivor['payment_amount'], 0.0);
        final tPay = _toDouble(survivor['total_pay'], 0.0);

        double segmentPay = 0.0;
        if (paymentAmount > 0) {
          segmentPay = paymentAmount;
        } else if (tPay > 0) {
          segmentPay = tPay;
        } else {
          segmentPay = survivorWorked * rate;
        }

        totalPay += segmentPay;

        final status = survivor['status'] as String? ?? 'pending';
        if (status == 'paid') {
          payPaid += segmentPay;
        } else if (status == 'approved') {
          payApproved += segmentPay;
        } else {
          payPending += segmentPay;
        }
      }
    }

    // 4. Cap at scheduled
    if (totalWorkedHours > scheduledHours && scheduledHours > 0) {
      totalWorkedHours = scheduledHours;
    }

    final maxPay = scheduledHours * shiftRate;
    if (totalPay > maxPay && maxPay > 0) {
      // Scale down the buckets proportionally if we hit the cap
      final ratio = maxPay / totalPay;
      payPaid *= ratio;
      payApproved *= ratio;
      payPending *= ratio;
      totalPay = maxPay;
    }

    return ShiftSessionResult(
      workedHours: totalWorkedHours,
      realPay: totalPay,
      payPaid: payPaid,
      payApproved: payApproved,
      payPending: payPending,
      hasPunchedTimesheets: true,
      hasForm: forms.isNotEmpty || shift['form_completed'] == true,
    );
  }

  static double _getStoredPay(Map<String, dynamic> ts) {
    final paymentAmount = _toDouble(ts['payment_amount'], 0.0);
    if (paymentAmount > 0) return paymentAmount;
    return _toDouble(ts['total_pay'], 0.0);
  }

  /// Standardized minute rounding for display: ceil(workedHours * 60).
  /// Internally [ShiftSessionResult.workedHours] keeps seconds precision; only
  /// round at the display / persistence boundary.
  static int workedMinutesCeil(ShiftSessionResult result) {
    final secs = (result.workedHours * 3600).round();
    if (secs <= 0) return 0;
    return ((secs + 59) ~/ 60);
  }

  static int workedMinutesCeilFromHours(double workedHours) {
    final secs = (workedHours * 3600).round();
    if (secs <= 0) return 0;
    return ((secs + 59) ~/ 60);
  }
}
