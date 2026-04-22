import '../constants/pricing_plan_ids.dart';

/// Estimates weekly / monthly cost from plan + schedule (informational only).
/// Defaults match the landing page; [numericPlanOverrides] comes from
/// [PublicSiteCmsService] when admins override rates in Firestore.
///
/// **Tutoring** (all tutoring plan ids): hourly rate by **total weekly hours** —
/// under 4 hrs/wk → higher rate (default \$11.99/hr), 4+ hrs/wk → lower (default \$9.99/hr).
/// Monthly est. = `floor(weeklyUsd × 4)` (4-week rule, dollars truncated).
///
/// **Islamic 1-on-1** (`islamic_1_4`): under 5 hrs/wk → \$8.50/hr, 5+ → \$6.99/hr; same monthly rule.
///
/// **Islamic weekend group**: CMS [hourlyUsd], standard `× 4.33` month (no floor).
abstract final class PricingQuoteService {
  /// V2 snapshot builder for track-based pricing.
  static Map<String, dynamic>? buildSnapshotV2({
    required String? trackId,
    required int? hoursPerWeek,
    Map<String, Map<String, dynamic>>? cmsOverrides,
  }) {
    if (trackId == null || hoursPerWeek == null || hoursPerWeek <= 0) {
      return null;
    }
    final override = cmsOverrides?[trackId];
    final int volumeThreshold = switch (trackId) {
      PricingPlanIds.islamic =>
        _intOverride(override, 'islamicDiscountThreshold', 4),
      PricingPlanIds.tutoring =>
        _intOverride(override, 'tutoringDiscountThreshold', 4),
      _ => 4,
    };
    final bool discountApplied = trackId != PricingPlanIds.group &&
        hoursPerWeek > volumeThreshold;
    final double hourlyRateUsd;
    final double monthlyEstimateUsd;
    double baseHourlyRateUsd;

    switch (trackId) {
      case PricingPlanIds.islamic:
        final base = _num(override, 'islamicBaseUsd') ??
            _num(override, 'islamicHrUnder5Usd') ??
            8.50;
        final discount = _num(override, 'islamicDiscountUsd') ??
            _num(override, 'islamicHr5PlusUsd') ??
            6.99;
        baseHourlyRateUsd = base;
        hourlyRateUsd = discountApplied ? discount : base;
        monthlyEstimateUsd = (hoursPerWeek * hourlyRateUsd * 4).roundToDouble();
        break;
      case PricingPlanIds.tutoring:
        final base = _num(override, 'tutoringBaseUsd') ??
            _num(override, 'tutoringHrUnder4Usd') ??
            11.99;
        final discount = _num(override, 'tutoringDiscountUsd') ??
            _num(override, 'tutoringHr4PlusUsd') ??
            9.99;
        baseHourlyRateUsd = base;
        hourlyRateUsd = discountApplied ? discount : base;
        monthlyEstimateUsd = (hoursPerWeek * hourlyRateUsd * 4).roundToDouble();
        break;
      case PricingPlanIds.group:
        hourlyRateUsd = _num(override, 'groupHourlyUsd') ??
            _num(override, 'hourlyUsd') ??
            2.50;
        baseHourlyRateUsd = hourlyRateUsd;
        monthlyEstimateUsd = hoursPerWeek * hourlyRateUsd * 4.33;
        break;
      default:
        return null;
    }

    return {
      'version': 2,
      'trackId': trackId,
      'hoursPerWeek': hoursPerWeek,
      'hourlyRateUsd': double.parse(hourlyRateUsd.toStringAsFixed(2)),
      'baseHourlyRateUsd': double.parse(baseHourlyRateUsd.toStringAsFixed(2)),
      'discountApplied': discountApplied,
      'monthlyEstimateUsd': trackId == PricingPlanIds.group
          ? double.parse(monthlyEstimateUsd.toStringAsFixed(2))
          : monthlyEstimateUsd,
    };
  }

