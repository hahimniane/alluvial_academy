import 'package:cloud_firestore/cloud_firestore.dart';

enum CircleCycleStatus {
  pending,
  inProgress,
  completed,
}

class CircleCycle {
  final String id;
  final String circleId;
  final int cycleNumber;
  final DateTime? dueDate;
  final String payoutRecipientUserId;
  final double payoutAmount;
  final CircleCycleStatus status;
  final double totalExpected;
  final double totalCollected;
  final DateTime? payoutSentAt;

  const CircleCycle({
    required this.id,
    required this.circleId,
    required this.cycleNumber,
    required this.dueDate,
    required this.payoutRecipientUserId,
    required this.payoutAmount,
    required this.status,
    required this.totalExpected,
    required this.totalCollected,
    required this.payoutSentAt,
  });

  factory CircleCycle.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return CircleCycle.fromMap(data, id: doc.id);
  }

  factory CircleCycle.fromMap(Map<String, dynamic> data, {String? id}) {
    return CircleCycle(
      id: id ?? _readString(data, ['id']),
      circleId: _readString(data, ['circle_id', 'circleId']),
      cycleNumber: _toInt(data['cycle_number'] ?? data['cycleNumber']) ?? 0,
      dueDate: _parseDateTime(data['due_date'] ?? data['dueDate']),
      payoutRecipientUserId: _readString(
          data, ['payout_recipient_user_id', 'payoutRecipientUserId']),
      payoutAmount:
          _toDouble(data['payout_amount'] ?? data['payoutAmount']) ?? 0,
      status: _parseStatus(data['status']),
      totalExpected:
          _toDouble(data['total_expected'] ?? data['totalExpected']) ?? 0,
      totalCollected:
          _toDouble(data['total_collected'] ?? data['totalCollected']) ?? 0,
      payoutSentAt:
          _parseDateTime(data['payout_sent_at'] ?? data['payoutSentAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'circle_id': circleId,
      'cycle_number': cycleNumber,
      if (dueDate != null) 'due_date': Timestamp.fromDate(dueDate!),
      'payout_recipient_user_id': payoutRecipientUserId,
      'payout_amount': payoutAmount,
      'status': _statusValue(status),
      'total_expected': totalExpected,
      'total_collected': totalCollected,
      if (payoutSentAt != null)
        'payout_sent_at': Timestamp.fromDate(payoutSentAt!),
    };
  }

  static CircleCycleStatus _parseStatus(dynamic value) {
    if (value is CircleCycleStatus) return value;
    final raw = (value ?? '').toString().trim().toLowerCase();
    switch (raw) {
      case 'in_progress':
      case 'inprogress':
      case 'inProgress':
        return CircleCycleStatus.inProgress;
      case 'completed':
        return CircleCycleStatus.completed;
      case 'pending':
      default:
        return CircleCycleStatus.pending;
    }
  }

  static String _statusValue(CircleCycleStatus status) {
    switch (status) {
      case CircleCycleStatus.pending:
        return 'pending';
      case CircleCycleStatus.inProgress:
        return 'in_progress';
      case CircleCycleStatus.completed:
        return 'completed';
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
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
}
