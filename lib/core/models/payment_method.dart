import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentMethod {
  final String id;
  final String type;
  final bool isDefault;
  final DateTime? createdAt;

  const PaymentMethod({
    required this.id,
    required this.type,
    required this.isDefault,
    this.createdAt,
  });

  factory PaymentMethod.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PaymentMethod.fromMap(data, id: doc.id);
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> data, {String? id}) {
    return PaymentMethod(
      id: id ?? (data['id'] ?? '').toString(),
      type: (data['type'] ?? 'payoneer').toString(),
      isDefault: (data['is_default'] == true) || (data['isDefault'] == true),
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'is_default': isDefault,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
