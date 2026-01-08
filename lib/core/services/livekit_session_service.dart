import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';

class LiveKitSessionService {
  static const String _collectionName = 'livekit_sessions';
  final FirebaseFirestore _firestore;

  LiveKitSessionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String _docId({required String shiftId, required String userId}) =>
      '${shiftId}_$userId';

  Future<void> recordParticipantJoin({
    required String shiftId,
    required String userId,
    required String role,
  }) async {
    if (shiftId.trim().isEmpty || userId.trim().isEmpty) return;

    final docRef = _firestore
        .collection(_collectionName)
        .doc(_docId(shiftId: shiftId, userId: userId));

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final now = FieldValue.serverTimestamp();

        if (!snap.exists) {
          tx.set(docRef, {
            'shift_id': shiftId,
            'user_id': userId,
            'role': role,
            'join_count': 1,
            'leave_count': 0,
            'joined_at': now,
            'left_at': null,
            'disconnect_reason': null,
            'last_event': 'join',
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
            'created_at': now,
            'updated_at': now,
          });
          return;
        }

        tx.update(docRef, {
          'shift_id': shiftId,
          'user_id': userId,
          'role': role,
          'join_count': FieldValue.increment(1),
          'joined_at': now,
          'last_event': 'join',
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'updated_at': now,
        });
      });
    } catch (e) {
      AppLogger.warning(
          'LiveKitSessionService: Failed to record join (shift=$shiftId, user=$userId): $e');
    }
  }

  Future<void> recordParticipantLeave({
    required String shiftId,
    required String userId,
    String? disconnectReason,
  }) async {
    if (shiftId.trim().isEmpty || userId.trim().isEmpty) return;

    final docRef = _firestore
        .collection(_collectionName)
        .doc(_docId(shiftId: shiftId, userId: userId));

    try {
      final now = FieldValue.serverTimestamp();
      await docRef.set(
        {
          'shift_id': shiftId,
          'user_id': userId,
          'leave_count': FieldValue.increment(1),
          'left_at': now,
          'disconnect_reason': disconnectReason,
          'last_event': 'leave',
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'updated_at': now,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      AppLogger.warning(
          'LiveKitSessionService: Failed to record leave (shift=$shiftId, user=$userId): $e');
    }
  }
}

