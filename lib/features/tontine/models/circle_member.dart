import 'package:cloud_firestore/cloud_firestore.dart';

enum CircleMemberStatus {
  invited,
  active,
  suspended,
  completed,
  removed,
}

class CircleMember {
  final String id;
  final String circleId;
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String contactInfo;
  final bool isTontineHead;
  final int payoutPosition;
  final CircleMemberStatus status;
  final DateTime? joinedAt;
  final double totalContributed;
  final double totalReceived;
  final bool hasReceivedPayout;

  const CircleMember({
    required this.id,
    required this.circleId,
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.contactInfo,
    required this.isTontineHead,
    required this.payoutPosition,
    required this.status,
    required this.joinedAt,
    required this.totalContributed,
    required this.totalReceived,
    required this.hasReceivedPayout,
  });

  factory CircleMember.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return CircleMember.fromMap(data, id: doc.id);
  }

  factory CircleMember.fromMap(Map<String, dynamic> data, {String? id}) {
    return CircleMember(
      id: id ?? _readString(data, ['id']),
      circleId: _readString(data, ['circle_id', 'circleId']),
      userId: _readString(data, ['user_id', 'userId']),
      displayName: _readString(data, ['display_name', 'displayName']),
      photoUrl: _readNullableString(data, ['photo_url', 'photoUrl']),
      contactInfo: _readString(data, ['contact_info', 'contactInfo']),
      isTontineHead: _toBool(data['is_tontine_head'] ?? data['isTontineHead']),
      payoutPosition:
          _toInt(data['payout_position'] ?? data['payoutPosition']) ?? 0,
      status: _parseStatus(data['status']),
      joinedAt: _parseDateTime(data['joined_at'] ?? data['joinedAt']),
      totalContributed:
          _toDouble(data['total_contributed'] ?? data['totalContributed']) ?? 0,
      totalReceived:
          _toDouble(data['total_received'] ?? data['totalReceived']) ?? 0,
      hasReceivedPayout: _toBool(
        data['has_received_payout'] ?? data['hasReceivedPayout'],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'circle_id': circleId,
      'user_id': userId,
      'display_name': displayName,
      'photo_url': photoUrl,
      'contact_info': contactInfo,
      'is_tontine_head': isTontineHead,
      'payout_position': payoutPosition,
      'status': status.name,
      if (joinedAt != null) 'joined_at': Timestamp.fromDate(joinedAt!),
      'total_contributed': totalContributed,
      'total_received': totalReceived,
      'has_received_payout': hasReceivedPayout,
    };
  }

  static CircleMemberStatus _parseStatus(dynamic value) {
    if (value is CircleMemberStatus) return value;
    final raw = (value ?? '').toString().trim().toLowerCase();
    return CircleMemberStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => CircleMemberStatus.invited,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return false;
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

  static String? _readNullableString(
      Map<String, dynamic> data, List<String> keys) {
    final value = _readString(data, keys);
    return value.isEmpty ? null : value;
  }
}
