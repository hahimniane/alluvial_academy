import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:alluwalacademyadmin/core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_contribution.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_cycle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_invite.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_member.dart';

class TontineParticipantDraft {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String contactInfo;
  final bool isCreator;
  final CircleInviteMethod? inviteMethod;

  const TontineParticipantDraft({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.contactInfo,
    required this.isCreator,
    this.inviteMethod,
  });
}

class TontineUserLookup {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String email;
  final String phoneNumber;

  const TontineUserLookup({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.email,
    required this.phoneNumber,
  });
}

class TontineService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _circles =>
      _firestore.collection('circles');
  static CollectionReference<Map<String, dynamic>> get _circleMembers =>
      _firestore.collection('circle_members');
  static CollectionReference<Map<String, dynamic>> get _circleCycles =>
      _firestore.collection('circle_cycles');
  static CollectionReference<Map<String, dynamic>> get _circleContributions =>
      _firestore.collection('circle_contributions');
  static CollectionReference<Map<String, dynamic>> get _circleInvites =>
      _firestore.collection('circle_invites');
  static CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static Future<String> createCircle({
    required String title,
    required CircleType type,
    required double contributionAmount,
    required String currency,
    String frequency = 'monthly',
    required DateTime startDate,
    required CircleRules rules,
    required String paymentInstructions,
    required List<TontineParticipantDraft> participantsInOrder,
  }) async {
    final creator = _auth.currentUser;
    if (creator == null) {
      throw Exception('No signed-in user');
    }
    if (participantsInOrder.isEmpty) {
      throw Exception('At least one participant is required');
    }

    final hasCreator = participantsInOrder.any(
      (participant) =>
          participant.userId == creator.uid && participant.isCreator,
    );
    if (!hasCreator) {
      throw Exception('Creator must be included in the payout order');
    }

    final circleRef = _circles.doc();
    final batch = _firestore.batch();

    final circle = Circle(
      id: circleRef.id,
      title: title.trim(),
      type: type,
      status: CircleStatus.forming,
      contributionAmount: contributionAmount,
      currency: currency,
      frequency: frequency,
      totalMembers: participantsInOrder.length,
      currentCycleIndex: 0,
      createdBy: creator.uid,
      createdAt: DateTime.now(),
      startDate: startDate,
      rules: rules,
      paymentInstructions: paymentInstructions.trim(),
    );

    final circleData = circle.toMap()
      ..['created_at'] = FieldValue.serverTimestamp()
      ..['current_cycle_index'] = 0;
    batch.set(circleRef, circleData);

    for (var index = 0; index < participantsInOrder.length; index++) {
      final participant = participantsInOrder[index];
      final memberRef = _circleMembers.doc();
      final member = CircleMember(
        id: memberRef.id,
        circleId: circleRef.id,
        userId: participant.userId,
        displayName: participant.displayName,
        photoUrl: participant.photoUrl,
        contactInfo: participant.contactInfo,
        isTontineHead: participant.isCreator,
        payoutPosition: index + 1,
        status: participant.isCreator
            ? CircleMemberStatus.active
            : CircleMemberStatus.invited,
        joinedAt: participant.isCreator ? DateTime.now() : null,
        totalContributed: 0,
        totalReceived: 0,
        hasReceivedPayout: false,
      );

      final memberData = member.toMap();
      if (participant.isCreator) {
        memberData['joined_at'] = FieldValue.serverTimestamp();
      } else {
        memberData.remove('joined_at');
      }
      batch.set(memberRef, memberData);

      if (participant.isCreator) {
        continue;
      }

      final inviteRef = _circleInvites.doc();
      final existingId = participant.userId.isEmpty ? null : participant.userId;
      final invite = CircleInvite(
        id: inviteRef.id,
        circleId: circleRef.id,
        circleName: title.trim(),
        inviteMethod: participant.inviteMethod ?? CircleInviteMethod.email,
        contactInfo: participant.contactInfo,
        createdBy: creator.uid,
        createdAt: DateTime.now(),
        status: CircleInviteStatus.pending,
        existingUserId: existingId,
        acceptedBy: null,
        acceptedAt: null,
      );

      final inviteData = invite.toMap()
        ..['created_at'] = FieldValue.serverTimestamp();
      batch.set(inviteRef, inviteData);
    }

    await batch.commit();
    return circleRef.id;
  }

  static Stream<List<Circle>> getUserCircles(String userId) {
    return _circleMembers
        .where('user_id', isEqualTo: userId)
        .where(
          'status',
          whereIn: <String>[
            CircleMemberStatus.active.name,
            CircleMemberStatus.suspended.name,
            CircleMemberStatus.completed.name,
          ],
        )
        .snapshots()
        .asyncMap((snapshot) async {
          final circleIds = snapshot.docs
              .map((doc) => (doc.data()['circle_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

          if (circleIds.isEmpty) {
            return <Circle>[];
          }

          final docs = await Future.wait(
            circleIds.map((circleId) => _circles.doc(circleId).get()),
          );

          final circles = docs
              .where((doc) => doc.exists)
              .map((doc) => Circle.fromFirestore(doc))
              .toList();

          circles.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return circles;
        })
        .handleError((error, stackTrace) {
          AppLogger.error('TontineService.getUserCircles error: $error');
          AppLogger.error('TontineService.getUserCircles stack: $stackTrace');
        });
  }

  static Stream<List<CircleInvite>> getPendingInvitesForUser(String userId) {
    return _circleInvites
        .where('existing_user_id', isEqualTo: userId)
        .where('status', isEqualTo: CircleInviteStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CircleInvite.fromFirestore(doc))
            .toList())
        .handleError((error, stackTrace) {
      AppLogger.error('TontineService.getPendingInvitesForUser error: $error');
      AppLogger.error(
          'TontineService.getPendingInvitesForUser stack: $stackTrace');
    });
  }

  static Stream<Circle?> getCircle(String circleId) {
    return _circles.doc(circleId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Circle.fromFirestore(doc);
    });
  }

  static Future<Circle?> getCircleById(String circleId) async {
    final doc = await _circles.doc(circleId).get();
    if (!doc.exists) return null;
    return Circle.fromFirestore(doc);
  }

  static Stream<List<CircleMember>> getCircleMembers(String circleId) {
    return _circleMembers
        .where('circle_id', isEqualTo: circleId)
        .orderBy('payout_position')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CircleMember.fromFirestore(doc))
            .toList())
        .handleError((error, stackTrace) {
      AppLogger.error('TontineService.getCircleMembers error: $error');
      AppLogger.error('TontineService.getCircleMembers stack: $stackTrace');
    });
  }

  static Stream<CircleCycle?> getCurrentCycle(String circleId) {
    return _circleCycles
        .where('circle_id', isEqualTo: circleId)
        .orderBy('cycle_number', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CircleCycle.fromFirestore(snapshot.docs.first);
    });
  }

  static Stream<List<CircleContribution>> getContributionsForCycle(
      String cycleId) {
    return _circleContributions
        .where('cycle_id', isEqualTo: cycleId)
        .orderBy('display_name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CircleContribution.fromFirestore(doc))
            .toList())
        .handleError((error, stackTrace) {
      AppLogger.error('TontineService.getContributionsForCycle error: $error');
      AppLogger.error(
          'TontineService.getContributionsForCycle stack: $stackTrace');
    });
  }

  static Future<String> submitContribution({
    required String circleId,
    required String cycleId,
    required double expectedAmount,
    required double submittedAmount,
    required String receiptImageUrl,
    required DateTime paymentDate,
    CircleContributionPaymentMethod paymentMethod =
        CircleContributionPaymentMethod.manual,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No signed-in user');
    }

    final memberQuery = await _circleMembers
        .where('circle_id', isEqualTo: circleId)
        .where('user_id', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (memberQuery.docs.isEmpty) {
      throw Exception('Circle membership not found');
    }

    final member = CircleMember.fromFirestore(memberQuery.docs.first);
    final existingQuery = await _circleContributions
        .where('cycle_id', isEqualTo: cycleId)
        .where('user_id', isEqualTo: user.uid)
        .limit(1)
        .get();

    final contributionRef = existingQuery.docs.isNotEmpty
        ? existingQuery.docs.first.reference
        : _circleContributions.doc();

    final contribution = CircleContribution(
      id: contributionRef.id,
      circleId: circleId,
      cycleId: cycleId,
      userId: user.uid,
      displayName: member.displayName,
      expectedAmount: expectedAmount,
      submittedAmount: submittedAmount,
      amountIsCorrect: submittedAmount == expectedAmount,
      status: CircleContributionStatus.submitted,
      paymentMethod: paymentMethod,
      receiptImageUrl: receiptImageUrl,
      submittedAt: DateTime.now(),
      paymentDate: paymentDate,
      confirmedAt: null,
      confirmedBy: null,
      rejectionReason: null,
    );

    final data = contribution.toMap()
      ..['submitted_at'] = FieldValue.serverTimestamp()
      ..['payment_date'] = Timestamp.fromDate(paymentDate)
      ..remove('confirmed_at')
      ..remove('confirmed_by');

    await contributionRef.set(data, SetOptions(merge: true));
    return contributionRef.id;
  }

  static Future<void> confirmContribution(String contributionId) async {
    final userId = _auth.currentUser?.uid;
    await _circleContributions.doc(contributionId).update({
      'status': CircleContributionStatus.confirmed.name,
      'confirmed_at': FieldValue.serverTimestamp(),
      'confirmed_by': userId,
      'rejection_reason': FieldValue.delete(),
    });
  }

  static Future<void> rejectContribution(
      String contributionId, String reason) async {
    await _circleContributions.doc(contributionId).update({
      'status': CircleContributionStatus.rejected.name,
      'rejection_reason': reason.trim(),
      'confirmed_at': FieldValue.delete(),
      'confirmed_by': FieldValue.delete(),
    });
  }

  static Future<void> markPayoutSent(String cycleId) async {
    await _circleCycles.doc(cycleId).update({
      'status': 'completed',
      'payout_sent_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> inviteMember({
    required String circleId,
    required String circleName,
    required String existingUserId,
    required String displayName,
    required String? photoUrl,
    required String contactInfo,
    required CircleInviteMethod inviteMethod,
    required int payoutPosition,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No signed-in user');
    }

    final batch = _firestore.batch();
    final memberRef = _circleMembers.doc();
    final inviteRef = _circleInvites.doc();

    batch.set(memberRef, {
      'circle_id': circleId,
      'user_id': existingUserId,
      'display_name': displayName,
      'photo_url': photoUrl,
      'contact_info': contactInfo,
      'is_tontine_head': false,
      'payout_position': payoutPosition,
      'status': CircleMemberStatus.invited.name,
      'total_contributed': 0.0,
      'total_received': 0.0,
      'has_received_payout': false,
    });

    batch.set(inviteRef, {
      'circle_id': circleId,
      'circle_name': circleName,
      'invite_method': inviteMethod.name,
      'contact_info': contactInfo,
      'created_by': currentUser.uid,
      'created_at': FieldValue.serverTimestamp(),
      'status': CircleInviteStatus.pending.name,
      'existing_user_id': existingUserId,
    });

    await batch.commit();
  }

  static Future<void> acceptInvite(String inviteId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No signed-in user');
    }

    final inviteRef = _circleInvites.doc(inviteId);
    final inviteDoc = await inviteRef.get();
    if (!inviteDoc.exists) {
      throw Exception('Invite not found');
    }
    final invite = CircleInvite.fromFirestore(inviteDoc);
    if (invite.status != CircleInviteStatus.pending) {
      throw Exception('Invite is no longer available');
    }
    if (invite.existingUserId != null &&
        invite.existingUserId != currentUser.uid) {
      throw Exception('This invite does not belong to the current user');
    }

    final memberQuery = await _circleMembers
        .where('circle_id', isEqualTo: invite.circleId)
        .where('user_id', isEqualTo: currentUser.uid)
        .limit(1)
        .get();
    if (memberQuery.docs.isEmpty) {
      throw Exception('Circle member record not found');
    }

    final currentUserSummary = await _getCurrentUserLookup();
    final memberRef = memberQuery.docs.first.reference;

    await _firestore.runTransaction((transaction) async {
      final freshInvite = await transaction.get(inviteRef);
      if (!freshInvite.exists) {
        throw Exception('Invite not found');
      }
      final freshInviteStatus =
          (freshInvite.data()?['status'] ?? '').toString();
      if (freshInviteStatus != CircleInviteStatus.pending.name) {
        throw Exception('Invite is no longer available');
      }

      transaction.update(inviteRef, {
        'status': CircleInviteStatus.accepted.name,
        'accepted_by': currentUser.uid,
        'accepted_at': FieldValue.serverTimestamp(),
      });

      transaction.update(memberRef, {
        'status': CircleMemberStatus.active.name,
        'joined_at': FieldValue.serverTimestamp(),
        'display_name': currentUserSummary.displayName,
        'photo_url': currentUserSummary.photoUrl,
        'contact_info': currentUserSummary.phoneNumber.isNotEmpty
            ? currentUserSummary.phoneNumber
            : currentUserSummary.email,
      });
    });
  }

  static Future<void> updateCircle(
    String circleId, {
    required String title,
    required double contributionAmount,
    required String currency,
    required String frequency,
    required DateTime startDate,
    required CircleRules rules,
    required String paymentInstructions,
  }) async {
    final circleRef = _circles.doc(circleId);
    await circleRef.update({
      'title': title.trim(),
      'contribution_amount': contributionAmount,
      'currency': currency,
      'frequency': frequency,
      'start_date': Timestamp.fromDate(startDate),
      'rules': rules.toMap(),
      'payment_instructions': paymentInstructions.trim(),
    });
  }

  static Future<void> activateCircle(String circleId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No signed-in user');
    }

    final circleRef = _circles.doc(circleId);
    final circleDoc = await circleRef.get();
    if (!circleDoc.exists) {
      throw Exception('Circle not found');
    }
    final circle = Circle.fromFirestore(circleDoc);
    if (circle.createdBy != currentUser.uid) {
      throw Exception('Only the tontine head can activate the circle');
    }

    final membersSnapshot =
        await _circleMembers.where('circle_id', isEqualTo: circleId).get();
    final members = membersSnapshot.docs
        .map((doc) => CircleMember.fromFirestore(doc))
        .toList();

    final activeMemberCount = members
        .where((member) => member.status == CircleMemberStatus.active)
        .length;
    if (activeMemberCount != circle.totalMembers) {
      throw Exception('All invited members must join before activation');
    }

    await circleRef.update({
      'status': CircleStatus.active.name,
    });
  }

  static Future<void> resendCircleInvite({
    required String circleId,
    required String userId,
  }) async {
    try {
      final inviteSnapshot = await _circleInvites
          .where('circle_id', isEqualTo: circleId)
          .where('existing_user_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (inviteSnapshot.docs.isEmpty) {
        throw Exception('Invite not found for this user in this circle.');
      }

      final inviteId = inviteSnapshot.docs.first.id;

      final callable =
          FirebaseFunctions.instance.httpsCallable('resendCircleInvite');
      await callable.call<Map<String, dynamic>>({
        'inviteId': inviteId,
      });
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('resendCircleInvite functions error', error: e);
      throw Exception(e.message ?? 'Failed to resend invite');
    } catch (e) {
      AppLogger.error('resendCircleInvite error', error: e);
      throw Exception('Failed to resend invite');
    }
  }

  static Stream<List<Circle>> getOpenCirclesForTeachers() {
    return _circles
        .where('type', isEqualTo: CircleType.teacher.name)
        .where('enrollment_mode', isEqualTo: 'open')
        .where('status', isEqualTo: CircleStatus.forming.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Circle.fromFirestore(doc))
            .toList())
        .handleError((error, stackTrace) {
      AppLogger.error(
          'TontineService.getOpenCirclesForTeachers error: $error');
    });
  }

  static Future<void> joinOpenCircle(String circleId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No signed-in user');
    }

    final circleDoc = await _circles.doc(circleId).get();
    if (!circleDoc.exists) throw Exception('Circle not found');
    final circle = Circle.fromFirestore(circleDoc);

    if (!circle.isOpenEnrollment) {
      throw Exception('This circle does not accept open enrollment');
    }
    if (circle.status != CircleStatus.forming) {
      throw Exception('This circle is no longer accepting members');
    }

    final existingMember = await _circleMembers
        .where('circle_id', isEqualTo: circleId)
        .where('user_id', isEqualTo: currentUser.uid)
        .limit(1)
        .get();
    if (existingMember.docs.isNotEmpty) {
      throw Exception('You are already a member of this circle');
    }

    final allMembers = await _circleMembers
        .where('circle_id', isEqualTo: circleId)
        .get();
    final currentCount = allMembers.docs.length;

    if (circle.maxMembers != null && currentCount >= circle.maxMembers!) {
      throw Exception('This circle is full');
    }

    final userLookup = await _getCurrentUserLookup();
    final payoutPosition = currentCount + 1;

    final memberRef = _circleMembers.doc();
    await memberRef.set({
      'circle_id': circleId,
      'user_id': currentUser.uid,
      'display_name': userLookup.displayName,
      'photo_url': userLookup.photoUrl,
      'contact_info': userLookup.phoneNumber.isNotEmpty
          ? userLookup.phoneNumber
          : userLookup.email,
      'is_tontine_head': false,
      'payout_position': payoutPosition,
      'status': CircleMemberStatus.active.name,
      'joined_at': FieldValue.serverTimestamp(),
      'total_contributed': 0.0,
      'total_received': 0.0,
      'has_received_payout': false,
    });

    await _circles.doc(circleId).update({
      'total_members': FieldValue.increment(1),
    });
  }

  static Future<TontineUserLookup?> searchExistingUser(
    String query, {
    required CircleInviteMethod method,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return null;

    QuerySnapshot<Map<String, dynamic>> snapshot;
    if (method == CircleInviteMethod.email) {
      snapshot = await _users
          .where('e-mail', isEqualTo: normalized.toLowerCase())
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        snapshot = await _users
            .where('email', isEqualTo: normalized.toLowerCase())
            .limit(1)
            .get();
      }
    } else {
      snapshot = await _users
          .where('phone_number', isEqualTo: normalized)
          .limit(1)
          .get();
    }

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    return TontineUserLookup(
      userId: doc.id,
      displayName: _buildDisplayName(data),
      photoUrl:
          _nullableString(data, ['profile_picture_url', 'profile_picture']),
      email: _readString(data, ['e-mail', 'email']),
      phoneNumber: _readString(data, ['phone_number']),
    );
  }

  static Future<TontineUserLookup> getCurrentUserLookup() async {
    return _getCurrentUserLookup();
  }

  static Future<TontineUserLookup> _getCurrentUserLookup() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No signed-in user');
    }

    final userData =
        await UserRoleService.getCurrentUserData() ?? <String, dynamic>{};
    return TontineUserLookup(
      userId: currentUser.uid,
      displayName: _buildDisplayName(userData,
          fallback: currentUser.displayName ?? 'User'),
      photoUrl:
          _nullableString(userData, ['profile_picture_url', 'profile_picture']),
      email: _readString(userData, ['e-mail', 'email'],
          fallback: currentUser.email ?? ''),
      phoneNumber: _readString(userData, ['phone_number']),
    );
  }

  static String _buildDisplayName(
    Map<String, dynamic> data, {
    String fallback = 'User',
  }) {
    final direct = _readString(data, ['display_name', 'displayName', 'name']);
    if (direct.isNotEmpty) {
      return direct;
    }

    final firstName = _readString(data, ['first_name', 'firstName']);
    final lastName = _readString(data, ['last_name', 'lastName']);
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    return fallback;
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

  static String? _nullableString(Map<String, dynamic> data, List<String> keys) {
    final value = _readString(data, keys);
    return value.isEmpty ? null : value;
  }
}
