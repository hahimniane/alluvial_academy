import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart' as constants;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/timesheet_table.dart' show TimesheetTable;
import '../../../core/services/location_service.dart';

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

  // Location data
  LocationData? _clockInLocation;
  LocationData? _clockOutLocation;
  bool _isGettingLocation = false;

  final List<dynamic> _timesheetEntries = [];
  final GlobalKey<State<TimesheetTable>> _timesheetTableKey =
      GlobalKey<State<TimesheetTable>>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStudents();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    _startTeachingSession(student);
  }

  void _startTeachingSession(Map<String, dynamic> student) async {
    if (!mounted) return;

    print('Starting teaching session for student: ${student['name']}');

    // First check if we already have location permissions
    bool hasPermission = await LocationService.hasLocationPermission();
    print('Has location permission: $hasPermission');

    // Show loading state while getting location
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Get location before clocking in
      print('Attempting to get current location...');
      LocationData? location = await LocationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      // Show location confirmation FIRST - only proceed after confirmation
      if (location != null) {
        print('Location obtained successfully: ${location.neighborhood}');
        _showLocationConfirmation(location, student: student, isClockIn: true);
      } else {
        print('Location was null despite no exception');
        _showLocationRequiredDialog(
            'Location could not be determined. Please ensure GPS is enabled.');
      }
    } catch (e) {
      print('Error getting location: $e');
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      // Show error - location is now mandatory for clock in
      _showLocationRequiredDialog(e.toString());
    }
  }

  void _startTimer() {
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

  void _updateTotalHours() {
    final elapsed = _stopwatch.elapsed;
    final hours = elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    _totalHoursWorked = '$hours:$minutes:$seconds';
    print(
        'Timer update: $_totalHoursWorked (elapsed: ${elapsed.inSeconds}s)'); // Debug
  }

  void _clockOut() async {
    if (!_isClockingIn || _clockInTime == null) return;

    // Show loading state while getting location
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Get location for clock out
      LocationData? clockOutLocation =
          await LocationService.getCurrentLocation();

      final now = DateTime.now();
      final startTime = DateFormat('h:mm a').format(_clockInTime!);
      final endTime = DateFormat('h:mm a').format(now);

      // Calculate final hours without seconds for storage
      final elapsed = _stopwatch.elapsed;
      final hours = elapsed.inHours.toString().padLeft(2, '0');
      final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
      final totalHours = '$hours:$minutes';

      // Create a simple entry for the clock-in entries list
      final clockInEntry = {
        'date': DateFormat('EEE MM/dd').format(now),
        'type': _selectedStudentName,
        'start': startTime,
        'end': endTime,
        'totalHours': totalHours,
        'clockInLocation': _clockInLocation,
        'clockOutLocation': clockOutLocation,
      };

      if (!mounted) return;
      setState(() {
        _timesheetEntries.insert(0, clockInEntry);
        _isClockingIn = false;
        _stopwatch.stop();
        _timer?.cancel();
        _stopwatch.reset();
        _clockInTime = null;
        _selectedStudentName = '';
        _clockOutLocation = clockOutLocation;
        _isGettingLocation = false;
      });

      // Save to Firebase
      bool savedSuccessfully = await _saveToFirebase(clockInEntry);

      // If saved successfully, remove from local list to avoid duplicates and refresh timesheet
      if (savedSuccessfully && mounted) {
        setState(() {
          _timesheetEntries.removeWhere((entry) =>
              entry is Map<String, dynamic> &&
              entry['date'] == clockInEntry['date'] &&
              entry['type'] == clockInEntry['type'] &&
              entry['start'] == clockInEntry['start'] &&
              entry['end'] == clockInEntry['end']);
        });

        // Refresh the timesheet table to show the new entry immediately
        // Add a small delay to ensure Firebase write is committed
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _refreshTimesheetData();
          }
        });
      }

      // Show location confirmation if available
      if (clockOutLocation != null) {
        _showLocationConfirmation(clockOutLocation, isClockIn: false);
      }

      // Show confirmation
      _showClockOutConfirmation(clockInEntry);

      // Reset location data
      _clockInLocation = null;
      _clockOutLocation = null;
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isGettingLocation = false;
      });

      // Continue with clock out even if location fails
      final now = DateTime.now();
      final startTime = DateFormat('h:mm a').format(_clockInTime!);
      final endTime = DateFormat('h:mm a').format(now);

      final elapsed = _stopwatch.elapsed;
      final hours = elapsed.inHours.toString().padLeft(2, '0');
      final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
      final totalHours = '$hours:$minutes';

      final clockInEntry = {
        'date': DateFormat('EEE MM/dd').format(now),
        'type': _selectedStudentName,
        'start': startTime,
        'end': endTime,
        'totalHours': totalHours,
        'clockInLocation': _clockInLocation,
        'clockOutLocation': null,
      };

      if (!mounted) return;
      setState(() {
        _timesheetEntries.insert(0, clockInEntry);
        _isClockingIn = false;
        _stopwatch.stop();
        _timer?.cancel();
        _stopwatch.reset();
        _clockInTime = null;
        _selectedStudentName = '';
        _clockOutLocation = null;
      });

      // Save to Firebase
      bool savedSuccessfully = await _saveToFirebase(clockInEntry);

      if (savedSuccessfully && mounted) {
        setState(() {
          _timesheetEntries.removeWhere((entry) =>
              entry is Map<String, dynamic> &&
              entry['date'] == clockInEntry['date'] &&
              entry['type'] == clockInEntry['type'] &&
              entry['start'] == clockInEntry['start'] &&
              entry['end'] == clockInEntry['end']);
        });

        // Refresh the timesheet table to show the new entry immediately
        // Add a small delay to ensure Firebase write is committed
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _refreshTimesheetData();
          }
        });
      }

      _showClockOutConfirmation(clockInEntry);
      _clockInLocation = null;
    }
  }

  Future<bool> _saveToFirebase(Map<String, dynamic> entry) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated, cannot save timesheet entry');
        return false;
      }

      // Prepare location data
      final clockInLocation = entry['clockInLocation'] as LocationData?;
      final clockOutLocation = entry['clockOutLocation'] as LocationData?;

      // Create location display string
      String locationInfo = '';
      if (clockInLocation != null) {
        locationInfo =
            'Clock-in: ${LocationService.formatLocationForDisplay(clockInLocation.address, clockInLocation.neighborhood)}';
        if (clockOutLocation != null) {
          locationInfo +=
              ' | Clock-out: ${LocationService.formatLocationForDisplay(clockOutLocation.address, clockOutLocation.neighborhood)}';
        }
      } else {
        locationInfo = 'Location not captured';
      }

      await FirebaseFirestore.instance.collection('timesheet_entries').add({
        'teacher_id': user.uid,
        'teacher_email': user.email,
        'date': entry['date'],
        'student_name': entry['type'],
        'start_time': entry['start'],
        'end_time': entry['end'],
        'break_duration': '15 min',
        'total_hours': entry['totalHours'],
        'description': 'Teaching session with ${entry['type']}',
        'status': 'draft',
        'source': 'clock_in',
        // Location data
        'clock_in_latitude': clockInLocation?.latitude,
        'clock_in_longitude': clockInLocation?.longitude,
        'clock_in_address': clockInLocation?.address,
        'clock_in_neighborhood': clockInLocation?.neighborhood,
        'clock_out_latitude': clockOutLocation?.latitude,
        'clock_out_longitude': clockOutLocation?.longitude,
        'clock_out_address': clockOutLocation?.address,
        'clock_out_neighborhood': clockOutLocation?.neighborhood,
        'location_info': locationInfo,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('Clock-in entry saved to Firebase successfully with location data');
      return true;
    } catch (e) {
      print('Error saving clock-in entry to Firebase: $e');
      return false;
    }
  }

  void _proceedWithClockIn(
      LocationData location, Map<String, dynamic> student) {
    if (!mounted) return;
    setState(() {
      _isClockingIn = true;
      _selectedStudentName = student['name'];
      _clockInTime = DateTime.now();
      _clockInLocation = location;
      _totalHoursWorked = "00:00:00";
      _stopwatch.reset();
      _stopwatch.start();
      _startTimer();
    });
  }

  void _proceedWithClockOut(LocationData location) {
    if (!mounted) return;
    _clockOut();
  }

  void _showLocationConfirmation(LocationData location,
      {Map<String, dynamic>? student, required bool isClockIn}) {
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
        content: Container(
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
                      location.neighborhood,
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
                location.address,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xff64748B),
                ),
              ),
            ],
          ),
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
                _proceedWithClockIn(location, student!);
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
                    'If you\'re using Chrome, please ensure location is enabled for this site. You may need to refresh the page after granting permission.',
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
      body: Column(
        children: [
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
                                onPressed: _isGettingLocation
                                    ? null
                                    : () => _showStudentSelectionPopup(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isGettingLocation
                                      ? Colors.grey
                                      : const Color(0xff0386FF),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(100, 40),
                                ),
                                child: _isGettingLocation
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
                                          const Text('Getting Location...'),
                                        ],
                                      )
                                    : const Text('Clock In'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Timesheet section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TimesheetTable(
                clockInEntries: _timesheetEntries,
                key: _timesheetTableKey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
