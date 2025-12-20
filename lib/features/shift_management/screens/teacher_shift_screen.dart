import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../dashboard/widgets/date_strip_calendar.dart';
import '../../dashboard/widgets/timeline_shift_card.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/shift_timesheet_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/timezone_utils.dart';
import '../widgets/shift_details_dialog.dart';
import '../widgets/report_schedule_issue_dialog.dart';
import 'available_shifts_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _setupShiftStream();
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

    // Listen to real-time shifts stream
    ShiftService.getTeacherShifts(user.uid).listen(
      (shifts) {
        if (mounted) {
          setState(() {
            _allShifts = shifts;
            _filterShiftsForDate(_selectedDate);
            _isLoading = false;
          });
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

      // Get location
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get location. Please enable location services.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Clock in directly
      final result = await ShiftTimesheetService.clockInToShift(
        user.uid,
        shift.id,
        location: location,
        platform: 'mobile',
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clocked in successfully!'),
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
      }
    } catch (e) {
      AppLogger.error('Error clocking in: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                    builder: (context) => ReportScheduleIssueDialog(shift: shift),
                  ).then((refresh) {
                    if (refresh == true) {
                      _setupShiftStream();
                    }
                  });
                },
              )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.access_time, color: Color(0xFFF59E0B)),
                title: Text(
                  'Fix My Timezone Only',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedTimezone ?? 'UTC',
                    isExpanded: true,
                    items: TimezoneUtils.getCommonTimezones().map((tz) {
                      return DropdownMenuItem<String>(
                        value: tz,
                        child: Text(tz, style: GoogleFonts.inter(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedTimezone = value);
                    },
                  ),
                ),
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
                if (selectedTimezone != null && selectedTimezone != currentTimezone) {
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
                          content: Text('Timezone updated to $selectedTimezone'),
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
              child: Text('Update', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
            icon: const Icon(Icons.settings, color: Color(0xFF6B7280), size: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          return TimelineShiftCard(
                            shift: shift,
                            isLast: index == _dailyShifts.length - 1,
                            onTap: () => _showShiftDetails(shift),
                            onClockIn: () => _handleClockIn(shift),
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
