import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/teaching_shift.dart';
import '../utils/app_logger.dart';
import 'zoom_meeting_sdk_join_service.dart';
// Web SDK service import - only used on web platform
import 'zoom_web_sdk_service.dart'
    if (dart.library.io) 'zoom_web_sdk_stub.dart';

/// Service for managing Zoom meetings within the app
///
/// Users simply click "Join Class" and are automatically routed to their
/// class (breakout room). The complexity of hub meetings and breakout rooms
/// is handled entirely behind the scenes.
class ZoomService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if the user can currently join the class
  /// Class is accessible from 10 minutes before shift start to 10 minutes after shift end
  static bool canJoinClass(TeachingShift shift) {
    if (!shift.hasZoomMeeting) return false;

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
    if (!shift.hasZoomMeeting) return null;

    final now = DateTime.now().toUtc();
    final joinWindowStart =
        shift.shiftStart.toUtc().subtract(const Duration(minutes: 10));

    if (now.isBefore(joinWindowStart)) {
      return joinWindowStart.difference(now);
    }

    return null;
  }

  /// Join the class - users are automatically routed to their class
  static Future<void> joinClass(
    BuildContext context,
    TeachingShift shift,
  ) async {
    if (!shift.hasZoomMeeting) {
      _showError(context, 'This class does not have a meeting configured yet');
      return;
    }

    if (!canJoinClass(shift)) {
      final timeUntil = getTimeUntilCanJoin(shift);
      if (timeUntil != null) {
        final minutes = timeUntil.inMinutes;
        final hours = minutes ~/ 60;
        final remainingMins = minutes % 60;

        String timeText;
        if (hours > 0) {
          timeText =
              '$hours hour${hours > 1 ? 's' : ''} and $remainingMins minute${remainingMins != 1 ? 's' : ''}';
        } else {
          timeText = '$minutes minute${minutes != 1 ? 's' : ''}';
        }

        _showError(context,
            'You can join this class in $timeText (10 minutes before it starts)');
      } else {
        _showError(context, 'This class has ended');
      }
      return;
    }

    // Teachers need to open breakout rooms after joining (Zoom does not reliably support auto-open via API).
    // Show a quick instruction prompt before launching the meeting UI.
    if (!kIsWeb) {
      final currentUser = _auth.currentUser;
      final isTeacherForShift =
          currentUser != null && currentUser.uid == shift.teacherId;

      if (isTeacherForShift && context.mounted) {
        final roomName = shift.breakoutRoomName;
        final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Open breakout rooms'),
                content: Text(
                  'After you join, you will be able to claim host and open breakout rooms.\n\n'
                  'Steps:\n'
                  '1) Join the class.\n'
                  '2) Claim host when prompted.\n'
                  '3) Tap “Breakout Rooms” → “Open All Rooms”.\n\n'
                  '${roomName != null && roomName.isNotEmpty ? 'Your room: $roomName\n\n' : ''}'
                  'Students will stay in the main room until rooms are opened.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ) ??
            false;

        if (!shouldContinue) return;
      }
    }

    // Use appropriate SDK based on platform
    if (kIsWeb) {
      // Use Web SDK on web platform
      await _joinMeetingWeb(context, shift);
    } else {
      // Use native Meeting SDK on mobile
      await _joinMeeting(context, shift);
    }
  }

  /// Legacy method name for backward compatibility
  @Deprecated('Use joinClass instead')
  static Future<void> joinMeetingInApp(
    BuildContext context,
    TeachingShift shift, {
    String? userEmail,
  }) async {
    await joinClass(context, shift);
  }

  /// Legacy method name for backward compatibility
  @Deprecated('Use canJoinClass instead')
  static bool canJoinMeeting(TeachingShift shift) => canJoinClass(shift);

  /// Join the meeting using native Meeting SDK
  static Future<void> _joinMeeting(
    BuildContext context,
    TeachingShift shift,
  ) async {
    final joinService = ZoomMeetingSdkJoinService();

    try {
      AppLogger.info('ZoomService: Joining class for shift ${shift.id}');

      // Show progress dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _JoinClassDialog(
            joinService: joinService,
            shiftId: shift.id,
          ),
        );
      }

      // Join the meeting - backend handles hub/breakout routing via pre-assignment
      final success = await joinService.joinShift(shiftId: shift.id);

      if (context.mounted) {
        // Close progress dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (success) {
          // Successfully joined - user is automatically in their class
          joinService.reset();
        }
      }
    } on ZoomJoinError catch (e) {
      AppLogger.error(
          'ZoomService: Join error: ${e.type} - ${e.message} \nDetail: ${e.detail}');

      if (context.mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        switch (e.type) {
          case ZoomJoinErrorType.unauthenticated:
            _showError(context, 'Please log in to join the class.');
            break;
          case ZoomJoinErrorType.permissionDenied:
            _showError(context, "You're not allowed to join this class.");
            break;
          case ZoomJoinErrorType.tooEarly:
            _showError(context, e.message);
            break;
          case ZoomJoinErrorType.tooLate:
            _showError(context, 'This class has ended.');
            break;
          case ZoomJoinErrorType.notFound:
            _showError(context, 'Class not configured. Contact admin.');
            break;
          case ZoomJoinErrorType.wrongPasscode:
            _showError(context, 'Unable to join. Contact support.');
            break;
          case ZoomJoinErrorType.networkError:
            _showError(context, "Couldn't connect. Please try again.");
            break;
          case ZoomJoinErrorType.cancelled:
            // User cancelled, no error message needed
            break;
          case ZoomJoinErrorType.sdkAuthFailed:
          case ZoomJoinErrorType.joinFailed:
          case ZoomJoinErrorType.unknown:
            _showError(context, 'Error joining class: ${e.message}');
            break;
        }
      }
    } catch (e) {
      AppLogger.error('ZoomService: Unexpected error: $e');

      if (context.mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showError(context, 'Unexpected error joining class');
      }
    }
  }

  /// Join the meeting using Web SDK (web platform only)
  static Future<void> _joinMeetingWeb(
    BuildContext context,
    TeachingShift shift,
  ) async {
    final webService = ZoomWebSdkService();

    try {
      AppLogger.info(
          'ZoomService: Joining class via Web SDK for shift ${shift.id}');

      // Show progress dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _JoinWebClassDialog(
            webService: webService,
            shiftId: shift.id,
          ),
        );
      }

      // Initialize the Web SDK first
      final initialized = await webService.initialize();
      if (!initialized) {
        throw Exception('Failed to initialize Zoom Web SDK');
      }

      // Fetch join payload from backend
      AppLogger.debug('ZoomService: Fetching web join payload...');
      final callable = _functions.httpsCallable('getZoomMeetingSdkJoinPayload');
      final result = await callable.call({'shiftId': shift.id});

      final rawData = result.data;
      if (rawData == null) {
        throw Exception('Received null data from backend');
      }

      final data = Map<String, dynamic>.from(rawData as Map);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to get join payload');
      }

      final meetingNumber = data['meetingNumber']?.toString() ?? '';
      final meetingPasscode = data['meetingPasscode']?.toString() ?? '';
      final meetingSdkJwt = data['meetingSdkJwt']?.toString() ?? '';
      final sdkKey = data['sdkKey']?.toString() ?? '';
      final displayName = data['displayName']?.toString() ?? 'Participant';
      final payloadUserEmail = data['userEmail']?.toString();
      final payloadAuthEmail = data['authEmail']?.toString();

      if (meetingNumber.isEmpty || meetingSdkJwt.isEmpty || sdkKey.isEmpty) {
        throw Exception('Missing meeting details from backend');
      }

      // Web pre-assign routing works best when Zoom can match the joiner to the pre-assigned email.
      // If Firebase Auth email and profile email disagree, warn before joining.
      final currentAuthEmail = _auth.currentUser?.email;
      final normalizedAuthEmail = (currentAuthEmail ?? '').trim().toLowerCase();
      final normalizedPayloadAuthEmail = (payloadAuthEmail ?? '').trim().toLowerCase();
      final normalizedPayloadUserEmail = (payloadUserEmail ?? '').trim().toLowerCase();

      final expectedEmailForRouting =
          normalizedPayloadUserEmail.isNotEmpty ? payloadUserEmail!.trim() : (currentAuthEmail?.trim());

      final emailsDisagree = normalizedPayloadUserEmail.isNotEmpty &&
          normalizedAuthEmail.isNotEmpty &&
          normalizedPayloadUserEmail != normalizedAuthEmail;

      if (context.mounted && emailsDisagree) {
        final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Email mismatch'),
                content: Text(
                  'Your account email (${currentAuthEmail ?? "unknown"}) does not match the email on your profile (${payloadUserEmail ?? "unknown"}).\n\n'
                  'Zoom breakout auto-routing is email-based. To be routed to the correct breakout room, sign into Zoom using: ${payloadUserEmail ?? "your assigned email"}.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ) ??
            false;

        if (!shouldContinue) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          return;
        }
      } else if (context.mounted &&
          expectedEmailForRouting != null &&
          expectedEmailForRouting.trim().isNotEmpty) {
        // Light-touch reminder (no blocking) to reduce routing issues.
        AppLogger.debug(
            'ZoomService: Web join expected email for routing: $expectedEmailForRouting (authEmail: ${normalizedAuthEmail.isNotEmpty ? currentAuthEmail : normalizedPayloadAuthEmail})');
      }

      AppLogger.debug(
          'ZoomService: Got payload, joining meeting $meetingNumber');

      // Join the meeting using web SDK
      final success = await webService.joinMeeting(
        meetingNumber: meetingNumber,
        signature: meetingSdkJwt,
        sdkKey: sdkKey,
        displayName: displayName,
        password: meetingPasscode,
        email: expectedEmailForRouting,
      );

      if (context.mounted) {
        // Close progress dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (success) {
          // Successfully joined - the Zoom UI will be shown by the SDK
          AppLogger.info(
              'ZoomService: Successfully joined meeting via Web SDK');
          webService.reset();
        } else {
          _showError(context, 'Failed to join meeting');
        }
      }
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'ZoomService: Firebase error joining web: ${e.code} - ${e.message}');

      if (context.mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        String message;
        switch (e.code) {
          case 'unauthenticated':
            message = 'Please log in to join the class.';
            break;
          case 'permission-denied':
            message = "You're not allowed to join this class.";
            break;
          case 'failed-precondition':
            message = e.message ?? 'Cannot join at this time.';
            break;
          case 'not-found':
            message = 'Class not configured. Contact admin.';
            break;
          default:
            message = "Couldn't connect. Please try again.";
        }
        _showError(context, message);
      }
    } catch (e) {
      AppLogger.error('ZoomService: Error joining via Web SDK: $e');

      if (context.mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showError(context, 'Error joining class: $e');
      }
    }
  }

  /// Request a new Zoom meeting to be created for a shift (admin use)
  static Future<bool> createMeetingForShift(String shiftId) async {
    try {
      final callable = _functions.httpsCallable('testZoomForShift');
      final result = await callable.call({'shiftId': shiftId});

      final data = result.data as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      AppLogger.error('ZoomService: Error creating meeting: $e');
      return false;
    }
  }

  static void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

