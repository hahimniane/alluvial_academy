import 'package:cloud_firestore/cloud_firestore.dart';

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
      shiftIds: List<String>.from(data['shift_ids'] ?? data['shiftIds'] ?? const []),
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.createdAt,
    this.updatedAt,
  });

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return Invoice.fromMap(data, id: doc.id);
  }

  factory Invoice.fromMap(Map<String, dynamic> data, {String? id}) {
    return Invoice(
      id: id ?? (data['id'] ?? '').toString(),
      invoiceNumber: (data['invoice_number'] ?? data['invoiceNumber'] ?? '').toString(),
      parentId: (data['parent_id'] ?? data['parentId'] ?? '').toString(),
      studentId: (data['student_id'] ?? data['studentId'] ?? '').toString(),
      status: _parseStatus(data['status']),
      totalAmount: _toDouble(data['total_amount'] ?? data['totalAmount']) ?? 0.0,
      paidAmount: _toDouble(data['paid_amount'] ?? data['paidAmount']) ?? 0.0,
      currency: (data['currency'] ?? 'USD').toString(),
      issuedDate: _parseDateTime(data['issued_date'] ?? data['issuedDate']) ?? DateTime.now(),
      dueDate: _parseDateTime(data['due_date'] ?? data['dueDate']) ??
          DateTime.now().add(const Duration(days: 30)),
      items: ((data['items'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((e) => InvoiceItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      shiftIds: List<String>.from(data['shift_ids'] ?? data['shiftIds'] ?? const []),
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
      updatedAt: _parseDateTime(data['updated_at'] ?? data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
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
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  bool get isFullyPaid => paidAmount >= totalAmount && totalAmount > 0;

  double get remainingBalance {
    final remaining = totalAmount - paidAmount;
    if (remaining < 0) return 0;
    return remaining;
  }

  bool get isOverdue =>
      !isFullyPaid && DateTime.now().isAfter(dueDate) && status != InvoiceStatus.cancelled;

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
}

