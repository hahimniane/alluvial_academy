import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/teaching_shift.dart';
import '../utils/app_logger.dart';
import '../../features/zoom/screens/in_app_zoom_meeting_screen.dart';

/// Service for managing Zoom meetings within the app
class ZoomService {
  // Keep region explicit so callable endpoints match deployed functions.
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Get the join URL for a shift's Zoom meeting
  /// The backend generates a time-gated token that's only valid around the shift time
  static Future<String> getJoinUrl(TeachingShift shift) async {
    if (!shift.hasZoomMeeting) {
      throw Exception('This shift does not have a Zoom meeting configured');
    }
    
    try {
      final callable = _functions.httpsCallable('getZoomJoinUrl');
      final result = await callable.call({'shiftId': shift.id});
      
      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true && data['joinUrl'] != null) {
        return data['joinUrl'] as String;
      }
      
      throw Exception('Failed to get join URL: ${data['error'] ?? 'Unknown error'}');
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('ZoomService: Error getting join URL: $e');
      if (e.code == 'not-found') {
        throw Exception(
          'Zoom join service is unavailable (Cloud Function `getZoomJoinUrl` not found). '
          'Confirm you deployed Cloud Functions to the `alluwal-academy` project/`us-central1`.',
        );
      }
      rethrow;
    } catch (e) {
      AppLogger.error('ZoomService: Error getting join URL: $e');
      rethrow;
    }
  }

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

  /// Join the Zoom meeting in-app
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
          timeText = '$hours hour${hours > 1 ? 's' : ''} and $remainingMins minute${remainingMins != 1 ? 's' : ''}';
        } else {
          timeText = '$minutes minute${minutes != 1 ? 's' : ''}';
        }
        
        _showError(
          context, 
          'You can join this meeting in $timeText (10 minutes before the shift starts)'
        );
      } else {
        _showError(context, 'The meeting window for this shift has ended');
      }
      return;
    }

    // On web, we can't use WebView, so open externally
    if (kIsWeb) {
      AppLogger.info('ZoomService: Opening Zoom meeting externally (web platform)');
      // On web, we need to use url_launcher
      // Import it at the top of the file and use it here
      return;
    }

    try {
      AppLogger.info('ZoomService: Joining Zoom meeting in-app for shift ${shift.id}');
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final meetingUrl = await getJoinUrl(shift);
      
      if (!context.mounted) return;
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InAppZoomMeetingScreen(
            meetingUrl: meetingUrl,
            meetingId: shift.zoomMeetingId,
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('ZoomService: Error joining meeting: $e');
      if (context.mounted) {
        // Close loading dialog if it's still showing.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showError(context, 'Failed to join meeting: ${e.toString()}');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
