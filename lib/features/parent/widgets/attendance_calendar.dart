import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/core/enums/shift_enums.dart';

class AttendanceCalendar extends StatelessWidget {
  final List<TeachingShift> shifts;
  final DateTime selectedMonth;

  const AttendanceCalendar({
    super.key,
    required this.shifts,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    final daysInMonth = lastDayOfMonth.day;

    // Create a map of date -> shift status for quick lookup
    final Map<int, ShiftStatus> dateStatusMap = {};
    for (final shift in shifts) {
      if (shift.shiftStart.year == selectedMonth.year &&
          shift.shiftStart.month == selectedMonth.month) {
        final day = shift.shiftStart.day;
        // Keep the most significant status (completed > missed > cancelled > scheduled)
        if (!dateStatusMap.containsKey(day) ||
            _getStatusPriority(shift.status) > _getStatusPriority(dateStatusMap[day]!)) {
          dateStatusMap[day] = shift.status;
        }
      }
    }

    final monthName = DateFormat('MMMM yyyy').format(selectedMonth);
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthName,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),
          // Weekday headers
          Row(
            children: weekDays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
          // Calendar grid
          ...List.generate(((daysInMonth + firstWeekday - 1) / 7).ceil(), (weekIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: List.generate(7, (dayIndex) {
                  final dayNumber = (weekIndex * 7) + dayIndex - (firstWeekday - 1) + 1;
                  
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return Expanded(child: Container());
                  }

                  final status = dateStatusMap[dayNumber];
                  final isToday = dayNumber == DateTime.now().day &&
                      selectedMonth.year == DateTime.now().year &&
                      selectedMonth.month == DateTime.now().month;

                  return Expanded(
                    child: _buildDayCell(dayNumber, status, isToday),
                  );
                }),
              ),
            );
          }),
          const SizedBox(height: 20),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Completed', const Color(0xFF16A34A)),
              _buildLegendItem('Missed', const Color(0xFFDC2626)),
              _buildLegendItem('Scheduled', const Color(0xFF2563EB)),
              _buildLegendItem('None', const Color(0xFFE5E7EB)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(int day, ShiftStatus? status, bool isToday) {
    Color? backgroundColor;
    Color textColor = const Color(0xFF111827);

    if (status != null) {
      switch (status) {
        case ShiftStatus.completed:
        case ShiftStatus.fullyCompleted:
        case ShiftStatus.partiallyCompleted:
          backgroundColor = const Color(0xFFD1FAE5);
          break;
        case ShiftStatus.missed:
          backgroundColor = const Color(0xFFFEE2E2);
          break;
        case ShiftStatus.cancelled:
          backgroundColor = const Color(0xFFF3F4F6);
          break;
        case ShiftStatus.scheduled:
          backgroundColor = const Color(0xFFDBEAFE);
          break;
        default:
          backgroundColor = null;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: const Color(0xFF0386FF), width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          day.toString(),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  int _getStatusPriority(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.completed:
      case ShiftStatus.fullyCompleted:
      case ShiftStatus.partiallyCompleted:
        return 4;
      case ShiftStatus.missed:
        return 3;
      case ShiftStatus.cancelled:
        return 2;
      case ShiftStatus.scheduled:
        return 1;
      default:
        return 0;
    }
  }
}

