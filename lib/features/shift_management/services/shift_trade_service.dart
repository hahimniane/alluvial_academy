import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/user_role_service.dart';
import '../../../core/utils/app_logger.dart';
import '../enums/shift_enums.dart';
import '../models/teaching_shift.dart';
import 'shift_service.dart';
import 'shift_trading.dart';

/// Offering a class or duty to others, taking the offer back, and knowing
/// who may take a leadership duty. The rules themselves live in
/// [ShiftTrading]; the server enforces them.
class ShiftTradeService {
  ShiftTradeService._();

  /// Offers ([offered] true) or takes back ([offered] false) the given
  /// classes in one call. Returns one result per class; a class the server
  /// did not answer for counts as failed.
  static Future<List<ShiftOfferResult>> setOffers({
    required List<String> shiftIds,
    required bool offered,
  }) async {
    final ids = shiftIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];

    final callable = FirebaseFunctions.instance.httpsCallable('setShiftOffers');
    final results = <ShiftOfferResult>[];
    for (var i = 0; i < ids.length; i += ShiftTrading.maxOffersPerCall) {
      final end = i + ShiftTrading.maxOffersPerCall > ids.length
          ? ids.length
          : i + ShiftTrading.maxOffersPerCall;
      final chunk = ids.sublist(i, end);
      final response = await callable.call(<String, dynamic>{
        'shiftIds': chunk,
        'offered': offered,
      });
      final parsed = ShiftTrading.parseResults(response.data);
      final answered = parsed.map((r) => r.shiftId).toSet();
      results.addAll(parsed);
      for (final id in chunk) {
        if (!answered.contains(id)) {
          results.add(ShiftOfferResult(
            shiftId: id,
            ok: false,
            failure: ShiftOfferFailure.other,
          ));
        }
      }
    }
    return results;
  }

  /// The days of [opened]'s series its teacher can offer together with it.
  /// A one-off class, or a failed lookup, yields only [opened].
  static Future<List<TeachingShift>> seriesOfferChoices(
    TeachingShift opened,
  ) async {
    final templateId = opened.templateId?.trim() ?? '';
    final now = DateTime.now();
    var candidates = const <TeachingShift>[];
    if (templateId.isNotEmpty && opened.teacherId.isNotEmpty) {
      try {
        candidates = await ShiftService.getUpcomingSeriesShifts(
          teacherId: opened.teacherId,
          templateId: templateId,
          from: now,
          to: now.add(const Duration(days: ShiftTrading.seriesWindowDays)),
        );
      } catch (e) {
        AppLogger.error('ShiftTradeService: series lookup failed: $e');
      }
    }
    return ShiftTrading.seriesOfferChoices(
      opened: opened,
      candidates: candidates,
      now: now,
    );
  }

  /// Whether [uid] holds at least one leadership duty (a shift that is not a
  /// taught class).
  static Future<bool> holdsLeadershipDuty(String uid) async {
    try {
      final dutyCategories = ShiftCategory.values
          .where((c) => c != ShiftCategory.teaching)
          .map((c) => c.name)
          .toList();
      final snapshot = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: uid)
          .where('shift_category', whereIn: dutyCategories)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      AppLogger.error('ShiftTradeService: leadership duty lookup failed: $e');
      return false;
    }
  }

  /// Whether the signed-in person is a leader: an admin, an admin-teacher, or
  /// someone who already holds a leadership duty.
  static Future<bool> isCurrentUserLeader() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final data = await UserRoleService.getCurrentUserData();
      final activeRole = await UserRoleService.getCurrentUserRole();
      // The server reads the role from either field, so both count here.
      if (ShiftTrading.isLeader(
            primaryRole: data?['user_type']?.toString(),
            activeRole: activeRole,
            isAdminTeacher: data?['is_admin_teacher'] == true,
          ) ||
          ShiftTrading.isLeader(primaryRole: data?['role']?.toString())) {
        return true;
      }
    } catch (e) {
      AppLogger.error('ShiftTradeService: role lookup failed: $e');
    }
    return holdsLeadershipDuty(uid);
  }
}
