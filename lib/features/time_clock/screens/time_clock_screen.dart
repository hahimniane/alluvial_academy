// ============================================================================
// TIME CLOCK SCREEN
// ============================================================================
// This screen handles the teacher's time clock functionality for tracking
// work hours against pre-scheduled teaching shifts.
//
// KEY FEATURES:
// - Shift-based clock-in/clock-out (teachers can only clock in during scheduled shifts)
// - Location verification for both clock-in and clock-out
// - Session persistence (resumes active sessions across app restarts)
// - Auto-logout after shift ends
// - Real-time timesheet display (desktop table view / mobile card view)
// - Comprehensive debug logging to Firestore for troubleshooting
//
// ARCHITECTURE:
// - Uses ShiftTimesheetService for all backend operations
// - Validates shifts and locations before allowing clock actions
// - Maintains UI state synchronized with backend database
// - Handles edge cases like expired shifts, network issues, and state mismatches
// ============================================================================

import '../../../core/enums/shift_enums.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/timesheet_table.dart' show TimesheetTable;
import '../widgets/mobile_timesheet_view.dart' show MobileTimesheetView;
import '../../../core/services/location_service.dart';
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/utils/platform_utils.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Main time clock screen widget - stateful to manage clock-in/out sessions
class TimeClockScreen extends StatefulWidget {
  const TimeClockScreen({super.key});

  @override
  _TimeClockScreenState createState() => _TimeClockScreenState();
}

