import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../../quran/widgets/quran_reader.dart';
import 'package:alluwalacademyadmin/features/livekit/widgets/call_whiteboard.dart';
import '../../shift_management/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/features/livekit/services/livekit_session_service.dart';
import 'package:alluwalacademyadmin/core/services/error_reporting_service.dart';
import 'package:alluwalacademyadmin/core/services/class_video_service.dart'
    as class_video;
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/utils/environment_utils.dart';
import 'package:alluwalacademyadmin/core/utils/picture_in_picture.dart'
    if (dart.library.io) 'package:alluwalacademyadmin/core/utils/picture_in_picture_stub.dart'
    as pip;
import 'package:alluwalacademyadmin/core/utils/web_runtime_info.dart'
    as web_runtime;
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// LiveKit join token response from Cloud Functions
class LiveKitJoinResult {
  final bool success;
  final String? livekitUrl;
  final String? token;
  final String? roomName;
  final String? userRole;
  final String? displayName;
  final String? shiftName;
  final int? expiresInSeconds;
  final bool roomLocked;
  final String? error;

  LiveKitJoinResult({
    required this.success,
    this.livekitUrl,
    this.token,
    this.roomName,
    this.userRole,
    this.displayName,
    this.shiftName,
    this.expiresInSeconds,
    this.roomLocked = false,
    this.error,
  });

  factory LiveKitJoinResult.fromMap(Map<String, dynamic> data) {
    return LiveKitJoinResult(
      success: data['success'] == true,
      livekitUrl: data['livekitUrl']?.toString(),
      token: data['token']?.toString(),
      roomName: data['roomName']?.toString(),
      userRole: data['userRole']?.toString(),
      displayName: data['displayName']?.toString(),
      shiftName: data['shiftName']?.toString(),
      expiresInSeconds: data['expiresInSeconds'] as int?,
      roomLocked: data['roomLocked'] == true,
    );
  }

  factory LiveKitJoinResult.error(String message) {
    return LiveKitJoinResult(
      success: false,
      roomLocked: false,
      error: message,
    );
  }
}

class LiveKitRoomParticipantPresence {
  final String identity;
  final String name;
  final String? role;
  final DateTime? joinedAt;
  final bool isPublisher;

  LiveKitRoomParticipantPresence({
    required this.identity,
    required this.name,
    this.role,
    this.joinedAt,
    required this.isPublisher,
  });

  factory LiveKitRoomParticipantPresence.fromMap(Map<String, dynamic> data) {
    final joinedAtIso = data['joinedAtIso']?.toString();
    return LiveKitRoomParticipantPresence(
      identity: data['identity']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      role: data['role']?.toString(),
      joinedAt: joinedAtIso == null ? null : DateTime.tryParse(joinedAtIso),
      isPublisher: data['isPublisher'] == true,
    );
  }
}

class LiveKitRoomPresenceResult {
  final bool success;
  final String? roomName;
  final int participantCount;
  final List<LiveKitRoomParticipantPresence> participants;
  final bool? inJoinWindow;
  final DateTime? generatedAt;
  final String? error;

  LiveKitRoomPresenceResult({
    required this.success,
    this.roomName,
    required this.participantCount,
    required this.participants,
    this.inJoinWindow,
    this.generatedAt,
    this.error,
  });

  factory LiveKitRoomPresenceResult.fromMap(Map<String, dynamic> data) {
    final rawParticipants = data['participants'];
    final participants = <LiveKitRoomParticipantPresence>[];
    if (rawParticipants is List) {
      for (final item in rawParticipants) {
        if (item is Map) {
          participants.add(
            LiveKitRoomParticipantPresence.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    final generatedAtIso = data['generatedAtIso']?.toString();
    return LiveKitRoomPresenceResult(
      success: data['success'] == true,
      roomName: data['roomName']?.toString(),
      participantCount:
          (data['participantCount'] as num?)?.toInt() ?? participants.length,
      participants: participants,
      inJoinWindow: data['inJoinWindow'] == true,
      generatedAt:
          generatedAtIso == null ? null : DateTime.tryParse(generatedAtIso),
      error: data['error']?.toString(),
    );
  }

  factory LiveKitRoomPresenceResult.error(String message) {
    return LiveKitRoomPresenceResult(
      success: false,
      participantCount: 0,
      participants: const [],
      error: message,
    );
  }
}

class _ClassIssueOption {
  final String code;
  final String category;
  final String label;

  const _ClassIssueOption(this.code, this.category, this.label);
}

const List<_ClassIssueOption> _classIssueOptions = [
  _ClassIssueOption('mutual_audio_issue', 'Audio', "We can't hear each other"),
  _ClassIssueOption('cannot_hear_other', 'Audio', "I can't hear them"),
  _ClassIssueOption('other_cannot_hear_me', 'Audio', "They can't hear me"),
  _ClassIssueOption('audio_cuts_out', 'Audio', 'Audio cuts out'),
  _ClassIssueOption('echo_feedback_noise', 'Audio', 'Echo, feedback, or noise'),
  _ClassIssueOption('mic_permission_or_device', 'Audio',
      'Microphone permission or device problem'),
  _ClassIssueOption('camera_not_working', 'Video', 'My camera is not working'),
  _ClassIssueOption('cannot_see_other', 'Video', "I can't see them"),
  _ClassIssueOption('other_cannot_see_me', 'Video', "They can't see me"),
  _ClassIssueOption('frozen_video', 'Video', 'Video is frozen'),
  _ClassIssueOption('video_quality_lag', 'Video', 'Video is laggy or blurry'),
  _ClassIssueOption('screen_share_not_working', 'Screen share',
      'Screen share will not start'),
  _ClassIssueOption('cannot_see_screen_share', 'Screen share',
      "I can't see the screen share"),
  _ClassIssueOption('screen_share_quality', 'Screen share',
      'Screen share is blurry or delayed'),
  _ClassIssueOption(
      'whiteboard_not_loading', 'Whiteboard', 'Whiteboard is not loading'),
  _ClassIssueOption(
      'whiteboard_drawing_not_working', 'Whiteboard', 'Drawing is not working'),
  _ClassIssueOption(
      'whiteboard_not_syncing', 'Whiteboard', 'Whiteboard is not syncing'),
  _ClassIssueOption('cannot_join_class', 'Join / room', "Can't join the class"),
  _ClassIssueOption(
      'participant_missing', 'Join / room', 'Someone is missing from the room'),
  _ClassIssueOption('wrong_room_or_duplicate_tab', 'Join / room',
      'Wrong room, duplicate tab, or kicked out'),
  _ClassIssueOption('disconnected_or_reconnecting', 'Connection',
      'Disconnected or reconnecting'),
  _ClassIssueOption('class_lagging', 'Connection', 'Everything is lagging'),
  _ClassIssueOption('controls_not_working', 'Controls',
      'Buttons or controls are not working'),
  _ClassIssueOption(
      'mute_lock_problem', 'Controls', 'Muted or locked unexpectedly'),
  _ClassIssueOption('recording_problem', 'Recording', 'Recording problem'),
  _ClassIssueOption(
      'chat_or_messages_problem', 'Chat', 'Chat or messages problem'),
  _ClassIssueOption('materials_or_links_problem', 'Materials',
      'Class materials or links problem'),
  _ClassIssueOption('other_technical_issue', 'Other', 'Other technical issue'),
];

class _ScreenShareCaptureOptionsWithCursor extends ScreenShareCaptureOptions {
  final String? cursor;

  const _ScreenShareCaptureOptionsWithCursor({
    this.cursor,
    super.useiOSBroadcastExtension = false,
    super.captureScreenAudio = false,
    super.preferCurrentTab = false,
    super.selfBrowserSurface,
    super.sourceId,
    super.maxFrameRate,
    super.params = VideoParametersPresets.screenShareH1080FPS15,
  });

  @override
  Map<String, dynamic> toMediaConstraintsMap() {
    final constraints = super.toMediaConstraintsMap();
    if (kIsWeb && cursor != null && cursor!.isNotEmpty) {
      constraints['cursor'] = cursor;
    }
    return constraints;
  }
}

/// Service for managing LiveKit video calls within the app
///
/// This is a beta video provider alternative to Zoom.
/// Shifts with `videoProvider == livekit` will use this service.
class LiveKitService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Request necessary permissions for video calls
  ///
  /// According to LiveKit docs, we need camera, microphone, and Bluetooth permissions
  /// https://docs.livekit.io/reference/client-sdk-flutter/
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return true; // Web handles permissions differently

    try {
      // Request camera and microphone
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      // On Android, also request Bluetooth for headset support
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Permission.bluetooth.request();
        await Permission.bluetoothConnect.request();
      }

      return cameraStatus.isGranted && micStatus.isGranted;
    } catch (e) {
      AppLogger.error('LiveKitService: Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if permissions are permanently denied
  static Future<bool> arePermissionsPermanentlyDenied() async {
    if (kIsWeb) return false;

    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    return cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied;
  }

  /// Show a permission dialog that guides users to enable camera/mic
  static Future<bool> requestPermissionsWithDialog(BuildContext context) async {
    if (kIsWeb) return true;

    // First check current status
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    // If already granted, return true
    if (cameraStatus.isGranted && micStatus.isGranted) {
      // Also request Bluetooth on Android
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Permission.bluetooth.request();
        await Permission.bluetoothConnect.request();
      }
      return true;
    }

    // Check if permanently denied
    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      if (!context.mounted) return false;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.videocam_off, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                  child:
                      Text(AppLocalizations.of(context)!.permissionsRequired)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!
                    .cameraAndMicrophoneAccessAreNeeded,
                style: TextStyle(fontSize: 15),
              ),
              SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!
                            .pleaseEnablePermissionsInSettingsTo,
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await openAppSettings();
                if (ctx.mounted) Navigator.pop(ctx, false);
              },
              icon: const Icon(Icons.settings, size: 18),
              label: Text(AppLocalizations.of(context)!.openSettings),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E72ED),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

      return result ?? false;
    }

    // Request permissions normally
    final granted = await requestPermissions();

    if (!granted && context.mounted) {
      // Show dialog explaining why permissions are needed
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                  child: Text(AppLocalizations.of(context)!.permissionsDenied)),
            ],
          ),
          content: Text(
            '${AppLocalizations.of(context)!.cameraAndMicrophonePermissionsAreRequired} '
            'Please grant these permissions when prompted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.commonOk),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Try requesting again
                await requestPermissions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E72ED),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.errorTryAgain),
            ),
          ],
        ),
      );
    }

    return granted;
  }

  /// Start a direct call to another user (audio or video)
  ///
  /// This initiates a 1-on-1 call outside of scheduled classes.
  /// [recipientId] - The user ID of the person to call
  /// [recipientName] - Display name of the recipient
  /// [isAudioOnly] - If true, starts an audio-only call; otherwise video call
  static Future<void> startCall(
    BuildContext context, {
    required String recipientId,
    required String recipientName,
    bool isAudioOnly = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showError(context, 'You must be logged in to make calls');
      return;
    }

    // Request permissions (Android pre-request, iOS will prompt natively)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final hasPermissions = await requestPermissionsWithDialog(context);
      if (!hasPermissions) return;
    }

    // Show loading
    if (context.mounted) {
      showDialog(
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
                  child: Text(
                    isAudioOnly
                        ? 'Starting audio call with $recipientName...'
                        : 'Starting video call with $recipientName...',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      // Call backend to create/get call room and token
      final result = await _functions.httpsCallable('createDirectCall').call({
        'recipientId': recipientId,
        'isAudioOnly': isAudioOnly,
      });

      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        if (context.mounted) {
          _showError(context, data['error'] ?? 'Failed to start call');
        }
        return;
      }

      // Navigate to call screen
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveKitCallScreen(
              livekitUrl: data['livekitUrl'],
              token: data['token'],
              roomName: data['roomName'],
              displayName: data['displayName'] ?? 'You',
              isTeacher: false,
              isAudioOnlyMode: isAudioOnly,
            ),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      AppLogger.error('LiveKitService: Error starting call: $e');

      if (context.mounted) {
        // Check if it's a "not found" error (function doesn't exist yet)
        final errorMsg = e.toString();
        if (errorMsg.contains('NOT_FOUND') || errorMsg.contains('not-found')) {
          _showInfo(
            context,
            'Direct calls coming soon! This feature is being developed.',
          );
        } else {
          _showError(context, 'Failed to start call. Please try again.');
        }
      }
    }
  }

  /// Check if the user can currently join the class
  /// Class is accessible from 10 minutes before shift start to 10 minutes after shift end
  static bool canJoinClass(TeachingShift shift) {
    final now = DateTime.now().toUtc();
    final shiftStart = shift.shiftStart.toUtc();
    final shiftEnd = shift.shiftEnd.toUtc();

    // Can join 10 minutes before start until 10 minutes after end
    final joinWindowStart = shiftStart.subtract(const Duration(minutes: 10));
    final joinWindowEnd = shiftEnd.add(const Duration(minutes: 10));

    return !now.isBefore(joinWindowStart) && !now.isAfter(joinWindowEnd);
  }

  /// Get the time until the class can be joined
  static Duration? getTimeUntilCanJoin(TeachingShift shift) {
    final now = DateTime.now().toUtc();
    final shiftStart = shift.shiftStart.toUtc();
    final joinWindowStart = shiftStart.subtract(const Duration(minutes: 10));

    if (now.isBefore(joinWindowStart)) {
      return joinWindowStart.difference(now);
    }
    return null;
  }

  /// Get LiveKit join token from backend
  static Future<LiveKitJoinResult> getJoinToken(String shiftId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return LiveKitJoinResult.error('User not logged in');
      }

      final callable = _functions.httpsCallable('getLiveKitJoinToken');
      final result = await callable.call({'shiftId': shiftId});

      final data = Map<String, dynamic>.from(result.data as Map);

      // Debug: Log token info (first 50 chars only for security)
      final token = data['token']?.toString();
      if (token != null) {
        AppLogger.debug(
            'LiveKit: Received token (length: ${token.length}, preview: ${token.substring(0, token.length > 50 ? 50 : token.length)}...)');
        AppLogger.debug(
            'LiveKit: URL: ${data['livekitUrl']}, Room: ${data['roomName']}');
      } else {
        AppLogger.error('LiveKit: No token in response! Data: $data');
      }

      return LiveKitJoinResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'LiveKitService: Firebase function error: ${e.code} - ${e.message}');
      return LiveKitJoinResult.error(e.message ?? 'Failed to get join token');
    } catch (e) {
      AppLogger.error('LiveKitService: Error getting join token: $e');
      return LiveKitJoinResult.error('Failed to connect to class');
    }
  }

  /// Get LiveKit join token for a guest (no-auth) flow.
  static Future<LiveKitJoinResult> getGuestJoinToken(
    String shiftId, {
    String? displayName,
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
          return LiveKitJoinResult.error(raw['error'].toString());
        }
        final fallback =
            response.body.isNotEmpty ? response.body : 'Failed to join class';
        return LiveKitJoinResult.error(fallback);
      }

      if (raw is! Map) {
        return LiveKitJoinResult.error('Unexpected response from server');
      }

      return LiveKitJoinResult.fromMap(Map<String, dynamic>.from(raw));
    } catch (e) {
      AppLogger.error('LiveKitService: Error getting guest join token: $e');
      return LiveKitJoinResult.error('Failed to connect to class');
    }
  }

  static Uri _buildGuestJoinUri(
    String shiftId, {
    String? displayName,
  }) {
    final projectId = EnvironmentUtils.projectId ??
        (EnvironmentUtils.isDevelopment ? 'alluwal-dev' : 'alluwal-academy');
    final params = <String, String>{'shiftId': shiftId};
    if (displayName != null && displayName.trim().isNotEmpty) {
      params['name'] = displayName.trim();
    }

    return Uri.https(
      'us-central1-$projectId.cloudfunctions.net',
      'getLiveKitGuestJoin',
      params,
    );
  }

  /// Fetch current LiveKit room participants for a shift (presence preview)
  static Future<LiveKitRoomPresenceResult> getRoomPresence(
      String shiftId) async {
    final result = await class_video.ClassVideoService.getRoomPresence(shiftId);
    return LiveKitRoomPresenceResult(
      success: result.success,
      roomName: result.roomName,
      participantCount: result.participantCount,
      participants: result.participants
          .map(
            (participant) => LiveKitRoomParticipantPresence(
              identity: participant.identity,
              name: participant.name,
              role: participant.role,
              joinedAt: participant.joinedAt,
              isPublisher: participant.isPublisher,
            ),
          )
          .toList(growable: false),
      inJoinWindow: result.inJoinWindow,
      generatedAt: result.generatedAt,
      error: result.error,
    );
  }

  /// Ensure class recording is started (best effort, non-blocking for UI).
  ///
  /// This should be called automatically when any authorized class participant joins.
  static Future<void> ensureShiftRecording(String shiftId) async {
    if (shiftId.trim().isEmpty) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final callable = _functions.httpsCallable('ensureLiveKitShiftRecording');
      final result = await callable.call({'shiftId': shiftId});
      final data = result.data;
      if (data is! Map) return;

      final typed = Map<String, dynamic>.from(data);
      if (typed['recordingStarted'] == true) {
        AppLogger.info('LiveKit: Class recording started (shiftId: $shiftId)');
        return;
      }
      if (typed['alreadyRecording'] == true) {
        AppLogger.debug(
            'LiveKit: Class recording already active (shiftId: $shiftId)');
        return;
      }

      final reason = typed['reason']?.toString();
      final error = typed['error']?.toString();
      if (reason != null && reason.isNotEmpty) {
        AppLogger.warning(
            'LiveKit: Recording not started (shiftId: $shiftId): $reason');
      } else if (error != null && error.isNotEmpty) {
        AppLogger.warning(
            'LiveKit: Recording failed to start (shiftId: $shiftId): $error');
      }
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'LiveKitService: ensureShiftRecording Firebase function error: ${e.code} - ${e.message}');
    } catch (e) {
      AppLogger.error('LiveKitService: Error ensuring class recording: $e');
    }
  }

  static Future<void> muteParticipant({
    required String shiftId,
    required String identity,
  }) async {
    await setParticipantMuted(
        shiftId: shiftId, identity: identity, muted: true);
  }

  static Future<void> unmuteParticipant({
    required String shiftId,
    required String identity,
  }) async {
    await setParticipantMuted(
        shiftId: shiftId, identity: identity, muted: false);
  }

  static Future<void> setParticipantMuted({
    required String shiftId,
    required String identity,
    required bool muted,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final callable = _functions.httpsCallable('muteLiveKitParticipant');
      await callable.call({
        'shiftId': shiftId,
        'identity': identity,
        'muted': muted,
      });
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'LiveKitService: setParticipantMuted Firebase function error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Failed to update participant microphone');
    }
  }

  static Future<void> muteAllParticipants({
    required String shiftId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final callable = _functions.httpsCallable('muteAllLiveKitParticipants');
      await callable.call({'shiftId': shiftId});
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'LiveKitService: muteAllParticipants Firebase function error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Failed to mute participants');
    }
  }

  static Future<void> kickParticipant({
    required String shiftId,
    required String identity,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final callable = _functions.httpsCallable('kickLiveKitParticipant');
      await callable.call({'shiftId': shiftId, 'identity': identity});
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'LiveKitService: kickParticipant Firebase function error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Failed to remove participant');
    }
  }

  static Future<void> setRoomLock({
    required String shiftId,
    required bool locked,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final callable = _functions.httpsCallable('setLiveKitRoomLock');
      await callable.call({'shiftId': shiftId, 'locked': locked});
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'LiveKitService: setRoomLock Firebase function error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Failed to update room lock');
    }
  }

  /// Join a LiveKit class
  ///
  /// This method:
  /// 1. Gets a join token from the backend
  /// 2. Connects to the LiveKit room
  /// 3. Opens the LiveKit call UI
  static Future<void> joinClass(
    BuildContext context,
    TeachingShift shift, {
    bool isTeacher = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showError(context, 'You must be logged in to join the class');
      return;
    }

    // Check if class is joinable
    if (!canJoinClass(shift)) {
      final timeUntil = getTimeUntilCanJoin(shift);
      if (timeUntil != null) {
        final minutes = timeUntil.inMinutes;
        _showInfo(
          context,
          'Class opens in $minutes minute${minutes == 1 ? '' : 's'}',
        );
      } else {
        _showError(context, 'This class has ended');
      }
      return;
    }

    // On iOS, skip permission_handler and let LiveKit request permissions natively
    // This ensures the proper iOS system prompt appears
    // On Android, pre-request permissions for better UX
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final hasPermissions = await requestPermissionsWithDialog(context);
      if (!hasPermissions) {
        return; // Dialog already shown to user
      }
    }
    // On iOS, LiveKit will trigger the native permission prompt when enabling camera/mic

    // Show loading indicator
    if (context.mounted) {
      showDialog(
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
                    child:
                        Text(AppLocalizations.of(context)!.connectingToClass)),
              ],
            ),
          ),
        ),
      );
    }

    try {
      // Get join token from backend
      final joinResult = await getJoinToken(shift.id);

      // Dismiss loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!joinResult.success) {
        if (context.mounted) {
          _showError(context, joinResult.error ?? 'Failed to connect');
        }
        return;
      }

      // Navigate to the LiveKit call screen
      if (context.mounted) {
        final isModerator = isTeacher ||
            joinResult.userRole == 'teacher' ||
            joinResult.userRole == 'admin';
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveKitCallScreen(
              livekitUrl: joinResult.livekitUrl!,
              token: joinResult.token!,
              roomName: joinResult.roomName!,
              displayName: joinResult.displayName ?? 'Participant',
              isTeacher: isModerator,
              userRole: joinResult.userRole,
              shiftId: shift.id,
              shiftName: shift.displayName,
              initialRoomLocked: joinResult.roomLocked,
            ),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog if still showing
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showError(context, 'Failed to join class: $e');
      }
      AppLogger.error('LiveKitService: Error joining class: $e');
    }
  }

  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// LiveKit call screen - provides the video call UI
