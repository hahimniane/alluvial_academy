import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';

class TimelineShiftCard extends StatelessWidget {
  final TeachingShift shift;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback? onClockIn;
  final VoidCallback? onClockOut;
  final bool showClockInButtons; // If false, hide clock-in buttons (for home screen)

  const TimelineShiftCard({
    super.key,
    required this.shift,
    this.isLast = false,
    required this.onTap,
    this.onClockIn,
    this.onClockOut,
    this.showClockInButtons = true, // Default to true (show buttons in shift tabs)
  });

  // Check if clock-in is allowed right now
  bool get _canClockInNow {
    final now = DateTime.now();
    final shiftStart = shift.shiftStart;
    final shiftEnd = shift.shiftEnd;

    // Allow clock-in from shift start to shift end
    // Also allow if status is active (re-entry) but ensure not already clocked in (checked by caller or separate logic)
    return now.isAfter(shiftStart.subtract(const Duration(minutes: 1))) &&
        now.isBefore(shiftEnd) &&
        (shift.status == ShiftStatus.scheduled || shift.status == ShiftStatus.active);
  }

  // Check if this is an upcoming shift (not yet time to clock in)
  bool get _isUpcoming {
    final now = DateTime.now();
    return shift.shiftStart.isAfter(now) && shift.status == ShiftStatus.scheduled;
  }

  // Check if shift is currently active (clocked in)
  bool get _isActive {
    // Only consider active if explicitly clocked in
    // ShiftStatus.active just means the time window has started
    return shift.isClockedIn;
  }

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat('HH:mm').format(shift.shiftStart);
    final endTime = DateFormat('HH:mm').format(shift.shiftEnd);
    final duration = shift.shiftEnd.difference(shift.shiftStart).inMinutes;

    // Status color logic
    Color statusColor;
    Color statusBgColor;
    String statusText;
    Color statusTextColor;

    switch (shift.status) {
      case ShiftStatus.active:
        statusColor = const Color(0xFF10B981); // Green
        statusBgColor = const Color(0xFFDCFCE7);
        statusText = "ACTIVE";
        statusTextColor = const Color(0xFF166534);
        break;
      case ShiftStatus.completed:
      case ShiftStatus.fullyCompleted:
        statusColor = const Color(0xFF8B5CF6); // Purple
        statusBgColor = const Color(0xFFF3E8FF);
        statusText = "COMPLETED";
        statusTextColor = const Color(0xFF6B21A8);
        break;
      case ShiftStatus.partiallyCompleted:
        statusColor = const Color(0xFFF59E0B); // Orange/Amber
        statusBgColor = const Color(0xFFFEF3C7);
        statusText = "PARTIAL";
        statusTextColor = const Color(0xFFB45309);
        break;
      case ShiftStatus.missed:
        statusColor = const Color(0xFFEF4444); // Red
        statusBgColor = const Color(0xFFFEE2E2);
        statusText = "MISSED";
        statusTextColor = const Color(0xFF991B1B);
        break;
      case ShiftStatus.cancelled:
        statusColor = const Color(0xFF9CA3AF); // Grey
        statusBgColor = const Color(0xFFF3F4F6);
        statusText = "CANCELLED";
        statusTextColor = const Color(0xFF374151);
        break;
      default:
        // Scheduled or default
        // Check if it's technically missed (past end time but still scheduled)
        if (shift.shiftEnd.isBefore(DateTime.now()) &&
            shift.status == ShiftStatus.scheduled) {
          statusColor = const Color(0xFFEF4444); // Red
          statusBgColor = const Color(0xFFFEE2E2);
          statusText = "MISSED";
          statusTextColor = const Color(0xFF991B1B);
        } else if (_canClockInNow) {
          statusColor = const Color(0xFF10B981); // Green - ready to clock in
          statusBgColor = const Color(0xFFDCFCE7);
          statusText = "READY";
          statusTextColor = const Color(0xFF166534);
        } else {
          statusColor = const Color(0xFF0386FF); // Blue
          statusBgColor = const Color(0xFFDBEAFE);
          statusText = "UPCOMING";
          statusTextColor = const Color(0xFF1E40AF);
        }
    }

    // Check for Clock In if Active
    if (shift.isClockedIn) {
      statusColor = const Color(0xFF10B981); // Force Green if clocked in
      statusBgColor = const Color(0xFFDCFCE7);
      statusText = "IN PROGRESS";
      statusTextColor = const Color(0xFF166534);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Column
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  startTime,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B)),
                ),
                Text(
                  endTime,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),

          // The Timeline Line
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: statusColor, width: 3),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),

          // The Card
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF64748B).withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                  border:
                      Border(left: BorderSide(color: statusColor, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            shift.displayName,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(statusText,
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusTextColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text("${shift.studentNames.length} Students",
                            style: GoogleFonts.inter(
                                fontSize: 13, color: const Color(0xFF64748B))),
                        const SizedBox(width: 16),
                        const Icon(Icons.timer_outlined,
                            size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text("${(duration / 60).toStringAsFixed(1)} hrs",
                            style: GoogleFonts.inter(
                                fontSize: 13, color: const Color(0xFF64748B))),
                      ],
                    ),
                    
                    // Clock In/Out Button Row
                    const SizedBox(height: 12),
                    _buildClockButton(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockButton(BuildContext context) {
    // If clock-in buttons are disabled (home screen), only show for active shifts
    if (!showClockInButtons && !_isActive) {
      return const SizedBox.shrink(); // Hide buttons entirely for upcoming/past shifts on home
    }
    
    if (_isActive) {
      // Show Clock Out button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onClockOut ?? onTap, // Fallback to onTap if no handler
          icon: const Icon(Icons.logout, size: 18),
          label: Text(
            "Clock Out",
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      );
    } else if (_canClockInNow) {
      // Show enabled Clock In button (green)
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onClockIn ?? onTap, // Fallback to onTap if no handler
          icon: const Icon(Icons.login, size: 18),
          label: Text(
            "Clock In Now",
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      );
    } else if (_isUpcoming) {
      // Show disabled Clock In button (grey) for upcoming shifts in shift tabs only
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null, // Disabled
          icon: const Icon(Icons.schedule, size: 18),
          label: Text(
            "Clock In (Not Yet)",
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE2E8F0),
            foregroundColor: const Color(0xFF94A3B8),
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: const Color(0xFF94A3B8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      );
    } else {
      // For completed/missed/cancelled - show View Details
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: Text(
            "View Details",
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      );
    }
  }
}
