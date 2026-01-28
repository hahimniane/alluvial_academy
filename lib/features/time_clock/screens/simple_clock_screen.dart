// Import statements for required packages and local files
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';  // For custom fonts
import 'package:firebase_auth/firebase_auth.dart';  // Firebase authentication
import 'dart:async';  // For asynchronous operations and timers
import '../../../core/services/shift_timesheet_service.dart';  // Shift/timesheet operations
import '../../../core/services/location_service.dart';  // Location handling
import '../../../core/models/teaching_shift.dart';  // Shift data model
import '../../../core/utils/platform_utils.dart';  // Platform detection

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';  // Logging utility
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Simple clock screen widget for mobile clock-in/out functionality
class SimpleClockScreen extends StatefulWidget {
  const SimpleClockScreen({super.key});

  @override
  State<SimpleClockScreen> createState() => _SimpleClockScreenState();
}

/// State class for SimpleClockScreen that manages clock-in/out logic
class _SimpleClockScreenState extends State<SimpleClockScreen> {
  // State variables
  bool _isClockedIn = false;  // Tracks if user is currently clocked in
  DateTime? _clockInTime;  // Timestamp when user clocked in
  Timer? _timer;  // Timer for tracking elapsed time
  Timer? _autoLogoutTimer;  // Timer for automatic logout after shift
  Timer? _availabilityRefreshTimer;  // Timer to periodically check shift availability
  String _elapsedTime = "00:00:00";  // Formatted elapsed time display
  TeachingShift? _currentShift;  // Current teaching shift data
  bool _isProcessing = false;  // Flag for in-progress operations
  StreamSubscription<User?>? _authSub;  // Firebase auth state listener
  String? _availabilityMessage;  // Message about when clock-in becomes available

