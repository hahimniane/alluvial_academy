import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';

class EligibilityResult {
  final bool isEligible;
  final List<String> failedReasons;
  final double? estimatedMonthlyIncome;

  const EligibilityResult({
    required this.isEligible,
    this.failedReasons = const [],
    this.estimatedMonthlyIncome,
  });
}

class EligibilityService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<EligibilityResult> checkEligibility({
    required String userId,
    required EligibilityRules rules,
    required double contributionAmount,
  }) async {
    final reasons = <String>[];

    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return const EligibilityResult(
        isEligible: false,
        failedReasons: ['User not found'],
      );
    }
    final userData = userDoc.data() ?? {};

    final hourlyRate = _toDouble(
            userData['wage_override'] ?? userData['hourly_rate']) ??
        0;

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    double avgWeeklyHours = 10;
    double? estimatedIncome;

    try {
      final shiftsQuery = await _firestore
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final shiftCount = shiftsQuery.docs.length;

      double totalHours = 0;
      for (final doc in shiftsQuery.docs) {
        final data = doc.data();
        final duration = _toDouble(data['duration_hours'] ?? data['durationHours']);
        if (duration != null) {
          totalHours += duration;
        } else {
          totalHours += 1;
        }
      }

      if (shiftCount > 0) {
        avgWeeklyHours = (totalHours / 30) * 7;
      }

      estimatedIncome = hourlyRate * avgWeeklyHours * 4;

      if (rules.incomeMultiplier > 0 && contributionAmount > 0) {
        final requiredIncome = contributionAmount * rules.incomeMultiplier;
        if (estimatedIncome < requiredIncome) {
          reasons.add(
            'Estimated monthly income (\$${estimatedIncome.toStringAsFixed(0)}) '
            'is below the required ${(rules.incomeMultiplier * 100).toStringAsFixed(0)}% '
            'of the contribution (\$${requiredIncome.toStringAsFixed(0)})',
          );
        }
      }

      if (rules.minShiftsLast30Days > 0) {
        if (shiftCount < rules.minShiftsLast30Days) {
          reasons.add(
            'Taught $shiftCount shifts in the last 30 days '
            '(minimum ${rules.minShiftsLast30Days} required)',
          );
        }
      }
    } catch (_) {
      // If shift query fails, skip activity-based checks
    }

    if (rules.minTenureMonths > 0) {
      final startDate = _parseDateTime(
        userData['employment_start_date'] ?? userData['date_added'],
      );
      if (startDate == null) {
        reasons.add(
          'Employment start date not set '
          '(minimum ${rules.minTenureMonths} months required)',
        );
      } else {
        final monthsEmployed =
            (now.difference(startDate).inDays / 30).floor();
        if (monthsEmployed < rules.minTenureMonths) {
          reasons.add(
            'Employed for $monthsEmployed months '
            '(minimum ${rules.minTenureMonths} required)',
          );
        }
      }
    }

    return EligibilityResult(
      isEligible: reasons.isEmpty,
      failedReasons: reasons,
      estimatedMonthlyIncome: estimatedIncome,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