class LiveKitCallScreen extends StatefulWidget {
  final String livekitUrl;
  final String token;
  final String roomName;
  final String displayName;
  final bool isTeacher;
  final String shiftId;
  final String shiftName;
  final bool initialRoomLocked;
  final bool isAudioOnlyMode;
  final String? userRole;

  const LiveKitCallScreen({
    super.key,
    required this.livekitUrl,
    required this.token,
    required this.roomName,
    required this.displayName,
    required this.isTeacher,
    this.shiftId = '',
    this.shiftName = 'Call',
    this.initialRoomLocked = false,
    this.isAudioOnlyMode = false,
    this.userRole,
  });

  @override
  State<LiveKitCallScreen> createState() => _LiveKitCallScreenState();
}

class _LiveKitCallScreenState extends State<LiveKitCallScreen>
    with WidgetsBindingObserver {
  static const String _hostControlTopic = 'alluwal_host_control';
  static const String _whiteboardTopic = 'alluwal_whiteboard';
  static const Duration _pointerSendThrottle = Duration(milliseconds: 50);
  static const Duration _pointerHideDelay = Duration(milliseconds: 1200);
  static const int _maxReconnectAttempts = 2;

  final LiveKitSessionService _sessionService = LiveKitSessionService();
  Room? _room;
  LocalParticipant? _localParticipant;
  EventsListener<RoomEvent>? _listener;

  late String _currentToken;
  late String _currentLivekitUrl;
  bool _manualDisconnect = false;
  bool _reconnecting = false;
  int _reconnectAttempts = 0;
  DateTime? _lastRecordingEnsureAt;
  DateTime? _connectedAt;

  DateTime? _lastPointerSentAt;
  Timer? _pointerSendTimer;
  Offset? _pendingPointerPosition;
  bool _pendingPointerVisible = false;
  Offset? _lastPointerPosition;

  Offset? _remotePointerPosition;
  bool _remotePointerVisible = false;
  String? _remotePointerIdentity;
  Timer? _remotePointerHideTimer;

  bool _connecting = true;
  bool _initializingMedia =
      false; // True while camera/mic are being enabled on join
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _screenShareEnabled = false;
  bool _submittingClassIssueReport = false;
  bool _roomLocked = false;
  bool _studentMicrophonesLocked = false;
  bool _micLockedByHost = false;
  bool _showParticipantsOverlay = true;
  Offset _participantsOverlayOffset = const Offset(16, 16);
  bool _isScreenShareFullscreen = false;
  bool _screenShareUiVisible = true;
  VideoViewFit _screenShareFit = VideoViewFit.contain;
  final TransformationController _screenShareTransformController =
      TransformationController();
  TapDownDetails? _screenShareDoubleTapDetails;
  String? _activeScreenShareIdentity;
  bool _overlayAutoHiddenForShare = false;
  Timer? _screenShareUiHideTimer;
  String? _error;

  String _resolvedSessionRole() {
    final normalized = widget.userRole?.trim().toLowerCase();
    if (normalized == 'teacher' ||
        normalized == 'student' ||
        normalized == 'parent' ||
        normalized == 'admin' ||
        normalized == 'guest') {
      return normalized!;
    }
    return widget.isTeacher ? 'teacher' : 'student';
  }

  rtc.RTCVideoRenderer? _pipRenderer;
  VideoTrack? _pipTrack;
  String? _pipIdentity;
  bool _pipBusy = false;

  // No-show detection for students (teacher didn't arrive)
  Timer? _noShowCheckTimer;
  Timer? _noShowAutoSendTimer;
  bool _noShowDialogShown = false;
  bool _noShowReportSent = false;
  static const Duration _noShowCheckDelay = Duration(minutes: 5);
  static const Duration _noShowAutoSendDelay = Duration(seconds: 30);

  // No-show detection for teachers (students didn't arrive) - web only
  Timer? _studentNoShowCheckTimer;
  Timer? _studentNoShowAutoSendTimer;
  bool _studentNoShowDialogShown = false;
  bool _studentNoShowReportSent = false;

  // Audio playback state (for recovery after reconnection)
  bool _audioPlaybackAllowed = true;
  final List<Map<String, dynamic>> _recentLiveKitAudioEvents = [];

  // Whiteboard state (web only)
  bool _whiteboardEnabled = false;
  bool _studentDrawingEnabled = false; // Controlled by teacher
  final StreamController<Map<String, dynamic>> _whiteboardProjectController =
      StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? _lastWhiteboardProject;
  List<Map<String, dynamic>>?
      _initialWhiteboardStrokes; // Loaded from Firestore
  bool _whiteboardStateSaving = false; // Debounce flag for Firestore saves

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentToken = widget.token;
    _currentLivekitUrl = widget.livekitUrl;
    _roomLocked = widget.initialRoomLocked;
    AppLogger.breadcrumb(
      'livekit_screen_init shift=${widget.shiftId} room=${widget.roomName}',
    );
    _connectToRoom();
    _startNoShowDetection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.breadcrumb(
      'livekit_app_lifecycle state=$state shift=${widget.shiftId} room=${widget.roomName}',
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreAudioAfterResume());
    }
  }

  Future<void> _restoreAudioAfterResume() async {
    await _ensureAudioPlayback();

    final local = _localParticipant;
    if (local == null || !_micEnabled) return;

    try {
      await local.setMicrophoneEnabled(true);
      _syncLocalMediaState();
    } catch (e) {
      AppLogger.warning(
          'LiveKit: Failed to restore microphone after resume: $e');
    }
  }

  String _diagnosticSnapshot({
    DisconnectReason? reason,
    String? trigger,
    String? extra,
  }) {
    final room = _room;
    final localIdentity = room?.localParticipant?.identity ?? 'none';
    final remoteParticipantCount = room?.remoteParticipants.length ?? 0;
    final connectedFor = _connectedAt == null
        ? 'not_connected'
        : DateTime.now().difference(_connectedAt!).inSeconds.toString();
    final webRuntime = kIsWeb ? web_runtime.buildRuntimeDiagnostic() : '';

    return [
      'shiftId=${widget.shiftId}',
      'room=${widget.roomName}',
      'role=${_resolvedSessionRole()}',
      'isTeacher=${widget.isTeacher}',
      'audioOnly=${widget.isAudioOnlyMode}',
      'manualDisconnect=$_manualDisconnect',
      'connecting=$_connecting',
      'reconnecting=$_reconnecting',
      'reconnectAttempts=$_reconnectAttempts',
      'roomLocked=$_roomLocked',
      'reason=${reason?.name ?? 'none'}',
      'trigger=${trigger ?? 'none'}',
      'localIdentity=$localIdentity',
      'remoteParticipantCount=$remoteParticipantCount',
      'connectedForSeconds=$connectedFor',
      if (webRuntime.isNotEmpty) 'web=$webRuntime',
      if (extra != null && extra.isNotEmpty) 'extra=$extra',
    ].join(' ');
  }

  dynamic _readPublicationField(dynamic pub, dynamic Function(dynamic) read) {
    try {
      return read(pub);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _audioPublicationDiagnostic(dynamic pub) {
    final source = _readPublicationField(pub, (p) => p.source);
    final track = _readPublicationField(pub, (p) => p.track);

    return {
      'sid': _readPublicationField(pub, (p) => p.sid),
      'name': _readPublicationField(pub, (p) => p.name),
      'muted': _readPublicationField(pub, (p) => p.muted),
      'subscribed': _readPublicationField(pub, (p) => p.subscribed),
      'subscriptionAllowed':
          _readPublicationField(pub, (p) => p.subscriptionAllowed),
      'source': _readPublicationField(source, (s) => s.name),
      'hasTrack': track != null,
      'trackMuted': _readPublicationField(track, (t) => t.muted),
    };
  }

  bool _audioPublicationLooksAudible(dynamic pub) {
    final track = _readPublicationField(pub, (p) => p.track);
    return _readPublicationField(pub, (p) => p.muted) != true &&
        _readPublicationField(pub, (p) => p.subscribed) != false &&
        track != null &&
        _readPublicationField(track, (t) => t.muted) != true;
  }

  Map<String, dynamic>? _audioSourceStatsDiagnostic(dynamic stats) {
    if (stats == null) return null;
    return {
      'audioLevel': _readPublicationField(stats, (s) => s.audioLevel),
      'totalAudioEnergy':
          _readPublicationField(stats, (s) => s.totalAudioEnergy),
      'totalSamplesDuration':
          _readPublicationField(stats, (s) => s.totalSamplesDuration),
      'echoReturnLoss': _readPublicationField(stats, (s) => s.echoReturnLoss),
      'echoReturnLossEnhancement':
          _readPublicationField(stats, (s) => s.echoReturnLossEnhancement),
      'trackIdentifier': _readPublicationField(stats, (s) => s.trackIdentifier),
      'remoteSource': _readPublicationField(stats, (s) => s.remoteSource),
    };
  }

  Map<String, dynamic> _audioSenderStatsDiagnostic(dynamic stats) {
    return {
      'direction': 'outbound',
      'streamId': _readPublicationField(stats, (s) => s.streamId),
      'timestamp': _readPublicationField(stats, (s) => s.timestamp),
      'packetsSent': _readPublicationField(stats, (s) => s.packetsSent),
      'bytesSent': _readPublicationField(stats, (s) => s.bytesSent),
      'packetsLost': _readPublicationField(stats, (s) => s.packetsLost),
      'roundTripTime': _readPublicationField(stats, (s) => s.roundTripTime),
      'jitter': _readPublicationField(stats, (s) => s.jitter),
      'mimeType': _readPublicationField(stats, (s) => s.mimeType),
      'payloadType': _readPublicationField(stats, (s) => s.payloadType),
      'channels': _readPublicationField(stats, (s) => s.channels),
      'clockRate': _readPublicationField(stats, (s) => s.clockRate),
      'audioSourceStats': _audioSourceStatsDiagnostic(
        _readPublicationField(stats, (s) => s.audioSourceStats),
      ),
    };
  }

  Map<String, dynamic> _audioReceiverStatsDiagnostic(dynamic stats) {
    return {
      'direction': 'inbound',
      'streamId': _readPublicationField(stats, (s) => s.streamId),
      'timestamp': _readPublicationField(stats, (s) => s.timestamp),
      'packetsReceived': _readPublicationField(stats, (s) => s.packetsReceived),
      'bytesReceived': _readPublicationField(stats, (s) => s.bytesReceived),
      'packetsLost': _readPublicationField(stats, (s) => s.packetsLost),
      'jitter': _readPublicationField(stats, (s) => s.jitter),
      'jitterBufferDelay':
          _readPublicationField(stats, (s) => s.jitterBufferDelay),
      'concealedSamples':
          _readPublicationField(stats, (s) => s.concealedSamples),
      'concealmentEvents':
          _readPublicationField(stats, (s) => s.concealmentEvents),
      'silentConcealedSamples':
          _readPublicationField(stats, (s) => s.silentConcealedSamples),
      'silentConcealmentEvents':
          _readPublicationField(stats, (s) => s.silentConcealmentEvents),
      'totalAudioEnergy':
          _readPublicationField(stats, (s) => s.totalAudioEnergy),
      'totalSamplesDuration':
          _readPublicationField(stats, (s) => s.totalSamplesDuration),
      'mimeType': _readPublicationField(stats, (s) => s.mimeType),
      'payloadType': _readPublicationField(stats, (s) => s.payloadType),
      'channels': _readPublicationField(stats, (s) => s.channels),
      'clockRate': _readPublicationField(stats, (s) => s.clockRate),
      'audioSourceStats': _audioSourceStatsDiagnostic(
        _readPublicationField(stats, (s) => s.audioSourceStats),
      ),
    };
  }

  Future<Map<String, dynamic>?> _audioTrackStatsDiagnostic(
      dynamic track) async {
    if (track == null) return null;
    try {
      if (track is LocalAudioTrack) {
        final stats = await track
            .getSenderStats()
            .timeout(const Duration(milliseconds: 1800));
        if (stats == null) return {'direction': 'outbound', 'available': false};
        return _audioSenderStatsDiagnostic(stats);
      }
      if (track is RemoteAudioTrack) {
        final stats = await track
            .getReceiverStats()
            .timeout(const Duration(milliseconds: 1800));
        if (stats == null) return {'direction': 'inbound', 'available': false};
        return _audioReceiverStatsDiagnostic(stats);
      }
    } catch (e) {
      return {
        'available': false,
        'error': e.toString(),
      };
    }
    return {'available': false, 'trackType': track.runtimeType.toString()};
  }

  Future<Map<String, dynamic>> _audioPublicationDiagnosticWithStats(
    dynamic pub,
  ) async {
    final diagnostic = _audioPublicationDiagnostic(pub);
    diagnostic['webRtcStats'] = await _audioTrackStatsDiagnostic(
      _readPublicationField(pub, (p) => p.track),
    );
    return diagnostic;
  }

  Map<String, dynamic> _videoPublicationDiagnostic(dynamic pub) {
    final source = _readPublicationField(pub, (p) => p.source);
    final track = _readPublicationField(pub, (p) => p.track);
    final name = _readPublicationField(pub, (p) => p.name)?.toString() ?? '';
    final isScreenShare =
        _readPublicationField(pub, (p) => p.isScreenShare) == true ||
            source == TrackSource.screenShareVideo ||
            name.toLowerCase().contains('screen');

    return {
      'sid': _readPublicationField(pub, (p) => p.sid),
      'name': name,
      'muted': _readPublicationField(pub, (p) => p.muted),
      'subscribed': _readPublicationField(pub, (p) => p.subscribed),
      'subscriptionAllowed':
          _readPublicationField(pub, (p) => p.subscriptionAllowed),
      'source': _readPublicationField(source, (s) => s.name),
      'isScreenShare': isScreenShare,
      'hasTrack': track != null,
      'trackMuted': _readPublicationField(track, (t) => t.muted),
      'trackType': track?.runtimeType.toString(),
    };
  }

  Future<Map<String, dynamic>> _participantDiagnostic(
    Participant participant,
  ) async {
    final audioPublications = participant.audioTrackPublications.toList();
    final videoPublications = participant.videoTrackPublications.toList();
    final audioDiagnostics = await Future.wait(
      audioPublications.map(_audioPublicationDiagnosticWithStats),
    );
    final videoDiagnostics =
        videoPublications.map(_videoPublicationDiagnostic).toList();
    return {
      'identity': participant.identity,
      'name': participant.name,
      'metadata': participant.metadata,
      'isLocal': participant is LocalParticipant,
      'isSpeaking': participant.isSpeaking,
      'connectionQuality': participant.connectionQuality.name,
      'audioPublicationCount': audioPublications.length,
      'hasAudibleAudioPublication':
          audioPublications.any(_audioPublicationLooksAudible),
      'hasPublishedAudio': audioPublications.any((pub) => pub.muted != true),
      'audioPublications': audioDiagnostics,
      'videoPublicationCount': videoPublications.length,
      'hasCameraPublication': videoDiagnostics.any(
        (pub) => pub['isScreenShare'] != true,
      ),
      'hasActiveCameraPublication': videoDiagnostics.any(
        (pub) =>
            pub['isScreenShare'] != true &&
            pub['muted'] != true &&
            pub['hasTrack'] == true,
      ),
      'hasScreenSharePublication': videoDiagnostics.any(
        (pub) => pub['isScreenShare'] == true,
      ),
      'hasActiveScreenSharePublication': videoDiagnostics.any(
        (pub) =>
            pub['isScreenShare'] == true &&
            pub['muted'] != true &&
            pub['hasTrack'] == true,
      ),
      'videoPublications': videoDiagnostics,
    };
  }

  void _recordLiveKitAudioEvent(
    String event, {
    Participant? participant,
    dynamic publication,
    dynamic track,
    Map<String, dynamic>? extra,
  }) {
    final source = _readPublicationField(publication, (p) => p.source);
    final isAudio = publication == null ||
        source == TrackSource.microphone ||
        _readPublicationField(source, (s) => s.name) == 'microphone';
    if (!isAudio) return;

    _recentLiveKitAudioEvents.add({
      'timestamp': DateTime.now().toIso8601String(),
      'event': event,
      if (participant != null) 'participantIdentity': participant.identity,
      if (participant != null) 'participantName': participant.name,
      if (participant != null)
        'connectionQuality': participant.connectionQuality.name,
      if (publication != null)
        'publication': _audioPublicationDiagnostic(publication),
      if (track != null) 'trackMuted': track.muted,
      if (extra != null) ...extra,
    });

    if (_recentLiveKitAudioEvents.length > 40) {
      _recentLiveKitAudioEvents.removeRange(
        0,
        _recentLiveKitAudioEvents.length - 40,
      );
    }
  }

  List<String> _buildAudioIssueFindings(Room? room) {
    final findings = <String>[];
    final local = room?.localParticipant;
    final remoteParticipants = _nonSystemRemoteParticipants(room);

    if (room == null) {
      findings.add('room_not_initialized');
      return findings;
    }

    if (!room.canPlaybackAudio || !_audioPlaybackAllowed) {
      findings.add('audio_playback_blocked_or_not_started');
    }

    if (_reconnecting || _connecting) {
      findings.add('room_connecting_or_reconnecting');
    }

    if (_micLockedByHost) {
      findings.add('local_microphone_locked_by_host');
    }

    if (local == null) {
      findings.add('local_participant_missing');
    } else {
      final localAudio = local.audioTrackPublications.toList();
      if (_micEnabled && localAudio.isEmpty) {
        findings.add('local_mic_enabled_in_ui_but_no_audio_publication');
      } else if (_micEnabled &&
          !localAudio.any(_audioPublicationLooksAudible)) {
        findings.add('local_mic_enabled_but_audio_track_not_active');
      } else if (!_micEnabled) {
        findings.add('local_mic_disabled_in_ui');
      }

      if (local.connectionQuality == ConnectionQuality.poor ||
          local.connectionQuality == ConnectionQuality.lost) {
        findings
            .add('local_connection_quality_${local.connectionQuality.name}');
      }
    }

    if (remoteParticipants.isEmpty) {
      findings.add('no_remote_participants_visible');
    }

    final remoteWithNoAudio = <String>[];
    final remoteMuted = <String>[];
    final remoteNotSubscribed = <String>[];
    final remoteNoTrack = <String>[];
    final remotePoorQuality = <String>[];

    for (final participant in remoteParticipants) {
      final audioPublications = participant.audioTrackPublications.toList();
      if (audioPublications.isEmpty) {
        remoteWithNoAudio.add(participant.identity);
      }
      if (participant.connectionQuality == ConnectionQuality.poor ||
          participant.connectionQuality == ConnectionQuality.lost) {
        remotePoorQuality.add(
            '${participant.identity}:${participant.connectionQuality.name}');
      }
      for (final pub in audioPublications) {
        if (pub.muted == true) remoteMuted.add(participant.identity);
        if (pub.subscribed == false) {
          remoteNotSubscribed.add(participant.identity);
        }
        if (pub.track == null) remoteNoTrack.add(participant.identity);
      }
    }

    if (remoteWithNoAudio.isNotEmpty) {
      findings.add(
          'remote_participants_without_audio=${remoteWithNoAudio.join(',')}');
    }
    if (remoteMuted.isNotEmpty) {
      findings.add('remote_audio_muted=${remoteMuted.toSet().join(',')}');
    }
    if (remoteNotSubscribed.isNotEmpty) {
      findings.add(
          'remote_audio_not_subscribed=${remoteNotSubscribed.toSet().join(',')}');
    }
    if (remoteNoTrack.isNotEmpty) {
      findings.add(
          'remote_audio_publication_has_no_track=${remoteNoTrack.toSet().join(',')}');
    }
    if (remotePoorQuality.isNotEmpty) {
      findings.add(
          'remote_connection_quality_issue=${remotePoorQuality.join(',')}');
    }

    return findings;
  }

  List<String> _buildWebRtcStatsFindings(
    Map<String, dynamic>? localParticipant,
    List<Map<String, dynamic>> remoteParticipants,
  ) {
    final findings = <String>[];

    final localAudio = (localParticipant?['audioPublications'] as List?)
            ?.whereType<Map>()
            .toList() ??
        const <Map>[];
    for (final pub in localAudio) {
      final stats = pub['webRtcStats'];
      if (stats is! Map || stats['direction'] != 'outbound') continue;
      final bytesSent = (stats['bytesSent'] as num?) ?? 0;
      final packetsSent = (stats['packetsSent'] as num?) ?? 0;
      final source = stats['audioSourceStats'];
      final audioEnergy = source is Map
          ? (source['totalAudioEnergy'] as num?)
          : (stats['totalAudioEnergy'] as num?);
      if (bytesSent <= 0 || packetsSent <= 0) {
        findings.add('local_outbound_audio_no_packets_or_bytes');
      }
      if (audioEnergy != null && audioEnergy <= 0) {
        findings.add('local_microphone_audio_energy_zero');
      }
    }

    for (final participant in remoteParticipants) {
      final identity = participant['identity']?.toString() ?? 'unknown';
      final audio = (participant['audioPublications'] as List?)
              ?.whereType<Map>()
              .toList() ??
          const <Map>[];
      for (final pub in audio) {
        final stats = pub['webRtcStats'];
        if (stats is! Map || stats['direction'] != 'inbound') continue;
        final bytesReceived = (stats['bytesReceived'] as num?) ?? 0;
        final packetsReceived = (stats['packetsReceived'] as num?) ?? 0;
        final packetsLost = (stats['packetsLost'] as num?) ?? 0;
        final concealedSamples = (stats['concealedSamples'] as num?) ?? 0;
        if (bytesReceived <= 0 || packetsReceived <= 0) {
          findings.add('remote_inbound_audio_no_packets_or_bytes=$identity');
        }
        if (packetsLost > 0) {
          findings
              .add('remote_inbound_audio_packets_lost=$identity:$packetsLost');
        }
        if (concealedSamples > 0) {
          findings.add(
              'remote_inbound_audio_concealment=$identity:$concealedSamples');
        }
      }
    }

    return findings;
  }

  List<String> _buildClassIssueFindings(
    Room? room,
    Map<String, dynamic>? localParticipant,
    List<Map<String, dynamic>> remoteParticipants,
  ) {
    final findings = <String>[];

    if (room == null) {
      findings.add('room_not_initialized');
      return findings;
    }

    if (_roomLocked) findings.add('room_locked');
    if (_studentMicrophonesLocked) findings.add('student_microphones_locked');
    if (_manualDisconnect) findings.add('manual_disconnect_in_progress');
    if (_connecting || _reconnecting) {
      findings.add('room_connecting_or_reconnecting');
    }

    if (_cameraEnabled &&
        localParticipant != null &&
        localParticipant['hasActiveCameraPublication'] != true) {
      findings.add('local_camera_enabled_but_no_active_video_track');
    }

    if (_screenShareEnabled &&
        localParticipant != null &&
        localParticipant['hasActiveScreenSharePublication'] != true) {
      findings.add('local_screen_share_enabled_but_no_active_track');
    }

    if (_whiteboardEnabled && _whiteboardStateSaving) {
      findings.add('whiteboard_state_save_in_progress');
    }

    if (_whiteboardEnabled && !widget.isTeacher && !_studentDrawingEnabled) {
      findings.add('student_whiteboard_drawing_disabled');
    }

    final remoteNoCamera = <String>[];
    final remoteVideoNoTrack = <String>[];
    final remoteScreenShareNoTrack = <String>[];

    for (final participant in remoteParticipants) {
      final identity = participant['identity']?.toString() ?? 'unknown';
      final videoPublications = (participant['videoPublications'] as List?)
              ?.whereType<Map>()
              .toList() ??
          const <Map>[];

      final hasActiveCamera = videoPublications.any(
        (pub) =>
            pub['isScreenShare'] != true &&
            pub['muted'] != true &&
            pub['hasTrack'] == true,
      );
      if (!hasActiveCamera) remoteNoCamera.add(identity);

      for (final pub in videoPublications) {
        if (pub['muted'] == true) continue;
        if (pub['hasTrack'] == true) continue;
        if (pub['isScreenShare'] == true) {
          remoteScreenShareNoTrack.add(identity);
        } else {
          remoteVideoNoTrack.add(identity);
        }
      }
    }

    if (remoteNoCamera.isNotEmpty) {
      findings.add(
          'remote_participants_without_active_camera=${remoteNoCamera.toSet().join(',')}');
    }
    if (remoteVideoNoTrack.isNotEmpty) {
      findings.add(
          'remote_video_publication_missing_track=${remoteVideoNoTrack.toSet().join(',')}');
    }
    if (remoteScreenShareNoTrack.isNotEmpty) {
      findings.add(
          'remote_screen_share_publication_missing_track=${remoteScreenShareNoTrack.toSet().join(',')}');
    }

    return findings;
  }

  Future<Map<String, dynamic>> _buildClassReportDiagnostics({
    String? issueType,
    String? note,
    String? trigger,
  }) async {
    final room = _room;
    final local = room?.localParticipant;
    final remoteParticipants = _nonSystemRemoteParticipants(room);
    final localParticipantDiagnostic =
        local == null ? null : await _participantDiagnostic(local);
    final remoteParticipantDiagnostics = await Future.wait(
      remoteParticipants.map(_participantDiagnostic),
    );
    final reportingContext = ErrorReportingService.reportingContext(
      shiftId: widget.shiftId,
      roomName: widget.roomName,
    );

    return {
      'schemaVersion': 1,
      'issueType': issueType,
      if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      'trigger': trigger,
      'shiftId': widget.shiftId,
      'shiftName': widget.shiftName,
      'roomName': widget.roomName,
      'reporterName': widget.displayName,
      'reporterRole': _resolvedSessionRole(),
      'isTeacher': widget.isTeacher,
      'audioOnly': widget.isAudioOnlyMode,
      'appSessionId': reportingContext['appSessionId'],
      'platform': reportingContext['platform'],
      'clientTimestamp': reportingContext['clientTimestamp'],
      'webRuntime': kIsWeb ? web_runtime.buildRuntimeDiagnostic() : null,
      'canPlaybackAudio': room?.canPlaybackAudio,
      'audioPlaybackAllowedState': _audioPlaybackAllowed,
      'micEnabledInUi': _micEnabled,
      'cameraEnabledInUi': _cameraEnabled,
      'connecting': _connecting,
      'reconnecting': _reconnecting,
      'reconnectAttempts': _reconnectAttempts,
      'manualDisconnect': _manualDisconnect,
      'roomLocked': _roomLocked,
      'studentMicrophonesLocked': _studentMicrophonesLocked,
      'micLockedByHost': _micLockedByHost,
      'screenShareEnabledInUi': _screenShareEnabled,
      'screenShareFit': _screenShareFit.name,
      'screenShareUiVisible': _screenShareUiVisible,
      'screenShareFullscreen': _isScreenShareFullscreen,
      'whiteboardEnabled': _whiteboardEnabled,
      'studentDrawingEnabled': _studentDrawingEnabled,
      'whiteboardStateSaving': _whiteboardStateSaving,
      'showParticipantsOverlay': _showParticipantsOverlay,
      'connectedForSeconds': _connectedAt == null
          ? null
          : DateTime.now().difference(_connectedAt!).inSeconds,
      'localParticipant': localParticipantDiagnostic,
      'remoteParticipantCount': remoteParticipants.length,
      'remoteParticipants': remoteParticipantDiagnostics,
      'clientAudioFindings': [
        ..._buildAudioIssueFindings(room),
        ..._buildWebRtcStatsFindings(
          localParticipantDiagnostic,
          remoteParticipantDiagnostics,
        ),
      ],
      'clientClassFindings': _buildClassIssueFindings(
        room,
        localParticipantDiagnostic,
        remoteParticipantDiagnostics,
      ),
      'recentLiveKitAudioEvents':
          List<Map<String, dynamic>>.from(_recentLiveKitAudioEvents),
      'diagnosticSnapshot':
          _diagnosticSnapshot(trigger: trigger, extra: issueType),
      'recentBreadcrumbs': reportingContext['recentBreadcrumbs'],
    };
  }

  void _logLiveKitDiagnostic(
    String event, {
    DisconnectReason? reason,
    String? trigger,
    String? extra,
    StackTrace? stackTrace,
  }) {
    final message =
        'LiveKit diagnostic: $event ${_diagnosticSnapshot(reason: reason, trigger: trigger, extra: extra)}';
    AppLogger.diagnostic(
      message,
      context: 'livekit_$event',
      stackTrace: stackTrace,
    );
  }

  void _startNoShowDetection() {
    // For students: check if teacher arrives within 5 minutes
    if (!widget.isTeacher) {
      _noShowCheckTimer = Timer(_noShowCheckDelay, _checkTeacherPresence);
    }
    // For teachers on web: check if any student arrives within 5 minutes
    else if (kIsWeb) {
      _studentNoShowCheckTimer =
          Timer(_noShowCheckDelay, _checkStudentPresence);
    }
  }

  void _cancelNoShowTimers() {
    _noShowCheckTimer?.cancel();
    _noShowAutoSendTimer?.cancel();
    _studentNoShowCheckTimer?.cancel();
    _studentNoShowAutoSendTimer?.cancel();
  }

  bool _isSystemParticipantIdentity(String? identity) {
    final normalized = identity?.trim().toUpperCase() ?? '';
    return normalized.startsWith('EG_');
  }

  List<RemoteParticipant> _nonSystemRemoteParticipants([Room? room]) {
    final targetRoom = room ?? _room;
    if (targetRoom == null) return <RemoteParticipant>[];
    return targetRoom.remoteParticipants.values
        .where((participant) =>
            !_isSystemParticipantIdentity(participant.identity))
        .toList();
  }

  bool _isTeacherInRoom() {
    // Check if any remote participant is a teacher
    // Teachers have identity containing "teacher" or are the host
    final remoteParticipants = _nonSystemRemoteParticipants();
    for (final participant in remoteParticipants) {
      // The identity format is typically "userId_role" or similar
      // Check metadata or identity for teacher indication
      final metadata = participant.metadata;
      if (metadata != null) {
        try {
          final decoded = jsonDecode(metadata);
          if (decoded['role'] == 'teacher' || decoded['isTeacher'] == true) {
            return true;
          }
        } catch (_) {}
      }
      // Fallback: check if participant can lock room (teacher capability)
      // For now, assume if there's any remote participant and room is locked by them, they're the teacher
    }
    return false;
  }

  bool _areStudentsInRoom() {
    // Check if any students are in the room
    final remoteParticipants = _nonSystemRemoteParticipants();
    return remoteParticipants.isNotEmpty;
  }

  void _checkTeacherPresence() {
    if (!mounted || _noShowDialogShown || _noShowReportSent) return;

    if (!_isTeacherInRoom()) {
      _showTeacherNoShowDialog();
    }
  }

  void _checkStudentPresence() {
    if (!mounted || _studentNoShowDialogShown || _studentNoShowReportSent) {
      return;
    }

    if (!_areStudentsInRoom()) {
      _showStudentNoShowDialog();
    }
  }

  void _showTeacherNoShowDialog() {
    if (!mounted || _noShowDialogShown) return;

    setState(() => _noShowDialogShown = true);

    // Start auto-send timer
    _noShowAutoSendTimer = Timer(_noShowAutoSendDelay, () {
      if (mounted && !_noShowReportSent) {
        _sendNoShowReport(isTeacherNoShow: true);
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.teacherNotHere,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.yourTeacherHasnTJoinedThe,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!
                          .autoSendingReportIn30Seconds,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _noShowAutoSendTimer?.cancel();
                setState(() => _noShowDialogShown = false);
                Navigator.of(dialogContext).pop();
              },
              child: Text(AppLocalizations.of(context)!.teacherArrived),
            ),
            ElevatedButton(
              onPressed: () {
                _noShowAutoSendTimer?.cancel();
                _sendNoShowReport(isTeacherNoShow: true);
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.reportNow),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentNoShowDialog() {
    if (!mounted || _studentNoShowDialogShown) return;

    setState(() => _studentNoShowDialogShown = true);

    // Start auto-send timer
    _studentNoShowAutoSendTimer = Timer(_noShowAutoSendDelay, () {
      if (mounted && !_studentNoShowReportSent) {
        _sendNoShowReport(isTeacherNoShow: false);
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.noStudentsYet,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.noStudentsHaveJoinedTheClass,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!
                          .autoSendingReportIn30Seconds,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _studentNoShowAutoSendTimer?.cancel();
                setState(() => _studentNoShowDialogShown = false);
                Navigator.of(dialogContext).pop();
              },
              child: Text(AppLocalizations.of(context)!.studentJoined),
            ),
            ElevatedButton(
              onPressed: () {
                _studentNoShowAutoSendTimer?.cancel();
                _sendNoShowReport(isTeacherNoShow: false);
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.reportNow),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendNoShowReport({required bool isTeacherNoShow}) async {
    if (isTeacherNoShow) {
      if (_noShowReportSent) return;
      setState(() => _noShowReportSent = true);
    } else {
      if (_studentNoShowReportSent) return;
      setState(() => _studentNoShowReportSent = true);
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('reportNoShow');
      await callable.call<Map<String, dynamic>>({
        'shiftId': widget.shiftId,
        'shiftName': widget.shiftName,
        'roomName': widget.roomName,
        'reportedBy': FirebaseAuth.instance.currentUser?.uid,
        'reporterName': widget.displayName,
        'reporterRole': _resolvedSessionRole(),
        'isTeacherNoShow': isTeacherNoShow,
        'timestamp': DateTime.now().toIso8601String(),
        'appSessionId': ErrorReportingService.sessionId,
        'diagnostics': await _buildClassReportDiagnostics(
          issueType: isTeacherNoShow ? 'teacher_no_show' : 'student_no_show',
          trigger: 'no_show_report',
        ),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTeacherNoShow
                  ? 'Report sent. Administrators have been notified about the missing teacher.'
                  : 'Report sent. Administrators have been notified about missing students.',
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to send no-show report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.failedToSendReportPleaseTry),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showClassIssueReportDialog() async {
    if (_submittingClassIssueReport) return;

    final selectedIssues = <String>{_classIssueOptions.first.code};
    final noteController = TextEditingController();

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categories =
              _classIssueOptions.map((option) => option.category).toSet();
          return AlertDialog(
            title: const Text('Report class issue'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select all that apply',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final category in categories) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in _classIssueOptions.where(
                            (option) => option.category == category,
                          ))
                            FilterChip(
                              label: Text(option.label),
                              selected: selectedIssues.contains(option.code),
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedIssues.add(option.code);
                                  } else if (selectedIssues.length > 1) {
                                    selectedIssues.remove(option.code);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Selected',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final code in selectedIssues)
                            Chip(
                              label: Text(
                                _classIssueOptions
                                    .firstWhere((option) => option.code == code)
                                    .label,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'What happened?',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: selectedIssues.isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.send),
                label: Text(
                  selectedIssues.length <= 1
                      ? 'Send report'
                      : 'Send ${selectedIssues.length} issues',
                ),
              ),
            ],
          );
        },
      ),
    );

    if (shouldSubmit != true) {
      noteController.dispose();
      return;
    }

    final note = noteController.text;
    noteController.dispose();
    await _sendClassIssueReport(
      issueTypes: selectedIssues.toList(growable: false),
      note: note,
      trigger: 'user_report_dialog',
    );
  }

  Future<void> _showQuickClassIssueSheet() async {
    if (_submittingClassIssueReport) return;

    final quickOptions = [
      _classIssueOptions.firstWhere((o) => o.code == 'cannot_hear_other'),
      _classIssueOptions.firstWhere((o) => o.code == 'other_cannot_hear_me'),
      _classIssueOptions.firstWhere((o) => o.code == 'camera_not_working'),
      _classIssueOptions.firstWhere((o) => o.code == 'cannot_see_other'),
      _classIssueOptions
          .firstWhere((o) => o.code == 'screen_share_not_working'),
      _classIssueOptions.firstWhere((o) => o.code == 'whiteboard_not_syncing'),
      _classIssueOptions
          .firstWhere((o) => o.code == 'disconnected_or_reconnecting'),
      _classIssueOptions.firstWhere((o) => o.code == 'other_technical_issue'),
    ];

    final selectedIssues = <String>{};

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Report issue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in quickOptions)
                      FilterChip(
                        label: Text(option.label),
                        selected: selectedIssues.contains(option.code),
                        onSelected: (selected) {
                          setSheetState(() {
                            if (selected) {
                              selectedIssues.add(option.code);
                            } else {
                              selectedIssues.remove(option.code);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: selectedIssues.isEmpty
                      ? null
                      : () => Navigator.pop(
                            sheetContext,
                            selectedIssues.toList(growable: false),
                          ),
                  icon: const Icon(Icons.send),
                  label: Text(
                    selectedIssues.length <= 1
                        ? 'Send report'
                        : 'Send ${selectedIssues.length} issues',
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showClassIssueReportDialog();
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('More options'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (selected == null || selected.isEmpty) return;
    await _sendClassIssueReport(
      issueTypes: selected,
      trigger: 'quick_report_sheet',
    );
  }

  Future<void> _sendClassIssueReport({
    required List<String> issueTypes,
    String? note,
    String? trigger,
  }) async {
    if (_submittingClassIssueReport || issueTypes.isEmpty) return;

    final primaryIssueType = issueTypes.first;

    setState(() => _submittingClassIssueReport = true);
    try {
      final diagnostics = await _buildClassReportDiagnostics(
        issueType: primaryIssueType,
        note: note,
        trigger: trigger,
      );
      final callable =
          FirebaseFunctions.instance.httpsCallable('reportClassTechnicalIssue');
      await callable.call<Map<String, dynamic>>({
        'shiftId': widget.shiftId,
        'shiftName': widget.shiftName,
        'roomName': widget.roomName,
        'reportedBy': FirebaseAuth.instance.currentUser?.uid,
        'reporterName': widget.displayName,
        'reporterRole': _resolvedSessionRole(),
        'issueType': primaryIssueType,
        'issueTypes': issueTypes,
        'note': note?.trim(),
        'timestamp': DateTime.now().toIso8601String(),
        'appSessionId': ErrorReportingService.sessionId,
        'diagnostics': diagnostics,
      });

      AppLogger.diagnostic(
        'LiveKit class issue report submitted ${_diagnosticSnapshot(trigger: trigger, extra: issueTypes.join(','))}',
        context: 'livekit_class_issue_report',
      );
      if (mounted) {
        _showSnack(
          issueTypes.length <= 1 ? 'Issue report sent' : 'Issue reports sent',
          backgroundColor: Colors.green.shade600,
        );
      }
    } catch (e) {
      AppLogger.error(
        'Failed to send class issue report: $e',
        error: e,
        stackTrace: StackTrace.current,
        context: 'livekit_class_issue_report_failed',
      );
      if (mounted) {
        _showSnack(
          'Failed to send report. Please try again.',
          backgroundColor: Colors.red.shade600,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submittingClassIssueReport = false);
      }
    }
  }

  bool _participantHasMicOn(Participant p) {
    for (final pub in p.audioTrackPublications) {
      if (!pub.muted) return true;
    }
    return false;
  }

  bool _participantHasCameraOn(Participant p) {
    for (final pub in p.videoTrackPublications) {
      if (!pub.muted &&
          !pub.isScreenShare &&
          pub.source == TrackSource.camera) {
        return true;
      }
    }
    return false;
  }

  bool _participantHasScreenShareOn(Participant p) {
    for (final pub in p.videoTrackPublications) {
      if (!pub.muted && pub.isScreenShare) return true;
    }
    return false;
  }

  void _syncLocalMediaState() {
    if (!mounted) return;
    final local = _localParticipant;
    if (local == null) return;

    final nextMic = _participantHasMicOn(local);
    final nextCam = _participantHasCameraOn(local);
    final nextScreen = _participantHasScreenShareOn(local);

    if (_micEnabled == nextMic &&
        _cameraEnabled == nextCam &&
        _screenShareEnabled == nextScreen) {
      return;
    }

    setState(() {
      _micEnabled = nextMic;
      _cameraEnabled = nextCam;
      _screenShareEnabled = nextScreen;
    });
  }

  bool _shouldAttemptReconnect(DisconnectReason? reason) {
    if (_manualDisconnect) return false;
    switch (reason) {
      case DisconnectReason.clientInitiated:
      case DisconnectReason.participantRemoved:
      case DisconnectReason.roomDeleted:
      case DisconnectReason.duplicateIdentity:
      case DisconnectReason.joinFailure:
        return false;
      default:
        return true;
    }
  }

  String _disconnectDialogTitle(DisconnectReason? reason) {
    switch (reason) {
      case DisconnectReason.duplicateIdentity:
        return 'Signed in somewhere else';
      case DisconnectReason.participantRemoved:
        return 'Removed from class';
      case DisconnectReason.roomDeleted:
        return 'Class ended';
      case DisconnectReason.joinFailure:
        return 'Could not join class';
      case DisconnectReason.signalingConnectionFailure:
        return 'Class connection lost';
      case DisconnectReason.reconnectAttemptsExceeded:
        return 'Could not reconnect';
      default:
        return 'Class connection ended';
    }
  }

  String _disconnectDialogMessage(DisconnectReason? reason) {
    switch (reason) {
      case DisconnectReason.duplicateIdentity:
        return 'This class was closed because the same account joined from another device or browser tab.';
      case DisconnectReason.participantRemoved:
        return 'You were removed from this class by the host.';
      case DisconnectReason.roomDeleted:
        return 'This class is no longer available.';
      case DisconnectReason.joinFailure:
        return 'The class could not finish connecting. This usually means the browser or network blocked the media connection.';
      case DisconnectReason.stateMismatch:
        return 'The class connection fell out of sync and had to close.';
      case DisconnectReason.serverShutdown:
        return 'The class connection ended because the call server restarted.';
      case DisconnectReason.signalingConnectionFailure:
        return 'The class connection dropped because the browser could no longer reach the call server.';
      case DisconnectReason.reconnectAttemptsExceeded:
        return 'The class connection could not recover after several retry attempts.';
      case DisconnectReason.disconnected:
        return 'The class connection was closed before media could recover.';
      default:
        final name = reason?.name ?? 'unknown';
        return 'The class connection ended unexpectedly ($name).';
    }
  }

  Future<void> _showUnexpectedDisconnectDialog(DisconnectReason? reason) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_disconnectDialogTitle(reason)),
          content: Text(_disconnectDialogMessage(reason)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _disposeRoom() async {
    try {
      // Explicitly stop mic and camera before disposing
      try {
        await _localParticipant?.setMicrophoneEnabled(false);
        await _localParticipant?.setCameraEnabled(false);
      } catch (e) {
        AppLogger.warning('LiveKit: Error disabling media in disposeRoom: $e');
      }

      _listener?.dispose();
      _listener = null;
      await _room?.disconnect();
      await _room?.dispose();
    } catch (e) {
      AppLogger.error('LiveKit: Error disposing room: $e');
    } finally {
      _room = null;
      _localParticipant = null;
    }
  }

  Future<void> _attemptReconnect(DisconnectReason? reason) async {
    if (_reconnecting || _manualDisconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logLiveKitDiagnostic(
        'reconnect_exhausted',
        reason: reason,
        extra: 'maxReconnectAttempts=$_maxReconnectAttempts',
      );
      if (mounted) {
        setState(() {
          _reconnecting = false;
          _connecting = false;
          _error = 'Connection lost. Please rejoin the class.';
        });
      }
      return;
    }

    _reconnectAttempts += 1;
    _logLiveKitDiagnostic(
      'reconnect_attempt_started',
      reason: reason,
      extra: 'attempt=$_reconnectAttempts',
    );
    if (mounted) {
      setState(() {
        _reconnecting = true;
        _connecting = true;
        _error = null;
      });
    }

    await _disposeRoom();

    try {
      final joinResult = await LiveKitService.getJoinToken(widget.shiftId);
      if (!joinResult.success ||
          joinResult.token == null ||
          joinResult.livekitUrl == null) {
        if (mounted) {
          setState(() {
            _reconnecting = false;
            _connecting = false;
            _error = joinResult.error ?? 'Failed to reconnect to the class.';
          });
        }
        return;
      }

      _currentToken = joinResult.token!;
      _currentLivekitUrl = joinResult.livekitUrl!;
      _roomLocked = joinResult.roomLocked;
      if (!mounted) return;
      await _connectToRoom();
    } catch (e) {
      _logLiveKitDiagnostic(
        'reconnect_attempt_failed',
        reason: reason,
        extra: 'attempt=$_reconnectAttempts error=$e',
        stackTrace: StackTrace.current,
      );
      AppLogger.error(
        'LiveKit: Reconnect attempt failed: $e',
        error: e,
        stackTrace: StackTrace.current,
        context: 'livekit_reconnect_failed',
      );
      if (mounted) {
        setState(() {
          _reconnecting = false;
          _connecting = false;
          _error = 'Failed to reconnect: $e';
        });
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _reconnecting = false);
      }
    }
  }

  /// Ensure audio playback is working after reconnection or when audio status changes.
  /// This is critical for mobile platforms where audio may stop after network changes.
  Future<void> _ensureAudioPlayback() async {
    if (_room == null) return;

    try {
      // Check if audio playback is allowed
      if (!_room!.canPlaybackAudio) {
        AppLogger.warning(
            'LiveKit: Audio playback not allowed, attempting to start...');
        await _room!.startAudio();
        AppLogger.info('LiveKit: Audio playback started successfully');
      }

      // Verify all remote audio tracks are subscribed and playing
      for (final participant in _room!.remoteParticipants.values) {
        for (final pub in participant.audioTrackPublications) {
          if (pub.subscribed && pub.track != null) {
            final track = pub.track as RemoteAudioTrack;
            // Ensure the track is not muted at the media level
            if (!track.muted) {
              AppLogger.debug(
                'LiveKit: Audio track from ${participant.identity} is active',
              );
            }
          } else if (!pub.subscribed && pub.subscriptionAllowed) {
            // Re-subscribe to tracks that should be subscribed
            AppLogger.warning(
              'LiveKit: Re-subscribing to audio track from ${participant.identity}',
            );
            try {
              await pub.subscribe();
            } catch (e) {
              AppLogger.error('LiveKit: Failed to re-subscribe to audio: $e');
            }
          }
        }
      }

      if (mounted) {
        setState(() => _audioPlaybackAllowed = _room!.canPlaybackAudio);
      }
    } catch (e) {
      AppLogger.error('LiveKit: Error ensuring audio playback: $e');
      if (mounted) {
        setState(
            () => _audioPlaybackAllowed = _room?.canPlaybackAudio ?? false);
      }
    }
  }

  Future<void> _handleEnableAudioPressed() async {
    await _ensureAudioPlayback();

    if (!mounted) return;
    if (_room?.canPlaybackAudio == true) {
      _showSnack(
        'Audio enabled',
        backgroundColor: Colors.green,
      );
    }
  }

  /// Show a snackbar prompting user to tap to enable audio (required on some platforms)
  void _showAudioPlaybackPrompt() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tap here to enable audio'),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Enable',
          textColor: Colors.white,
          onPressed: () async {
            await _ensureAudioPlayback();
          },
        ),
      ),
    );
  }

  void _queuePointerUpdate({
    Offset? position,
    required bool visible,
  }) {
    if (!widget.isTeacher) return;
    if (_localParticipant == null) return;

    if (position != null) {
      _pendingPointerPosition = position;
      _lastPointerPosition = position;
    }
    _pendingPointerVisible = visible;

    final now = DateTime.now();
    final lastSent = _lastPointerSentAt;
    if (lastSent == null || now.difference(lastSent) >= _pointerSendThrottle) {
      _sendPointerUpdate(
        position: _pendingPointerPosition,
        visible: _pendingPointerVisible,
      );
      _pendingPointerPosition = null;
      _pointerSendTimer?.cancel();
      _pointerSendTimer = null;
      return;
    }

    if (_pointerSendTimer != null) return;
    final delay = _pointerSendThrottle - now.difference(lastSent);
    _pointerSendTimer = Timer(delay, () {
      final position = _pendingPointerPosition;
      final visible = _pendingPointerVisible;
      _pendingPointerPosition = null;
      _pointerSendTimer = null;
      _sendPointerUpdate(position: position, visible: visible);
    });
  }

  void _sendPointerUpdate({
    Offset? position,
    required bool visible,
  }) {
    final local = _localParticipant;
    if (local == null) return;

    final payload = <String, dynamic>{
      'type': 'screen_pointer',
      'visible': visible,
    };
    final effectivePosition = position ?? _lastPointerPosition;
    if (effectivePosition != null) {
      payload['x'] = effectivePosition.dx;
      payload['y'] = effectivePosition.dy;
    }

    _lastPointerSentAt = DateTime.now();
    local
        .publishData(
      utf8.encode(jsonEncode(payload)),
      reliable: false,
      topic: _hostControlTopic,
    )
        .catchError((e) {
      AppLogger.debug('LiveKit: Failed to send pointer update: $e');
    });
  }

  void _handleScreenSharePointerEvent(PointerEvent event, Size size) {
    if (!widget.isTeacher || !_screenShareEnabled) return;
    if (event.kind != PointerDeviceKind.mouse) return;
    if (size.width <= 0 || size.height <= 0) return;

    final dx = (event.localPosition.dx / size.width).clamp(0.0, 1.0);
    final dy = (event.localPosition.dy / size.height).clamp(0.0, 1.0);
    _queuePointerUpdate(position: Offset(dx, dy), visible: true);
  }

  void _handleScreenSharePointerExit() {
    if (!widget.isTeacher) return;
    _queuePointerUpdate(visible: false);
  }

  void _scheduleRemotePointerHide() {
    _remotePointerHideTimer?.cancel();
    _remotePointerHideTimer = Timer(_pointerHideDelay, () {
      if (!mounted) return;
      setState(() => _remotePointerVisible = false);
    });
  }

  void _clearRemotePointer({bool notify = true}) {
    _remotePointerHideTimer?.cancel();
    if (notify && mounted) {
      setState(() {
        _remotePointerVisible = false;
        _remotePointerPosition = null;
        _remotePointerIdentity = null;
      });
    } else {
      _remotePointerVisible = false;
      _remotePointerPosition = null;
      _remotePointerIdentity = null;
    }
  }

  Future<void> _connectToRoom() async {
    try {
      setState(() {
        _connecting = true;
        _error = null;
      });

      // Create room options
      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        // Use conservative defaults to reduce bandwidth spikes in larger rooms.
        defaultCameraCaptureOptions: const CameraCaptureOptions(
          maxFrameRate: 24,
          params: VideoParametersPresets.h540_169,
        ),
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
        defaultVideoPublishOptions: const VideoPublishOptions(
          simulcast: true,
          degradationPreference: DegradationPreference.maintainFramerate,
          // Use multi-codec publishing to support Safari/iOS (H264) and Chrome/Android (VP8).
          // Dynacast ensures unused layers/codecs are paused to reduce bandwidth/CPU.
          videoCodec: 'vp8',
          backupVideoCodec: BackupVideoCodec(
            enabled: true,
            codec: 'h264',
            simulcast: true,
          ),
        ),
        defaultAudioPublishOptions: const AudioPublishOptions(
          dtx:
              true, // Discontinuous transmission - saves bandwidth during silence
          red:
              true, // Redundant audio encoding - protects voice against packet loss
        ),
        defaultScreenShareCaptureOptions:
            const _ScreenShareCaptureOptionsWithCursor(
          useiOSBroadcastExtension: true,
          params: VideoParametersPresets.screenShareH720FPS15,
          cursor: 'always',
        ),
      );

      // Create and connect to room
      final room = Room(roomOptions: roomOptions);

      // Set up room event listener
      _listener = room.createListener();
      _setupRoomListeners(_listener!);

      // Debug: Log connection details
      AppLogger.debug('LiveKit: Connecting to $_currentLivekitUrl');
      AppLogger.debug('LiveKit: Room: ${widget.roomName}');
      AppLogger.debug('LiveKit: Token length: ${_currentToken.length}');
      AppLogger.debug(
          'LiveKit: Token preview: ${_currentToken.substring(0, _currentToken.length > 50 ? 50 : _currentToken.length)}...');

      // Connect to the room
      // Try without fastConnectOptions first to see if that's the issue
      try {
        AppLogger.debug(
            'LiveKit: Attempting connection without fastConnectOptions...');
        await room.connect(
          _currentLivekitUrl,
          _currentToken,
        );
        AppLogger.info(
            'LiveKit: Connected successfully without fastConnectOptions');
      } on LiveKitException catch (e) {
        AppLogger.error(
            'LiveKit: Connection exception - Message: ${e.message}');
        AppLogger.error('LiveKit: Exception details: $e');
        AppLogger.error('LiveKit: Full exception: ${e.toString()}');

        // Check if it's a token-related error
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('token') ||
            errorStr.contains('invalid') ||
            errorStr.contains('unauthorized')) {
          AppLogger.error(
              'LiveKit: Token validation failed - this suggests API key/secret mismatch');
          AppLogger.error(
              'LiveKit: Please verify credentials match LiveKit Cloud dashboard');
        }
        rethrow;
      } catch (e) {
        AppLogger.error('LiveKit: Unexpected connection error: $e');
        AppLogger.error('LiveKit: Error type: ${e.runtimeType}');
        rethrow;
      }

      setState(() {
        _room = room;
        _localParticipant = room.localParticipant;
        _connecting = false;
      });

      _reconnectAttempts = 0;
      _connectedAt = DateTime.now();
      AppLogger.breadcrumb(
        'livekit_connect_success shift=${widget.shiftId} room=${widget.roomName}',
      );

      // Automatically enable camera and microphone when joining
      try {
        final localP = room.localParticipant;
        if (localP != null) {
          if (mounted) {
            setState(() => _initializingMedia = true);
          }
          // Enable microphone for both audio and video calls
          await localP.setMicrophoneEnabled(true);
          // Only enable camera if not audio-only mode
          if (!widget.isAudioOnlyMode) {
            AppLogger.info('LiveKit: Enabling camera and microphone...');
            await localP.setCameraEnabled(true);
          } else {
            AppLogger.info(
                'LiveKit: Audio-only mode - enabling microphone only');
          }
          AppLogger.info('LiveKit: Media enabled');
        }
      } catch (e) {
        AppLogger.warning('LiveKit: Could not enable media automatically: $e');
        // Don't fail the connection if media fails - user can enable manually
      } finally {
        if (mounted) {
          setState(() => _initializingMedia = false);
        }
      }

      _syncLocalMediaState();
      await _ensureAudioPlayback();
      AppLogger.info('LiveKit: Connected to room ${widget.roomName}');

      // Load persisted whiteboard state so teacher/student see current board on rejoin
      _loadWhiteboardStateFromFirestore();

      // Students: ask the host for the latest whiteboard state (helps late joiners).
      if (!widget.isTeacher) {
        _requestWhiteboardProject();
      }
    } catch (e) {
      _logLiveKitDiagnostic(
        'connect_failed',
        extra: 'error=$e',
        stackTrace: StackTrace.current,
      );
      AppLogger.error(
        'LiveKit: Failed to connect: $e',
        error: e,
        stackTrace: StackTrace.current,
        context: 'livekit_connect_failed',
      );
      setState(() {
        _connecting = false;
        _error = 'Failed to connect: $e';
      });
    }
  }

  void _setupRoomListeners(EventsListener<RoomEvent> listener) {
    listener
      ..on<RoomConnectedEvent>((event) async {
        _connectedAt = DateTime.now();
        AppLogger.breadcrumb(
          'livekit_room_connected shift=${widget.shiftId} room=${widget.roomName}',
        );
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId == null) {
          AppLogger.warning(
              'LiveKit: Skipping session join tracking (no user)');
          return;
        }

        final diagnostics = await _buildClassReportDiagnostics(
          trigger: 'room_connected',
        );
        await _sessionService.recordParticipantJoin(
          shiftId: widget.shiftId,
          userId: currentUserId,
          role: _resolvedSessionRole(),
          roomName: widget.roomName,
          appSessionId: ErrorReportingService.sessionId,
          diagnostics: diagnostics,
        );

        _triggerShiftRecordingEnsure('room_connected');
      })
      ..on<RoomReconnectingEvent>((event) {
        AppLogger.breadcrumb(
          'livekit_room_reconnecting shift=${widget.shiftId} room=${widget.roomName}',
        );
        _logLiveKitDiagnostic(
          'room_reconnecting',
          extra: 'targetReconnectAttempt=${_reconnectAttempts + 1}',
        );
        AppLogger.warning('LiveKit: Reconnecting to room...');
        // SDK-driven (resume/ICE) reconnects never reach RoomDisconnectedEvent,
        // so capture them here — these are the otherwise-invisible mid-class drops.
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null) {
          _sessionService.recordTransientDisconnect(
            shiftId: widget.shiftId,
            userId: currentUserId,
            disconnectReason: 'sdk_reconnecting',
            roomName: widget.roomName,
          );
        }
        if (mounted) {
          setState(() => _reconnecting = true);
        }
      })
      ..on<RoomReconnectedEvent>((event) async {
        AppLogger.breadcrumb(
          'livekit_room_reconnected shift=${widget.shiftId} room=${widget.roomName}',
        );
        AppLogger.info('LiveKit: Reconnected to room');
        if (mounted) {
          setState(() => _reconnecting = false);
        }
        // Ensure audio tracks are working after reconnection
        // This is critical for fixing audio loss after network changes
        await _ensureAudioPlayback();
        _triggerShiftRecordingEnsure('room_reconnected');
      })
      ..on<RoomDisconnectedEvent>((event) async {
        final shouldReconnect = _shouldAttemptReconnect(event.reason);
        _logLiveKitDiagnostic(
          'room_disconnected',
          reason: event.reason,
          extra: 'shouldReconnect=$shouldReconnect',
        );
        AppLogger.breadcrumb(
          'livekit_room_disconnected reason=${event.reason?.name ?? 'none'} shift=${widget.shiftId} room=${widget.roomName}',
        );

        if (_manualDisconnect) {
          return;
        }

        if (shouldReconnect) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId != null) {
            await _sessionService.recordTransientDisconnect(
              shiftId: widget.shiftId,
              userId: currentUserId,
              disconnectReason: event.reason?.name ?? 'unknown',
              roomName: widget.roomName,
              reconnectAttempt: _reconnectAttempts + 1,
            );
          }
          await _attemptReconnect(event.reason);
          return;
        }

        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null) {
          await _sessionService.recordParticipantLeave(
            shiftId: widget.shiftId,
            userId: currentUserId,
            disconnectReason: event.reason?.toString(),
            roomName: widget.roomName,
            appSessionId: ErrorReportingService.sessionId,
            diagnostics: await _buildClassReportDiagnostics(
              trigger: 'room_disconnected',
            ),
          );
        }

        if (mounted) {
          await _showUnexpectedDisconnectDialog(event.reason);
          if (!mounted) return;
          _logLiveKitDiagnostic(
            'room_disconnected_navigate_pop',
            reason: event.reason,
          );
          Navigator.of(context).pop();
        }
      })
      ..on<ParticipantConnectedEvent>((event) async {
        AppLogger.info(
            'LiveKit: Participant connected: ${event.participant.identity}');
        setState(() {});
        await _ensureAudioPlayback();
        _triggerShiftRecordingEnsure('participant_connected');

        // Cancel no-show timers when relevant participant joins
        if (!widget.isTeacher) {
          // Student: cancel timer if teacher joins
          if (_isTeacherInRoom()) {
            _noShowCheckTimer?.cancel();
            _noShowAutoSendTimer?.cancel();
            if (_noShowDialogShown && mounted) {
              Navigator.of(context, rootNavigator: true).pop();
              setState(() => _noShowDialogShown = false);
            }
          }
        } else {
          // Teacher: cancel timer if any student joins
          if (_areStudentsInRoom()) {
            _studentNoShowCheckTimer?.cancel();
            _studentNoShowAutoSendTimer?.cancel();
            if (_studentNoShowDialogShown && mounted) {
              Navigator.of(context, rootNavigator: true).pop();
              setState(() => _studentNoShowDialogShown = false);
            }
          }
        }

        if (widget.isTeacher && _studentMicrophonesLocked) {
          try {
            await _broadcastStudentMicLock(
              locked: true,
              destinationIdentities: [event.participant.identity],
            );
          } catch (e) {
            AppLogger.error('LiveKit: Failed to sync mic lock state: $e');
          }
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        AppLogger.info(
            'LiveKit: Participant disconnected: ${event.participant.identity}');
        if (_pipIdentity != null &&
            event.participant.identity == _pipIdentity &&
            kIsWeb) {
          pip.exitPictureInPicture();
          _pipRenderer?.srcObject = null;
          _pipTrack = null;
          _pipIdentity = null;
        }
        setState(() {});
      })
      ..on<DataReceivedEvent>(_handleDataReceived)
      ..on<TrackMutedEvent>((event) {
        _recordLiveKitAudioEvent(
          'track_muted',
          participant: event.participant,
          publication: event.publication,
        );
        _syncLocalMediaState();
        if (mounted) setState(() {});
      })
      ..on<TrackUnmutedEvent>((event) {
        _recordLiveKitAudioEvent(
          'track_unmuted',
          participant: event.participant,
          publication: event.publication,
        );
        _syncLocalMediaState();
        if (mounted) setState(() {});
      })
      ..on<TrackPublishedEvent>((event) {
        _recordLiveKitAudioEvent(
          'track_published',
          participant: event.participant,
          publication: event.publication,
        );
        _triggerShiftRecordingEnsure('remote_track_published');
        _syncLocalMediaState();
        setState(() {});
      })
      ..on<TrackUnpublishedEvent>((event) {
        _recordLiveKitAudioEvent(
          'track_unpublished',
          participant: event.participant,
          publication: event.publication,
        );
        _syncLocalMediaState();
        setState(() {});
      })
      ..on<TrackSubscribedEvent>((event) {
        _recordLiveKitAudioEvent(
          'track_subscribed',
          participant: event.participant,
          publication: event.publication,
          track: event.track,
        );
        _ensureAudioPlayback();
        setState(() {});
      })
      ..on<TrackUnsubscribedEvent>((event) {
        _recordLiveKitAudioEvent(
          'track_unsubscribed',
          participant: event.participant,
          publication: event.publication,
          track: event.track,
        );
        setState(() {});
      })
      ..on<LocalTrackPublishedEvent>((event) {
        _recordLiveKitAudioEvent(
          'local_track_published',
          participant: _localParticipant,
          publication: event.publication,
        );
        _triggerShiftRecordingEnsure('local_track_published');
        _syncLocalMediaState();
        setState(() {});
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        _recordLiveKitAudioEvent(
          'local_track_unpublished',
          participant: _localParticipant,
          publication: event.publication,
        );
        _syncLocalMediaState();
        setState(() {});
      })
      ..on<AudioPlaybackStatusChanged>((event) {
        _recentLiveKitAudioEvents.add({
          'timestamp': DateTime.now().toIso8601String(),
          'event': 'audio_playback_status_changed',
          'isPlaying': event.isPlaying,
        });
        if (_recentLiveKitAudioEvents.length > 40) {
          _recentLiveKitAudioEvents.removeRange(
            0,
            _recentLiveKitAudioEvents.length - 40,
          );
        }
        // Handle audio playback status changes (e.g., after tab switch, device change)
        AppLogger.info(
            'LiveKit: Audio playback status changed - canPlayback: ${event.isPlaying}');
        if (mounted) {
          setState(() => _audioPlaybackAllowed = event.isPlaying);
        }
        if (!event.isPlaying) {
          // Audio playback was blocked - prompt user to re-enable
          _showAudioPlaybackPrompt();
        }
      })
      ..on<TrackStreamStateUpdatedEvent>((event) {
        _recordLiveKitAudioEvent(
          'track_stream_state_updated',
          participant: event.participant,
          publication: event.publication,
          extra: {'streamState': event.streamState.name},
        );
        // Handle track stream state changes (e.g., track paused/active)
        AppLogger.debug(
          'LiveKit: Track stream state updated - ${event.participant.identity}: ${event.publication.sid} -> ${event.streamState}',
        );
        // If a track becomes active again after being paused, ensure audio is working
        if (event.streamState == StreamState.active) {
          _ensureAudioPlayback();
        }
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        AppLogger.debug(
          'LiveKit: Connection quality - ${event.participant.identity}: ${event.connectionQuality.name}',
        );
        if (mounted) setState(() {});
      });
  }

  void _triggerShiftRecordingEnsure(String reason) {
    // TODO(recording): Re-enable when VPS is upgraded to KVM 8
    // Recording is paused — current VPS (KVM 4) cannot handle concurrent egress.
    return;

    // ignore: dead_code
    final shiftId = widget.shiftId.trim();
    if (shiftId.isEmpty) return;

    final now = DateTime.now();
    final lastTriggeredAt = _lastRecordingEnsureAt;
    if (lastTriggeredAt != null &&
        now.difference(lastTriggeredAt) < const Duration(seconds: 3)) {
      return;
    }

    _lastRecordingEnsureAt = now;
    AppLogger.debug(
        'LiveKit: Ensuring recording after $reason (shiftId: $shiftId)');
    unawaited(LiveKitService.ensureShiftRecording(shiftId));
  }

  bool _isModeratorMessage(RemoteParticipant? participant) {
    final raw = participant?.metadata;
    if (raw == null || raw.trim().isEmpty) return false;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final role = decoded['role']?.toString();
      return role == 'teacher' || role == 'admin';
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleDataReceived(DataReceivedEvent event) async {
    AppLogger.debug(
        'LiveKit: Data received - topic: "${event.topic}", from: ${event.participant?.identity}');

    // Handle whiteboard messages (for all participants)
    if (event.topic == _whiteboardTopic) {
      await _handleWhiteboardData(event);
      return;
    }

    // Host control messages are only for students
    if (widget.isTeacher) return;
    if (event.topic != _hostControlTopic) return;
    if (!_isModeratorMessage(event.participant)) return;

    final text = utf8.decode(event.data, allowMalformed: true);
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return;
    }

    if (decoded is! Map) return;

    final type = decoded['type']?.toString();
    if (type == 'student_mic_lock') {
      final locked = decoded['locked'] == true;
      if (!mounted) return;
      if (_micLockedByHost == locked) return;

      setState(() => _micLockedByHost = locked);

      if (locked) {
        try {
          await _localParticipant?.setMicrophoneEnabled(false);
          _syncLocalMediaState();
        } catch (e) {
          AppLogger.error(
              'LiveKit: Failed to disable mic due to host lock: $e');
        }
        _showSnack(
          'Muted by the host',
          backgroundColor: Colors.orange.shade700,
        );
      } else {
        _showSnack(
          'You can unmute now',
          backgroundColor: Colors.green,
        );
      }
      return;
    }

    if (type == 'screen_pointer') {
      final activeShare = _getActiveScreenShare();
      final senderIdentity = event.participant?.identity;
      if (activeShare == null || senderIdentity == null) return;
      if (activeShare.participant.identity != senderIdentity) return;

      final visible = decoded['visible'] != false;
      if (!visible) {
        _clearRemotePointer();
        return;
      }

      final x = (decoded['x'] as num?)?.toDouble();
      final y = (decoded['y'] as num?)?.toDouble();
      if (x == null || y == null) return;

      if (!mounted) return;
      setState(() {
        _remotePointerPosition = Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
        _remotePointerVisible = true;
        _remotePointerIdentity = senderIdentity;
      });
      _scheduleRemotePointerHide();
      return;
    }

    if (type == 'student_mic_state') {
      final enabled = decoded['enabled'] == true;
      try {
        await _localParticipant?.setMicrophoneEnabled(enabled);
        _syncLocalMediaState();
      } catch (e) {
        AppLogger.error('LiveKit: Failed to set mic state from host: $e');
      }

      _showSnack(
        enabled ? 'Microphone enabled by the host' : 'Muted by the host',
        backgroundColor: enabled ? Colors.green : Colors.orange.shade700,
      );
    }
  }

  Future<void> _broadcastStudentMicLock({
    required bool locked,
    List<String>? destinationIdentities,
  }) async {
    final local = _localParticipant;
    if (local == null) return;

    final payload = jsonEncode({
      'type': 'student_mic_lock',
      'locked': locked,
    });

    await local.publishData(
      utf8.encode(payload),
      reliable: true,
      destinationIdentities: destinationIdentities,
      topic: _hostControlTopic,
    );
  }

  Future<void> _broadcastStudentMicState({
    required bool enabled,
    required List<String> destinationIdentities,
  }) async {
    final local = _localParticipant;
    if (local == null) return;

    final payload = jsonEncode({
      'type': 'student_mic_state',
      'enabled': enabled,
    });

    await local.publishData(
      utf8.encode(payload),
      reliable: true,
      destinationIdentities: destinationIdentities,
      topic: _hostControlTopic,
    );
  }

  Future<void> _setStudentMicLock(bool locked, {bool muteFirst = false}) async {
    if (!widget.isTeacher) return;

    if (muteFirst) {
      try {
        await LiveKitService.muteAllParticipants(shiftId: widget.shiftId);
      } catch (e) {
        _showSnack('Failed to mute participants: $e',
            backgroundColor: Colors.red);
      }
    }

    if (!mounted) return;
    setState(() => _studentMicrophonesLocked = locked);

    try {
      await _broadcastStudentMicLock(locked: locked);
      _showSnack(
        locked
            ? 'Participants cannot unmute themselves'
            : 'Participants can unmute themselves',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      _showSnack('Failed to update mic lock: $e', backgroundColor: Colors.red);
    }
  }

  // --- Whiteboard methods ---

  Future<void> _handleWhiteboardData(DataReceivedEvent event) async {
    final senderIdentity = event.participant?.identity ?? 'unknown';
    AppLogger.debug(
        'LiveKit Whiteboard: Received data from $senderIdentity (I am ${widget.isTeacher ? "teacher" : "student"})');

    final text = utf8.decode(event.data, allowMalformed: true);
    final message = WhiteboardMessage.decode(text);
    if (message == null) {
      AppLogger.debug('LiveKit Whiteboard: Failed to decode message');
      return;
    }

    AppLogger.debug('LiveKit Whiteboard: Message type: ${message.type}');

    switch (message.type) {
      case WhiteboardMessage.typeProject:
        // Received project state - collaborative mode: everyone receives from everyone
        if (message.payload != null) {
          final strokeCount =
              (message.payload!['strokes'] as List?)?.length ?? 0;
          AppLogger.debug(
              'LiveKit Whiteboard: Received project with $strokeCount strokes, pushing to stream');
          _lastWhiteboardProject = message.payload;
          _whiteboardProjectController.add(message.payload!);
          // Enable whiteboard view when receiving project data (for students joining late)
          if (!widget.isTeacher && !_whiteboardEnabled && mounted) {
            setState(() => _whiteboardEnabled = true);
          }
        }
        break;

      case WhiteboardMessage.typeRequestProject:
        // Participant requesting current project state (typically late joiners)
        if (widget.isTeacher &&
            _whiteboardEnabled &&
            _lastWhiteboardProject != null) {
          final identity = event.participant?.identity;
          if (identity != null) {
            await _sendWhiteboardProject(
              _lastWhiteboardProject!,
              destinationIdentities: [identity],
            );
          }
        }
        break;

      case WhiteboardMessage.typeClosed:
        // Teacher closed whiteboard
        if (!widget.isTeacher && mounted) {
          setState(() => _whiteboardEnabled = false);
        }
        break;

      case WhiteboardMessage.typeStudentDrawingPermission:
        // Teacher changed student drawing permission
        if (!widget.isTeacher && message.payload != null) {
          final enabled = message.payload!['enabled'] == true;
          AppLogger.debug(
              'LiveKit Whiteboard: Student drawing permission changed to $enabled');
          if (mounted) {
            setState(() => _studentDrawingEnabled = enabled);
          }
        }
        break;
    }
  }

  void _toggleWhiteboard() {
    if (!widget.isTeacher) return;

    final enabling = !_whiteboardEnabled;
    setState(() => _whiteboardEnabled = enabling);

    if (!enabling) {
      // Notify students that whiteboard is closed.
      _sendWhiteboardClosed();
      return;
    }

    // When opening, immediately broadcast the current project so students (and
    // late joiners) can render the board without waiting for a new stroke.
    final strokes = _lastWhiteboardProject?['strokes'] as List? ??
        _initialWhiteboardStrokes ??
        const [];
    final project = <String, dynamic>{
      'strokes': strokes,
      'version': 2,
    };
    _lastWhiteboardProject = project;
    _sendWhiteboardProject(project);

    // Broadcast current student drawing permission so students match host state.
    _sendStudentDrawingPermission(_studentDrawingEnabled);
  }

  Future<void> _sendWhiteboardProject(
    Map<String, dynamic> projectData, {
    List<String>? destinationIdentities,
  }) async {
    final room = _room;
    final local = _localParticipant;

    if (room == null) {
      AppLogger.debug('LiveKit Whiteboard: Cannot send - no room');
      return;
    }

    if (local == null) {
      AppLogger.debug('LiveKit Whiteboard: Cannot send - no local participant');
      return;
    }

    final remoteCount = room.remoteParticipants.length;
    AppLogger.debug(
        'LiveKit Whiteboard: Room has $remoteCount remote participants');

    _lastWhiteboardProject = projectData;

    final message = WhiteboardMessage(
      type: WhiteboardMessage.typeProject,
      payload: projectData,
    );

    final strokeCount = (projectData['strokes'] as List?)?.length ?? 0;
    AppLogger.debug(
        'LiveKit Whiteboard: Sending project with $strokeCount strokes to topic "$_whiteboardTopic" (isTeacher: ${widget.isTeacher})');

    try {
      await local.publishData(
        utf8.encode(message.encode()),
        reliable: true,
        destinationIdentities: destinationIdentities,
        topic: _whiteboardTopic,
      );
      AppLogger.debug('LiveKit Whiteboard: Project sent successfully');
      // Persist so rejoin (teacher or student) sees current board for the duration of the class
      _saveWhiteboardStateToFirestore();
    } catch (e) {
      AppLogger.error('LiveKit: Failed to send whiteboard project: $e');
    }
  }

  Future<void> _sendWhiteboardClosed() async {
    final local = _localParticipant;
    if (local == null) return;

    final message = WhiteboardMessage(type: WhiteboardMessage.typeClosed);

    try {
      await local.publishData(
        utf8.encode(message.encode()),
        reliable: true,
        topic: _whiteboardTopic,
      );
    } catch (e) {
      AppLogger.error('LiveKit: Failed to send whiteboard closed: $e');
    }
  }

  Future<void> _requestWhiteboardProject() async {
    final local = _localParticipant;
    if (local == null) return;

    final message =
        WhiteboardMessage(type: WhiteboardMessage.typeRequestProject);

    try {
      await local.publishData(
        utf8.encode(message.encode()),
        reliable: true,
        topic: _whiteboardTopic,
      );
    } catch (e) {
      AppLogger.error('LiveKit: Failed to request whiteboard project: $e');
    }
  }

  void _toggleStudentDrawingPermission(bool enabled) {
    if (!widget.isTeacher) return;

    setState(() => _studentDrawingEnabled = enabled);
    _sendStudentDrawingPermission(enabled);

    // Also save to Firestore so late joiners get the correct permission
    _saveWhiteboardStateToFirestore();
  }

  Future<void> _sendStudentDrawingPermission(bool enabled) async {
    final local = _localParticipant;
    if (local == null) return;

    final message = WhiteboardMessage(
      type: WhiteboardMessage.typeStudentDrawingPermission,
      payload: {'enabled': enabled},
    );

    AppLogger.debug(
        'LiveKit Whiteboard: Sending student drawing permission: $enabled');

    try {
      await local.publishData(
        utf8.encode(message.encode()),
        reliable: true,
        topic: _whiteboardTopic,
      );
    } catch (e) {
      AppLogger.error('LiveKit: Failed to send student drawing permission: $e');
    }
  }

  // --- Firestore persistence for whiteboard ---

  Future<void> _saveWhiteboardStateToFirestore() async {
    if (_whiteboardStateSaving) return;
    _whiteboardStateSaving = true;

    try {
      final shiftId = widget.shiftId;
      if (shiftId.isEmpty) {
        AppLogger.debug(
            'LiveKit Whiteboard: No shift ID, skipping Firestore save');
        return;
      }

      final strokes = (_lastWhiteboardProject?['strokes'] as List?) ?? [];

      await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(shiftId)
          .set({
        'whiteboard': {
          'strokes': strokes,
          'studentDrawingEnabled': _studentDrawingEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      AppLogger.debug(
          'LiveKit Whiteboard: Saved ${strokes.length} strokes to Firestore');
    } catch (e) {
      AppLogger.error('LiveKit Whiteboard: Failed to save to Firestore: $e');
    } finally {
      _whiteboardStateSaving = false;
    }
  }

  Future<void> _loadWhiteboardStateFromFirestore() async {
    try {
      final shiftId = widget.shiftId;
      if (shiftId.isEmpty) {
        AppLogger.debug(
            'LiveKit Whiteboard: No shift ID, skipping Firestore load');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(shiftId)
          .get();

      if (!doc.exists) return;

      final data = doc.data();
      final whiteboard = data?['whiteboard'] as Map<String, dynamic>?;

      if (whiteboard != null) {
        final strokes = whiteboard['strokes'] as List?;
        final studentDrawingEnabled =
            whiteboard['studentDrawingEnabled'] as bool? ?? false;

        if (strokes != null && strokes.isNotEmpty) {
          _initialWhiteboardStrokes = strokes.cast<Map<String, dynamic>>();
          _lastWhiteboardProject = {'strokes': strokes};
          AppLogger.debug(
              'LiveKit Whiteboard: Loaded ${strokes.length} strokes from Firestore');
        }

        if (mounted) {
          setState(() => _studentDrawingEnabled = studentDrawingEnabled);
        }
      }
    } catch (e) {
      AppLogger.error('LiveKit Whiteboard: Failed to load from Firestore: $e');
    }
  }

  // --- End whiteboard methods ---

  Future<void> _toggleMicrophone() async {
    final local = _localParticipant;
    if (local == null) return;
    if (!widget.isTeacher && _micLockedByHost) {
      _showSnack(
        'Your microphone is locked by the host',
        backgroundColor: Colors.orange.shade700,
      );
      return;
    }

    try {
      final isMicOn = _participantHasMicOn(local);
      await local.setMicrophoneEnabled(!isMicOn);
      _syncLocalMediaState();
    } catch (e) {
      AppLogger.error('LiveKit: Failed to toggle mic: $e');
    }
  }

  Future<void> _toggleCamera() async {
    final local = _localParticipant;
    if (local == null) return;

    try {
      final isCameraOn = _participantHasCameraOn(local);
      await local.setCameraEnabled(!isCameraOn);
      _syncLocalMediaState();
    } catch (e) {
      AppLogger.error('LiveKit: Failed to toggle camera: $e');
    }
  }

  Future<void> _toggleScreenShare() async {
    final local = _localParticipant;
    if (local == null) return;
    if (!widget.isTeacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)!.onlyTeachersCanShareTheirScreen),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final isSharing = _participantHasScreenShareOn(local);
      final enable = !isSharing;

      // Call screen share immediately in user gesture handler
      // Note: On web, getDisplayMedia must be called in response to user gesture
      // The LiveKit SDK handles this internally, but we ensure it's called synchronously here
      await local.setScreenShareEnabled(enable);
      _syncLocalMediaState();

      if (!enable) {
        _queuePointerUpdate(visible: false);
      }

      if (mounted && enable) {
        setState(() => _showParticipantsOverlay = true);
      }
    } catch (e) {
      AppLogger.error('LiveKit: Failed to toggle screen share: $e');
      AppLogger.error('LiveKit: Error type: ${e.runtimeType}');
      AppLogger.error('LiveKit: Error details: ${e.toString()}');

      if (mounted) {
        String errorMessage = 'Failed to share screen';
        final errorStr = e.toString().toLowerCase();

        if (errorStr.contains('notallowed') ||
            errorStr.contains('permission denied')) {
          errorMessage = 'Screen sharing was denied. Please:\n'
              '• Select a screen/window/tab in the browser dialog\n'
              '• Click "Share" (not Cancel)\n'
              '• If using Chrome, check that screen capture is allowed in site settings';
        } else if (errorStr.contains('notreadable') ||
            errorStr.contains('could not start')) {
          errorMessage = 'Could not access screen. Try:\n'
              '• Closing other apps using your screen\n'
              '• Refreshing the page\n'
              '• Stopping your camera first, then sharing screen';
        } else if (errorStr.contains('abort') ||
            errorStr.contains('canceled')) {
          errorMessage =
              'Screen sharing was canceled. Click "Share Screen" again and select a source.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _leaveCall() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.leaveClass),
        content: Text(AppLocalizations.of(context)!.confirmLeaveClassMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.leave),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      _manualDisconnect = true;
      await _disconnect(trigger: 'leave_button');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _disconnect({String trigger = 'manual_disconnect'}) async {
    try {
      _manualDisconnect = true;
      _logLiveKitDiagnostic(
        'client_disconnect_requested',
        trigger: trigger,
      );
      AppLogger.breadcrumb(
        'livekit_client_disconnect trigger=$trigger shift=${widget.shiftId} room=${widget.roomName}',
      );
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        await _sessionService.recordParticipantLeave(
          shiftId: widget.shiftId,
          userId: currentUserId,
          disconnectReason: trigger,
          roomName: widget.roomName,
          appSessionId: ErrorReportingService.sessionId,
          diagnostics: await _buildClassReportDiagnostics(
            trigger: trigger,
          ),
        );
      }

      // Explicitly stop mic and camera before disconnecting
      try {
        await _localParticipant?.setMicrophoneEnabled(false);
        await _localParticipant?.setCameraEnabled(false);
        AppLogger.info('LiveKit: Mic and camera disabled before disconnect');
      } catch (e) {
        AppLogger.warning(
            'LiveKit: Error disabling media before disconnect: $e');
      }

      _listener?.dispose();
      _listener = null;
      await _room?.disconnect();
      await _room?.dispose();
      _room = null;
      _localParticipant = null;
    } catch (e) {
      AppLogger.error('LiveKit: Error disconnecting: $e');
    }
  }

  Widget _buildAudioPlaybackBanner() {
    if (_audioPlaybackAllowed || _room == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.volume_off, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Audio is paused on this device.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _handleEnableAudioPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Enable audio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _disposePictureInPictureResources() {
    // Best-effort cleanup. Don't await in dispose.
    pip.exitPictureInPicture();

    _pipTrack = null;
    _pipIdentity = null;

    final renderer = _pipRenderer;
    _pipRenderer = null;
    renderer?.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screenShareUiHideTimer?.cancel();
    _screenShareTransformController.dispose();
    _disposePictureInPictureResources();
    _pointerSendTimer?.cancel();
    _remotePointerHideTimer?.cancel();
    _cancelNoShowTimers();
    _whiteboardProjectController.close();
    _logLiveKitDiagnostic(
      'widget_dispose',
      trigger:
          _manualDisconnect ? 'already_manual_disconnect' : 'widget_dispose',
      stackTrace: StackTrace.current,
    );
    _disconnect(trigger: 'widget_dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participantCount = _getParticipantCount();
    final hasRemoteParticipants =
        (_room?.remoteParticipants.isNotEmpty ?? false);
    final activeScreenShare = _getActiveScreenShare();

    if (_isScreenShareFullscreen && activeScreenShare == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _exitScreenShareFullscreen();
      });
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isScreenShareFullscreen) {
          _exitScreenShareFullscreen();
          return false;
        }
        await _leaveCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: _isScreenShareFullscreen
            ? null
            : AppBar(
                backgroundColor: const Color(0xFF16213E),
                title: Text(
                  widget.shiftName,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _leaveCall,
                ),
                actions: [
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.participants,
                    onPressed: _room == null ? null : _showParticipantsDialog,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.people, color: Colors.white),
                        if (participantCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xff0386FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                participantCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Report issue',
                    onPressed: _room == null || _submittingClassIssueReport
                        ? null
                        : _showQuickClassIssueSheet,
                    icon: _submittingClassIssueReport
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.report_problem_outlined,
                            color: Colors.white,
                          ),
                  ),
                  if (activeScreenShare != null)
                    IconButton(
                      tooltip: _screenShareFit == VideoViewFit.contain
                          ? 'Fill screen'
                          : 'Fit to screen',
                      onPressed: _toggleScreenShareFit,
                      icon: Icon(
                        _screenShareFit == VideoViewFit.contain
                            ? Icons.crop_free
                            : Icons.fit_screen,
                        color: Colors.white,
                      ),
                    ),
                  if (activeScreenShare != null)
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.fullscreen,
                      onPressed: _enterScreenShareFullscreen,
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                    ),
                  if (widget.isTeacher)
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.muteAll,
                      onPressed: _room == null || !hasRemoteParticipants
                          ? null
                          : _confirmMuteAll,
                      icon: const Icon(Icons.volume_off, color: Colors.white),
                    ),
                  if (widget.isTeacher)
                    IconButton(
                      tooltip: _studentMicrophonesLocked
                          ? 'Allow participants to unmute'
                          : 'Prevent participants from unmuting',
                      onPressed: _room == null
                          ? null
                          : () => _setStudentMicLock(
                                !_studentMicrophonesLocked,
                                muteFirst: !_studentMicrophonesLocked,
                              ),
                      icon: Icon(
                        _studentMicrophonesLocked ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  if (widget.isTeacher)
                    IconButton(
                      tooltip: _roomLocked ? 'Unlock meeting' : 'Lock meeting',
                      onPressed: _toggleRoomLock,
                      icon: Icon(
                        _roomLocked ? Icons.lock : Icons.lock_open,
                        color: Colors.white,
                      ),
                    ),
                  if (kIsWeb)
                    IconButton(
                      tooltip: _pipIdentity != null
                          ? 'Exit picture-in-picture'
                          : 'Picture-in-picture',
                      onPressed: _pipBusy || !hasRemoteParticipants
                          ? null
                          : () => _togglePictureInPicture(),
                      icon: Icon(
                        _pipIdentity != null
                            ? Icons.picture_in_picture_alt
                            : Icons.picture_in_picture_alt_outlined,
                        color: Colors.white,
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: _connecting ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _connecting ? 'Connecting...' : 'Live',
                          style: TextStyle(
                            color: _connecting ? Colors.orange : Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        body: Stack(
          children: [
            _buildBody(activeScreenShare),
            _buildPictureInPictureRenderer(),
            if (!_isScreenShareFullscreen) _buildAudioPlaybackBanner(),
            // TODO(recording): Re-enable when VPS is upgraded to KVM 8
            // if (!_isScreenShareFullscreen) _buildRecordingNoticeBanner(),
          ],
        ),
        bottomNavigationBar: _isScreenShareFullscreen ? null : _buildControls(),
      ),
    );
  }

  int _getParticipantCount() {
    if (_room == null) return 0;
    final localCount = _localParticipant == null ? 0 : 1;
    return localCount + _nonSystemRemoteParticipants().length;
  }

  _ActiveScreenShare? _getActiveScreenShare() {
    final local = _localParticipant;
    if (local != null) {
      final localScreenShare = _getParticipantScreenShareVideoTrack(local);
      if (localScreenShare != null) {
        return _ActiveScreenShare(participant: local, track: localScreenShare);
      }
    }

    final remoteParticipants =
        List<RemoteParticipant>.from(_nonSystemRemoteParticipants());
    remoteParticipants.sort((a, b) => a.identity.compareTo(b.identity));

    for (final participant in remoteParticipants) {
      final remoteScreenShare =
          _getParticipantScreenShareVideoTrack(participant);
      if (remoteScreenShare != null) {
        return _ActiveScreenShare(
          participant: participant,
          track: remoteScreenShare,
        );
      }
    }

    return null;
  }

  void _resetScreenShareTransform() {
    _screenShareTransformController.value = Matrix4.identity();
  }

  void _toggleScreenShareFit() {
    setState(() {
      _screenShareFit = _screenShareFit == VideoViewFit.contain
          ? VideoViewFit.cover
          : VideoViewFit.contain;
    });
  }

  void _enterScreenShareFullscreen() {
    if (_getActiveScreenShare() == null) return;
    setState(() {
      _isScreenShareFullscreen = true;
      _screenShareUiVisible = true;
    });
    _scheduleHideScreenShareUi();
  }

  void _exitScreenShareFullscreen() {
    _screenShareUiHideTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isScreenShareFullscreen = false;
      _screenShareUiVisible = true;
    });
  }

  void _scheduleHideScreenShareUi() {
    _screenShareUiHideTimer?.cancel();
    _screenShareUiHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _screenShareUiVisible = false);
    });
  }

  void _toggleScreenShareUiVisible() {
    setState(() => _screenShareUiVisible = !_screenShareUiVisible);
    if (_screenShareUiVisible) {
      _scheduleHideScreenShareUi();
    } else {
      _screenShareUiHideTimer?.cancel();
    }
  }

  void _handleScreenShareDoubleTap() {
    final details = _screenShareDoubleTapDetails;
    if (details == null) return;

    final currentScale =
        _screenShareTransformController.value.getMaxScaleOnAxis();
    if (currentScale > 1.01) {
      _resetScreenShareTransform();
      return;
    }

    const targetScale = 2.5;
    final tapPosition = details.localPosition;
    _screenShareTransformController.value = Matrix4.identity()
      ..translate(
        -tapPosition.dx * (targetScale - 1),
        -tapPosition.dy * (targetScale - 1),
      )
      ..scale(targetScale);
  }

  Widget _buildZoomableScreenShare(
    VideoTrack track, {
    required bool enableTapToToggleUi,
    bool enablePointerCapture = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enableTapToToggleUi ? _toggleScreenShareUiVisible : null,
      onDoubleTapDown: (details) => _screenShareDoubleTapDetails = details,
      onDoubleTap: _handleScreenShareDoubleTap,
      child: InteractiveViewer(
        transformationController: _screenShareTransformController,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: true,
        scaleEnabled: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final canShowPointer = _remotePointerVisible &&
                _remotePointerPosition != null &&
                _remotePointerIdentity != null &&
                _remotePointerIdentity == _activeScreenShareIdentity &&
                width.isFinite &&
                height.isFinite;

            Widget content = Stack(
              children: [
                Positioned.fill(
                  child: VideoTrackRenderer(
                    track,
                    fit: _screenShareFit,
                  ),
                ),
                if (canShowPointer)
                  Builder(
                    builder: (context) {
                      const pointerSize = 16.0;
                      final position = _remotePointerPosition!;
                      var left = position.dx * width - pointerSize / 2;
                      var top = position.dy * height - pointerSize / 2;
                      left = left.clamp(
                        0.0,
                        math.max(0.0, width - pointerSize),
                      );
                      top = top.clamp(
                        0.0,
                        math.max(0.0, height - pointerSize),
                      );

                      return Positioned(
                        left: left,
                        top: top,
                        child: const IgnorePointer(child: _RemotePointer()),
                      );
                    },
                  ),
              ],
            );

            if (enablePointerCapture) {
              content = MouseRegion(
                onExit: (_) => _handleScreenSharePointerExit(),
                child: Listener(
                  onPointerHover: (event) => _handleScreenSharePointerEvent(
                      event, constraints.biggest),
                  onPointerMove: (event) => _handleScreenSharePointerEvent(
                      event, constraints.biggest),
                  onPointerDown: (event) => _handleScreenSharePointerEvent(
                      event, constraints.biggest),
                  child: content,
                ),
              );
            }

            return content;
          },
        ),
      ),
    );
  }

  Widget _buildPictureInPictureRenderer() {
    if (!kIsWeb || _pipRenderer == null || _pipTrack == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomRight,
      child: IgnorePointer(
        child: SizedBox(
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0,
            child: VideoTrackRenderer(
              _pipTrack!,
              cachedRenderer: _pipRenderer,
              autoDisposeRenderer: false,
              autoCenter: false,
              fit: VideoViewFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildRecordingNoticeBanner() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF7F1D1D).withOpacity(0.94),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF87171)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fiber_manual_record,
                size: 12,
                color: Color(0xFFFCA5A5),
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'This session is being recorded',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openQuranDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final maxHeight = size.height * 0.9;

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 320,
              maxWidth: 980,
              maxHeight: maxHeight,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book, color: Color(0xff0386FF)),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.quran,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff111827),
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: AppLocalizations.of(context)!.commonClose,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: QuranReader(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmMuteAll() async {
    if (_room == null || !mounted) return;

    var allowUnmute = !_studentMicrophonesLocked;

    final allowUnmuteResult = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.muteEveryone),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!
                  .thisWillMuteAllParticipantsExcept),
              SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: allowUnmute,
                onChanged: (value) => setDialogState(
                    () => allowUnmute = value == null ? true : value),
                title: Text(
                    AppLocalizations.of(context)!.allowParticipantsToUnmute),
                subtitle: Text(
                  AppLocalizations.of(context)!.turnOffToKeepParticipantsMuted,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, allowUnmute),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.muteAll),
            ),
          ],
        ),
      ),
    );

    if (allowUnmuteResult == null) return;

    try {
      await LiveKitService.muteAllParticipants(shiftId: widget.shiftId);
      _showSnack('Muted all participants', backgroundColor: Colors.green);
    } catch (e) {
      _showSnack('Failed to mute all: $e', backgroundColor: Colors.red);
    }

    final locked = allowUnmuteResult == false;
    await _setStudentMicLock(locked);
  }

  Future<void> _toggleRoomLock() async {
    if (!widget.isTeacher) return;

    final nextLocked = !_roomLocked;
    setState(() => _roomLocked = nextLocked);

    try {
      await LiveKitService.setRoomLock(
        shiftId: widget.shiftId,
        locked: nextLocked,
      );
      _showSnack(
        nextLocked ? 'Meeting locked' : 'Meeting unlocked',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _roomLocked = !nextLocked);
      }
      _showSnack('Failed to update lock: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _showParticipantsDialog() async {
    final room = _room;
    if (room == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final local = _localParticipant;
            final remoteParticipants = _nonSystemRemoteParticipants(room)
              ..sort((a, b) => a.identity.compareTo(b.identity));

            final participants = <Participant>[
              if (local != null) local,
              ...remoteParticipants,
            ];

            bool isMicOn(Participant p) {
              for (final pub in p.audioTrackPublications) {
                if (!pub.muted) return true;
              }
              return false;
            }

            bool isCamOn(Participant p) {
              for (final pub in p.videoTrackPublications) {
                if (!pub.muted &&
                    !pub.isScreenShare &&
                    pub.source == TrackSource.camera) {
                  return true;
                }
              }
              return false;
            }

            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text(AppLocalizations.of(context)!
                        .livekitParticipantsCount(participants.length)),
                  ),
                  if (widget.isTeacher)
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.muteAll,
                      onPressed: () async {
                        Navigator.pop(context);
                        await _confirmMuteAll();
                      },
                      icon: const Icon(Icons.volume_off),
                    ),
                  if (widget.isTeacher)
                    IconButton(
                      tooltip: _roomLocked ? 'Unlock' : 'Lock',
                      onPressed: () async {
                        await _toggleRoomLock();
                        setDialogState(() {});
                      },
                      icon: Icon(_roomLocked ? Icons.lock : Icons.lock_open),
                    ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: participants.isEmpty
                    ? Text(AppLocalizations.of(context)!.noParticipants)
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: participants.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final participant = participants[index];
                          final displayName = participant.name.isNotEmpty
                              ? participant.name
                              : participant.identity;
                          final micOn = isMicOn(participant);
                          final camOn = isCamOn(participant);
                          final isLocal = participant is LocalParticipant;

                          final cameraTrack =
                              _getParticipantCameraVideoTrack(participant);
                          final canPiP = kIsWeb && cameraTrack != null;

                          return ListTile(
                            dense: true,
                            title: Text(
                              isLocal ? '$displayName (You)' : displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              participant.identity,
                              overflow: TextOverflow.ellipsis,
                            ),
                            leading: CircleAvatar(
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  micOn ? Icons.mic : Icons.mic_off,
                                  size: 18,
                                  color: micOn ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  camOn ? Icons.videocam : Icons.videocam_off,
                                  size: 18,
                                  color: camOn ? Colors.green : Colors.red,
                                ),
                                if (!isLocal &&
                                    widget.isTeacher &&
                                    participant is RemoteParticipant &&
                                    !_isModeratorMessage(participant)) ...[
                                  const SizedBox(width: 6),
                                  PopupMenuButton<String>(
                                    tooltip: AppLocalizations.of(context)!
                                        .timesheetActions,
                                    onSelected: (value) async {
                                      if (value == 'mute') {
                                        try {
                                          await LiveKitService.muteParticipant(
                                            shiftId: widget.shiftId,
                                            identity: participant.identity,
                                          );
                                          _showSnack('Muted $displayName',
                                              backgroundColor: Colors.green);
                                        } catch (e) {
                                          _showSnack('Failed to mute: $e',
                                              backgroundColor: Colors.red);
                                        } finally {
                                          setDialogState(() {});
                                        }
                                      }

                                      if (value == 'unmute') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                                AppLocalizations.of(context)!
                                                    .unmuteParticipant),
                                            content: Text(
                                              'Enable $displayName\'s microphone?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: Text(AppLocalizations.of(
                                                        context)!
                                                    .commonCancel),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xff0386FF),
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: Text(AppLocalizations.of(
                                                        context)!
                                                    .unmute),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm != true) return;

                                        try {
                                          await LiveKitService
                                              .unmuteParticipant(
                                            shiftId: widget.shiftId,
                                            identity: participant.identity,
                                          );
                                        } catch (e) {
                                          _showSnack('Failed to unmute: $e',
                                              backgroundColor: Colors.red);
                                        }

                                        try {
                                          await _broadcastStudentMicState(
                                            enabled: true,
                                            destinationIdentities: [
                                              participant.identity,
                                            ],
                                          );
                                          _showSnack('Unmuted $displayName',
                                              backgroundColor: Colors.green);
                                        } catch (e) {
                                          AppLogger.error(
                                              'LiveKit: Failed to request unmute: $e');
                                        } finally {
                                          setDialogState(() {});
                                        }
                                      }

                                      if (value == 'kick') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                                AppLocalizations.of(context)!
                                                    .removeParticipant),
                                            content: Text(
                                              'Remove $displayName from the meeting?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: Text(AppLocalizations.of(
                                                        context)!
                                                    .commonCancel),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: Text(AppLocalizations.of(
                                                        context)!
                                                    .remove),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          try {
                                            await LiveKitService
                                                .kickParticipant(
                                              shiftId: widget.shiftId,
                                              identity: participant.identity,
                                            );
                                            _showSnack('Removed $displayName',
                                                backgroundColor: Colors.green);
                                          } catch (e) {
                                            _showSnack('Failed to remove: $e',
                                                backgroundColor: Colors.red);
                                          } finally {
                                            setDialogState(() {});
                                          }
                                        }
                                      }

                                      if (value == 'pip') {
                                        await _togglePictureInPicture(
                                          identity: participant.identity,
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: micOn ? 'mute' : 'unmute',
                                        child: Text(
                                            micOn ? 'Mute mic' : 'Unmute mic'),
                                      ),
                                      PopupMenuItem(
                                        value: 'kick',
                                        child: Text(
                                            AppLocalizations.of(context)!
                                                .remove),
                                      ),
                                      if (canPiP)
                                        PopupMenuItem(
                                          value: 'pip',
                                          child: Text(
                                              AppLocalizations.of(context)!
                                                  .pictureInPicture),
                                        ),
                                    ],
                                  ),
                                ] else if (!isLocal && canPiP) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    tooltip: AppLocalizations.of(context)!
                                        .pictureInPicture,
                                    onPressed: () => _togglePictureInPicture(
                                      identity: participant.identity,
                                    ),
                                    icon: const Icon(
                                        Icons.picture_in_picture_alt),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.commonClose),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _togglePictureInPicture({String? identity}) async {
    if (!kIsWeb) {
      _showSnack('Picture-in-picture is only available on web',
          backgroundColor: Colors.orange);
      return;
    }
    if (_pipBusy) return;

    setState(() => _pipBusy = true);
    try {
      final supported = await pip.isPictureInPictureSupported();
      if (!supported) {
        throw Exception('Picture-in-picture is not supported in this browser');
      }

      final active = await pip.isPictureInPictureActive();
      if (active) {
        await pip.exitPictureInPicture();
        _pipRenderer?.srcObject = null;
        if (mounted) {
          setState(() {
            _pipTrack = null;
            _pipIdentity = null;
          });
        }
        return;
      }

      final room = _room;
      if (room == null) throw Exception('Not connected');

      final RemoteParticipant? participant = identity == null
          ? room.remoteParticipants.values.firstWhere(
              (p) => _getParticipantCameraVideoTrack(p) != null,
              orElse: () => room.remoteParticipants.values.first,
            )
          : room.remoteParticipants[identity];

      if (participant == null) throw Exception('Participant not found');

      final track = _getParticipantCameraVideoTrack(participant);
      if (track == null) {
        throw Exception('Participant has no camera video');
      }

      await _ensurePipRendererInitialized();
      if (!mounted) return;

      setState(() {
        _pipTrack = track;
        _pipIdentity = participant.identity;
      });

      // Allow a frame for the VideoTrackRenderer to mount the underlying <video>.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final viewType = (_pipRenderer as dynamic).viewType as String?;
      if (viewType == null || viewType.isEmpty) {
        throw Exception('PiP renderer not available');
      }
      final elementId = 'video_$viewType';
      await _enterPictureInPictureWithRetries(elementId);
    } catch (e) {
      _showSnack('PiP failed: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _pipBusy = false);
    }
  }

  Future<void> _ensurePipRendererInitialized() async {
    if (_pipRenderer != null) return;

    final renderer = rtc.RTCVideoRenderer();
    await renderer.initialize();
    if (!mounted) {
      await renderer.dispose();
      return;
    }
    setState(() => _pipRenderer = renderer);
  }

  Future<void> _enterPictureInPictureWithRetries(String elementId) async {
    const maxAttempts = 25;
    const delay = Duration(milliseconds: 100);

    Object? lastError;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) break;
      try {
        await pip.enterPictureInPictureByElementId(elementId);
        return;
      } catch (e) {
        lastError = e;
        await Future.delayed(delay);
      }
    }
    throw lastError ?? Exception('Unable to start picture-in-picture');
  }

  Widget _buildBody(_ActiveScreenShare? activeScreenShare) {
    if (_connecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.connectingToClass,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _reconnectAttempts = 0;
                _attemptReconnect(null);
              },
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.commonRetry),
            ),
          ],
        ),
      );
    }

    if (_room == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.notConnected,
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    if (_isScreenShareFullscreen && activeScreenShare != null) {
      return _buildFullscreenScreenShare(activeScreenShare);
    }

    if (widget.isTeacher && _screenShareEnabled) {
      final screenShareTrack = _localParticipant == null
          ? null
          : _getParticipantScreenShareVideoTrack(_localParticipant!);
      return _buildTeacherScreenShareWithOverlay(screenShareTrack);
    }

    if (activeScreenShare != null) {
      return _buildScreenShareStage(activeScreenShare);
    }

    // Whiteboard view - teacher can set students as viewer or editor
    if (_whiteboardEnabled) {
      return CallWhiteboard(
        isTeacher: widget.isTeacher,
        onSendProject: _sendWhiteboardProject,
        projectStream: _whiteboardProjectController.stream,
        onClose: widget.isTeacher ? _toggleWhiteboard : null,
        studentDrawingEnabled: _studentDrawingEnabled,
        onStudentDrawingToggle: _toggleStudentDrawingPermission,
        initialStrokes: _initialWhiteboardStrokes,
      );
    }

    if (_activeScreenShareIdentity != null) {
      _activeScreenShareIdentity = null;
      _overlayAutoHiddenForShare = false;
      _resetScreenShareTransform();
    }
    _clearRemotePointer(notify: false);

    return _buildParticipantGrid();
  }

  Widget _buildTeacherScreenShareWithOverlay(VideoTrack? screenShareTrack) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final remoteParticipants =
            List<RemoteParticipant>.from(_nonSystemRemoteParticipants());
        remoteParticipants.sort((a, b) => a.identity.compareTo(b.identity));

        final shareIdentity = _localParticipant?.identity;
        if (shareIdentity != null &&
            _activeScreenShareIdentity != shareIdentity) {
          _activeScreenShareIdentity = shareIdentity;
          _overlayAutoHiddenForShare = false;
          _resetScreenShareTransform();
          _clearRemotePointer(notify: false);
        }

        final maxOverlayWidth = math.max(0.0, constraints.maxWidth - 24);
        final maxOverlayHeight = math.max(0.0, constraints.maxHeight - 24);

        final overlayWidth = math.min(
          maxOverlayWidth,
          (constraints.maxWidth * 0.35).clamp(200.0, 320.0).toDouble(),
        );
        final overlayHeight = math.min(
          maxOverlayHeight,
          (overlayWidth * 0.8).clamp(180.0, 260.0).toDouble(),
        );

        final safeOffset = _clampOverlayOffset(
          _participantsOverlayOffset,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          overlayWidth: overlayWidth,
          overlayHeight: overlayHeight,
          padding: 12,
        );

        if (safeOffset != _participantsOverlayOffset) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _participantsOverlayOffset = safeOffset);
          });
        }

        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black),
                child: screenShareTrack == null
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.startingScreenShare,
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      )
                    : _buildZoomableScreenShare(
                        screenShareTrack,
                        enableTapToToggleUi: false,
                        enablePointerCapture: true,
                      ),
              ),
            ),
            if (_showParticipantsOverlay)
              Positioned(
                left: safeOffset.dx,
                top: safeOffset.dy,
                child: _ParticipantsOverlayWindow(
                  width: overlayWidth,
                  height: overlayHeight,
                  participants: List<Participant>.from(remoteParticipants),
                  onPanUpdate: (delta) {
                    setState(() {
                      _participantsOverlayOffset = _clampOverlayOffset(
                        _participantsOverlayOffset + delta,
                        maxWidth: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                        overlayWidth: overlayWidth,
                        overlayHeight: overlayHeight,
                        padding: 12,
                      );
                    });
                  },
                  onClose: () =>
                      setState(() => _showParticipantsOverlay = false),
                ),
              )
            else
              Positioned(
                left: 12,
                top: 12,
                child: _ParticipantsOverlayChip(
                  onPressed: () =>
                      setState(() => _showParticipantsOverlay = true),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildScreenShareStage(_ActiveScreenShare activeShare) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shareIdentity = activeShare.participant.identity;
        if (_activeScreenShareIdentity != shareIdentity) {
          _activeScreenShareIdentity = shareIdentity;
          _overlayAutoHiddenForShare = false;
          _resetScreenShareTransform();
          _clearRemotePointer(notify: false);
        }

        final isNarrow = constraints.maxWidth < 700;
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final shouldAutoHideOverlay =
            !widget.isTeacher && isNarrow && isPortrait;

        if (shouldAutoHideOverlay &&
            !_overlayAutoHiddenForShare &&
            _showParticipantsOverlay) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _showParticipantsOverlay = false;
              _overlayAutoHiddenForShare = true;
            });
          });
        } else if (shouldAutoHideOverlay &&
            !_overlayAutoHiddenForShare &&
            !_showParticipantsOverlay) {
          _overlayAutoHiddenForShare = true;
        }

        final allParticipants = <Participant>[];
        if (_localParticipant != null) {
          allParticipants.add(_localParticipant!);
        }
        final remoteParticipants =
            List<RemoteParticipant>.from(_nonSystemRemoteParticipants());
        remoteParticipants.sort((a, b) => a.identity.compareTo(b.identity));
        allParticipants.addAll(remoteParticipants);

        final maxOverlayWidth = math.max(0.0, constraints.maxWidth - 24);
        final maxOverlayHeight = math.max(0.0, constraints.maxHeight - 24);

        final overlayWidth = math.min(
          maxOverlayWidth,
          (constraints.maxWidth * (isNarrow ? 0.9 : 0.35))
              .clamp(200.0, isNarrow ? 360.0 : 340.0)
              .toDouble(),
        );
        final overlayHeight = math.min(
          maxOverlayHeight,
          (overlayWidth * 0.75)
              .clamp(180.0, isNarrow ? 260.0 : 280.0)
              .toDouble(),
        );

        final safeOffset = _clampOverlayOffset(
          _participantsOverlayOffset,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          overlayWidth: overlayWidth,
          overlayHeight: overlayHeight,
          padding: 12,
        );

        if (safeOffset != _participantsOverlayOffset) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _participantsOverlayOffset = safeOffset);
          });
        }

        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black),
                child: _buildZoomableScreenShare(
                  activeShare.track,
                  enableTapToToggleUi: false,
                ),
              ),
            ),
            if (_showParticipantsOverlay)
              Positioned(
                left: safeOffset.dx,
                top: safeOffset.dy,
                child: _ParticipantsOverlayWindow(
                  width: overlayWidth,
                  height: overlayHeight,
                  participants: allParticipants,
                  onPanUpdate: (delta) {
                    setState(() {
                      _participantsOverlayOffset = _clampOverlayOffset(
                        _participantsOverlayOffset + delta,
                        maxWidth: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                        overlayWidth: overlayWidth,
                        overlayHeight: overlayHeight,
                        padding: 12,
                      );
                    });
                  },
                  onClose: () =>
                      setState(() => _showParticipantsOverlay = false),
                ),
              )
            else
              Positioned(
                left: 12,
                top: 12,
                child: _ParticipantsOverlayChip(
                  onPressed: () =>
                      setState(() => _showParticipantsOverlay = true),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFullscreenScreenShare(_ActiveScreenShare activeShare) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black),
            child: _buildZoomableScreenShare(
              activeShare.track,
              enableTapToToggleUi: true,
              enablePointerCapture: widget.isTeacher &&
                  _screenShareEnabled &&
                  _localParticipant?.identity ==
                      activeShare.participant.identity,
            ),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            child: IgnorePointer(
              ignoring: !_screenShareUiVisible,
              child: AnimatedOpacity(
                opacity: _screenShareUiVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FullscreenActionButton(
                        icon: Icons.arrow_back,
                        tooltip: AppLocalizations.of(context)!.leave,
                        onPressed: _leaveCall,
                      ),
                      Row(
                        children: [
                          _FullscreenActionButton(
                            icon: _screenShareFit == VideoViewFit.contain
                                ? Icons.crop_free
                                : Icons.fit_screen,
                            tooltip: _screenShareFit == VideoViewFit.contain
                                ? 'Fill screen'
                                : 'Fit to screen',
                            onPressed: _toggleScreenShareFit,
                          ),
                          const SizedBox(width: 8),
                          _FullscreenActionButton(
                            icon: Icons.menu_book,
                            tooltip: AppLocalizations.of(context)!.quran,
                            onPressed: _openQuranDialog,
                          ),
                          const SizedBox(width: 8),
                          _FullscreenActionButton(
                            icon: Icons.refresh,
                            tooltip: AppLocalizations.of(context)!.resetZoom,
                            onPressed: _resetScreenShareTransform,
                          ),
                          const SizedBox(width: 8),
                          _FullscreenActionButton(
                            icon: Icons.fullscreen_exit,
                            tooltip:
                                AppLocalizations.of(context)!.exitFullscreen,
                            onPressed: _exitScreenShareFullscreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Offset _clampOverlayOffset(
    Offset offset, {
    required double maxWidth,
    required double maxHeight,
    required double overlayWidth,
    required double overlayHeight,
    double padding = 0,
  }) {
    final maxDx = math.max(padding, maxWidth - overlayWidth - padding);
    final maxDy = math.max(padding, maxHeight - overlayHeight - padding);

    final dx = offset.dx.clamp(padding, maxDx).toDouble();
    final dy = offset.dy.clamp(padding, maxDy).toDouble();
    return Offset(dx, dy);
  }

  Widget _buildParticipantGrid() {
    final participants = <Participant>[];

    // Add local participant first
    if (_localParticipant != null) {
      participants.add(_localParticipant!);
    }

    // Add remote participants
    if (_room != null) {
      participants.addAll(_nonSystemRemoteParticipants());
    }

    if (participants.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.waitingForOthersToJoin,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length == 1 ? 1 : 2,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        return _ParticipantTile(participant: participants[index]);
      },
    );
  }

  Widget _buildControls() {
    final participantCount = _getParticipantCount();
    final hasRemoteParticipants =
        _room != null && _nonSystemRemoteParticipants().isNotEmpty;
    final micLocked = !widget.isTeacher && _micLockedByHost;
    final micLabel = micLocked
        ? (_micEnabled ? 'Mic locked' : 'Locked')
        : (_micEnabled ? 'Mute' : 'Unmute');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: SafeArea(
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          runAlignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: [
            _ControlButton(
              icon: _micEnabled ? Icons.mic : Icons.mic_off,
              label: _initializingMedia ? 'Starting...' : micLabel,
              isActive: _micEnabled,
              isLoading: _initializingMedia,
              onPressed: _initializingMedia
                  ? () {} // Disabled while loading
                  : (micLocked
                      ? () => _showSnack(
                            'Your microphone is locked by the host',
                            backgroundColor: Colors.orange.shade700,
                          )
                      : _toggleMicrophone),
            ),
            _ControlButton(
              icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
              label: _initializingMedia
                  ? 'Starting...'
                  : (_cameraEnabled ? 'Stop Video' : 'Start Video'),
              isActive: _cameraEnabled,
              isLoading: _initializingMedia,
              onPressed: _initializingMedia ? () {} : _toggleCamera,
            ),
            if (widget.isTeacher)
              _ControlButton(
                icon: _screenShareEnabled
                    ? Icons.stop_screen_share
                    : Icons.screen_share,
                label: _screenShareEnabled ? 'Stop Share' : 'Share Screen',
                isActive: _screenShareEnabled,
                activeColor: Colors.blue,
                onPressed: _toggleScreenShare,
              ),
            // Whiteboard button (teacher only)
            if (widget.isTeacher)
              _ControlButton(
                icon: _whiteboardEnabled ? Icons.draw : Icons.draw_outlined,
                label: _whiteboardEnabled
                    ? AppLocalizations.of(context)!.whiteboardClose
                    : AppLocalizations.of(context)!.whiteboard,
                isActive: _whiteboardEnabled,
                activeColor: Colors.purple,
                onPressed: _toggleWhiteboard,
              ),
            _ControlButton(
              icon: Icons.people,
              label: participantCount > 0
                  ? 'People ($participantCount)'
                  : 'People',
              isActive: true,
              onPressed: _room == null ? () {} : _showParticipantsDialog,
            ),
            if (widget.isTeacher)
              _ControlButton(
                icon: Icons.volume_off,
                label: AppLocalizations.of(context)!.livekitMuteAll,
                isActive: true,
                onPressed: !hasRemoteParticipants
                    ? () => _showSnack(
                          'No participants to mute',
                          backgroundColor: Colors.orange.shade700,
                        )
                    : _confirmMuteAll,
              ),
            if (widget.isTeacher)
              _ControlButton(
                icon: _studentMicrophonesLocked ? Icons.mic_off : Icons.mic,
                label: _studentMicrophonesLocked ? 'Allow unmute' : 'Lock mics',
                isActive: _studentMicrophonesLocked,
                onPressed: _room == null
                    ? () {}
                    : () => _setStudentMicLock(
                          !_studentMicrophonesLocked,
                          muteFirst: !_studentMicrophonesLocked,
                        ),
              ),
            if (widget.isTeacher)
              _ControlButton(
                icon: _roomLocked ? Icons.lock : Icons.lock_open,
                label: _roomLocked ? 'Unlock' : 'Lock',
                isActive: _roomLocked,
                onPressed: _room == null ? () {} : _toggleRoomLock,
              ),
            if (kIsWeb)
              _ControlButton(
                icon: _pipIdentity != null
                    ? Icons.picture_in_picture_alt
                    : Icons.picture_in_picture_alt_outlined,
                label: AppLocalizations.of(context)!.livekitPip,
                isActive: _pipIdentity != null,
                onPressed: _pipBusy || !hasRemoteParticipants
                    ? () => _showSnack(
                          'Picture-in-picture needs a participant video',
                          backgroundColor: Colors.orange.shade700,
                        )
                    : () => _togglePictureInPicture(),
              ),
            _ControlButton(
              icon: Icons.menu_book,
              label: AppLocalizations.of(context)!.livekitQuran,
              isActive: true,
              onPressed: _openQuranDialog,
            ),
            _ControlButton(
              icon: Icons.call_end,
              label: AppLocalizations.of(context)!.livekitLeave,
              isActive: true,
              activeColor: Colors.red,
              backgroundColor: Colors.red,
              onPressed: _leaveCall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveScreenShare {
  final Participant participant;
  final VideoTrack track;

  const _ActiveScreenShare({
    required this.participant,
    required this.track,
  });
}

class _FullscreenActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _FullscreenActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x73000000),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;

  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    // Get video track - prioritize screen share over camera
    final screenShareTrack = _getParticipantScreenShareVideoTrack(participant);
    final cameraTrack = _getParticipantCameraVideoTrack(participant);
    final videoTrack = screenShareTrack ?? cameraTrack;
    final isScreenSharing = screenShareTrack != null;

    // Check if audio is enabled
    bool audioEnabled = false;
    for (final trackPublication in participant.audioTrackPublications) {
      if (!trackPublication.muted) {
        audioEnabled = true;
        break;
      }
    }

    final isLocal = participant is LocalParticipant;
    final displayName =
        participant.name.isNotEmpty ? participant.name : participant.identity;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isScreenSharing
              ? Colors.orange.shade400
              : (isLocal ? Colors.white30 : Colors.white24),
          width: isScreenSharing ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Video view or placeholder
          if (videoTrack != null)
            VideoTrackRenderer(
              videoTrack,
            )
          else
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blueGrey.shade700,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Name overlay at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  if (isScreenSharing)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.screen_share,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)!.sharing,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Text(
                      isLocal ? '$displayName (You)' : displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!audioEnabled)
                    const Icon(
                      Icons.mic_off,
                      color: Colors.red,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),

          // Speaking indicator
          if (participant.isSpeaking)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.green, width: 3),
                ),
              ),
            ),

          // Connection quality badge
          Positioned(
            top: 6,
            right: 6,
            child: _buildConnectionQualityBadge(participant),
          ),
        ],
      ),
    );
  }
}