  static String tierCaptionV2({
    required String trackId,
    Map<String, dynamic>? cmsOverrides,
  }) {
    switch (trackId) {
      case PricingPlanIds.islamic:
        final base = _num(cmsOverrides, 'islamicBaseUsd') ??
            _num(cmsOverrides, 'islamicHrUnder5Usd') ??
            8.50;
        final discount = _num(cmsOverrides, 'islamicDiscountUsd') ??
            _num(cmsOverrides, 'islamicHr5PlusUsd') ??
            6.99;
        final th = _intOverride(cmsOverrides, 'islamicDiscountThreshold', 4);
        return '\$${base.toStringAsFixed(2)}/hr standard · \$${discount.toStringAsFixed(2)}/hr for over $th hrs/wk';
      case PricingPlanIds.tutoring:
        final base = _num(cmsOverrides, 'tutoringBaseUsd') ??
            _num(cmsOverrides, 'tutoringHrUnder4Usd') ??
            11.99;
        final discount = _num(cmsOverrides, 'tutoringDiscountUsd') ??
            _num(cmsOverrides, 'tutoringHr4PlusUsd') ??
            9.99;
        final th = _intOverride(cmsOverrides, 'tutoringDiscountThreshold', 4);
        return '\$${base.toStringAsFixed(2)}/hr standard · \$${discount.toStringAsFixed(2)}/hr for over $th hrs/wk';
      case PricingPlanIds.group:
        final hourly =
            _num(cmsOverrides, 'groupHourlyUsd') ?? _num(cmsOverrides, 'hourlyUsd') ?? 2.50;
        return '\$${hourly.toStringAsFixed(2)}/hr flat';
      default:
        return '';
    }
  }

  /// Builds a Firestore-friendly snapshot for [metadata.pricingSnapshot].
  @Deprecated('Use buildSnapshotV2 for track-based pricing.')
  static Map<String, dynamic>? buildSnapshot({
    required String? planId,
    required List<String> preferredDays,
    required String? sessionDuration,
    Map<String, Map<String, dynamic>>? numericPlanOverrides,
  }) {
    if (planId == null || preferredDays.isEmpty || sessionDuration == null) {
      return null;
    }
    final minutes = _sessionMinutes(sessionDuration);
    if (minutes == null) return null;

    final sessionsPerWeek = preferredDays.length;
    final weeklyHours = sessionsPerWeek * (minutes / 60.0);

    final rate = _rateForPlan(
      planId: planId,
      sessionMinutes: minutes,
      weeklyHours: weeklyHours,
      numericOverride: _effectivePlanOverride(planId, numericPlanOverrides),
    );
    if (rate == null) return null;

    final weeklyUsd = rate.isPerHour
        ? weeklyHours * rate.amountUsd
        : sessionsPerWeek * rate.perSessionUsd(minutes);

    final double monthlyEstimateUsd;
    if (rate.monthlyFourWeekFloor) {
      monthlyEstimateUsd = (weeklyUsd * 4).floorToDouble();
    } else {
      const weeksPerMonth = 4.33;
      monthlyEstimateUsd = weeklyUsd * weeksPerMonth;
    }

    return {
      'planId': planId,
      'sessionsPerWeek': sessionsPerWeek,
      'sessionMinutes': minutes,
      'weeklyHours': double.parse(weeklyHours.toStringAsFixed(2)),
      'unitLabel': rate.unitLabelFor(minutes),
      'unitUsd': rate.isPerHour
          ? rate.amountUsd
          : rate.perSessionUsd(minutes),
      'weeklyUsd': double.parse(weeklyUsd.toStringAsFixed(2)),
      'monthlyEstimateUsd': double.parse(monthlyEstimateUsd.toStringAsFixed(2)),
      'summary': rate.summaryLine(
        sessionsPerWeek: sessionsPerWeek,
        sessionMinutes: minutes,
        weeklyHours: weeklyHours,
        weeklyUsd: weeklyUsd,
        monthlyUsd: monthlyEstimateUsd,
      ),
    };
  }

