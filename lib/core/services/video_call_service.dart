import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/teaching_shift.dart';
import '../enums/shift_enums.dart';
import '../utils/app_logger.dart';
import 'user_role_service.dart';
import 'zoom_service.dart';
import 'livekit_service.dart';
import 'join_link_service.dart';

/// Unified video call service that routes to the appropriate provider
///
/// This service acts as the single entry point for joining video calls.
/// It determines which video provider (Zoom or LiveKit) to use based on
/// the shift's `videoProvider` field and routes accordingly.
class VideoCallService {
  /// Check if the user can currently join the class
  ///
  /// This checks the time window regardless of video provider.
  static bool canJoinClass(TeachingShift shift) {
    if (shift.usesLiveKit) {
      return LiveKitService.canJoinClass(shift);
    } else {
      return ZoomService.canJoinClass(shift);
    }
  }

  /// Get the time until the class can be joined
  static Duration? getTimeUntilCanJoin(TeachingShift shift) {
    if (shift.usesLiveKit) {
      return LiveKitService.getTimeUntilCanJoin(shift);
    } else {
      return ZoomService.getTimeUntilCanJoin(shift);
    }
  }

  /// Join a class using the appropriate video provider
  ///
  /// Automatically routes to Zoom or LiveKit based on the shift's
  /// `videoProvider` field.
  static Future<void> joinClass(
    BuildContext context,
    TeachingShift shift, {
    bool isTeacher = false,
  }) async {
    AppLogger.info(
      'VideoCallService: Joining class ${shift.id} via ${shift.videoProvider.name}',
    );

    // Client-side access guard:
    // - LiveKit also enforces this server-side when generating join tokens.
    // - Zoom meetings can't be fully enforced server-side, so we gate in the client
    //   to ensure students can only join their own classes.
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in again to join this class.'),
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
          const SnackBar(
            content: Text('You are not assigned to this class.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (shift.usesLiveKit) {
      await LiveKitService.joinClass(context, shift, isTeacher: isTeacher);
    } else {
      // Default to Zoom (existing behavior)
      await ZoomService.joinClass(context, shift);
    }
  }

  /// Get a human-readable name for the video provider
  static String getProviderDisplayName(VideoProvider provider) {
    switch (provider) {
      case VideoProvider.livekit:
        return 'LiveKit (Beta)';
      case VideoProvider.zoom:
        return 'Zoom';
    }
  }

  /// Get the icon for the video provider
  static IconData getProviderIcon(VideoProvider provider) {
    switch (provider) {
      case VideoProvider.livekit:
        return Icons.video_call;
      case VideoProvider.zoom:
        return Icons.videocam;
    }
  }

  /// Check if a video call is available for the shift
  static bool hasVideoCall(TeachingShift shift) {
    if (shift.usesLiveKit) {
      // LiveKit rooms are created on-demand, so always available
      return true;
    } else {
      // Zoom requires a pre-created meeting
      return shift.hasZoomMeeting;
    }
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
      const SnackBar(
        content: Text('Guest class link copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
