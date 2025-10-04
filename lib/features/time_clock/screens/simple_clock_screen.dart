import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/teaching_shift.dart';

class SimpleClockScreen extends StatefulWidget {
  const SimpleClockScreen({super.key});

  @override
  State<SimpleClockScreen> createState() => _SimpleClockScreenState();
}

class _SimpleClockScreenState extends State<SimpleClockScreen> {
  bool _isClockedIn = false;
  DateTime? _clockInTime;
  Timer? _timer;
  Timer? _autoLogoutTimer;
  String _elapsedTime = "00:00:00";
  TeachingShift? _currentShift;
  bool _isProcessing = false;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _checkCurrentShiftStatus();
    // Also resume once auth rehydrates after a web refresh
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _checkCurrentShiftStatus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoLogoutTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  /// Check if user is already clocked in to a shift
  Future<void> _checkCurrentShiftStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Prefer resuming from an open session (with accurate clock-in time)
      final session = await ShiftTimesheetService.getOpenSession(user.uid);
      if (session != null && mounted) {
        final shift = session['shift'] as TeachingShift?;
        final start = session['clockInTime'] as DateTime?;
        if (shift != null) {
          setState(() {
            _isClockedIn = true;
            _currentShift = shift;
            _clockInTime = start ?? DateTime.now();
            _startTimer();
            _startAutoLogoutTimer();
          });
          return;
        }
      }

      // Fallback: legacy behavior
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
      print('Error checking shift status: $e');
    }
  }

  /// Simple clock-in process
  Future<void> _clockIn() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('Please log in first', isError: true);
        return;
      }

      print('SimpleClockScreen: Starting clock-in for user ${user.uid}');

      // 1. Check if there's a valid shift
      print('SimpleClockScreen: Checking for valid shift...');
      final shiftResult =
          await ShiftTimesheetService.getValidShiftForClockIn(user.uid);
      final shift = shiftResult['shift'] as TeachingShift?;
      final canClockIn = shiftResult['canClockIn'] as bool;
      final status = shiftResult['status'] as String;
      final message = shiftResult['message'] as String;

      print('SimpleClockScreen: Shift check result:');
      print('  - Status: $status');
      print('  - Can clock in: $canClockIn');
      print('  - Message: $message');
      print('  - Shift found: ${shift != null}');
      if (shift != null) {
        print('  - Shift ID: ${shift.id}');
        print('  - Shift Name: ${shift.displayName}');
        print('  - Shift Start: ${shift.shiftStart}');
        print('  - Shift End: ${shift.shiftEnd}');
      }

      if (!canClockIn || shift == null) {
        _showMessage('No valid shift: $message', isError: true);
        return;
      }

      // 2. Request permission on user gesture to ensure web prompt
      await LocationService.requestPermission();

      // 3. Try to get location (use cached if available, proceed without if not)
      print('SimpleClockScreen: Getting location...');
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation()
            .timeout(const Duration(seconds: 30), onTimeout: () {
          print('SimpleClockScreen: Location request timed out');
          return null;
        });
      } catch (e) {
        print('SimpleClockScreen: Location error: $e');
        location = null; // Proceed without location
      }

      // Use default location if none available
      if (location == null) {
        print('SimpleClockScreen: Using default location');
        location = LocationData(
          latitude: 0.0,
          longitude: 0.0,
          address: 'Location unavailable',
          neighborhood: 'Clock-in without location',
        );
      } else {
        print('SimpleClockScreen: Location obtained: ${location.neighborhood}');
      }

      // 4. Clock in to shift
      print('SimpleClockScreen: Attempting clock-in to shift ${shift.id}...');
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        shift.id,
        location: location,
      );

      print('SimpleClockScreen: Clock-in result:');
      print('  - Success: ${result['success']}');
      print('  - Message: ${result['message']}');

      if (result['success']) {
        setState(() {
          _isClockedIn = true;
          _currentShift = shift;
          _clockInTime = DateTime.now();
          _startTimer();
          _startAutoLogoutTimer();
        });
        _showMessage('Clocked in successfully!');
        print('SimpleClockScreen: Clock-in completed successfully');
      } else {
        _showMessage('Clock-in failed: ${result['message']}', isError: true);
        print('SimpleClockScreen: Clock-in failed: ${result['message']}');
      }
    } catch (e) {
      print('SimpleClockScreen: Exception during clock-in: $e');
      _showMessage('Error during clock-in: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Simple clock-out process
  Future<void> _clockOut() async {
    if (_isProcessing || _currentShift == null) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get location for clock out (optional)
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation().timeout(
          const Duration(seconds: 30),
          onTimeout: () => null,
        );
      } catch (e) {
        location = null;
      }

      // Use default location if none available
      location ??= LocationData(
        latitude: 0.0,
        longitude: 0.0,
        address: 'Location unavailable',
        neighborhood: 'Clock-out without location',
      );

      // Clock out and submit timesheet
      final result = await ShiftTimesheetService.clockOutFromShift(
        user.uid,
        _currentShift!.id,
        location: location,
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
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Error during clock-out: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_clockInTime != null && mounted) {
        final elapsed = DateTime.now().difference(_clockInTime!);
        setState(() {
          _elapsedTime = _formatDuration(elapsed);
        });
      }
    });
  }

  void _startAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();

    if (_currentShift == null) return;

    // Calculate when auto logout should happen: shift end + 15 minutes (in UTC)
    final autoLogoutTimeUtc = _currentShift!.clockOutDeadline;
    final nowUtc = DateTime.now().toUtc();

    // If auto logout time is in the future, set timer
    if (autoLogoutTimeUtc.isAfter(nowUtc)) {
      final timeUntilAutoLogout = autoLogoutTimeUtc.difference(nowUtc);

      print(
          'Auto logout scheduled for: ${autoLogoutTimeUtc.toLocal()} (in ${timeUntilAutoLogout.inMinutes} minutes)');

      _autoLogoutTimer = Timer(timeUntilAutoLogout, () {
        if (_isClockedIn && _currentShift != null && mounted) {
          print('Auto logout triggered for shift: ${_currentShift!.id}');
          _performAutoLogout();
        }
      });
    } else {
      // If shift already ended + 15 minutes, auto logout immediately
      print('Shift has already ended, performing immediate auto logout');
      Timer(const Duration(seconds: 1), () {
        if (_isClockedIn && _currentShift != null && mounted) {
          _performAutoLogout();
        }
      });
    }
  }

  Future<void> _performAutoLogout() async {
    if (!_isClockedIn || _currentShift == null) return;

    print('Performing auto logout for shift: ${_currentShift!.id}');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get location for auto logout (optional)
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      } catch (e) {
        location = null;
      }

      // Use default location if none available
      location ??= LocationData(
        latitude: 0.0,
        longitude: 0.0,
        address: 'Auto logout - location unavailable',
        neighborhood: 'Auto logout',
      );

      // Use the auto logout service which handles timesheet with shift end time
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
      print('Error during auto logout: $e');
      if (mounted) {
        _showMessage('Auto logout error: $e', isError: true);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

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
          'Simple Clock',
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
