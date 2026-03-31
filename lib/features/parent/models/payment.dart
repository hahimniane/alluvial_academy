import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
}

class Payment {
  final String id;
  final String invoiceId;
  final String parentId;
  final double amount;
  final PaymentStatus status;
  final String paymentMethod;
  final String? payoneerSessionId;
  final String? payoneerTransactionId;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const Payment({
    required this.id,
    required this.invoiceId,
    required this.parentId,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    this.payoneerSessionId,
    this.payoneerTransactionId,
    this.createdAt,
    this.completedAt,
  });

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return Payment.fromMap(data, id: doc.id);
  }

  factory Payment.fromMap(Map<String, dynamic> data, {String? id}) {
    return Payment(
      id: id ?? (data['id'] ?? '').toString(),
      invoiceId: (data['invoice_id'] ?? data['invoiceId'] ?? '').toString(),
      parentId: (data['parent_id'] ?? data['parentId'] ?? '').toString(),
      amount: _toDouble(data['amount']) ?? 0.0,
      status: _parseStatus(data['status']),
      paymentMethod: (data['payment_method'] ?? data['paymentMethod'] ?? '').toString(),
      payoneerSessionId: (data['payoneer_session_id'] ?? data['payoneerSessionId'])?.toString(),
      payoneerTransactionId:
          (data['payoneer_transaction_id'] ?? data['payoneerTransactionId'])?.toString(),
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
      completedAt: _parseDateTime(data['completed_at'] ?? data['completedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoice_id': invoiceId,
      'parent_id': parentId,
      'amount': amount,
      'status': status.name,
      'payment_method': paymentMethod,
      if (payoneerSessionId != null) 'payoneer_session_id': payoneerSessionId,
      if (payoneerTransactionId != null) 'payoneer_transaction_id': payoneerTransactionId,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (completedAt != null) 'completed_at': Timestamp.fromDate(completedAt!),
    };
  }

  static PaymentStatus _parseStatus(dynamic value) {
    if (value is PaymentStatus) return value;
    final raw = (value ?? '').toString().trim();
    return PaymentStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => PaymentStatus.pending,
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