Widget _buildConnectionQualityBadge(Participant participant,
    {double iconSize = 14}) {
  final quality = participant.connectionQuality;
  IconData icon;
  Color color;
  String tooltip;
  switch (quality) {
    case ConnectionQuality.excellent:
      icon = Icons.signal_wifi_4_bar;
      color = Colors.green.shade400;
      tooltip = 'Excellent connection';
      break;
    case ConnectionQuality.good:
      icon = Icons.signal_wifi_4_bar;
      color = Colors.lightGreen.shade300;
      tooltip = 'Good connection';
      break;
    case ConnectionQuality.poor:
      icon = Icons.signal_wifi_bad;
      color = Colors.orange.shade400;
      tooltip = 'Poor connection';
      break;
    case ConnectionQuality.lost:
      icon = Icons.signal_wifi_off;
      color = Colors.red.shade400;
      tooltip = 'Connection lost';
      break;
    case ConnectionQuality.unknown:
      return const SizedBox.shrink();
  }
  return Tooltip(
    message: tooltip,
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: iconSize),
    ),
  );
}

VideoTrack? _getParticipantScreenShareVideoTrack(Participant participant) {
  final publications = participant.videoTrackPublications;

  for (final publication in publications) {
    if (publication.track == null || publication.muted) continue;
    if (publication.isScreenShare ||
        publication.source == TrackSource.screenShareVideo) {
      final track = publication.track;
      return track is VideoTrack ? track : null;
    }
  }

  // Fallback for any unknown source cases.
  for (final publication in publications) {
    if (publication.track == null || publication.muted) continue;
    final name = publication.name.toLowerCase();
    if (name.contains('screen')) {
      final track = publication.track;
      return track is VideoTrack ? track : null;
    }
  }

  return null;
}

