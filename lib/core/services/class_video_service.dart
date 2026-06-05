import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:alluwalacademyadmin/core/services/join_link_service.dart';
import 'package:alluwalacademyadmin/core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/utils/environment_utils.dart';
import 'package:alluwalacademyadmin/core/widgets/realtimekit_meeting_screen.dart';
import 'package:alluwalacademyadmin/features/shift_management/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/features/shift_management/services/mobile_classes_access_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ClassVideoJoinResult {
  final bool success;
  final String? authToken;
  final String? meetingId;
  final String? participantId;
  final String? userRole;
  final String? displayName;
  final String? shiftName;
  final bool roomLocked;
  final String? error;

  ClassVideoJoinResult({
    required this.success,
    this.authToken,
    this.meetingId,
    this.participantId,
    this.userRole,
    this.displayName,
    this.shiftName,
    this.roomLocked = false,
    this.error,
  });

  factory ClassVideoJoinResult.fromMap(Map<String, dynamic> data) {
    return ClassVideoJoinResult(
      success: data['success'] == true,
      authToken: (data['authToken'] ?? data['token'])?.toString(),
      meetingId: data['meetingId']?.toString(),
      participantId: data['participantId']?.toString(),
      userRole: data['userRole']?.toString(),
      displayName: data['displayName']?.toString(),
      shiftName: data['shiftName']?.toString(),
      roomLocked: data['roomLocked'] == true,
    );
  }

  factory ClassVideoJoinResult.error(String message) {
    return ClassVideoJoinResult(success: false, error: message);
  }
}

class ClassVideoPresenceService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<void> markPresence({
    required String shiftId,
    required String event,
    String? meetingId,
    String? participantId,
    String? displayName,
    String? userRole,
  }) async {
    if (shiftId.trim().isEmpty) return;
    try {
      final callable = _functions.httpsCallable('updateRealtimeKitPresence');
      await callable.call({
        'shiftId': shiftId,
        'event': event,
        if ((meetingId ?? '').trim().isNotEmpty) 'meetingId': meetingId,
        if ((participantId ?? '').trim().isNotEmpty)
          'participantId': participantId,
        if ((displayName ?? '').trim().isNotEmpty) 'displayName': displayName,
        if ((userRole ?? '').trim().isNotEmpty) 'userRole': userRole,
      });
    } catch (e) {
      AppLogger.warning(
          'ClassVideoPresenceService: failed to mark $event for $shiftId: $e');
    }
  }
}

class ClassRoomParticipantPresence {
  final String identity;
  final String name;
  final String? role;
  final DateTime? joinedAt;
  final bool isPublisher;

  ClassRoomParticipantPresence({
    required this.identity,
    required this.name,
    this.role,
    this.joinedAt,
    required this.isPublisher,
  });

  factory ClassRoomParticipantPresence.fromMap(Map<String, dynamic> data) {
    final joinedAtIso = data['joinedAtIso']?.toString();
    return ClassRoomParticipantPresence(
      identity: data['identity']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      role: data['role']?.toString(),
      joinedAt: joinedAtIso == null ? null : DateTime.tryParse(joinedAtIso),
      isPublisher: data['isPublisher'] == true,
    );
  }
}

class ClassRoomPresenceResult {
  final bool success;
  final String? roomName;
  final int participantCount;
  final List<ClassRoomParticipantPresence> participants;
  final bool? inJoinWindow;
  final DateTime? generatedAt;
  final String? error;

  ClassRoomPresenceResult({
    required this.success,
    this.roomName,
    required this.participantCount,
    required this.participants,
    this.inJoinWindow,
    this.generatedAt,
    this.error,
  });