  @override
  void initState() {
    super.initState();
    // Initialize shift status when widget loads
    _checkCurrentShiftStatus();
    
    // Listen to auth state changes to handle session persistence
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _checkCurrentShiftStatus();
      }
    });

    // Periodically check shift availability to enable 1-minute early clock-in
    // This ensures the button becomes active when the clock-in window opens
    _availabilityRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isClockedIn && !_isProcessing && mounted) {
        _checkShiftAvailability();
      }
    });
  }

  @override
  void dispose() {
    // Clean up timers and subscriptions when widget is disposed
    _timer?.cancel();
    _autoLogoutTimer?.cancel();
    _availabilityRefreshTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  /// Checks shift availability and updates UI message
  /// This runs periodically to enable 1-minute early clock-in
  Future<void> _checkShiftAvailability() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final shiftResult = await ShiftTimesheetService.getValidShiftForClockIn(user.uid);
      final shift = shiftResult['shift'] as TeachingShift?;
      final canClockIn = shiftResult['canClockIn'] as bool;
      final canProgramClockIn = (shiftResult['canProgramClockIn'] as bool?) ?? false;
      final message = shiftResult['message'] as String?;

      if (mounted) {
        setState(() {
          if (shift != null && (canClockIn || canProgramClockIn)) {
            // Shift is available for clock-in
            _availabilityMessage = null;
            if (!_isClockedIn && _currentShift?.id != shift.id) {
              _currentShift = shift;
            }
          } else if (message != null) {
            // Show when clock-in becomes available
            _availabilityMessage = message;
          } else {
            _availabilityMessage = null;
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error checking shift availability: $e');
    }
  }

  /// Checks if user is already clocked in to a shift
  Future<void> _checkCurrentShiftStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // First try to resume from an existing open session
      final session = await ShiftTimesheetService.getOpenSession(user.uid);
      if (session != null && mounted) {
        final shift = session['shift'] as TeachingShift?;
        final start = session['clockInTime'] as DateTime?;
        if (shift != null) {
          setState(() {
            _isClockedIn = true;
            _currentShift = shift;
            _clockInTime = start ?? DateTime.now();
            _startTimer();  // Start tracking elapsed time
            _startAutoLogoutTimer();  // Start auto logout timer
          });
          return;
        }
      }

      // Fallback to legacy behavior if no open session exists
      final activeShift = await ShiftTimesheetService.getActiveShift(user.uid);
      if (activeShift != null && mounted) {
        setState(() {
          _isClockedIn = true;
          _currentShift = activeShift;
          _clockInTime = DateTime.now();
          _startTimer();
          _startAutoLogoutTimer();
        });
      }
    } catch (e) {
      AppLogger.error('Error checking shift status: $e');
    }
  }

  /// Handles the clock-in process
  Future<void> _clockIn() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('Please log in first', isError: true);
        return;
      }

      // Step 1: Validate shift availability
      final shiftResult =
          await ShiftTimesheetService.getValidShiftForClockIn(user.uid);
      final shift = shiftResult['shift'] as TeachingShift?;
      final canClockIn = shiftResult['canClockIn'] as bool;
      final canProgramClockIn = (shiftResult['canProgramClockIn'] as bool?) ?? false;

      if ((!canClockIn && !canProgramClockIn) || shift == null) {
        _showMessage('No valid shift: ${shiftResult['message']}', isError: true);
        return;
      }

      // Step 2: Request location permissions
      await LocationService.requestPermission();

      // Step 3: Get current location
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation()
            .timeout(const Duration(seconds: 30), onTimeout: () {
          return null;
        });
      } catch (e) {
        AppLogger.error('SimpleClockScreen: Location error: $e');
      }

      // Use default location if actual location unavailable
      location ??= LocationData(
        latitude: 0.0,
        longitude: 0.0,
        address: 'Location unavailable',
        neighborhood: 'Clock-in without location',
      );

      // Step 4: Perform clock-in operation
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        shift.id,
        location: location,
      );

      if (result['success']) {
        setState(() {
          _isClockedIn = true;
          _currentShift = shift;
          _clockInTime = DateTime.now();
          _availabilityMessage = null;  // Clear availability message after successful clock-in
          _startTimer();
          _startAutoLogoutTimer();
        });
        _showMessage('Clocked in successfully!');
      } else {
        _showMessage('Clock-in failed: ${result['message']}', isError: true);
      }
    } catch (e) {
      _showMessage('Error during clock-in: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Handles the clock-out process
  Future<void> _clockOut() async {
    if (_isProcessing || _currentShift == null) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get location for clock-out
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation().timeout(
          const Duration(seconds: 30),
          onTimeout: () => null,
        );
      } catch (e) {
        location = null;
      }

      // Use default location if actual location unavailable
      location ??= LocationData(
        latitude: 0.0,
        longitude: 0.0,
        address: 'Location unavailable',
        neighborhood: 'Clock-out without location',
      );

      // Perform clock-out operation
      final platform = PlatformUtils.detectPlatform();
      final result = await ShiftTimesheetService.clockOutFromShift(
        user.uid,
        _currentShift!.id,
        location: location,
        platform: platform,
      );

      if (result['success']) {
        setState(() {
          _isClockedIn = false;
          _currentShift = null;
          _clockInTime = null;
          _elapsedTime = "00:00:00";
          _timer?.cancel();
          _autoLogoutTimer?.cancel();
        });
        _showMessage('Clocked out and timesheet submitted!');
        // Check for next available shift after clock-out
        _checkShiftAvailability();
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Error during clock-out: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Starts the timer to track elapsed time since clock-in
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_clockInTime != null && mounted) {
        DateTime effectiveStartTime = _clockInTime!;
        if (_currentShift != null && _clockInTime!.isBefore(_currentShift!.shiftStart)) {
           effectiveStartTime = _currentShift!.shiftStart;
        }
        
        final now = DateTime.now();
        Duration elapsed;
        if (now.isBefore(effectiveStartTime)) {
           elapsed = Duration.zero;
        } else {
           elapsed = now.difference(effectiveStartTime);
        }

        setState(() {
          _elapsedTime = _formatDuration(elapsed);
        });
      }
    });
  }

  /// Starts auto logout timer based on shift end time
  void _startAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();

    if (_currentShift == null) return;

    // Calculate auto logout time (shift end + 15 minutes)
    final autoLogoutTimeUtc = _currentShift!.clockOutDeadline;
    final nowUtc = DateTime.now().toUtc();

    if (autoLogoutTimeUtc.isAfter(nowUtc)) {
      final timeUntilAutoLogout = autoLogoutTimeUtc.difference(nowUtc);
      _autoLogoutTimer = Timer(timeUntilAutoLogout, () {
        if (_isClockedIn && _currentShift != null && mounted) {
          _performAutoLogout();
        }
      });
    } else {
      // Immediate logout if shift already ended
      Timer(const Duration(seconds: 1), () {
        if (_isClockedIn && _currentShift != null && mounted) {
          _performAutoLogout();
        }
      });
    }
  }

  /// Performs automatic logout when shift ends
  Future<void> _performAutoLogout() async {
    if (!_isClockedIn || _currentShift == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get location for auto logout
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      } catch (e) {
        location = null;
      }

      location ??= LocationData(
        latitude: 0.0,
        longitude: 0.0,
        address: 'Auto logout - location unavailable',
        neighborhood: 'Auto logout',
      );

      // Perform auto logout via service
      final result = await ShiftTimesheetService.autoClockOutFromShift(
        user.uid,
        _currentShift!.id,
        location: location,
      );

      if (mounted) {
        setState(() {
          _isClockedIn = false;
          _currentShift = null;
          _clockInTime = null;
          _elapsedTime = "00:00:00";
          _timer?.cancel();
          _autoLogoutTimer?.cancel();
        });

        _showMessage(
          'Auto logged out - shift ended. Timesheet submitted.',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Auto logout error: $e', isError: true);
      }
    }
  }

  /// Formats duration as HH:MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  /// Shows a snackbar message
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.simpleClock,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Status Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isClockedIn
                            ? const Color(0xff10B981).withOpacity(0.1)
                            : const Color(0xff6B7280).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        _isClockedIn ? Icons.access_time : Icons.schedule,
                        size: 40,
                        color: _isClockedIn
                            ? const Color(0xff10B981)
                            : const Color(0xff6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status Text
                    Text(
                      _isClockedIn ? 'Clocked In' : 'Not Clocked In',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _isClockedIn
                            ? const Color(0xff10B981)
                            : const Color(0xff6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Shift Name
                    if (_currentShift != null)
                      Text(
                        _currentShift!.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xff4B5563),
                        ),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 16),

                    // Availability Message (shows when clock-in window opens)
                    if (_availabilityMessage != null && !_isClockedIn)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _availabilityMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff6B7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _elapsedTime,
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff1F2937),
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : (_isClockedIn ? _clockOut : _clockIn),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isClockedIn ? Colors.red : const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isClockedIn ? 'Clock Out' : 'Clock In',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Help Text
              Text(
                _isClockedIn
                    ? 'Click "Clock Out" to finish and submit your timesheet'
                    : 'Click "Clock In" to start tracking your teaching time',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
