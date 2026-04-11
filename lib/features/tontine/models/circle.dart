import 'package:cloud_firestore/cloud_firestore.dart';

enum CircleType {
  open,
  teacher,
  parent,
}

enum CircleStatus {
  forming,
  active,
  completed,
  cancelled,
}

enum CircleMissedPaymentAction {
  moveToBack,
  suspend,
}

class CircleRules {
  final int gracePeriodDays;
  final CircleMissedPaymentAction missedPaymentAction;

  const CircleRules({
    required this.gracePeriodDays,
    required this.missedPaymentAction,
  });

  factory CircleRules.fromMap(Map<String, dynamic>? data) {
    final map = data ?? <String, dynamic>{};
    return CircleRules(
      gracePeriodDays:
          _toInt(map['grace_period_days'] ?? map['gracePeriodDays']) ?? 0,
      missedPaymentAction: _parseMissedPaymentAction(
        map['missed_payment_action'] ?? map['missedPaymentAction'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'grace_period_days': gracePeriodDays,
      'missed_payment_action': _missedPaymentActionValue(missedPaymentAction),
    };
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static CircleMissedPaymentAction _parseMissedPaymentAction(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();
    switch (raw) {
      case 'move_to_back':
      case 'movetoback':
      case 'moveToBack':
        return CircleMissedPaymentAction.moveToBack;
      case 'suspend':
        return CircleMissedPaymentAction.suspend;
      default:
        return CircleMissedPaymentAction.moveToBack;
    }
  }

  static String _missedPaymentActionValue(CircleMissedPaymentAction action) {
    switch (action) {
      case CircleMissedPaymentAction.moveToBack:
        return 'move_to_back';
      case CircleMissedPaymentAction.suspend:
        return 'suspend';
    }
  }
}

class EligibilityRules {
  final double incomeMultiplier;
  final int minTenureMonths;
  final int minShiftsLast30Days;

  const EligibilityRules({
    this.incomeMultiplier = 1.6,
    this.minTenureMonths = 0,
    this.minShiftsLast30Days = 0,
  });

  factory EligibilityRules.fromMap(Map<String, dynamic>? data) {
    final map = data ?? <String, dynamic>{};
    return EligibilityRules(
      incomeMultiplier: _toDouble(
              map['income_multiplier'] ?? map['incomeMultiplier']) ??
          1.6,
      minTenureMonths:
          _toInt(map['min_tenure_months'] ?? map['minTenureMonths']) ?? 0,
      minShiftsLast30Days: _toInt(
              map['min_shifts_last_30_days'] ?? map['minShiftsLast30Days']) ??
          0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'income_multiplier': incomeMultiplier,
      'min_tenure_months': minTenureMonths,
      'min_shifts_last_30_days': minShiftsLast30Days,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class Circle {
  final String id;
  final String title;
  final CircleType type;
  final CircleStatus status;
  final double contributionAmount;
  final String currency;
  final String frequency;
  final int totalMembers;
  final int currentCycleIndex;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? startDate;
  final CircleRules rules;
  final String paymentInstructions;
  final String enrollmentMode;
  final int? maxMembers;
  final EligibilityRules? eligibilityRules;

  const Circle({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.contributionAmount,
    required this.currency,
    required this.frequency,
    required this.totalMembers,
    required this.currentCycleIndex,
    required this.createdBy,
    required this.createdAt,
    required this.startDate,
    required this.rules,
    required this.paymentInstructions,
    this.enrollmentMode = 'manual',
    this.maxMembers,
    this.eligibilityRules,
  });

  bool get isOpenEnrollment => enrollmentMode == 'open';

  factory Circle.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return Circle.fromMap(data, id: doc.id);
  }

  factory Circle.fromMap(Map<String, dynamic> data, {String? id}) {
    final eligibilityData = data['eligibility_rules'] ?? data['eligibilityRules'];
    return Circle(
      id: id ?? _readString(data, ['id']),
      title: _readString(data, ['title']),
      type: _parseType(data['type']),
      status: _parseStatus(data['status']),
      contributionAmount: _toDouble(
            data['contribution_amount'] ?? data['contributionAmount'],
          ) ??
          0,
      currency: _readString(data, ['currency'], fallback: 'USD'),
      frequency: _readString(data, ['frequency'], fallback: 'monthly'),
      totalMembers: _toInt(data['total_members'] ?? data['totalMembers']) ?? 0,
      currentCycleIndex:
          _toInt(data['current_cycle_index'] ?? data['currentCycleIndex']) ?? 0,
      createdBy: _readString(data, ['created_by', 'createdBy']),
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
      startDate: _parseDateTime(data['start_date'] ?? data['startDate']),
      rules: CircleRules.fromMap(data['rules'] as Map<String, dynamic>?),
      paymentInstructions: _readString(
        data,
        ['payment_instructions', 'paymentInstructions'],
      ),
      enrollmentMode: _readString(
        data,
        ['enrollment_mode', 'enrollmentMode'],
        fallback: 'manual',
      ),
      maxMembers:
          _toInt(data['max_members'] ?? data['maxMembers']),
      eligibilityRules: eligibilityData is Map<String, dynamic>
          ? EligibilityRules.fromMap(eligibilityData)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.name,
      'status': status.name,
      'contribution_amount': contributionAmount,
      'currency': currency,
      'frequency': frequency,
      'total_members': totalMembers,
      'current_cycle_index': currentCycleIndex,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (startDate != null) 'start_date': Timestamp.fromDate(startDate!),
      'rules': rules.toMap(),
      'payment_instructions': paymentInstructions,
      'enrollment_mode': enrollmentMode,
      if (maxMembers != null) 'max_members': maxMembers,
      if (eligibilityRules != null)
        'eligibility_rules': eligibilityRules!.toMap(),
    };
  }

  static CircleType _parseType(dynamic value) {
    if (value is CircleType) return value;
    final raw = (value ?? '').toString().trim().toLowerCase();
    return CircleType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => CircleType.open,
    );
  }

  static CircleStatus _parseStatus(dynamic value) {
    if (value is CircleStatus) return value;
    final raw = (value ?? '').toString().trim().toLowerCase();
    return CircleStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => CircleStatus.forming,
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
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
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
