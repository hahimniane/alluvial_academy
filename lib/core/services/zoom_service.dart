import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/teaching_shift.dart';
import '../utils/app_logger.dart';
import 'zoom_meeting_sdk_join_service.dart';

/// Service for managing Zoom meetings within the app
///
/// This service now supports two join methods:
/// 1. Meeting SDK join (default for mobile) - native in-app Zoom experience
/// 2. Legacy WebView join (fallback) - opens Zoom web client in WebView
///
/// Use Remote Config `useLegacyZoomJoin` to toggle between methods.
class ZoomService {
  // Keep region explicit so callable endpoints match deployed functions.
  // Keep region explicit so callable endpoints match deployed functions.
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Check if the teacher can currently join the Zoom meeting
  /// Zoom link is accessible from 10 minutes before shift start to 10 minutes after shift end
  static bool canJoinMeeting(TeachingShift shift) {
    if (!shift.hasZoomMeeting) return false;

    final now = DateTime.now().toUtc();
    final shiftStart = shift.shiftStart.toUtc();
    final shiftEnd = shift.shiftEnd.toUtc();

    // Can join 10 minutes before start until 10 minutes after end
    final joinWindowStart = shiftStart.subtract(const Duration(minutes: 10));
    final joinWindowEnd = shiftEnd.add(const Duration(minutes: 10));

    return !now.isBefore(joinWindowStart) && !now.isAfter(joinWindowEnd);
  }

  /// Get the time until the Zoom meeting can be joined
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

  /// Join the Zoom meeting - uses Meeting SDK on mobile only
  static Future<void> joinMeetingInApp(
    BuildContext context,
    TeachingShift shift,
  ) async {
    if (!shift.hasZoomMeeting) {
      _showError(context, 'This shift does not have a Zoom meeting configured');
      return;
    }

    if (!canJoinMeeting(shift)) {
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
            'You can join this meeting in $timeText (10 minutes before the shift starts)');
      } else {
        _showError(context, 'The meeting window for this shift has ended');
      }
      return;
    }

    // On web, show error as SDK is mobile only
    if (kIsWeb) {
      _showError(
          context, 'In-app Zoom meeting is only supported on mobile devices.');
      return;
    }

    // Use Meeting SDK join for mobile
    await _joinWithMeetingSdk(context, shift);
  }

  /// Join using the native Meeting SDK (preferred for mobile)
  static Future<void> _joinWithMeetingSdk(
    BuildContext context,
    TeachingShift shift,
  ) async {
    final joinService = ZoomMeetingSdkJoinService();

    try {
      AppLogger.info(
          'ZoomService: Joining via Meeting SDK for shift ${shift.id}');

      // Show progress dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _MeetingSdkJoinDialog(
            joinService: joinService,
            shiftId: shift.id,
          ),
        );
      }

      // Start join flow
      final success = await joinService.joinShift(shiftId: shift.id);

      if (context.mounted) {
        // Close dialog if still showing
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (success) {
          // Meeting ended or user left - just reset state
          joinService.reset();
        }
      }
    } on ZoomJoinError catch (e) {
      AppLogger.error(
          'ZoomService: Meeting SDK join error: ${e.type} - ${e.message} \nDetail: ${e.detail}');

      if (context.mounted) {
        // Close dialog if showing
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Handle specific error types
        switch (e.type) {
          case ZoomJoinErrorType.unauthenticated:
            _showError(context, 'Please log in to join the meeting.');
            break;
          case ZoomJoinErrorType.permissionDenied:
            _showError(context, "You're not allowed to join this meeting.");
            break;
          case ZoomJoinErrorType.tooEarly:
            _showError(context, e.message);
            break;
          case ZoomJoinErrorType.tooLate:
            _showError(context, 'The meeting window has ended.');
            break;
          case ZoomJoinErrorType.notFound:
            _showError(context, 'Meeting not configured for this shift.');
            break;
          case ZoomJoinErrorType.wrongPasscode:
            _showError(context, 'Meeting password incorrect. Contact support.');
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
            _showError(context, 'Zoom Error: ${e.message}');
            break;
        }
      }
    } catch (e) {
      AppLogger.error('ZoomService: Unexpected Meeting SDK error: $e');

      if (context.mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showError(context, 'Unexpected error joining meeting: $e');
      }
    }
  }

  /// Request a new Zoom meeting to be created for a shift
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
    // Ensure we are on the main thread and context is valid
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

/// Dialog showing Meeting SDK join progress
class _MeetingSdkJoinDialog extends StatefulWidget {
  final ZoomMeetingSdkJoinService joinService;
  final String shiftId;

  const _MeetingSdkJoinDialog({
    required this.joinService,
    required this.shiftId,
  });

  @override
  State<_MeetingSdkJoinDialog> createState() => _MeetingSdkJoinDialogState();
}

class _MeetingSdkJoinDialogState extends State<_MeetingSdkJoinDialog> {
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

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state != ZoomJoinState.error) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                Text(
                  state.progressMessage,
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