  factory ClassRoomPresenceResult.fromMap(Map<String, dynamic> data) {
    final participants = <ClassRoomParticipantPresence>[];
    final rawParticipants = data['participants'];
    if (rawParticipants is List) {
      for (final item in rawParticipants) {
        if (item is Map) {
          participants.add(
            ClassRoomParticipantPresence.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    final generatedAtIso = data['generatedAtIso']?.toString();
    return ClassRoomPresenceResult(
      success: data['success'] == true,
      roomName: (data['roomName'] ?? data['meetingId'])?.toString(),
      participantCount:
          (data['participantCount'] as num?)?.toInt() ?? participants.length,
      participants: participants,
      inJoinWindow: data['inJoinWindow'] == true,
      generatedAt:
          generatedAtIso == null ? null : DateTime.tryParse(generatedAtIso),
      error: data['error']?.toString(),
    );
  }

  factory ClassRoomPresenceResult.error(String message) {
    return ClassRoomPresenceResult(
      success: false,
      participantCount: 0,
      participants: const [],
      error: message,
    );
  }
}

class VideoCallService {
  static bool canJoinClass(TeachingShift shift) =>
      ClassVideoService.canJoinClass(shift);
  static Duration? getTimeUntilCanJoin(TeachingShift shift) =>
      ClassVideoService.getTimeUntilCanJoin(shift);
  static Future<void> joinClass(
    BuildContext context,
    TeachingShift shift, {
    bool isTeacher = false,
  }) =>
      ClassVideoService.joinClass(context, shift, isTeacher: isTeacher);
  static String getProviderDisplayName(VideoProvider provider) => 'Video Call';
  static IconData getProviderIcon(VideoProvider provider) => Icons.video_call;
  static bool hasVideoCall(TeachingShift shift) =>
      shift.category == ShiftCategory.teaching;
  static Uri buildJoinLink(TeachingShift shift) =>
      JoinLinkService.buildGuestJoinUri(shift.id);
  static Future<void> copyJoinLink(BuildContext context, TeachingShift shift) =>
      ClassVideoService.copyJoinLink(context, shift);
}

class ClassVideoService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static bool canJoinClass(TeachingShift shift) {
    final now = DateTime.now().toUtc();
    final joinWindowStart =
        shift.shiftStart.toUtc().subtract(const Duration(minutes: 10));
    final joinWindowEnd =
        shift.shiftEnd.toUtc().add(const Duration(minutes: 10));
    return !now.isBefore(joinWindowStart) && !now.isAfter(joinWindowEnd);
  }

  static Duration? getTimeUntilCanJoin(TeachingShift shift) {
    final now = DateTime.now().toUtc();
    final joinWindowStart =
        shift.shiftStart.toUtc().subtract(const Duration(minutes: 10));
    if (now.isBefore(joinWindowStart)) return joinWindowStart.difference(now);
    return null;
  }

  static Future<ClassVideoJoinResult> getJoinToken(
    String shiftId, {
    String fallbackError = '',
    String unauthenticatedError = '',
  }) async {
    try {
      if (_auth.currentUser == null) {
        return ClassVideoJoinResult.error(unauthenticatedError);
      }
      final callable = _functions.httpsCallable('getRealtimeKitJoinToken');
      final result = await callable.call({'shiftId': shiftId});
      return ClassVideoJoinResult.fromMap(
        Map<String, dynamic>.from(result.data as Map),
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
        'ClassVideoService: join token error: ${e.code} - ${e.message}',
      );
      return ClassVideoJoinResult.error(e.message ?? fallbackError);
    } catch (e) {
      AppLogger.error('ClassVideoService: join token error: $e');
      return ClassVideoJoinResult.error(fallbackError);
    }
  }

  static Future<ClassVideoJoinResult> getGuestJoinToken(
    String shiftId, {
    String? displayName,
    String fallbackError = '',
    String unexpectedResponseError = '',
  }) async {
    try {
      final uri = _buildGuestJoinUri(shiftId, displayName: displayName);
      final response = await http.get(uri);
      dynamic raw;
      if (response.body.isNotEmpty) {
        try {
          raw = jsonDecode(response.body);
        } catch (_) {
          raw = response.body;
        }
      }
      if (response.statusCode != 200) {
        if (raw is Map && raw['error'] != null) {
          return ClassVideoJoinResult.error(raw['error'].toString());
        }
        return ClassVideoJoinResult.error(
          response.body.isNotEmpty ? response.body : 'Failed to join class',
        );
      }
      if (raw is! Map) {
        return ClassVideoJoinResult.error(unexpectedResponseError);
      }
      return ClassVideoJoinResult.fromMap(Map<String, dynamic>.from(raw));
    } catch (e) {
      AppLogger.error('ClassVideoService: guest join token error: $e');
      return ClassVideoJoinResult.error(fallbackError);
    }
  }

  static Future<ClassRoomPresenceResult> getRoomPresence(String shiftId) async {
    try {
      if (_auth.currentUser == null) {
        return ClassRoomPresenceResult.error('User not logged in');
      }
      final callable = _functions.httpsCallable('getRealtimeKitRoomPresence');
      final result = await callable.call({'shiftId': shiftId});
      return ClassRoomPresenceResult.fromMap(
        Map<String, dynamic>.from(result.data as Map),
      );
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim().isNotEmpty == true
          ? e.message!.trim()
          : 'Failed to fetch participants';
      return ClassRoomPresenceResult.error('${e.code}: $message');
    } catch (e) {
      AppLogger.error('ClassVideoService: presence error: $e');
      return ClassRoomPresenceResult.error('Failed to fetch participants');
    }
  }

  static Future<void> kickParticipant({
    required String shiftId,
    required String identity,
  }) async {
    final callable = _functions.httpsCallable('kickRealtimeKitParticipant');
    await callable.call({'shiftId': shiftId, 'identity': identity});
  }

  static Future<void> setRoomLock({
    required String shiftId,
    required bool locked,
  }) async {
    final callable = _functions.httpsCallable('setRealtimeKitRoomLock');
    await callable.call({'shiftId': shiftId, 'locked': locked});
  }

  /// Admin-only: allow or disallow recording for a single class.
  static Future<void> setRecordingEnabled({
    required String shiftId,
    required bool enabled,
  }) async {
    final callable = _functions.httpsCallable('setRealtimeKitRecordingEnabled');
    await callable.call({'shiftId': shiftId, 'enabled': enabled});
  }

  static Future<int> bulkSetRecordingEnabled({
    required List<String> shiftIds,
    required bool enabled,
  }) async {
    final normalizedIds = shiftIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) return 0;

    final callable =
        _functions.httpsCallable('bulkSetRealtimeKitRecordingEnabled');
    final result = await callable.call({
      'shiftIds': normalizedIds,
      'enabled': enabled,
    });
    final data = result.data;
    if (data is Map && data['updatedCount'] is num) {
      return (data['updatedCount'] as num).toInt();
    }
    return normalizedIds.length;
  }

  static Future<void> joinClass(
    BuildContext context,
    TeachingShift shift, {
    bool isTeacher = false,
  }) async {
    AppLogger.info(
        'ClassVideoService: Joining class ${shift.id} via RealtimeKit');
    final l10n = AppLocalizations.of(context)!;

    final currentUser = _auth.currentUser;
    final uid = currentUser?.uid;
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseSignInAgainToJoin),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    var isAllowed = uid == shift.teacherId || shift.studentIds.contains(uid);
    if (!isAllowed) {
      try {
        final role =
            (await UserRoleService.getCurrentUserRole())?.toLowerCase();
        if (role == 'admin' || role == 'super_admin' || role == 'parent') {
          isAllowed = true;
        }
      } catch (_) {}
    }

    if (!isAllowed) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.youAreNotAssignedToThis),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final isNativeMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    final isTeacherForShift = uid == shift.teacherId;
    if (isNativeMobile && isTeacherForShift) {
      final userData = await UserRoleService.getCurrentUserData();
      final primaryRole =
          (userData?['user_type'] as String?)?.trim().toLowerCase();
      final isPrimaryAdmin =
          primaryRole == 'admin' || primaryRole == 'super_admin';
      if (!isPrimaryAdmin) {
        final allowed =
            await MobileClassesAccessService.canTeacherHostFromMobile(
          uid: uid,
          email: currentUser?.email,
        );
        if (!allowed) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.classVideoMobileTeacherNotEnabled),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
    }

    if (!canJoinClass(shift)) {
      final timeUntil = getTimeUntilCanJoin(shift);
      final message = timeUntil == null
          ? l10n.classVideoEnded
          : l10n.classVideoOpensInMinutes(timeUntil.inMinutes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    if (context.mounted) {
      unawaited(_showLoading(context));
    }

    try {
      final joinResult = await getJoinToken(
        shift.id,
        fallbackError: l10n.classVideoConnectFailed,
        unauthenticatedError: l10n.pleaseSignInAgainToJoin,
      );
      if (context.mounted) Navigator.of(context).pop();

      if (!joinResult.success || joinResult.authToken == null) {
        final error = joinResult.error?.trim().isNotEmpty == true
            ? joinResult.error!
            : l10n.classVideoConnectFailed;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RealtimeKitMeetingScreen(
            authToken: joinResult.authToken!,
            displayName: joinResult.displayName ?? 'Participant',
            shiftName: joinResult.shiftName ?? 'Class',
            shiftId: shift.id,
            meetingId: joinResult.meetingId,
            participantId: joinResult.participantId,
            userRole: joinResult.userRole,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      AppLogger.error('ClassVideoService: join error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.classJoinFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> copyJoinLink(
      BuildContext context, TeachingShift shift) async {
    final uri = JoinLinkService.buildGuestJoinUri(shift.id);
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.guestClassLinkCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<void> openGuestJoin(
    BuildContext context,
    String shiftId, {
    String? displayName,
  }) async {
    final joinResult = await getGuestJoinToken(
      shiftId,
      displayName: displayName,
      fallbackError: AppLocalizations.of(context)!.classVideoConnectFailed,
      unexpectedResponseError:
          AppLocalizations.of(context)!.classVideoJoinUnavailable,
    );
    if (!context.mounted) return;
    if (!joinResult.success || joinResult.authToken == null) {
      final fallback = AppLocalizations.of(context)!.classVideoJoinUnavailable;
      final message = joinResult.error?.trim().isNotEmpty == true
          ? joinResult.error!
          : fallback;
      throw Exception(
        message,
      );
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RealtimeKitMeetingScreen(
          authToken: joinResult.authToken!,
          displayName: joinResult.displayName ?? 'Guest',
          shiftName: joinResult.shiftName ?? 'Class',
          shiftId: shiftId,
          meetingId: joinResult.meetingId,
          participantId: joinResult.participantId,
          userRole: joinResult.userRole,
        ),
      ),
    );
  }

  static Uri _buildGuestJoinUri(String shiftId, {String? displayName}) {
    final projectId = EnvironmentUtils.projectId ??
        (EnvironmentUtils.isDevelopment ? 'alluwal-dev' : 'alluwal-academy');
    final params = <String, String>{'shiftId': shiftId};
    if (displayName != null && displayName.trim().isNotEmpty) {
      params['name'] = displayName.trim();
    }
    return Uri.https(
      'us-central1-$projectId.cloudfunctions.net',
      'getRealtimeKitGuestJoin',
      params,
    );
  }

  static Future<void> _showLoading(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(AppLocalizations.of(context)!.connectingToClass),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
