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
import '../widgets/shift_details_dialog.dart';
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
        actions: const [], // Removed "Find Shifts" - not relevant for teacher schedule view
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
                          return TimelineShiftCard(
                            shift: _dailyShifts[index],
                            isLast: index == _dailyShifts.length - 1,
                            onTap: () => _showShiftDetails(_dailyShifts[index]),
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