/// State class for TimeClockScreen
/// WidgetsBindingObserver allows us to detect when app goes to background/foreground
/// This is crucial for resuming active sessions when user returns to the app
class _TimeClockScreenState extends State<TimeClockScreen>
    with WidgetsBindingObserver {
  // ============================================================================
  // STATE VARIABLES - Clock-In Session
  // ============================================================================
  // These variables track the current clock-in session state

  /// Whether the user is currently clocked in
  bool _isClockingIn = false;

  /// Display name of the shift the user is clocked into (e.g., "Math Class - Nov 22")
  String _selectedStudentName = '';

  /// The exact time when the user clocked in (used to calculate total hours)
  DateTime? _clockInTime;

  /// Stopwatch for tracking elapsed time in the current session
  final Stopwatch _stopwatch = Stopwatch();

  /// Timer that updates the UI every second to show elapsed time
  Timer? _timer;

  /// Formatted string showing total hours worked (e.g., "02:30:45")
  String _totalHoursWorked = "00:00:00";

  // ============================================================================
  // STATE VARIABLES - Auto-Logout
  // ============================================================================
  // These variables handle automatic clock-out when shift ends

  /// Timer that triggers auto-logout when shift ends
  Timer? _autoLogoutTimer;

  /// Countdown string shown to user (e.g., "Auto-logout in 5:00")
  String _timeUntilAutoLogout = "";

  // ============================================================================
  // STATE VARIABLES - Location Data
  // ============================================================================
  // Location is required for both clock-in and clock-out to verify
  // the teacher is at the correct location

  /// Location data captured when user clocked in
  LocationData? _clockInLocation;

  /// Location data captured when user clocked out
  LocationData? _clockOutLocation;

  /// Loading state while fetching GPS location
  bool _isGettingLocation = false;

  // ============================================================================
  // STATE VARIABLES - Shift Management
  // ============================================================================
  // The shift represents the scheduled teaching session that the user can clock into

  /// The current shift the user can clock into (or is clocked into)
  /// null if no valid shift is available
  TeachingShift? _currentShift;

  /// Loading state while checking for available shifts
  bool _isCheckingShift = false;

  /// Flag to prevent auto-resuming sessions after user manually clocks out
  /// This prevents the app from immediately resuming a session the user just ended
  bool _hasExplicitlyClockedOut = false;

  // ============================================================================
  // STATE VARIABLES - Session Tracking & Debugging
  // ============================================================================
  // These variables help with debugging and tracking session state

  /// ID of the last open session (used for debugging and logging)
  String? _lastSessionId;

  /// Timestamp of the last session check (used for debugging)
  DateTime? _lastSessionCheck;

  /// Flag to prevent duplicate session resume calls
  bool _isResumingSession = false;

  // ============================================================================
  // STATE VARIABLES - UI Components
  // ============================================================================

  /// Legacy list - kept for backward compatibility but not used
  /// Timesheet data is now fetched directly from Firestore by TimesheetTable widget
  final List<dynamic> _timesheetEntries = [];

  /// Key to access and refresh the TimesheetTable widget
  final GlobalKey<State<TimesheetTable>> _timesheetTableKey =
      GlobalKey<State<TimesheetTable>>();

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  /// Platform detection helper
  /// Returns true if running on Android or iOS (false for web or desktop)
  /// Used to determine which UI layout to show (mobile vs desktop)
  bool get _isMobile {
    // Check if we're on web first
    if (kIsWeb) {
      return false;
    }
    // Check platform
    final platform = defaultTargetPlatform;
    final isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return isMobile;
  }

  // ============================================================================
  // DEBUG LOGGING SYSTEM
  // ============================================================================
  // These methods provide comprehensive logging for troubleshooting clock-in/out issues
  // Logs go to both console (via AppLogger) and Firestore (for persistent debugging)

  /// Enhanced debug logging with timestamps and user identification
  ///
  /// Parameters:
  /// - message: The log message
  /// - isError: If true, logs as error; otherwise logs as debug
  ///
  /// All logs are prefixed with timestamp, user ID, and screen name for easy filtering
  void _debugLog(String message, {bool isError = false}) {
    final timestamp = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
    final userId =
        FirebaseAuth.instance.currentUser?.uid?.substring(0, 8) ?? 'unknown';
    final prefix = '[$timestamp][User:$userId][TimeClockScreen]';

    if (isError) {
      AppLogger.error('❌ $prefix ERROR: $message');
    } else {
      AppLogger.debug('🕐 $prefix $message');
    }

    // Also log to Firestore for debugging problematic users
    _logToFirestore(message, isError: isError);
  }

  /// Logs important events to Firestore for persistent debugging
  ///
  /// Only logs events related to clock operations, sessions, or errors
  /// to avoid excessive database writes. Logs include device info and session state.
  /// Firestore logs can be viewed in the admin panel for troubleshooting user issues.
  Future<void> _logToFirestore(String message, {bool isError = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Only log important events
      if (isError ||
          message.contains('clock') ||
          message.contains('session') ||
          message.contains('resume')) {
        await FirebaseFirestore.instance
            .collection('debug_logs')
            .doc(user.uid)
            .collection('time_clock_logs')
            .add({
          'timestamp': FieldValue.serverTimestamp(),
          'message': message,
          'isError': isError,
          'deviceInfo': {
            'platform': defaultTargetPlatform.toString(),
            'isWeb': kIsWeb,
            'isMobile': _isMobile,
          },
          'sessionInfo': {
            'isClockingIn': _isClockingIn,
            'hasExplicitlyClockedOut': _hasExplicitlyClockedOut,
            'currentShiftId': _currentShift?.id,
            'lastSessionId': _lastSessionId,
            'clockInTime': _clockInTime?.toIso8601String(),
          },
        });
      }
    } catch (e) {
      // Silently fail - don't break the app for logging
    }
  }

  // ============================================================================
  // LIFECYCLE METHODS
  // ============================================================================
  // Flutter lifecycle hooks for initialization, cleanup, and app state changes

  /// Called when the widget is first created
  ///
  /// Initializes the screen by:
  /// 1. Adding this widget as an app lifecycle observer
  /// 2. Checking for active shifts the user can clock into
  /// 3. Attempting to resume any open session from the database
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _debugLog('initState called');
    // Initialize shift and session in proper order
    _initializeShiftAndSession();
    // DISABLED: Shift monitoring is now handled by backend cloud function
    // to avoid timezone issues and ensure consistency
    // _runPeriodicShiftMonitoring();
  }

  /// Orchestrates the initialization flow
  ///
  /// Must run in this order:
  /// 1. Check for active shift first (loads _currentShift)
  /// 2. Resume open session second (may update _currentShift from database)
  Future<void> _initializeShiftAndSession() async {
    _debugLog('Starting initialization sequence');
    await _checkForActiveShift();
    await _resumeOpenSession();
    _debugLog('Initialization sequence completed');
  }

  /// Formats a duration into HH:MM:SS string
  ///
  /// Example: Duration of 90 minutes 30 seconds -> "01:30:30"
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // ============================================================================
  // SESSION MANAGEMENT
  // ============================================================================
  // These methods handle resuming and maintaining clock-in sessions

  /// Attempts to resume an open clock-in session from the database
  ///
  /// This is called:
  /// - On app startup (initState)
  /// - When app returns to foreground (didChangeAppLifecycleState)
  /// - When screen becomes active (didChangeDependencies)
  ///
  /// The method will skip resuming if:
  /// - User explicitly clocked out (to prevent immediate re-clock-in)
  /// - No open session exists in database
  /// - Session data is invalid or shift has ended
  ///
  /// If a valid open session is found, it restores:
  /// - The current shift
  /// - Clock-in time
  /// - Elapsed time counter
  /// - Auto-logout timer
  Future<void> _resumeOpenSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _debugLog('No authenticated user, skipping resume');
      return;
    }

    // Don't resume if user explicitly clocked out
    if (_hasExplicitlyClockedOut) {
      _debugLog(
          'Skipping resume - user has explicitly clocked out (flag=$_hasExplicitlyClockedOut)');
      return;
    }

    // Don't resume if already resuming (prevent duplicate calls)
    if (_isResumingSession) {
      _debugLog('Already resuming session, skipping duplicate call');
      return;
    }

    setState(() {
      _isResumingSession = true;
    });

    try {
      _debugLog('Checking for open session for user ${user.uid}');
      final session = await ShiftTimesheetService.getOpenSession(user.uid);

      if (session == null) {
        _debugLog('No open session found in database');
        // Reset the UI state if no session found
        if (_isClockingIn) {
          _debugLog(
              'UI shows clocked in but no session in database - resetting UI');
          _resetClockOutState(null, skipExplicitFlag: true);
        }
        return;
      }

      if (!mounted) return;

      final shift = session['shift'] as TeachingShift?;
      final clockInTime = session['clockInTime'] as DateTime?;
      final sessionId = session['sessionId'] as String?;

      if (shift == null || clockInTime == null) {
        _debugLog(
            'Invalid session data: shift=${shift != null}, clockInTime=${clockInTime != null}');
        return;
      }

      // Fix: Check if shift is actually valid to resume
      // If the shift is missed, completed, cancelled, we should NOT resume the timer
      // ALSO: If shift is expired AND still scheduled/active (server hasn't updated yet), don't resume
      // BUT: Allow resuming if shift is expired but user is actively clocked in (they need to clock out)
      if (shift.status == ShiftStatus.missed ||
          shift.status == ShiftStatus.completed ||
          shift.status == ShiftStatus.fullyCompleted ||
          shift.status == ShiftStatus.partiallyCompleted ||
          shift.status == ShiftStatus.cancelled) {
        _debugLog(
            'Shift ${shift.id} has final status ${shift.status.name} - stopping session');

        if (mounted) {
          _resetClockOutState(null, skipExplicitFlag: true);
          _showStateMismatchError();
        }
        return;
      }

      // Prevent resuming expired shifts that are still scheduled/active (stale data)
      // But allow resuming active sessions that need to clock out
      if (shift.hasExpired && shift.status == ShiftStatus.scheduled) {
        _debugLog(
            'Shift ${shift.id} is expired and still scheduled - stopping invalid session');

        if (mounted) {
          _resetClockOutState(null, skipExplicitFlag: true);
          _showStateMismatchError();
        }
        return;
      }

      // Calculate elapsed time since clock-in
      final now = DateTime.now();
      final elapsed = now.difference(clockInTime);

      _debugLog(
          'Found open session: sessionId=$sessionId, elapsed=${elapsed.inMinutes} minutes');
      _lastSessionId = sessionId;
      _lastSessionCheck = now;

      setState(() {
        _currentShift = shift;
        _isClockingIn = true;
        _selectedStudentName = shift.displayName;
        _clockInTime =
            clockInTime; // Use the actual clock-in time from database
        _totalHoursWorked = _formatDuration(elapsed);
        _hasExplicitlyClockedOut =
            false; // Reset flag when resuming valid session

        // Reset and start the stopwatch
        _stopwatch.reset();
        _stopwatch.start();
        // Note: We track the actual start time separately in _clockInTime

        _startTimer();
        _startAutoLogoutTimer();
      });

      _debugLog(
          'Session resumed successfully - elapsed time: ${elapsed.inMinutes} minutes');
    } catch (e) {
      _debugLog('Error resuming open session: $e', isError: true);
      // Reset UI state on error
      if (_isClockingIn && mounted) {
        _resetClockOutState(null, skipExplicitFlag: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResumingSession = false;
        });
      }
    }
  }

  /// Checks for available shifts the user can clock into
  ///
  /// This is called:
  /// - On app initialization
  /// - When app returns to foreground
  ///
  /// Queries ShiftTimesheetService to find any valid shift within the allowed
  /// clock-in window. If found, stores it in _currentShift so the user can clock in.
  Future<void> _checkForActiveShift() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _debugLog('No authenticated user for shift check');
      return;
    }

    try {
      _debugLog('Checking for active shift');
      // Check if teacher has any valid shift
      final shiftResult =
          await ShiftTimesheetService.getValidShiftForClockIn(user.uid);

      if (mounted) {
        final shift = shiftResult['shift'] as TeachingShift?;

        if (shift != null) {
          setState(() {
            _currentShift = shift;
          });

          _debugLog('Found available shift: ${shift.displayName}');
        } else {
          _debugLog('No valid shift found');
        }
      }
    } catch (e) {
      _debugLog('Error checking for active shift: $e', isError: true);
    }
  }

  /// Called when widget is being permanently removed
  ///
  /// Cleanup tasks:
  /// - Cancel all timers to prevent memory leaks
  /// - Remove app lifecycle observer
  @override
  void dispose() {
    _debugLog('dispose called');
    _timer?.cancel();
    _autoLogoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // DISABLED: Client-side shift monitoring has been removed
  // Shift status monitoring is now handled by backend cloud function (monitorShiftStatuses)
  // which runs every 5 minutes to ensure consistent UTC-based checking
  // and avoid timezone issues that were causing premature "Missed" status
  //
  // /// Run periodic shift monitoring for auto clock-outs and missed shifts
  // void _runPeriodicShiftMonitoring() {
  //   // Run monitoring immediately
  //   ShiftMonitoringService.runPeriodicMonitoring();
  //   _checkAndClearExpiredShift();
  //
  //   // Set up periodic monitoring every 15 minutes
  //   Timer.periodic(const Duration(minutes: 15), (timer) {
  //     if (!mounted) {
  //       timer.cancel();
  //       return;
  //     }
  //     ShiftMonitoringService.runPeriodicMonitoring();
  //   });
  //
  //   // Check for expired shifts more frequently (every minute)
  //   Timer.periodic(const Duration(minutes: 1), (timer) {
  //     if (!mounted) {
  //       timer.cancel();
  //       return;
  //     }
  //     _checkAndClearExpiredShift();
  //   });
  // }

  // DISABLED: No longer needed as shift monitoring is handled by backend
  // /// Check if current shift has expired and clear it
  // void _checkAndClearExpiredShift() {
  //   if (_currentShift != null && _currentShift!.hasExpired) {
  //     _debugLog('Clearing expired shift: ${_currentShift!.displayName}');
  //     setState(() {
  //       _currentShift = null;
  //     });
  //     // Refresh to get the next valid shift
  //     _checkForActiveShift();
  //   }
  // }

  // ============================================================================
  // UI STATE MANAGEMENT
  // ============================================================================
  // These methods handle resetting and managing the UI state

  /// Reset location loading state (safety method)
  /// Used to clear the loading spinner if location fetch gets stuck
  void _resetLocationState() {
    if (mounted) {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  /// Reset the entire clock-out UI state
  ///
  /// This is called after successful clock-out or when cleaning up invalid sessions
  ///
  /// Parameters:
  /// - finalLocation: The clock-out location to store (can be null)
  /// - skipExplicitFlag: If true, don't set the _hasExplicitlyClockedOut flag
  ///   (used when system is cleaning up, not user-initiated clock-out)
  ///
  /// Resets all session-related state variables and stops all timers
  void _resetClockOutState(LocationData? finalLocation,
      {bool skipExplicitFlag = false}) {
    _debugLog('Resetting clock-out state (skipExplicitFlag=$skipExplicitFlag)');

    if (mounted) {
      // Cancel timers BEFORE setState to prevent race conditions
      _timer?.cancel();
      _timer = null;
      _stopwatch.stop();
      _stopwatch.reset();
      _stopAutoLogoutTimer();

      setState(() {
        _isClockingIn = false;
        _clockInTime = null;
        _selectedStudentName = '';
        _clockOutLocation = finalLocation;
        _isGettingLocation = false;
        _totalHoursWorked = "00:00:00";
        _lastSessionId = null;
        _lastSessionCheck = null;

        // Only set the explicit flag if not skipping
        if (!skipExplicitFlag) {
          _hasExplicitlyClockedOut =
              true; // Mark that user explicitly clocked out
        }
      });

      _debugLog(
          'Successfully reset clock-out state - timer stopped, explicitFlag=${!skipExplicitFlag}');
    }
  }

  /// Show a less alarming error when UI state is out of sync with backend
  ///
  /// This happens when the backend has already closed a session but the UI
  /// still thinks the user is clocked in. Rather than showing a scary error,
  /// we inform the user that the session was closed by the system.
  void _showStateMismatchError() {
    _debugLog('Showing state mismatch error to user');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Session already closed by system. Timer has been reset.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // ============================================================================
  // APP LIFECYCLE HANDLING
  // ============================================================================
  // These methods handle app state changes (background/foreground)

  /// Called when app lifecycle state changes
  ///
  /// Key behaviors:
  /// - When app resumes (comes to foreground):
  ///   * Clear the explicit clock-out flag (allow session resuming)
  ///   * Try to resume any open session
  ///   * Refresh timesheet data
  ///   * Check for shift updates
  ///
  /// This ensures the UI is always in sync when user returns to the app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _debugLog('App lifecycle state changed to: $state');

    // When app comes back to foreground
    if (state == AppLifecycleState.resumed && mounted) {
      _debugLog('App resumed - checking for session updates');

      // Clear the explicit clock out flag when returning to app
      if (_hasExplicitlyClockedOut) {
        _debugLog('Clearing explicit clock out flag on app resume');
        setState(() {
          _hasExplicitlyClockedOut = false;
        });
      }

      // Always try to resume session when app comes back
      _resumeOpenSession();

      // Also refresh timesheet data
      _refreshTimesheetData();

      // Check for active shift updates
      _checkForActiveShift();
    }
  }

  /// Called when widget's dependencies change
  ///
  /// This is triggered when the screen becomes active in the navigation stack
  /// We use it to refresh data and check session state when user navigates back to this screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh timesheet data when the widget becomes active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _debugLog('didChangeDependencies - refreshing data');

        // Check session state when returning to screen
        if (!_hasExplicitlyClockedOut) {
          _resumeOpenSession();
        }

        _refreshTimesheetData();
      }
    });
  }

  /// Refreshes the timesheet data display
  ///
  /// Triggers the TimesheetTable widget to reload data from Firestore
  /// This is called after clock-in/out operations and when app resumes
  void _refreshTimesheetData() {
    // Call refresh on the TimesheetTable widget
    _debugLog('Refreshing timesheet data');
    TimesheetTable.refreshData(_timesheetTableKey);
  }

  // ============================================================================
  // CLOCK-IN/OUT HANDLERS
  // ============================================================================
  // These methods orchestrate the clock-in and clock-out process

  /// Main handler for the clock-in/out button press
  ///
  /// This method determines the current state and takes appropriate action:
  /// - If clocked in -> proceed to clock out
  /// - If not clocked in -> check for valid shift and start session
  ///
  /// The method intelligently decides between clock-in and clock-out based on
  /// both UI state (_isClockingIn) and shift state (_currentShift)
  void _handleClockInOut() async {
    _debugLog(
        'handleClockInOut called - isClockingIn=$_isClockingIn, hasShift=${_currentShift != null}');

    // Check if we already have a shift and determine action
    if (_currentShift != null &&
        _currentShift!.isClockedIn &&
        _currentShift!.canClockOut) {
      // Already clocked in, proceed directly to clock out
      _debugLog('User is clocked in, proceeding to clock out');
      _proceedToClockOut(_currentShift!);
    } else if (_isClockingIn) {
      // Currently in a clocked-in session, clock out
      _debugLog('Currently clocking in, proceeding to clock out');
      if (_currentShift != null) {
        _proceedToClockOut(_currentShift!);
      }
    } else {
      // Need to check for shift and start session
      _debugLog('No active session, checking for shifts to clock in');
      _checkShiftAndStartSession();
    }
  }

  /// Checks for valid shift and starts a new clock-in session
  ///
  /// This is the first step in the clock-in flow:
  /// 1. Queries backend for valid shift using ShiftTimesheetService
  /// 2. Validates the shift status and permissions
  /// 3. If valid, proceeds to location check and clock-in
  /// 4. If invalid or already clocked in, shows appropriate dialog
  ///
  /// Possible outcomes:
  /// - No shift available -> Show "No Active Shift" dialog
  /// - Already clocked in -> Show "Already Clocked In" dialog
  /// - Valid shift -> Proceed to _startTeachingSession()
  void _checkShiftAndStartSession() async {
    if (!mounted) return;

    setState(() {
      _isCheckingShift = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showNoShiftDialog('User not authenticated');
        return;
      }

      _debugLog('Checking for valid shift for clock-in');
      // Check for valid shift first
      final shiftResult =
          await ShiftTimesheetService.getValidShiftForClockIn(user.uid);

      if (!mounted) return;

      final shift = shiftResult['shift'] as TeachingShift?;
      final canClockIn = shiftResult['canClockIn'] as bool;
      final canClockOut = shiftResult['canClockOut'] as bool;
      final status = shiftResult['status'] as String;
      final message = shiftResult['message'] as String;

      setState(() {
        _isCheckingShift = false;
      });

      _debugLog(
          'Shift check result: status=$status, canClockIn=$canClockIn, canClockOut=$canClockOut');

      if (shift == null || status == 'none' || status == 'error') {
        _showNoShiftDialog(message);
        return;
      }

      // Store the current shift
      setState(() {
        _currentShift = shift;
      });

      if (canClockOut && !canClockIn) {
        // Teacher has an active timesheet (is currently clocked in)
        _debugLog('Teacher already has active timesheet');
        _showAlreadyClockedInDialog(shift);
        return;
      }

      if (canClockIn) {
        // Proceed with location check and clock-in (no student selection needed)
        _startTeachingSession();
      } else {
        _showNoShiftDialog(message);
      }
    } catch (e) {
      _debugLog('Error checking shift availability: $e', isError: true);
      if (!mounted) return;

      setState(() {
        _isCheckingShift = false;
      });

      _showNoShiftDialog('Error checking shift availability: $e');
    }
  }

  /// Shows a dialog explaining why clock-in is not available
  ///
  /// Used for various scenarios:
  /// - No shift scheduled at this time
  /// - Outside of shift hours
  /// - Network/authentication errors
  ///
  /// Parameters:
  /// - message: The explanation to show to the user
  void _showNoShiftDialog(String message) {
    _debugLog('Showing no shift dialog: $message');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.info_outline,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'No Active Shift',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (message.contains('not scheduled') ||
                message.contains('outside shift hours'))
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Please contact your supervisor if you believe this is an error.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog when user already has an active clock-in session
  ///
  /// This dialog:
  /// - Informs user they're already clocked in
  /// - Shows shift details (name and time range)
  /// - Offers option to clock out immediately
  ///
  /// Parameters:
  /// - shift: The active shift the user is clocked into
  void _showAlreadyClockedInDialog(TeachingShift shift) {
    _debugLog('Showing already clocked in dialog');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.timer_outlined,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Already Clocked In',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have an active session for:\n${shift.displayName}',
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shift: ${DateFormat('h:mm a').format(shift.shiftStart)} - ${DateFormat('h:mm a').format(shift.shiftEnd)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to clock out now?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToClockOut(shift);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Clock Out',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Initiates the clock-out process for the given shift
  ///
  /// This is a wrapper that immediately starts the clock-out flow
  /// by calling _clockOut()
  ///
  /// Parameters:
  /// - shift: The shift to clock out from
  void _proceedToClockOut(TeachingShift shift) {
    _debugLog('Proceeding to clock out from shift ${shift.id}');
    // Set current shift and proceed with clock out
    setState(() {
      _currentShift = shift;
    });
    _clockOut();
  }

  /// Starts a new teaching session (clock-in flow)
  ///
  /// This method handles the location verification and clock-in process:
  /// 1. Validates that a shift is available
  /// 2. Gets device location (GPS)
  /// 3. Validates location is within allowed radius of shift location
  /// 4. If valid, proceeds to _proceedWithClockIn()
  ///
  /// Shows loading indicator while getting location and displays
  /// appropriate error messages if location or validation fails
  void _startTeachingSession() async {
    if (!mounted) return;

    _debugLog('Starting teaching session');

    // Get current location
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final location = await LocationService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
        _clockInLocation = location;
      });

      if (location != null) {
        _proceedWithClockIn(location);
      } else {
        throw Exception('Unable to get location');
      }
    } catch (e) {
      _debugLog('Error getting location: $e', isError: true);
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      // Show error dialog with option to proceed without location
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Error'),
          content: Text('Unable to get your location: $e\n\n'
              'Would you like to proceed without location tracking?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _proceedWithClockIn(LocationData(
                  latitude: 0.0,
                  longitude: 0.0,
                  address: 'Location not available',
                  neighborhood: 'Unknown',
                ));
              },
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );
    }
  }

  // ============================================================================
  // TIMER MANAGEMENT
  // ============================================================================
  // These methods handle the various timers used in the screen

  /// Starts the main timer that updates the UI every second
  ///
  /// This timer:
  /// - Increments the stopwatch
  /// - Updates the total hours worked display
  /// - Runs every second while user is clocked in
  void _startTimer() {
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check if we still have an active session
      if (!_isClockingIn || _clockInTime == null) {
        _debugLog('Timer running but no active session - stopping timer');
        timer.cancel();
        return;
      }

      setState(() {
        _updateTotalHours();
      });
    });
    _debugLog('Timer started');
  }

  /// Starts the auto-logout timer
  ///
  /// This timer automatically clocks out the user when their shift ends.
  ///
  /// How it works:
  /// 1. Calculates time until shift end
  /// 2. Sets up a countdown timer
  /// 3. Updates "Auto-logout in X:XX" display every second
  /// 4. When shift ends, calls _performAutoLogout()
  ///
  /// The auto-logout ensures teachers don't forget to clock out and
  /// prevents accumulating extra (unpaid) hours
  void _startAutoLogoutTimer() {
    if (_currentShift == null) return;

    _autoLogoutTimer?.cancel();
    _autoLogoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _currentShift == null) {
        timer.cancel();
        return;
      }

      final nowUtc = DateTime.now().toUtc();
      final autoLogoutTimeUtc = _currentShift!.clockOutDeadline;

      if (nowUtc.isAfter(autoLogoutTimeUtc)) {
        // Time's up - auto logout
        _performAutoLogout();
        return;
      }

      final timeLeft = autoLogoutTimeUtc.difference(nowUtc);
      final hours = timeLeft.inHours;
      final minutes = timeLeft.inMinutes % 60;
      final seconds = timeLeft.inSeconds % 60;

      setState(() {
        _timeUntilAutoLogout =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      });
    });
    _debugLog('Auto-logout timer started');
  }

  /// Stops and clears the auto-logout timer
  ///
  /// Called when user manually clocks out before shift ends
  void _stopAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();
    setState(() {
      _timeUntilAutoLogout = "";
    });
    _debugLog('Auto-logout timer stopped');
  }

  /// Performs automatic clock-out when shift ends
  ///
  /// This is triggered by the auto-logout timer when shift end time is reached.
  ///
  /// Process:
  /// 1. Get current location
  /// 2. Record clock-out in database
  /// 3. Reset UI to clocked-out state
  /// 4. Show confirmation message
  ///
  /// If location fetch fails, still proceeds with clock-out but without location data
  void _performAutoLogout() async {
    if (!_isClockingIn || _currentShift == null) return;

    _debugLog('Performing auto-logout for shift ${_currentShift!.id}');

    // Store shift reference before clearing state
    final shift = _currentShift!;

    // Stop timers
    _stopAutoLogoutTimer();
    _timer?.cancel();
    _stopwatch.stop();

    try {
      // Get current location for auto clock-out
      LocationData? location = await LocationService.getCurrentLocation();

      if (location != null) {
        // Use the shift-timesheet service for auto clock-out
        final result = await ShiftTimesheetService.autoClockOutFromShift(
          FirebaseAuth.instance.currentUser!.uid,
          shift.id,
          location: location,
        );

        if (mounted) {
          _resetClockOutState(location, skipExplicitFlag: true);

          // Show auto-logout notification
          final endTime = shift.clockOutDeadline;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Session automatically ended at ${DateFormat('h:mm a').format(endTime)}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );

          // Refresh timesheet data
          _refreshTimesheetData();
        }
      } else {
        // Handle case where location couldn't be obtained
        if (mounted) {
          _resetClockOutState(null, skipExplicitFlag: true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Session automatically ended (location not captured)'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      _debugLog('Error during auto-logout: $e', isError: true);

      if (mounted) {
        _resetClockOutState(null, skipExplicitFlag: true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session automatically ended (error occurred)'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Updates the total hours worked based on elapsed time
  ///
  /// Calculates duration since _clockInTime and formats it as HH:MM:SS
  /// This is called every second by _startTimer
  void _updateTotalHours() {
    // Always calculate from the actual clock-in time, not stopwatch
    if (_clockInTime != null && _isClockingIn) {
      final elapsed = DateTime.now().difference(_clockInTime!);
      _totalHoursWorked = _formatDuration(elapsed);
    } else {
      // No active session - ensure timer is stopped
      if (_timer != null && _timer!.isActive) {
        _debugLog('No active session but timer still running - stopping it');
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  // ============================================================================
  // CLOCK-OUT LOGIC
  // ============================================================================

  /// Handles the clock-out process
  ///
  /// This is one of the most critical methods in the screen.
  ///
  /// Process:
  /// 1. Validates user has an active shift
  /// 2. Gets current GPS location
  /// 3. Validates location is within allowed radius
  /// 4. Calls backend to record clock-out
  /// 5. Resets UI state
  /// 6. Refreshes timesheet
  ///
  /// Error handling:
  /// - If location unavailable -> still allows clock-out
  /// - If location outside radius -> shows error, doesn't allow clock-out
  /// - If network error -> shows error, allows retry
  Future<void> _clockOut() async {
    if (!_isClockingIn || _currentShift == null) {
      _debugLog(
          'Clock out called but no active session (isClockingIn=$_isClockingIn, hasShift=${_currentShift != null})');
      return;
    }

    // Prevent multiple simultaneous clock-out attempts
    if (_isGettingLocation) {
      _debugLog(
          'Already getting location for clock-out, ignoring duplicate call');
      return;
    }

    _debugLog('Starting clock-out process for shift ${_currentShift!.id}');

    setState(() {
      _isGettingLocation = true;
    });

    try {
      LocationData? clockOutLocation;

      // Try to get location with fallback
      try {
        clockOutLocation = await LocationService.getCurrentLocation()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        _debugLog('Clock-out location failed, using fallback: $e',
            isError: true);
        // Use a fallback location
        clockOutLocation = LocationData(
          latitude: _clockInLocation?.latitude ?? 0.0,
          longitude: _clockInLocation?.longitude ?? 0.0,
          address: 'Clock-out location unavailable',
          neighborhood: 'Previous Location',
        );
      }

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && clockOutLocation != null) {
        _debugLog('Calling ShiftTimesheetService.clockOutFromShift');
        final result = await ShiftTimesheetService.clockOutFromShift(
          user.uid,
          _currentShift!.id,
          location: clockOutLocation,
        );

        _debugLog(
            'Clock-out result: success=${result['success']}, message=${result['message']}');

        if (result['success']) {
          // Clock-out successful
          _resetClockOutState(clockOutLocation);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Refresh timesheet data
          _refreshTimesheetData();
          _checkForActiveShift();
        } else {
          // Handle failure without getting stuck
          setState(() {
            _isGettingLocation = false;
          });

          // Check if it's a state mismatch
          final errorMessage = result['message'].toString().toLowerCase();
          if (errorMessage.contains('no active clock-in') ||
              errorMessage.contains('couldn\'t find a valid shift') ||
              errorMessage.contains('already closed') ||
              errorMessage.contains('session not found')) {
            _debugLog('Detected state mismatch error: ${result['message']}');
            // Force reset UI state when backend says no active session
            _resetClockOutState(clockOutLocation);
            _showStateMismatchError();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Clock-out failed: ${result['message']}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      if (mounted) {
        // Add a small delay to ensure Firebase write is committed
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _refreshTimesheetData();
          }
        });
      }
    } catch (e) {
      _debugLog('Clock-out error: $e', isError: true);
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Clock-out failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ============================================================================
  // CLOCK-IN LOGIC
  // ============================================================================

  /// Completes the clock-in process after location has been validated
  ///
  /// This method is called after _startTeachingSession has verified the location.
  ///
  /// Process:
  /// 1. Validates shift is still available
  /// 2. Calls backend to create new timesheet entry
  /// 3. Updates UI to show clocked-in state
  /// 4. Starts timers (elapsed time and auto-logout)
  /// 5. Refreshes timesheet display
  ///
  /// Parameters:
  /// - location: The validated GPS location for this clock-in
  ///
  /// On success:
  /// - Shows success message
  /// - Updates all UI state to reflect clocked-in status
  /// - Starts timers for tracking time and auto-logout
  Future<void> _proceedWithClockIn(LocationData location) async {
    if (!mounted) return;

    if (_currentShift == null) {
      _debugLog('No current shift for clock-in', isError: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid shift found for clock-in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _debugLog(
          'Calling ShiftTimesheetService.clockInToShift for shift ${_currentShift!.id}');
      // Detect platform for tracking
      final platform = PlatformUtils.detectPlatform();
      _debugLog('Clock-in platform detected: $platform');

      // Use the shift-based clock-in service
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        _currentShift!.id,
        location: location,
        platform: platform,
      );

      if (!mounted) return;

      _debugLog(
          'Clock-in result: success=${result['success']}, message=${result['message']}');

      if (result['success']) {
        setState(() {
          _isClockingIn = true;
          _hasExplicitlyClockedOut = false; // Reset flag when clocking in
          _selectedStudentName = _currentShift!.displayName;
          _clockInTime = DateTime.now(); // Store the actual clock-in time
          _clockInLocation = location;
          _totalHoursWorked = "00:00:00";
          _stopwatch.reset();
          _stopwatch.start();
          _startTimer();
          _startAutoLogoutTimer();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Refresh timesheet data after clocking in
        _refreshTimesheetData();
      } else {
        _debugLog('Clock-in failed: ${result['message']}', isError: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clock-in failed: ${result['message']}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _debugLog('Error during clock-in: $e', isError: true);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Clock-in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ============================================================================
  // UI BUILD METHOD
  // ============================================================================

  /// Builds the main UI for the time clock screen
  ///
  /// The UI structure:
  /// 1. Header section:
  ///    - Shift info card (when shift is available)
  ///    - Clock status display (when clocked in)
  /// 2. Main content:
  ///    - Timesheet table (desktop) or cards (mobile)
  /// 3. Floating action button:
  ///    - Clock In button (when shift available and not clocked in)
  ///    - Clock Out button (when clocked in)
  ///
  /// The UI adapts based on:
  /// - Platform (mobile vs desktop)
  /// - Clock-in state
  /// - Shift availability
  @override
  Widget build(BuildContext context) {
    // Determine if we should show the floating action button
    final showClockInButton =
        _currentShift != null && _currentShift!.canClockIn && !_isClockingIn;
    final showClockOutButton = _isClockingIn && _currentShift != null;
    final showActionButton = showClockInButton || showClockOutButton;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          // Header section with clock status
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Show shift card when shift is available and not expired
                if (_currentShift != null && !_currentShift!.hasExpired)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isMobile ? 12 : 16,
                      vertical: _isMobile ? 8 : 12,
                    ),
                    child: Card(
                      elevation: 0,
                      color: _currentShift!.canClockIn
                          ? const Color(
                              0xffF0FDF4) // Green background for active shift
                          : const Color(
                              0xffFEF3C7), // Yellow for past/future shift
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _currentShift!.canClockIn
                              ? const Color(0xff10B981).withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(_isMobile ? 12 : 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _currentShift!.canClockIn
                                    ? const Color(0xff10B981).withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.school,
                                color: _currentShift!.canClockIn
                                    ? const Color(0xff10B981)
                                    : Colors.orange,
                                size: _isMobile ? 24 : 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _currentShift!.canClockIn
                                            ? 'Active Shift'
                                            : (_currentShift!.hasExpired
                                                ? 'Shift Ended'
                                                : 'Upcoming Shift'),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _currentShift!.canClockIn
                                              ? const Color(0xff10B981)
                                              : Colors.orange,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (_currentShift!.canClockIn) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xff10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentShift!.displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xff1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat('h:mm a').format(_currentShift!.shiftStart)} - ${DateFormat('h:mm a').format(_currentShift!.shiftEnd)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xff64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Show timer card when clocked in
                if (_isClockingIn && _currentShift != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isMobile ? 12 : 16,
                      vertical: _isMobile ? 8 : 12,
                    ),
                    child: Card(
                      color: const Color(0xffEFF6FF),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(_isMobile ? 16 : 20),
                        child: Column(
                          children: [
                            Text(
                              'Teaching: $_selectedStudentName',
                              style: GoogleFonts.inter(
                                fontSize: _isMobile ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff0386FF),
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _totalHoursWorked,
                              style: GoogleFonts.inter(
                                fontSize: _isMobile ? 32 : 40,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff111827),
                                letterSpacing: 1,
                              ),
                            ),
                            if (_timeUntilAutoLogout.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      size: 18,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Auto-logout in $_timeUntilAutoLogout',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Timesheet section - use mobile or desktop version based on platform
          // Takes all remaining space
          Expanded(
            child: Container(
              padding: EdgeInsets.only(
                top: 16,
                bottom: showActionButton
                    ? 80
                    : 16, // Add bottom padding when FAB is visible
              ),
              child: Builder(
                builder: (context) {
                  if (_isMobile) {
                    return const MobileTimesheetView(); // Mobile-friendly card layout
                  } else {
                    return TimesheetTable(
                      // Desktop/web table layout
                      clockInEntries: _timesheetEntries,
                      key: _timesheetTableKey,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
      // Floating Action Button - always visible when clock in/out is available
      floatingActionButton: showActionButton
          ? _buildFloatingClockButton(showClockInButton, showClockOutButton)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Builds the floating action button for clock-in/clock-out
  ///
  /// The button appearance adapts based on state:
  /// - Clock In: Green button with "Clock In" text and icon
  /// - Clock Out: Red button with "Clock Out" text and icon
  /// - Processing: Shows spinner with "Processing..." text
  ///
  /// Parameters:
  /// - isClockIn: True if button should be styled for clock-in
  /// - isClockOut: True if button should be styled for clock-out
  Widget _buildFloatingClockButton(bool isClockIn, bool isClockOut) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCheckingShift ? null : _handleClockInOut,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isClockIn ? const Color(0xff10B981) : const Color(0xffEF4444),
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor:
              (isClockIn ? const Color(0xff10B981) : const Color(0xffEF4444))
                  .withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: _isCheckingShift
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isClockIn ? Icons.touch_app : Icons.logout_rounded,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isClockIn ? 'Tap to Clock In' : 'Tap to Clock Out',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
