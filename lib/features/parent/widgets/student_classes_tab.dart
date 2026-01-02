import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/core/services/parent_service.dart';
import 'package:alluwalacademyadmin/core/services/shift_service.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/class_card.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/attendance_calendar.dart';

class StudentClassesTab extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentClassesTab({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentClassesTab> createState() => _StudentClassesTabState();
}

class _StudentClassesTabState extends State<StudentClassesTab> {
  bool _showUpcoming = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterButton('Upcoming', true),
                  ),
                  Expanded(
                    child: _buildFilterButton('History', false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Attendance Calendar
            _sectionHeader('Attendance Calendar'),
            const SizedBox(height: 10),
            StreamBuilder<List<TeachingShift>>(
              stream: ShiftService.getStudentShifts(widget.studentId),
              builder: (context, snapshot) {
                final shifts = snapshot.data ?? [];
                return AttendanceCalendar(
                  shifts: shifts,
                  selectedMonth: _selectedMonth,
                );
              },
            ),
            const SizedBox(height: 20),

            // Classes List
            _sectionHeader(_showUpcoming ? 'Upcoming Classes' : 'Class History'),
            const SizedBox(height: 10),
            _showUpcoming
                ? _buildUpcomingClasses()
                : _buildClassHistory(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, bool isUpcoming) {
    final isSelected = _showUpcoming == isUpcoming;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _showUpcoming = isUpcoming;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF111827)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingClasses() {
    return StreamBuilder<List<TeachingShift>>(
      stream: ShiftService.getStudentShifts(widget.studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ));
        }

        if (snapshot.hasError) {
          return _errorCard('Failed to load upcoming classes: ${snapshot.error}');
        }

        final now = DateTime.now();
        final upcoming = (snapshot.data ?? []).where((shift) =>
          shift.shiftStart.isAfter(now)).toList();
        upcoming.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

        if (upcoming.isEmpty) {
          return _emptyCard(
            icon: Icons.calendar_month_rounded,
            title: 'No upcoming classes',
            subtitle: 'Your child has no upcoming classes scheduled.',
          );
        }

        return Column(
          children: upcoming.map((shift) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClassCard(shift: shift),
          )).toList(),
        );
      },
    );
  }

  Widget _buildClassHistory() {
    return FutureBuilder<List<TeachingShift>>(
      future: ParentService.getStudentShiftsHistory(widget.studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ));
        }

        if (snapshot.hasError) {
          return _errorCard('Failed to load class history: ${snapshot.error}');
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return _emptyCard(
            icon: Icons.history_rounded,
            title: 'No class history',
            subtitle: 'Completed classes will appear here.',
          );
        }

        return Column(
          children: history.map((shift) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClassCard(shift: shift),
          )).toList(),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF111827),
      ),
    );
  }

  Widget _emptyCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Icon(icon, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7F1D1D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