  static int? _sessionMinutes(String duration) {
    if (duration.contains('1 hr 30')) return 90;
    if (duration.contains('2 hr 30')) return 150;
    if (duration.contains('30 mins')) return 30;
    if (duration.contains('1 hr')) return 60;
    if (duration.contains('2 hrs')) return 120;
    if (duration.contains('3 hrs')) return 180;
    if (duration.contains('4 hrs')) return 240;
    return null;
  }

  static double? _num(Map<String, dynamic>? o, String key) {
    if (o == null) return null;
    final v = o[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  /// CMS volume discount: discounted rate applies when [hoursPerWeek] > this value.
  static int _intOverride(Map<String, dynamic>? o, String key, int fallback) {
    if (o == null) return fallback;
    final v = o[key];
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  /// Merges tutoring volume keys from any tutoring plan row (admin can set once).
  static Map<String, dynamic> _mergedTutoringVolumeOverrides(
    Map<String, Map<String, dynamic>>? all,
  ) {
    final out = <String, dynamic>{};
    if (all == null) return out;
    const keys = ['tutoringHrUnder4Usd', 'tutoringHr4PlusUsd'];
    for (final id in [
      PricingPlanIds.tutoring5Plus,
      PricingPlanIds.tutoring13,
      PricingPlanIds.tutoring4Plus,
    ]) {
      final m = all[id];
      if (m == null) continue;
      for (final k in keys) {
        final v = m[k];
        if (v != null) out[k] = v;
      }
    }
    return out;
  }

  static Map<String, dynamic>? _effectivePlanOverride(
    String planId,
    Map<String, Map<String, dynamic>>? all,
  ) {
    final own = all?[planId];
    if (_isTutoringPlan(planId)) {
      final merged = _mergedTutoringVolumeOverrides(all);
      if (own == null && merged.isEmpty) return null;
      return {...merged, ...?own};
    }
    if (own == null) return null;
    return Map<String, dynamic>.from(own);
  }

  static bool _isTutoringPlan(String planId) {
    return planId == PricingPlanIds.tutoring5Plus ||
        planId == PricingPlanIds.tutoring13 ||
        planId == PricingPlanIds.tutoring4Plus;
  }

  static _RateLine? _rateForPlan({
    required String planId,
    required int sessionMinutes,
    required double weeklyHours,
    Map<String, dynamic>? numericOverride,
  }) {
    switch (planId) {
      case PricingPlanIds.islamic14:
        final high = _num(numericOverride, 'islamicHrUnder5Usd') ?? 8.50;
        final low = _num(numericOverride, 'islamicHr5PlusUsd') ?? 6.99;
        final hourly = weeklyHours >= 5.0 ? low : high;
        return _RateLine(
          amountUsd: hourly,
          isPerHour: true,
          monthlyFourWeekFloor: true,
          perSessionUsd: (m) => hourly * (m / 60.0),
          unitLabelFor: (_) =>
              'per hr (${weeklyHours >= 5.0 ? '5+ hrs/wk' : 'under 5 hrs/wk'} band)',
        );
      case PricingPlanIds.islamicWeekend:
        final h = _num(numericOverride, 'hourlyUsd') ?? 2.50;
        return _RateLine(
          amountUsd: h,
          isPerHour: true,
          monthlyFourWeekFloor: false,
          perSessionUsd: (m) => h * (m / 60.0),
          unitLabelFor: (_) => 'per hour (weekend group)',
        );
      case PricingPlanIds.tutoring5Plus:
      case PricingPlanIds.tutoring13:
      case PricingPlanIds.tutoring4Plus:
        final high = _num(numericOverride, 'tutoringHrUnder4Usd') ?? 11.99;
        final low = _num(numericOverride, 'tutoringHr4PlusUsd') ?? 9.99;
        final hourly = weeklyHours >= 4.0 ? low : high;
        return _RateLine(
          amountUsd: hourly,
          isPerHour: true,
          monthlyFourWeekFloor: true,
          perSessionUsd: (m) => hourly * (m / 60.0),
          unitLabelFor: (_) =>
              'per hr (${weeklyHours >= 4.0 ? '4+ hrs/wk' : 'under 4 hrs/wk'} band)',
        );
      default:
        return null;
    }
  }

  /// Volume-band captions (no weekly hours — shows both brackets).
  @Deprecated('Use tierCaptionV2 for track-based pricing.')
  static String enrollmentTierPriceCaption({
    required String planId,
    Map<String, dynamic>? numericOverride,
  }) {
    switch (planId) {
      case PricingPlanIds.islamic14:
        final high = _num(numericOverride, 'islamicHrUnder5Usd') ?? 8.50;
        final low = _num(numericOverride, 'islamicHr5PlusUsd') ?? 6.99;
        return '\$${high.toStringAsFixed(2)}/hr under 5 hrs/wk · \$${low.toStringAsFixed(2)}/hr at 5+ hrs/wk';
      case PricingPlanIds.islamicWeekend:
        final h = _num(numericOverride, 'hourlyUsd') ?? 2.50;
        return '\$${h.toStringAsFixed(2)} / hr · 2 hr group days';
      case PricingPlanIds.tutoring5Plus:
      case PricingPlanIds.tutoring13:
      case PricingPlanIds.tutoring4Plus:
        final hi = _num(numericOverride, 'tutoringHrUnder4Usd') ?? 11.99;
        final lo = _num(numericOverride, 'tutoringHr4PlusUsd') ?? 9.99;
        return '\$${hi.toStringAsFixed(2)}/hr under 4 hrs/wk · \$${lo.toStringAsFixed(2)}/hr at 4+ hrs/wk';
      default:
        return '';
    }
  }

  /// Merge tutoring volume keys for enrollment tiles when [planId] is a tutoring tier.
  @Deprecated('Use tierCaptionV2/cmsOverrides with track IDs.')
  static Map<String, dynamic>? mergedCaptionOverride(
    String planId,
    Map<String, Map<String, dynamic>>? all,
  ) {
    if (!_isTutoringPlan(planId)) return all?[planId];
    final merged = _mergedTutoringVolumeOverrides(all);
    final own = all?[planId];
    if (own == null && merged.isEmpty) return null;
    return {...merged, ...?own};
  }
}

class _RateLine {
  final double amountUsd;
  final bool isPerHour;
  final bool monthlyFourWeekFloor;
  final double Function(int sessionMinutes) perSessionUsd;
  final String Function(int sessionMinutes) unitLabelFor;

  const _RateLine({
    required this.amountUsd,
    required this.isPerHour,
    required this.monthlyFourWeekFloor,
    required this.perSessionUsd,
    required this.unitLabelFor,
  });

  String summaryLine({
    required int sessionsPerWeek,
    required int sessionMinutes,
    required double weeklyHours,
    required double weeklyUsd,
    required double monthlyUsd,
  }) {
    final w = weeklyUsd.toStringAsFixed(2);
    if (monthlyFourWeekFloor) {
      final mInt = monthlyUsd.round();
      return '≈ \$$w/wk (~\$$mInt/mo, 4 wk × weekly, truncated) at \$${amountUsd.toStringAsFixed(2)}/hr × ${weeklyHours.toStringAsFixed(2)} hrs/wk';
    }
    final m = monthlyUsd.toStringAsFixed(2);
    final hrs = sessionsPerWeek * sessionMinutes / 60.0;
    return '≈ \$$w/wk (~\$$m/mo) at \$${amountUsd.toStringAsFixed(2)}/hr × ${hrs.toStringAsFixed(2)} hrs/wk';
  }
}
