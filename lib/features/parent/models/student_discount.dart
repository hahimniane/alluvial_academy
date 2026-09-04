/// The discount a student or a household carries, and what it takes off an
/// invoice.
///
/// This mirrors `functions/utils/student_discounts.js`, which is what actually
/// computes the discount when the invoice is created. The two must agree: this
/// side only shows the admin what the invoice will say, so a difference here
/// is a screen that lies about the total. Money is computed in whole cents on
/// both sides, and windows are compared by month, never by day of month.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

enum DiscountMode { percent, fixed }

enum DiscountDuration { months, ongoing }

/// Who the discount is for. `student` takes the amount off that child's own
/// charges, so two siblings on $10 off come to $20. `family` takes it off the
/// invoice once, however many children are on it.
enum DiscountScope { student, family }

class StudentDiscount {
  const StudentDiscount({
    required this.mode,
    required this.value,
    required this.scope,
    required this.duration,
    required this.startDate,
    this.months,
    this.reason = '',
  });

  final DiscountMode mode;
  final double value;
  final DiscountScope scope;
  final DiscountDuration duration;

  /// Set when [duration] is [DiscountDuration.months].
  final int? months;
  final DateTime startDate;
  final String reason;

  /// Parse a stored discount, or null when the record is not one.
  static StudentDiscount? read(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);

    final modeText = (data['mode'] ?? '').toString();
    if (modeText != 'percent' && modeText != 'fixed') return null;

    final value = _toDouble(data['value']);
    if (value == null || value <= 0) return null;
    if (modeText == 'percent' && value > 100) return null;

    final startDate = _toDate(data['startDate']);
    if (startDate == null) return null;

    final duration = (data['duration'] ?? '').toString() == 'ongoing'
        ? DiscountDuration.ongoing
        : DiscountDuration.months;
    final months = _toDouble(data['months'])?.round();
    if (duration == DiscountDuration.months && (months == null || months <= 0)) {
      return null;
    }

    return StudentDiscount(
      mode: modeText == 'percent' ? DiscountMode.percent : DiscountMode.fixed,
      value: value,
      // Absent on discounts saved before family scope existed; those are
      // per-student, which is what they have always done.
      scope: (data['scope'] ?? '').toString() == 'family'
          ? DiscountScope.family
          : DiscountScope.student,
      duration: duration,
      months: duration == DiscountDuration.months ? months : null,
      startDate: startDate,
      reason: (data['reason'] ?? '').toString(),
    );
  }

  /// Whether a billing period falls inside the window.
  ///
  /// The start month counts as month 1 whatever day of it the discount begins,
  /// so one starting the 15th still applies to that month's invoice. Periods
  /// before the start month never do.
  bool coversPeriod(DateTime periodStart) {
    final from = startDate.toUtc();
    final to = periodStart.toUtc();
    final elapsed = (to.year - from.year) * 12 + (to.month - from.month);
    if (elapsed < 0) return false;
    if (duration == DiscountDuration.ongoing) return true;
    return elapsed < (months ?? 0);
  }

  /// What comes off a total, never more than the total itself.
  double amountFor(double total) {
    if (total.isNaN || total <= 0) return 0;
    final totalCents = (total * 100).round();
    final rawCents = mode == DiscountMode.percent
        ? (totalCents * value / 100).round()
        : (value * 100).round();
    return rawCents.clamp(0, totalCents) / 100;
  }

  String get label {
    final amount = mode == DiscountMode.percent
        ? '${_trimZeros(value)}% off'
        : '\$${_trimZeros(value)} off';
    if (duration == DiscountDuration.ongoing) return '$amount · ongoing';
    final count = months ?? 0;
    return '$amount · first $count ${count == 1 ? 'month' : 'months'}';
  }

  static String _trimZeros(double value) {
    final text = value.toStringAsFixed(2);
    return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// One line of the discount summary shown while an invoice is being written.
class DiscountPreviewLine {
  const DiscountPreviewLine({required this.label, required this.amount});

  final String label;

  /// Negative: what the line takes off.
  final double amount;
}

class InvoicePreview {
  const InvoicePreview({
    required this.subtotal,
    required this.lines,
    required this.total,
  });

  final double subtotal;
  final List<DiscountPreviewLine> lines;
  final double total;
}

/// What the invoice will come to once the backend applies the same discounts.
///
/// Per-student lines first, then the household line against what is left — so a
/// percentage reads as a percentage of what the family would otherwise owe, and
/// the two together can never take an invoice below zero.
InvoicePreview previewInvoice({
  required List<({String name, double amount, StudentDiscount? discount})> charges,
  required StudentDiscount? familyDiscount,
  required DateTime periodStart,
}) {
  final subtotal = charges.fold<double>(0, (running, charge) => running + charge.amount);
  final lines = <DiscountPreviewLine>[];

  for (final charge in charges) {
    final discount = charge.discount;
    if (discount == null || discount.scope == DiscountScope.family) continue;
    if (!discount.coversPeriod(periodStart)) continue;
    final off = discount.amountFor(charge.amount);
    if (off <= 0) continue;
    lines.add(DiscountPreviewLine(
      label: '${charge.name} — ${discount.label}',
      amount: -off,
    ));
  }

  final afterStudents =
      subtotal + lines.fold<double>(0, (running, line) => running + line.amount);
  if (familyDiscount != null && familyDiscount.coversPeriod(periodStart)) {
    final off = familyDiscount.amountFor(afterStudents);
    if (off > 0) {
      lines.add(DiscountPreviewLine(
        label: 'Whole family — ${familyDiscount.label}',
        amount: -off,
      ));
    }
  }

  final total = subtotal + lines.fold<double>(0, (running, line) => running + line.amount);
  return InvoicePreview(subtotal: subtotal, lines: lines, total: total);
}
