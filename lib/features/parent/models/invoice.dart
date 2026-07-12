import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum InvoiceStatus {
  pending,
  paid,
  overdue,
  cancelled,
}

class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;
  final List<String> shiftIds;

  const InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.shiftIds = const [],
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> data) {
    return InvoiceItem(
      description: (data['description'] ?? '').toString(),
      quantity: _toInt(data['quantity']) ?? 1,
      unitPrice: _toDouble(data['unit_price'] ?? data['unitPrice']) ?? 0.0,
      total: _toDouble(data['total']) ?? 0.0,
      shiftIds:
          List<String>.from(data['shift_ids'] ?? data['shiftIds'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
      if (shiftIds.isNotEmpty) 'shift_ids': shiftIds,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String parentId;
  final String studentId;
  final InvoiceStatus status;
  final double totalAmount;
  final double paidAmount;
  final String currency;
  final DateTime issuedDate;
  final DateTime dueDate;
  final List<InvoiceItem> items;
  final List<String> shiftIds;

  /// Billing period label, usually `yyyy-MM` (e.g. from admin create flow).
  final String? period;
  final String? periodStart;
  final String? periodEnd;
  final int billingMonths;
  final String? notificationStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Date at which access is suspended if the invoice is still unpaid.
  /// Null means no cutoff is set (access is never suspended for this invoice).
  final DateTime? accessCutoffDate;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.parentId,
    required this.studentId,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.currency,
    required this.issuedDate,
    required this.dueDate,
    required this.items,
    required this.shiftIds,
    this.period,
    this.periodStart,
    this.periodEnd,
    this.billingMonths = 1,
    this.notificationStatus,
    this.createdAt,
    this.updatedAt,
    this.accessCutoffDate,
  });

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return Invoice.fromMap(data, id: doc.id);
  }

  factory Invoice.fromMap(Map<String, dynamic> data, {String? id}) {
    final periodRaw =
        (data['period'] ?? data['billing_period'] ?? data['billingPeriod'])
                ?.toString()
                .trim() ??
            '';
    return Invoice(
      id: id ?? (data['id'] ?? '').toString(),
      invoiceNumber:
          (data['invoice_number'] ?? data['invoiceNumber'] ?? '').toString(),
      parentId: (data['parent_id'] ?? data['parentId'] ?? '').toString(),
      studentId: (data['student_id'] ?? data['studentId'] ?? '').toString(),
      status: _parseStatus(data['status']),
      totalAmount:
          _toDouble(data['total_amount'] ?? data['totalAmount']) ?? 0.0,
      paidAmount: _toDouble(data['paid_amount'] ?? data['paidAmount']) ?? 0.0,
      currency: (data['currency'] ?? 'USD').toString(),
      issuedDate: _parseDateTime(data['issued_date'] ?? data['issuedDate']) ??
          DateTime.now(),
      dueDate: _parseDateTime(data['due_date'] ?? data['dueDate']) ??
          DateTime.now().add(const Duration(days: 30)),
      items: ((data['items'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((e) => InvoiceItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      shiftIds:
          List<String>.from(data['shift_ids'] ?? data['shiftIds'] ?? const []),
      period: periodRaw.isEmpty ? null : periodRaw,
      periodStart: (data['period_start'] ?? data['periodStart'])?.toString(),
      periodEnd: (data['period_end'] ?? data['periodEnd'])?.toString(),
      billingMonths:
          _toInt(data['billing_months'] ?? data['billingMonths']) ?? 1,
      notificationStatus:
          (data['notification_status'] ?? data['notificationStatus'])
              ?.toString(),
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
      updatedAt: _parseDateTime(data['updated_at'] ?? data['updatedAt']),
      accessCutoffDate: _parseDateTime(
          data['access_cutoff_date'] ?? data['accessCutoffDate']),
    );
  }

  Map<String, dynamic> toMap() {
    final periodOut = period;
    return {
      'invoice_number': invoiceNumber,
      'parent_id': parentId,
      'student_id': studentId,
      'status': status.name,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'currency': currency,
      'issued_date': Timestamp.fromDate(issuedDate),
      'due_date': Timestamp.fromDate(dueDate),
      'items': items.map((e) => e.toMap()).toList(),
      if (shiftIds.isNotEmpty) 'shift_ids': shiftIds,
      if (periodOut != null && periodOut.isNotEmpty) 'period': periodOut,
      if (periodStart != null && periodStart!.isNotEmpty)
        'period_start': periodStart,
      if (periodEnd != null && periodEnd!.isNotEmpty) 'period_end': periodEnd,
      'billing_months': billingMonths,
      if (notificationStatus != null && notificationStatus!.isNotEmpty)
        'notification_status': notificationStatus,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
      if (accessCutoffDate != null)
        'access_cutoff_date': Timestamp.fromDate(accessCutoffDate!),
    };
  }

  /// The effective cutoff date: stored value, or dueDate + 1 day if not set.
  DateTime get effectiveAccessCutoffDate =>
      accessCutoffDate ?? dueDate.add(const Duration(days: 1));

  bool get isFullyPaid => paidAmount >= totalAmount && totalAmount > 0;

  double get remainingBalance {
    final remaining = totalAmount - paidAmount;
    if (remaining < 0) return 0;
    return remaining;
  }

  bool get isOverdue =>
      !isFullyPaid &&
      DateTime.now().isAfter(dueDate) &&
      status != InvoiceStatus.cancelled;

  /// `period` is usually `yyyy-MM`. Returns a readable month, or the raw string, or null.
  String? get displayBillingPeriod {
    final storedStart = _formatPeriodLabel(periodStart, compact: true);
    final storedEnd = _formatPeriodLabel(periodEnd, compact: true);
    if (storedStart != null && storedEnd != null) {
      return storedStart == storedEnd
          ? storedStart
          : '$storedStart - $storedEnd';
    }

    final p = period;
    if (p == null || p.isEmpty) return null;
    if (p.contains('..')) {
      final parts = p.split('..');
      final start = _formatPeriodLabel(parts.isNotEmpty ? parts.first : null,
          compact: true);
      final end = _formatPeriodLabel(parts.length > 1 ? parts.last : null,
          compact: true);
      if (start != null && end != null) return '$start - $end';
    }
    return _formatPeriodLabel(p) ?? p;
  }

  static InvoiceStatus _parseStatus(dynamic value) {
    if (value is InvoiceStatus) return value;
    final raw = (value ?? '').toString().trim();
    return InvoiceStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => InvoiceStatus.pending,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String? _formatPeriodLabel(String? value, {bool compact = false}) {
    final raw = value?.trim() ?? '';
    final match = RegExp(r'(\d{4})-(\d{2})').firstMatch(raw);
    if (match == null) return null;
    final year = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    if (year == null || month == null || month < 1 || month > 12) return null;
    final date = DateTime(year, month);
    return compact
        ? DateFormat.yMMM().format(date)
        : DateFormat.yMMMM().format(date);
  }
}
