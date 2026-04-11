import 'package:cloud_firestore/cloud_firestore.dart';

enum CircleInviteMethod {
  phone,
  email,
}

enum CircleInviteStatus {
  pending,
  accepted,
  expired,
}

class CircleInvite {
  final String id;
  final String circleId;
  final String circleName;
  final CircleInviteMethod inviteMethod;
  final String contactInfo;
  final String createdBy;
  final DateTime? createdAt;
  final CircleInviteStatus status;
  final String? existingUserId;
  final String? acceptedBy;
  final DateTime? acceptedAt;

  const CircleInvite({
    required this.id,
    required this.circleId,
    required this.circleName,
    required this.inviteMethod,
    required this.contactInfo,
    required this.createdBy,
    required this.createdAt,
    required this.status,
    required this.existingUserId,
    required this.acceptedBy,
    required this.acceptedAt,
  });

  factory CircleInvite.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return CircleInvite.fromMap(data, id: doc.id);
  }

  factory CircleInvite.fromMap(Map<String, dynamic> data, {String? id}) {
    return CircleInvite(
      id: id ?? _readString(data, ['id']),
      circleId: _readString(data, ['circle_id', 'circleId']),
      circleName: _readString(data, ['circle_name', 'circleName']),
      inviteMethod: _parseMethod(data['invite_method'] ?? data['inviteMethod']),
      contactInfo: _readString(data, ['contact_info', 'contactInfo']),
      createdBy: _readString(data, ['created_by', 'createdBy']),
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
      status: _parseStatus(data['status']),
      existingUserId:
          _readNullableString(data, ['existing_user_id', 'existingUserId']),
      acceptedBy: _readNullableString(data, ['accepted_by', 'acceptedBy']),
      acceptedAt: _parseDateTime(data['accepted_at'] ?? data['acceptedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'circle_id': circleId,
      'circle_name': circleName,
      'invite_method': inviteMethod.name,
      'contact_info': contactInfo,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      'status': status.name,
      'existing_user_id': existingUserId,
      'accepted_by': acceptedBy,
      if (acceptedAt != null) 'accepted_at': Timestamp.fromDate(acceptedAt!),
    };
  }

  static CircleInviteMethod _parseMethod(dynamic value) {
    if (value is CircleInviteMethod) return value;
    final raw = (value ?? '').toString().trim().toLowerCase();
    return CircleInviteMethod.values.firstWhere(
      (method) => method.name == raw,
      orElse: () => CircleInviteMethod.email,
    );
  }

  static CircleInviteStatus _parseStatus(dynamic value) {
    if (value is CircleInviteStatus) return value;
    final raw = (value ?? '').toString().trim().toLowerCase();
    return CircleInviteStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => CircleInviteStatus.pending,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
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