/// Dialog showing join progress
class _JoinClassDialog extends StatefulWidget {
  final ZoomMeetingSdkJoinService joinService;
  final String shiftId;

  const _JoinClassDialog({
    required this.joinService,
    required this.shiftId,
  });

  @override
  State<_JoinClassDialog> createState() => _JoinClassDialogState();
}

class _JoinClassDialogState extends State<_JoinClassDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<ZoomJoinState>(
          stream: widget.joinService.stateStream,
          initialData: widget.joinService.state,
          builder: (context, snapshot) {
            final state = snapshot.data ?? ZoomJoinState.idle;

            // Map internal states to user-friendly messages
            String message;
            switch (state) {
              case ZoomJoinState.idle:
              case ZoomJoinState.preflight:
                message = 'Preparing...';
                break;
              case ZoomJoinState.fetchingPayload:
                message = 'Connecting to class...';
                break;
              case ZoomJoinState.sdkInitializing:
              case ZoomJoinState.sdkAuthenticating:
                message = 'Setting up...';
                break;
              case ZoomJoinState.joining:
                message = 'Joining class...';
                break;
              case ZoomJoinState.inMeeting:
                message = 'You are in the class';
                break;
              case ZoomJoinState.ended:
                message = 'Class ended';
                break;
              case ZoomJoinState.error:
                message = 'Unable to join';
                break;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state != ZoomJoinState.error) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (state != ZoomJoinState.inMeeting)
                  TextButton(
                    onPressed: () {
                      widget.joinService.cancelJoin();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Dialog showing web join progress
class _JoinWebClassDialog extends StatefulWidget {
  final ZoomWebSdkService webService;
  final String shiftId;

  const _JoinWebClassDialog({
    required this.webService,
    required this.shiftId,
  });

  @override
  State<_JoinWebClassDialog> createState() => _JoinWebClassDialogState();
}

class _JoinWebClassDialogState extends State<_JoinWebClassDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<ZoomWebState>(
          stream: widget.webService.stateStream,
          initialData: widget.webService.state,
          builder: (context, snapshot) {
            final state = snapshot.data ?? ZoomWebState.idle;

            // Map internal states to user-friendly messages
            String message;
            switch (state) {
              case ZoomWebState.idle:
              case ZoomWebState.initializing:
                message = 'Loading Zoom...';
                break;
              case ZoomWebState.initialized:
                message = 'Connecting to class...';
                break;
              case ZoomWebState.joining:
                message = 'Joining class...';
                break;
              case ZoomWebState.inMeeting:
                message = 'You are in the class';
                break;
              case ZoomWebState.ended:
                message = 'Class ended';
                break;
              case ZoomWebState.error:
                message = widget.webService.errorMessage ?? 'Unable to join';
                break;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state != ZoomWebState.error) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (state != ZoomWebState.inMeeting)
                  TextButton(
                    onPressed: () {
                      widget.webService.cancelJoin();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
