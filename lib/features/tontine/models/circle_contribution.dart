import 'package:cloud_firestore/cloud_firestore.dart';

enum CircleContributionStatus {
  pending,
  submitted,
  confirmed,
  rejected,
  missed,
}

enum CircleContributionPaymentMethod {
  manual,
  payrollDeduction,
}

class CircleContribution {
  final String id;
  final String circleId;
  final String cycleId;
  final String userId;
  final String displayName;
  final double expectedAmount;
  final double? submittedAmount;
  final bool? amountIsCorrect;
  final CircleContributionStatus status;
  final CircleContributionPaymentMethod paymentMethod;
  final String? receiptImageUrl;
  final DateTime? submittedAt;
  final DateTime? paymentDate;
  final DateTime? confirmedAt;
  final String? confirmedBy;
  final String? rejectionReason;

  const CircleContribution({
    required this.id,
    required this.circleId,
    required this.cycleId,
    required this.userId,
    required this.displayName,
    required this.expectedAmount,
    required this.submittedAmount,
    required this.amountIsCorrect,
    required this.status,
    required this.paymentMethod,
    required this.receiptImageUrl,
    required this.submittedAt,
    required this.paymentDate,
    required this.confirmedAt,
    required this.confirmedBy,
    required this.rejectionReason,
  });

  factory CircleContribution.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return CircleContribution.fromMap(data, id: doc.id);
  }

  factory CircleContribution.fromMap(Map<String, dynamic> data, {String? id}) {
    return CircleContribution(
      id: id ?? _readString(data, ['id']),
      circleId: _readString(data, ['circle_id', 'circleId']),
      cycleId: _readString(data, ['cycle_id', 'cycleId']),
      userId: _readString(data, ['user_id', 'userId']),
      displayName: _readString(data, ['display_name', 'displayName']),
      expectedAmount:
          _toDouble(data['expected_amount'] ?? data['expectedAmount']) ?? 0,
      submittedAmount:
          _toDouble(data['submitted_amount'] ?? data['submittedAmount']),
      amountIsCorrect:
          _toNullableBool(data['amount_is_correct'] ?? data['amountIsCorrect']),
      status: _parseStatus(data['status']),
      paymentMethod:
          _parsePaymentMethod(data['payment_method'] ?? data['paymentMethod']),
      receiptImageUrl:
          _readNullableString(data, ['receipt_image_url', 'receiptImageUrl']),
      submittedAt: _parseDateTime(data['submitted_at'] ?? data['submittedAt']),
      paymentDate: _parseDateTime(data['payment_date'] ?? data['paymentDate']),
      confirmedAt: _parseDateTime(data['confirmed_at'] ?? data['confirmedAt']),
      confirmedBy: _readNullableString(data, ['confirmed_by', 'confirmedBy']),
      rejectionReason:
          _readNullableString(data, ['rejection_reason', 'rejectionReason']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'circle_id': circleId,
      'cycle_id': cycleId,
      'user_id': userId,
      'display_name': displayName,
      'expected_amount': expectedAmount,
      'submitted_amount': submittedAmount,
      'amount_is_correct': amountIsCorrect,
      'status': status.name,
      'payment_method': _paymentMethodValue(paymentMethod),
      'receipt_image_url': receiptImageUrl,
      if (submittedAt != null) 'submitted_at': Timestamp.fromDate(submittedAt!),
      if (paymentDate != null) 'payment_date': Timestamp.fromDate(paymentDate!),
      if (confirmedAt != null) 'confirmed_at': Timestamp.fromDate(confirmedAt!),
      'confirmed_by': confirmedBy,
      'rejection_reason': rejectionReason,
    };
  }

  static CircleContributionStatus _parseStatus(dynamic value) {
    if (value is CircleContributionStatus) return value;
    final raw = (value ?? '').toString().trim().toLowerCase();
    return CircleContributionStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => CircleContributionStatus.pending,
    );
  }

  static CircleContributionPaymentMethod _parsePaymentMethod(dynamic value) {
    if (value is CircleContributionPaymentMethod) return value;
    final raw = (value ?? '').toString().trim().toLowerCase();
    switch (raw) {
      case 'payroll_deduction':
      case 'payrolldeduction':
      case 'payrollDeduction':
        return CircleContributionPaymentMethod.payrollDeduction;
      case 'manual':
      default:
        return CircleContributionPaymentMethod.manual;
    }
  }

  static String _paymentMethodValue(CircleContributionPaymentMethod method) {
    switch (method) {
      case CircleContributionPaymentMethod.manual:
        return 'manual';
      case CircleContributionPaymentMethod.payrollDeduction:
        return 'payroll_deduction';
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static bool? _toNullableBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  static String? _readNullableString(
      Map<String, dynamic> data, List<String> keys) {
    final value = _readString(data, keys);
    return value.isEmpty ? null : value;
  }
}
