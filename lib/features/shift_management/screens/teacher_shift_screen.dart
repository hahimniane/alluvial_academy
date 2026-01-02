import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../dashboard/widgets/date_strip_calendar.dart';
import '../../dashboard/widgets/timeline_shift_card.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/timezone_selector_field.dart';
import '../widgets/shift_details_dialog.dart';
import '../widgets/report_schedule_issue_dialog.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class TeacherShiftScreen extends StatefulWidget {
  const TeacherShiftScreen({super.key});

  @override
  State<TeacherShiftScreen> createState() => _TeacherShiftScreenState();
}

class _TeacherShiftScreenState extends State<TeacherShiftScreen> {
  List<TeachingShift> _allShifts = []; // All shifts from stream
  List<TeachingShift> _dailyShifts = []; // Filtered for selected day
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  // Programmed clock-in state
  String? _programmedShiftId;
  Timer? _programTimer;
  String _timeUntilAutoStart = "";
  Timer? _uiRefreshTimer;

  // Stream subscription for cleanup
  StreamSubscription<List<TeachingShift>>? _shiftsSubscription;

  @override
  void initState() {
    super.initState();
    _setupShiftStream();

    // Refresh UI every second to update button states
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Trigger rebuild to update time-based UI
        });
      }
    });
  }

  @override
  void dispose() {
    _programTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _shiftsSubscription?.cancel(); // Cancel stream subscription on dispose
    super.dispose();
  }

  /// Check for any persisted programmed state on startup
  Future<void> _checkForPersistedProgrammedState() async {
    // Skip if already programming a shift
    if (_programmedShiftId != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      // Check all daily shifts for persisted programmed state
      for (final shift in _dailyShifts) {
        final isProgrammed =
            prefs.getBool('programmed_start_${shift.id}') ?? false;
        if (isProgrammed && !shift.isClockedIn) {
          AppLogger.debug(
              'Found persisted programmed state for shift ${shift.id}');
          _startProgrammedClockIn(shift);
          break;
        }
      }
    } catch (e) {
      AppLogger.error('Error checking programmed state: $e');
    }
  }

  void _setupShiftStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppLogger.debug('TeacherShiftScreen: No authenticated user found');
      setState(() => _isLoading = false);
      return;
    }

    AppLogger.debug(
        'TeacherShiftScreen: Setting up real-time stream for user UID: ${user.uid}');

    // Cancel any existing subscription before creating a new one
    _shiftsSubscription?.cancel();

    // Listen to real-time shifts stream
    _shiftsSubscription = ShiftService.getTeacherShifts(user.uid).listen(
      (shifts) {
        if (mounted) {
          setState(() {
            _allShifts = shifts;
            _filterShiftsForDate(_selectedDate);
            _isLoading = false;
          });
          // Check for persisted programmed state after shifts are loaded
          _checkForPersistedProgrammedState();
        }
      },
      onError: (error) {
        AppLogger.error('Error in teacher shifts stream: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  void _filterShiftsForDate(DateTime date) {
    setState(() {
      _dailyShifts = _allShifts.where((shift) {
        return shift.shiftStart.year == date.year &&
            shift.shiftStart.month == date.month &&
            shift.shiftStart.day == date.day;
      }).toList();

      // Sort by start time
      _dailyShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _filterShiftsForDate(date);
  }

  Future<void> _handleClockIn(TeachingShift shift) async {
    final now = DateTime.now();
    final shiftStart = shift.shiftStart;
    final programmingWindowStart =
        shiftStart.subtract(const Duration(minutes: 1));

    // Check if we're in the programming window (before shift start)
    final isInProgramWindow =
        now.isAfter(programmingWindowStart) && now.isBefore(shiftStart);

    // Check if shift has started
    final shiftHasStarted = !now.isBefore(shiftStart);

    AppLogger.debug(
        '_handleClockIn: isInProgramWindow=$isInProgramWindow, shiftHasStarted=$shiftHasStarted');

    if (isInProgramWindow && !shiftHasStarted) {
      // Start programmed clock-in
      _startProgrammedClockIn(shift);
    } else if (shiftHasStarted) {
      // Immediate clock-in
      await _performClockIn(shift);
    } else {
      // Too early - shouldn't happen but handle gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Too early to clock in. Please wait for the programming window.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Start a programmed clock-in that will auto-trigger at shift start time
  void _startProgrammedClockIn(TeachingShift shift) async {
    AppLogger.debug('Starting programmed clock-in for shift ${shift.id}');

    final nowUtc = DateTime.now().toUtc();
    final shiftStartUtc = shift.shiftStart.toUtc();

    // If shift has already started, clock in immediately
    if (!nowUtc.isBefore(shiftStartUtc)) {
      AppLogger.debug('Shift already started - clocking in immediately');
      await _performClockIn(shift, isAutoStart: true);
      return;
    }

    // Calculate initial countdown
    final timeLeft = shiftStartUtc.difference(nowUtc);
    final initialSeconds = timeLeft.inSeconds;
    final initialMinutes = timeLeft.inMinutes;
    final remainingSeconds = initialSeconds % 60;

    // Persist programmed state
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('programmed_start_${shift.id}', true);
    } catch (e) {
      AppLogger.error('Failed to save programmed state: $e');
    }

    if (!mounted) return;

    // Format countdown
    final countdownText = initialMinutes > 0
        ? '${initialMinutes}m ${remainingSeconds.toString().padLeft(2, '0')}s'
        : '${initialSeconds}s';

    setState(() {
      _programmedShiftId = shift.id;
      _timeUntilAutoStart = 'Starting in $countdownText';
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Clock-in programmed for ${DateFormat('HH:mm').format(shift.shiftStart)}'),
        backgroundColor: const Color(0xFF3B82F6),
        duration: const Duration(seconds: 2),
      ),
    );

    // Cancel any existing timer
    _programTimer?.cancel();

    // Start countdown timer
    _programTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nowUtc = DateTime.now().toUtc();
      final shiftStartUtc = shift.shiftStart.toUtc();

      if (!nowUtc.isBefore(shiftStartUtc)) {
        // Time to clock in!
        AppLogger.debug('Auto-start time reached! Clocking in...');
        timer.cancel();

        // Clear persisted state
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('programmed_start_${shift.id}');
        });

        if (mounted) {
          setState(() {
            _timeUntilAutoStart = "Clocking In...";
          });
          _performClockIn(shift, isAutoStart: true);
        }
        return;
      }

      final timeLeft = shiftStartUtc.difference(nowUtc);
      final seconds = timeLeft.inSeconds;
      final minutes = timeLeft.inMinutes;
      final remainingSeconds = seconds % 60;

      final countdownText = minutes > 0
          ? '${minutes}m ${remainingSeconds.toString().padLeft(2, '0')}s'
          : '${seconds}s';

      if (mounted) {
        setState(() {
          _timeUntilAutoStart = 'Starting in $countdownText';
        });
      }
    });
  }

  /// Cancel a programmed clock-in
  void _cancelProgrammedClockIn() async {
    AppLogger.debug('Cancelling programmed clock-in');
    _programTimer?.cancel();
    _programTimer = null;

    // Clear persisted state
    if (_programmedShiftId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('programmed_start_$_programmedShiftId');
      } catch (e) {
        AppLogger.error('Failed to clear programmed state: $e');
      }
    }

    if (mounted) {
      setState(() {
        _programmedShiftId = null;
        _timeUntilAutoStart = "";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Programming cancelled'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Perform the actual clock-in
  Future<void> _performClockIn(TeachingShift shift,
      {bool isAutoStart = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get location with timeout
      LocationData? location;
      try {
        final timeoutDuration = Duration(seconds: isAutoStart ? 5 : 15);
        location =
            await LocationService.getCurrentLocation().timeout(timeoutDuration);
      } catch (e) {
        AppLogger.error('Location error: $e');
        if (isAutoStart) {
          // For auto-start, use fallback location
          location = LocationData(
            latitude: 0.0,
            longitude: 0.0,
            address: 'Auto clock-in - location unavailable',
            neighborhood: 'Programmed start',
          );
        }
      }

      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Unable to get location. Please enable location services.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Clock in
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        shift.id,
        location: location,
        platform: 'mobile',
      );

      if (result['success'] == true) {
        // Clear programmed state on success
        if (mounted) {
          setState(() {
            _programmedShiftId = null;
            _timeUntilAutoStart = "";
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAutoStart
                ? 'Auto clock-in successful!'
                : 'Clocked in successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh shifts to update status
        _setupShiftStream();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to clock in'),
            backgroundColor: Colors.red,
          ),
        );

        // Clear programmed state on failure too
        if (mounted) {
          setState(() {
            _programmedShiftId = null;
            _timeUntilAutoStart = "";
          });
        }
      }
    } catch (e) {
      AppLogger.error('Error clocking in: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );

      // Clear programmed state on error
      if (mounted) {
        setState(() {
          _programmedShiftId = null;
          _timeUntilAutoStart = "";
        });
      }
    }
  }

  void _showShiftDetails(TeachingShift shift) {
    showDialog(
      context: context,
      builder: (context) => ShiftDetailsDialog(
        shift: shift,
        onRefresh: () {
          // Refresh the shift stream by re-setting up
          _setupShiftStream();
        },
      ),
    );
  }

  void _showScheduleIssueDialog() {
    // If there are shifts today, show a picker. Otherwise, show timezone fix only
    if (_dailyShifts.isNotEmpty) {
      // Show shift picker
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Report Schedule Issue',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select a shift to report an issue, or fix your timezone:',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ..._dailyShifts.map((shift) => ListTile(
                    leading: const Icon(Icons.event, color: Color(0xFF0386FF)),
                    title: Text(
                      shift.displayName,
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    subtitle: Text(
                      '${DateFormat('h:mm a').format(shift.shiftStart)} - ${DateFormat('h:mm a').format(shift.shiftEnd)}',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) =>
                            ReportScheduleIssueDialog(shift: shift),
                      ).then((refresh) {
                        if (refresh == true) {
                          _setupShiftStream();
                        }
                      });
                    },
                  )),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.access_time, color: Color(0xFFF59E0B)),
                title: Text(
                  'Fix My Timezone Only',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Update timezone without reporting a shift issue',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Show timezone-only dialog (create a dummy shift or modify dialog)
                  _showTimezoneFixDialog();
                },
              ),
            ],
          ),
        ),
      );
    } else {
      // No shifts today - show timezone fix directly
      _showTimezoneFixDialog();
    }
  }

  void _showTimezoneFixDialog() async {
    // Create a minimal dialog for timezone fix only
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? selectedTimezone;
    String? currentTimezone;

    // Load current timezone
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        currentTimezone = userDoc.data()?['timezone'] as String?;
        selectedTimezone = currentTimezone ?? 'UTC';
      }
    } catch (e) {
      AppLogger.error('Error loading timezone: $e');
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.access_time, color: Color(0xFF0386FF)),
              const SizedBox(width: 8),
              Text(
                'Fix Timezone',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your correct timezone:',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TimezoneSelectorField(
                selectedTimezone: selectedTimezone ?? 'UTC',
                borderRadius: BorderRadius.circular(8),
                borderColor: const Color(0xFFE2E8F0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                textStyle: GoogleFonts.inter(fontSize: 14),
                onTimezoneSelected: (value) =>
                    setDialogState(() => selectedTimezone = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedTimezone != null &&
                    selectedTimezone != currentTimezone) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'timezone': selectedTimezone,
                      'timezone_updated_at': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Timezone updated to $selectedTimezone'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context, true);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0386FF),
                foregroundColor: Colors.white,
              ),
              child: Text('Update',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _setupShiftStream(); // Refresh shifts with new timezone
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          'Schedule',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff6B7280)),
        actions: [
          // Compact button to report schedule issues or fix timezone
          IconButton(
            icon:
                const Icon(Icons.settings, color: Color(0xFF6B7280), size: 20),
            tooltip: 'Fix timezone or report schedule issue',
            onPressed: () {
              // Show dialog to select a shift or fix timezone globally
              _showScheduleIssueDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Strip
          DateStripCalendar(
            selectedDate: _selectedDate,
            onDateSelected: _onDateSelected,
          ),

          // Selected Date Header - Shows which date is being viewed
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
                const Spacer(),
                if (_dailyShifts.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_dailyShifts.length} shift${_dailyShifts.length > 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0386FF),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dailyShifts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _dailyShifts.length,
                        itemBuilder: (context, index) {
                          final shift = _dailyShifts[index];
                          final isThisShiftProgrammed =
                              _programmedShiftId == shift.id;
                          return TimelineShiftCard(
                            shift: shift,
                            isLast: index == _dailyShifts.length - 1,
                            onTap: () => _showShiftDetails(shift),
                            onClockIn: () => _handleClockIn(shift),
                            onCancelProgram: isThisShiftProgrammed
                                ? _cancelProgrammedClockIn
                                : null,
                            isProgrammed: isThisShiftProgrammed,
                            countdownText: isThisShiftProgrammed
                                ? _timeUntilAutoStart
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "No shifts on this day",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff9CA3AF),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Enjoy your free time or check available shifts to pick up extra classes.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
