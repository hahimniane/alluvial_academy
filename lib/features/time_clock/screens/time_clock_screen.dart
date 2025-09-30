import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart' as constants;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/timesheet_table.dart' show TimesheetTable;
import '../../../core/services/location_service.dart';
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/services/shift_monitoring_service.dart';
import '../../../core/models/teaching_shift.dart';

class TimeClockScreen extends StatefulWidget {
  const TimeClockScreen({super.key});

  @override
  _TimeClockScreenState createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends State<TimeClockScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _students = [];
  bool _isLoadingStudents = false;

  bool _isClockingIn = false;
  String _selectedStudentName = '';
  DateTime? _clockInTime;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _totalHoursWorked = "00:00:00";

  // Auto-logout timer
  Timer? _autoLogoutTimer;
  String _timeUntilAutoLogout = "";

  // Location data
  LocationData? _clockInLocation;
  LocationData? _clockOutLocation;
  bool _isGettingLocation = false;

  // Shift data
  TeachingShift? _currentShift;
  bool _isCheckingShift = false;

  final List<dynamic> _timesheetEntries =
      []; // Legacy list - no longer used for actual timesheet storage
  final GlobalKey<State<TimesheetTable>> _timesheetTableKey =
      GlobalKey<State<TimesheetTable>>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStudents();
    // Initialize shift and session in proper order
    _initializeShiftAndSession();
    // Run shift monitoring in background
    _runPeriodicShiftMonitoring();
  }

  // New method to properly initialize in order
  Future<void> _initializeShiftAndSession() async {
    await _checkForActiveShift();
    await _resumeOpenSession();
  }

  // Helper method to format duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _resumeOpenSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final session = await ShiftTimesheetService.getOpenSession(user.uid);
      if (session == null || !mounted) return;

      final shift = session['shift'] as TeachingShift?;
      final clockInTime = session['clockInTime'] as DateTime?;
      
      if (shift == null || clockInTime == null) return;

      // Calculate elapsed time since clock-in
      final now = DateTime.now();
      final elapsed = now.difference(clockInTime);
      
      setState(() {
        _currentShift = shift;
        _isClockingIn = true;
        _selectedStudentName = shift.displayName;
        _clockInTime = clockInTime; // Use the actual clock-in time from database
        _totalHoursWorked = _formatDuration(elapsed);
        
        // Reset and start the stopwatch
        _stopwatch.reset();
        _stopwatch.start();
        // Note: We track the actual start time separately in _clockInTime
        
        _startTimer();
        _startAutoLogoutTimer();
      });
      
      print('TimeClockScreen: Resumed session - elapsed time: ${elapsed.inMinutes} minutes');
    } catch (e) {
      print('Error resuming open session: $e');
    }
  }

  Future<void> _checkForActiveShift() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if teacher has any valid shift
      final shiftResult =
          await ShiftTimesheetService.getValidShiftForClockIn(user.uid);

      if (mounted) {
        final shift = shiftResult['shift'] as TeachingShift?;

        if (shift != null) {
          setState(() {
            _currentShift = shift;
          });

          print('TimeClockScreen: Found available shift: ${shift.displayName}');
        } else {
          print('TimeClockScreen: No valid shift found');
        }
      }
    } catch (e) {
      print('Error checking for active shift: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoLogoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Run periodic shift monitoring for auto clock-outs and missed shifts
  void _runPeriodicShiftMonitoring() {
    // Run monitoring immediately
    ShiftMonitoringService.runPeriodicMonitoring();

    // Set up periodic monitoring every 15 minutes
    Timer.periodic(const Duration(minutes: 15), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      ShiftMonitoringService.runPeriodicMonitoring();
    });
  }

  /// Reset location loading state (safety method)
  void _resetLocationState() {
    if (mounted) {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  /// Reset the entire clock-out UI state
  void _resetClockOutState(LocationData? finalLocation) {
    if (mounted) {
      setState(() {
        _isClockingIn = false;
        _stopwatch.stop();
        _timer?.cancel();
        _stopAutoLogoutTimer();
        _stopwatch.reset();
        _clockInTime = null;
        _selectedStudentName = '';
        _clockOutLocation = finalLocation;
        _isGettingLocation = false;
      });
    }
  }

  /// Show a less alarming error when UI state is out of sync with backend
  void _showStateMismatchError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Session already closed by system. Timer has been reset.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh timesheet data when app comes back to foreground
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshTimesheetData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh timesheet data when the widget becomes active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshTimesheetData();
      }
    });
  }

  void _refreshTimesheetData() {
    // Call refresh on the TimesheetTable widget
    print('Refreshing timesheet data after clock-out...');
    TimesheetTable.refreshData(_timesheetTableKey);
  }

  Future<void> _loadStudents() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStudents = true;
    });

    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('user_type', isEqualTo: 'student')
          .get();

      List<Map<String, dynamic>> students = [];

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        String displayName = 'Unknown Student';
        if (data['first_name'] != null && data['last_name'] != null) {
          displayName = '${data['first_name']} ${data['last_name']}';
        } else if (data['first_name'] != null) {
          displayName = data['first_name'];
        } else if (data['last_name'] != null) {
          displayName = data['last_name'];
        } else if (data['email'] != null) {
          displayName = data['email'].split('@')[0];
        }

        students.add({
          'id': doc.id,
          'name': displayName,
          'email': data['email'] ?? '',
          'grade': data['title'] ?? 'Student',
          'kiosk_code': data['kiosk_code'] ?? '',
        });
      }

      students
          .sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

      if (!mounted) return;
      setState(() {
        _students = students;
        _isLoadingStudents = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingStudents = false;
      });
    }
  }

  void _handleStudentSelection(Map<String, dynamic> student) {
    Navigator.of(context).pop();
    _checkShiftAndStartSession();
  }

  void _handleClockInOut() async {
    // Check if we already have a shift and determine action
    if (_currentShift != null && _currentShift!.isClockedIn) {
      // Already clocked in, proceed to clock out
      _proceedToClockOut(_currentShift!);
    } else {
      // Need to check for shift and start session
      _checkShiftAndStartSession();
    }
  }

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
      if (!mounted) return;

      setState(() {
        _isCheckingShift = false;
      });

      _showNoShiftDialog('Error checking shift availability: $e');
    }
  }

  void _showNoShiftDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.schedule,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'No Valid Shift',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff1E293B),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xff475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAlreadyClockedInDialog(TeachingShift shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.access_time,
              color: Colors.green,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Already Clocked In',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff1E293B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are already clocked in to:',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff475569),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xff10B981).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('h:mm a').format(shift.shiftStart)} - ${DateFormat('h:mm a').format(shift.shiftEnd)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Would you like to clock out instead?',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff475569),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
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
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Clock Out',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToClockOut(TeachingShift shift) async {
    if (!mounted) return;

    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Get location for clock out with timeout
      LocationData? clockOutLocation = await LocationService.getCurrentLocation()
          .timeout(const Duration(seconds: 15), onTimeout: () {
        print('Clock-out location request timed out');
        return null;
      });

      if (!mounted) return;

      if (clockOutLocation != null) {
        _showLocationConfirmation(clockOutLocation, isClockIn: false);
      } else {
        // Show option to proceed without location instead of blocking
        setState(() {
          _isGettingLocation = false;
        });
        _showClockOutWithoutLocationDialog();
      }
    } catch (e) {
      print('Error getting location for clock-out: $e');
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      // Show option to proceed without location instead of blocking
      _showClockOutWithoutLocationDialog();
    }
  }

  void _startTeachingSession() async {
    if (!mounted) return;

    print(
        'Starting teaching session for shift: ${_currentShift?.displayName ?? "unknown"}');

    // Show loading state while getting location
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Request permission explicitly on user gesture to ensure web prompt
      await LocationService.requestPermission();
      // Try to get location but make it optional
      print('Attempting to get current location...');
      LocationData? location = await LocationService.getCurrentLocation()
          .timeout(const Duration(seconds: 30), onTimeout: () {
        print('Location request timed out - proceeding without location');
        return null;
      });

      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      // If location was obtained, show confirmation
      if (location != null) {
        print('Location obtained successfully: ${location.neighborhood}');
        _showLocationConfirmation(location, isClockIn: true);
      } else {
        print('Location unavailable - clock-in requires location for timezone');
        _showLocationRequiredDialog('Location access is required for clock-in to determine your timezone for accurate time tracking.');
      }
    } catch (e) {
      print('Error getting location: $e');
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      // Show location required dialog for clock-in
      _showLocationRequiredDialog('Location access is required for clock-in to determine your timezone for accurate time tracking.');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _updateTotalHours();
      });
    });
  }

  void _startAutoLogoutTimer() {
    if (_currentShift == null) return;

    _autoLogoutTimer?.cancel();

    _autoLogoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

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
  }

  void _stopAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();
    setState(() {
      _timeUntilAutoLogout = "";
    });
  }

  void _performAutoLogout() async {
    if (!_isClockingIn || _currentShift == null) return;

    print('Performing auto-logout for shift ${_currentShift!.id}');

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
          setState(() {
            _isClockingIn = false;
            _stopwatch.reset();
            _clockInTime = null;
            _selectedStudentName = '';
            _currentShift = null;
            _totalHoursWorked = "00:00:00";
          });

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
          setState(() {
            _isClockingIn = false;
            _stopwatch.reset();
            _clockInTime = null;
            _selectedStudentName = '';
            _currentShift = null;
            _totalHoursWorked = "00:00:00";
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Session automatically ended (location not captured)'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('Error during auto-logout: $e');

      if (mounted) {
        setState(() {
          _isClockingIn = false;
          _stopwatch.reset();
          _clockInTime = null;
          _selectedStudentName = '';
          _currentShift = null;
          _totalHoursWorked = "00:00:00";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session automatically ended (error occurred)'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _updateTotalHours() {
    // Always calculate from the actual clock-in time, not stopwatch
    if (_clockInTime != null) {
      final elapsed = DateTime.now().difference(_clockInTime!);
      _totalHoursWorked = _formatDuration(elapsed);
    }
  }

  void _clockOut() async {
    if (!_isClockingIn || _currentShift == null) return;

    // Prevent multiple simultaneous clock-out attempts
    if (_isGettingLocation) return;

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
        print('Clock-out location failed, using fallback: $e');
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
        final result = await ShiftTimesheetService.clockOutFromShift(
          user.uid,
          _currentShift!.id,
          location: clockOutLocation,
        );

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
          if (result['message'].toString().toLowerCase().contains('no active clock-in') ||
              result['message'].toString().toLowerCase().contains('couldn\'t find a valid shift')) {
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
      print('Clock-out error: $e');
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

  void _proceedWithClockIn(LocationData location) async {
    if (!mounted) return;

    if (_currentShift == null) {
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

      // Use the shift-based clock-in service
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        _currentShift!.id,
        location: location,
      );

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _isClockingIn = true;
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
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during clock-in: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _proceedWithClockOut(LocationData location) async {
    if (!mounted) return;

    if (_currentShift == null) {
      setState(() {
        _isGettingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active shift found for clock-out'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      // Use the shift-based clock-out service
      final result = await ShiftTimesheetService.clockOutFromShift(
        user.uid,
        _currentShift!.id,
        location: location,
      );

      if (!mounted) return;

      if (result['success']) {
        // Reset the clock-out state directly without calling _clockOut() again
        _resetClockOutState(location);

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
        if (result['message'].toString().toLowerCase().contains('no active clock-in') ||
            result['message'].toString().toLowerCase().contains('couldn\'t find a valid shift')) {
          // Force reset UI state when backend says no active session
          _resetClockOutState(location);
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during clock-out: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<LocationData> _getBestLocationDisplay(LocationData loc) async {
    final addr = (loc.address).toLowerCase();
    final neigh = (loc.neighborhood).toLowerCase();
    final looksLikeCoords = addr.startsWith('location:') ||
        neigh.startsWith('coordinates:') ||
        neigh == 'gps coordinates' ||
        RegExp(r'^-?\d+\.\d+').hasMatch(loc.address);
    if (!looksLikeCoords) return loc;

    try {
      final improved = await LocationService.coordinatesToLocation(
          loc.latitude, loc.longitude);
      if (improved != null) {
        return LocationData(
          latitude: loc.latitude,
          longitude: loc.longitude,
          address: improved.address,
          neighborhood: improved.neighborhood,
        );
      }
    } catch (_) {}
    return loc;
  }

  void _showLocationConfirmation(LocationData location,
      {required bool isClockIn}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.location_on,
              color: const Color(0xff0386FF),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isClockIn ? 'Clock In Location' : 'Clock Out Location',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff1E293B),
              ),
            ),
          ],
        ),
        content: FutureBuilder<LocationData>(
          future: _getBestLocationDisplay(location),
          builder: (context, snap) {
            final loc = snap.data ?? location;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.place,
                        color: const Color(0xff10B981),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.neighborhood,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.address,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xff64748B),
                    ),
                  ),
                  if (snap.connectionState == ConnectionState.waiting) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Refining location...')
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Proceed with clock-in or clock-out after location confirmation
              if (isClockIn) {
                _proceedWithClockIn(location);
              } else {
                _proceedWithClockOut(location);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
            ),
            child: Text(
              isClockIn ? 'Confirm Clock In' : 'Confirm Clock Out',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationRequiredDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false, // Can't dismiss without action
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.location_off,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Location Required',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff1E293B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff475569),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location access is mandatory for clock-in to verify attendance.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tips: Move to an open area, enable high accuracy GPS, or try refreshing the page if you just granted location permission.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Try again without going to settings
                  },
                  child: Text(
                    'Try Again',
                    style: GoogleFonts.inter(
                      color: const Color(0xff0386FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Open app settings to enable location
                    LocationService.openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Open Settings',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLocationOptionalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.location_searching,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Location Unavailable',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff1E293B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location access is required for clock-in to determine your timezone for accurate time tracking.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff475569),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location tracking helps with attendance verification.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please enable location access and try again.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTeachingSession(); // Retry getting location
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClockOutWithoutLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.location_searching,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Location Unavailable',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff1E293B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We couldn\'t determine your location for clock-out. You can still proceed without location data.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff475569),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your timezone was already determined during clock-in, so your time tracking will remain accurate.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can try again to enable location, or proceed with clock-out.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _proceedToClockOut(_currentShift!); // Retry getting location
                  },
                  child: Text(
                    'Try Again',
                    style: GoogleFonts.inter(
                      color: const Color(0xff0386FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Proceed with clock-out without location
                    _proceedWithClockOutWithoutLocation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Clock Out',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _proceedWithClockOutWithoutLocation() async {
    if (!mounted) return;

    if (_currentShift == null) {
      setState(() {
        _isGettingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active shift found for clock-out'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      // Create a fallback location for clock-out when location is unavailable
      final fallbackLocation = LocationData(
        latitude: _clockInLocation?.latitude ?? 0.0,
        longitude: _clockInLocation?.longitude ?? 0.0,
        address: 'Clock-out location unavailable',
        neighborhood: 'Location not captured',
      );

      // Use the shift-based clock-out service with fallback location
      final result = await ShiftTimesheetService.clockOutFromShift(
        user.uid,
        _currentShift!.id,
        location: fallbackLocation,
      );

      if (!mounted) return;

      if (result['success']) {
        // Reset the clock-out state
        _resetClockOutState(fallbackLocation);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['message']} (without location tracking)'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        // Refresh timesheet data
        _refreshTimesheetData();
        _checkForActiveShift();
      } else {
        // Handle failure
        setState(() {
          _isGettingLocation = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clock-out failed: ${result['message']}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during clock-out: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }


  void _showClockOutConfirmation(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Session Completed',
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 18,
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
              'Your teaching session has been recorded:',
              style: constants.openSansHebrewTextStyle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Student:', entry['type']),
                  _buildInfoRow('Date:', entry['date']),
                  _buildInfoRow('Time:', '${entry['start']} - ${entry['end']}'),
                  _buildInfoRow('Total Hours:', entry['totalHours']),
                  if (entry['clockInLocation'] != null ||
                      entry['clockOutLocation'] != null) ...[
                    const SizedBox(height: 8),
                    _buildLocationInfo(entry),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This entry has been saved as a draft. You can review and submit it for approval in the timesheet below.',
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('View Timesheet'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(Map<String, dynamic> entry) {
    final clockInLocation = entry['clockInLocation'] as LocationData?;
    final clockOutLocation = entry['clockOutLocation'] as LocationData?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xff10B981).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xff10B981),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Location Information',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (clockInLocation != null) ...[
            Text(
              '📍 Clock-in: ${clockInLocation.neighborhood}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xff064E3B),
              ),
            ),
            if (clockInLocation.address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '   ${clockInLocation.address}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ],
          if (clockOutLocation != null) ...[
            const SizedBox(height: 6),
            Text(
              '📍 Clock-out: ${clockOutLocation.neighborhood}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xff064E3B),
              ),
            ),
            if (clockOutLocation.address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '   ${clockOutLocation.address}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ],
          if (clockInLocation == null && clockOutLocation == null) ...[
            Text(
              '⚠️ Location was not captured',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showStudentSelectionPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        String localSearchQuery = '';
        List<Map<String, dynamic>> localFilteredStudents = List.from(_students);
        TextEditingController localSearchController = TextEditingController();

        return StatefulBuilder(
          builder: (context, dialogSetState) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 500,
                maxHeight: 600,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xffF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xff0386FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.school,
                            color: Color(0xff0386FF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Student',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff111827),
                                ),
                              ),
                              Text(
                                'Choose a student to clock in',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xff6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xff6B7280),
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search field
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xffE5E7EB)),
                      ),
                      child: TextField(
                        controller: localSearchController,
                        onChanged: (value) {
                          dialogSetState(() {
                            localSearchQuery = value.toLowerCase();
                            if (localSearchQuery.isEmpty) {
                              localFilteredStudents = _students;
                            } else {
                              localFilteredStudents =
                                  _students.where((student) {
                                return student['name']
                                        .toLowerCase()
                                        .contains(localSearchQuery) ||
                                    student['email']
                                        .toLowerCase()
                                        .contains(localSearchQuery) ||
                                    student['grade']
                                        .toLowerCase()
                                        .contains(localSearchQuery) ||
                                    student['kiosk_code']
                                        .toLowerCase()
                                        .contains(localSearchQuery);
                              }).toList();
                            }
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search students...',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xff9CA3AF),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xff9CA3AF),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Students list
                  Flexible(
                    child: _isLoadingStudents
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                color: Color(0xff0386FF),
                              ),
                            ),
                          )
                        : localFilteredStudents.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        localSearchQuery.isEmpty
                                            ? 'No students found'
                                            : 'No students match your search',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xff6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: localFilteredStudents.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final student = localFilteredStudents[index];
                                  return InkWell(
                                    onTap: () =>
                                        _handleStudentSelection(student),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor:
                                                const Color(0xff0386FF)
                                                    .withOpacity(0.1),
                                            child: Text(
                                              student['name'][0].toUpperCase(),
                                              style: GoogleFonts.inter(
                                                color: const Color(0xff0386FF),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  student['name'],
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        const Color(0xff111827),
                                                  ),
                                                ),
                                                if (student['email'].isNotEmpty)
                                                  Text(
                                                    student['email'],
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: const Color(
                                                          0xff6B7280),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (student['kiosk_code'].isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xff0386FF)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                student['kiosk_code'],
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      const Color(0xff0386FF),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  // Footer
                  if (!_isLoadingStudents && localFilteredStudents.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xffF9FAFB),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${localFilteredStudents.length} student${localFilteredStudents.length == 1 ? '' : 's'} found',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xff6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Shift information section (if active)
            if (_currentShift != null)
              Container(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: const Color(0xff10B981).withOpacity(0.1),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: const Color(0xff10B981),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentShift!.isClockedIn
                                  ? 'Clocked In'
                                  : 'Active Shift',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff10B981),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentShift!.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xff1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('MMM dd, h:mm a').format(_currentShift!.shiftStart)} - ${DateFormat('h:mm a').format(_currentShift!.shiftEnd)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff64748B),
                          ),
                        ),
                        if (_currentShift!.studentNames.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Students: ${_currentShift!.studentNames.join(', ')}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xff64748B),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            // Clock-in section
            Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.white,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Clock",
                        style: constants.openSansHebrewTextStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          child: _isClockingIn
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Teaching: $_selectedStudentName',
                                        style: constants.openSansHebrewTextStyle
                                            .copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xff0386FF),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _totalHoursWorked,
                                      style: constants.openSansHebrewTextStyle
                                          .copyWith(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    if (_timeUntilAutoLogout.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
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
                                              size: 16,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Auto-logout in $_timeUntilAutoLogout',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _clockOut,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(100, 40),
                                      ),
                                      child: const Text('Stop'),
                                    ),
                                  ],
                                )
                              : ElevatedButton(
                                  onPressed:
                                      (_isGettingLocation || _isCheckingShift)
                                          ? null
                                          : () => _handleClockInOut(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: (_isGettingLocation ||
                                            _isCheckingShift)
                                        ? Colors.grey
                                        : (_currentShift != null &&
                                                _currentShift!.isClockedIn)
                                            ? Colors.red // Show red for clock-out
                                            : const Color(
                                                0xff0386FF), // Blue for clock-in
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(100, 40),
                                  ),
                                  child: _isCheckingShift
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                        Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('Checking Shift...'),
                                          ],
                                        )
                                      : _isGettingLocation
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(Colors.white),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Text('Getting Location...'),
                                              ],
                                            )
                                          : Text((_currentShift != null &&
                                                  _currentShift!.isClockedIn)
                                              ? 'Clock Out'
                                              : 'Clock In'),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Timesheet section - now with fixed height instead of Expanded
            Container(
              height: 600, // Fixed height for the table
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: TimesheetTable(
                clockInEntries: _timesheetEntries,
                key: _timesheetTableKey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}