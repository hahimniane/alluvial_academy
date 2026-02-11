import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/teaching_shift.dart';
import '../enums/shift_enums.dart';
import '../utils/app_logger.dart';
import 'mobile_classes_access_service.dart';
import 'user_role_service.dart';
import 'livekit_service.dart';
import 'join_link_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Unified video call service for joining classes
///
/// All classes use LiveKit for video calls. Zoom support has been removed.
class VideoCallService {
  /// Check if the user can currently join the class
  ///
  /// This checks the time window (10 minutes before start to 10 minutes after end).
  static bool canJoinClass(TeachingShift shift) {
    return LiveKitService.canJoinClass(shift);
  }

  /// Get the time until the class can be joined
  static Duration? getTimeUntilCanJoin(TeachingShift shift) {
    return LiveKitService.getTimeUntilCanJoin(shift);
  }

  /// Join a class using LiveKit
  static Future<void> joinClass(
    BuildContext context,
    TeachingShift shift, {
    bool isTeacher = false,
  }) async {
    AppLogger.info(
      'VideoCallService: Joining class ${shift.id} via LiveKit',
    );

    // Client-side access guard - LiveKit also enforces this server-side
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pleaseSignInAgainToJoin),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final email = currentUser!.email;

    var isAllowed = uid == shift.teacherId || shift.studentIds.contains(uid);
    if (!isAllowed) {
      try {
        final role =
            (await UserRoleService.getCurrentUserRole())?.toLowerCase();
        isAllowed = role == 'admin' || role == 'super_admin';
      } catch (_) {
        // Ignore role lookup errors; fall back to strict membership check above.
      }
    }

    if (!isAllowed) {
      AppLogger.warning(
          'VideoCallService: Blocked join for uid=$uid on shift=${shift.id} (not assigned)');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.youAreNotAssignedToThis),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Teachers hosting from the native mobile app (iOS/Android) must be enabled by admins.
    final isNativeMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final isTeacherForShift = uid == shift.teacherId;

    if (isNativeMobile && isTeacherForShift) {
      // Primary admins can always join for support/testing.
      final userData = await UserRoleService.getCurrentUserData();
      final primaryRole =
          (userData?['user_type'] as String?)?.trim().toLowerCase();
      final isPrimaryAdmin =
          primaryRole == 'admin' || primaryRole == 'super_admin';

      if (!isPrimaryAdmin) {
        final allowed = await MobileClassesAccessService.canTeacherHostFromMobile(
          uid: uid,
          email: email,
        );
        if (!allowed) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Mobile app classes are not enabled for your account. Please contact an administrator.',
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
    }

    if (!context.mounted) return;
    await LiveKitService.joinClass(context, shift, isTeacher: isTeacher);
  }

  /// Get a human-readable name for the video provider
  static String getProviderDisplayName(VideoProvider provider) {
    // All providers now use LiveKit
    return 'Video Call';
  }

  /// Get the icon for the video provider
  static IconData getProviderIcon(VideoProvider provider) {
    return Icons.video_call;
  }

  /// Check if a video call is available for the shift
  /// 
  /// Always returns true since LiveKit rooms are created on-demand.
  static bool hasVideoCall(TeachingShift shift) {
    // LiveKit rooms are created on-demand, so always available
    return true;
  }

  /// Build a shareable join link for a shift.
  static Uri buildJoinLink(TeachingShift shift) {
    return JoinLinkService.buildGuestJoinUri(shift.id);
  }

  /// Copy the join link to clipboard and notify the user.
  static Future<void> copyJoinLink(
    BuildContext context,
    TeachingShift shift,
  ) async {
    final uri = buildJoinLink(shift);
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.guestClassLinkCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