VideoTrack? _getParticipantCameraVideoTrack(Participant participant) {
  final publications = participant.videoTrackPublications;

  for (final publication in publications) {
    if (publication.track == null || publication.muted) continue;
    if (publication.source == TrackSource.camera) {
      final track = publication.track;
      return track is VideoTrack ? track : null;
    }
  }

  // Fallback: first non-screenshare video track.
  for (final publication in publications) {
    if (publication.track == null || publication.muted) continue;
    if (publication.isScreenShare ||
        publication.source == TrackSource.screenShareVideo) continue;
    final name = publication.name.toLowerCase();
    if (name.contains('screen')) continue;
    final track = publication.track;
    return track is VideoTrack ? track : null;
  }

  return null;
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final Color? backgroundColor;
  final VoidCallback onPressed;
  final bool isLoading;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.activeColor,
    this.backgroundColor,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        (isActive
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.05));
    final iconColor = isLoading
        ? Colors.white38
        : (activeColor ?? (isActive ? Colors.white : Colors.white54));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(icon, color: iconColor),
                  onPressed: onPressed,
                  padding: const EdgeInsets.all(12),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: iconColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _ParticipantsOverlayChip extends StatelessWidget {
  final VoidCallback onPressed;

  const _ParticipantsOverlayChip({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.participants,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantsOverlayWindow extends StatelessWidget {
  final double width;
  final double height;
  final List<Participant> participants;
  final ValueChanged<Offset> onPanUpdate;
  final VoidCallback onClose;

  const _ParticipantsOverlayWindow({
    required this.width,
    required this.height,
    required this.participants,
    required this.onPanUpdate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => onPanUpdate(details.delta),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF16213E),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.drag_handle,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!
                            .livekitParticipantsCount(participants.length),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white70, size: 18),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: AppLocalizations.of(context)!.hide,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: participants.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.noParticipantsYet,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: participants.length == 1 ? 1 : 2,
                          childAspectRatio: 16 / 9,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          return _ParticipantCameraTile(
                              participant: participants[index]);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemotePointer extends StatelessWidget {
  const _RemotePointer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _ParticipantCameraTile extends StatelessWidget {
  final Participant participant;

  const _ParticipantCameraTile({
    required this.participant,
  });

  @override
  Widget build(BuildContext context) {
    final cameraTrack = _getParticipantCameraVideoTrack(participant);
    final displayName =
        participant.name.isNotEmpty ? participant.name : participant.identity;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (cameraTrack != null)
            VideoTrackRenderer(
              cameraTrack,
              fit: VideoViewFit.cover,
              autoCenter: false,
            )
          else
            Center(
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blueGrey.shade700,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 6),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _buildConnectionQualityBadge(participant, iconSize: 11),
          ),
        ],
      ),
    );
  }
}
