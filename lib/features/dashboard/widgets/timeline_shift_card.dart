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
  final VoidCallback? onCancelProgram;
  final bool showClockInButtons;
  final bool isProgrammed;
  final String? countdownText;

  const TimelineShiftCard({
    super.key,
    required this.shift,
    this.isLast = false,
    required this.onTap,
    this.onClockIn,
    this.onClockOut,
    this.onCancelProgram,
    this.showClockInButtons = true,
    this.isProgrammed = false,
    this.countdownText,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Snapshot time once for consistency across the entire widget build
    final now = DateTime.now();
    
    // 2. Get visual configuration (colors, text) based on current state
    final config = _getVisualConfig(now);
    
    // 3. Pre-calculate time strings
    final startTime = DateFormat('HH:mm').format(shift.shiftStart);
    final endTime = DateFormat('HH:mm').format(shift.shiftEnd);
    final durationHrs = (shift.shiftEnd.difference(shift.shiftStart).inMinutes / 60).toStringAsFixed(1);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- TIME COLUMN ---
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
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  endTime,
                  style: GoogleFonts.inter(
                    fontSize: 12, 
                    color: const Color(0xFF94A3B8), // Standardized grey
                  ),
                ),
              ],
            ),
          ),

          // --- TIMELINE LINE ---
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: config.primaryColor, width: 3),
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

          // --- MAIN CARD ---
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
                      offset: const Offset(0, 4),
                    ),
                  ],
                  // Left colored border indicating status
                  border: Border(left: BorderSide(color: config.primaryColor, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Title and Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            shift.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(config),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Info Row: Students and Duration
                    Row(
                      children: [
                        _buildInfoIcon(Icons.people_outline, "${shift.studentNames.length} Students"),
                        const SizedBox(width: 16),
                        _buildInfoIcon(Icons.timer_outlined, "$durationHrs hrs"),
                      ],
                    ),

                    // Action Buttons
                    const SizedBox(height: 12),
                    _buildActionButtons(now),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildStatusBadge(_VisualConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        config.label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: config.textColor,
        ),
      ),
    );
  }

  Widget _buildInfoIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildActionButtons(DateTime now) {
    final canClockIn = _checkCanClockIn(now);
    final canProgramClockIn = _checkCanProgramClockIn(now);
    final isActive = shift.isClockedIn;
    final isUpcoming = _checkIsUpcoming(now);

    // 1. Hidden on Home Screen (unless active or programmed)
    if (!showClockInButtons && !isActive && !isProgrammed) {
      return const SizedBox.shrink();
    }

    // 2. Active State (Clock Out)
    if (isActive) {
      return _buildButton(
        label: "Clock Out",
        icon: Icons.logout,
        color: const Color(0xFFEF4444),
        onPressed: onClockOut ?? onTap,
      );
    }
    
    // 3. PROGRAMMED State - Show countdown and cancel button
    if (isProgrammed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Countdown display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                Text(
                  countdownText ?? 'Programmed...',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Cancel button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCancelProgram,
              icon: const Icon(Icons.close, size: 16),
              label: Text(
                "Cancel",
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ],
      );
    }

    // 4. Ready State (Clock In) - Shift has started
    if (canClockIn) {
      return _buildButton(
        label: "Clock In Now",
        icon: Icons.login,
        color: const Color(0xFF10B981),
        onPressed: onClockIn ?? onTap,
      );
    }

    // 5. Programming Window (Can program clock-in) - Before shift starts
    if (canProgramClockIn) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            label: "Program Clock-In",
            icon: Icons.schedule_send,
            color: const Color(0xFF3B82F6),
            onPressed: onClockIn ?? onTap, // Will start programmed clock-in
          ),
          const SizedBox(height: 4),
          Text(
            "Will clock in at ${DateFormat('h:mm a').format(shift.shiftStart)}",
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // 6. Upcoming State (Disabled)
    if (isUpcoming) {
      return _buildButton(
        label: "Clock In (Not Yet)",
        icon: Icons.schedule,
        color: const Color(0xFF94A3B8),
        bgColor: const Color(0xFFE2E8F0),
        onPressed: null, // Disabled
      );
    }

    // 7. Default (View Details)
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

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    Color? bgColor,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor ?? color,
          foregroundColor: bgColor != null ? color : Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }

  // --- LOGIC HELPERS ---

  bool _checkCanClockIn(DateTime now) {
    // No actual early clock-in - only at exact start time or after
    return (now.isAtSameMomentAs(shift.shiftStart) || now.isAfter(shift.shiftStart)) &&
        now.isBefore(shift.shiftEnd) &&
        (shift.status == ShiftStatus.scheduled || shift.status == ShiftStatus.active);
  }

  bool _checkCanProgramClockIn(DateTime now) {
    // Can program clock-in in the 1-minute window before start
    final programmingWindowStart = shift.shiftStart.subtract(const Duration(minutes: 1));
    return (now.isAfter(programmingWindowStart) || now.isAtSameMomentAs(programmingWindowStart)) &&
        now.isBefore(shift.shiftStart) &&
        (shift.status == ShiftStatus.scheduled || shift.status == ShiftStatus.active);
  }

  bool _checkIsUpcoming(DateTime now) {
    return shift.shiftStart.isAfter(now) && shift.status == ShiftStatus.scheduled;
  }

  // --- VISUAL CONFIGURATION ---

  _VisualConfig _getVisualConfig(DateTime now) {
    // 0. Show PROGRAMMED if this shift is programmed
    if (isProgrammed) {
      return const _VisualConfig(
        primaryColor: Color(0xFF3B82F6),
        bgColor: Color(0xFFDBEAFE),
        textColor: Color(0xFF1E40AF),
        label: "PROGRAMMED",
      );
    }
    
    // 1. Force Green if actually clocked in
    if (shift.isClockedIn) {
      return const _VisualConfig(
        primaryColor: Color(0xFF10B981),
        bgColor: Color(0xFFDCFCE7),
        textColor: Color(0xFF166534),
        label: "IN PROGRESS",
      );
    }

    // 2. Handle standard statuses
    switch (shift.status) {
      case ShiftStatus.active:
        return const _VisualConfig(
          primaryColor: Color(0xFF10B981),
          bgColor: Color(0xFFDCFCE7),
          textColor: Color(0xFF166534),
          label: "ACTIVE",
        );
      case ShiftStatus.completed:
      case ShiftStatus.fullyCompleted:
        return const _VisualConfig(
          primaryColor: Color(0xFF8B5CF6),
          bgColor: Color(0xFFF3E8FF),
          textColor: Color(0xFF6B21A8),
          label: "COMPLETED",
        );
      case ShiftStatus.partiallyCompleted:
        return const _VisualConfig(
          primaryColor: Color(0xFFF59E0B),
          bgColor: Color(0xFFFEF3C7),
          textColor: Color(0xFFB45309),
          label: "PARTIAL",
        );
      case ShiftStatus.missed:
        return const _VisualConfig(
          primaryColor: Color(0xFFEF4444),
          bgColor: Color(0xFFFEE2E2),
          textColor: Color(0xFF991B1B),
          label: "MISSED",
        );
      case ShiftStatus.cancelled:
        return const _VisualConfig(
          primaryColor: Color(0xFF9CA3AF),
          bgColor: Color(0xFFF3F4F6),
          textColor: Color(0xFF374151),
          label: "CANCELLED",
        );
      default:
        // 3. Handle Scheduled dynamic states (Missed vs Ready vs Upcoming)
        if (shift.shiftEnd.isBefore(now) && shift.status == ShiftStatus.scheduled) {
          return const _VisualConfig(
            primaryColor: Color(0xFFEF4444),
            bgColor: Color(0xFFFEE2E2),
            textColor: Color(0xFF991B1B),
            label: "MISSED",
          );
        } else if (_checkCanClockIn(now)) {
          return const _VisualConfig(
            primaryColor: Color(0xFF10B981),
            bgColor: Color(0xFFDCFCE7),
            textColor: Color(0xFF166534),
            label: "READY",
          );
        } else {
          return const _VisualConfig(
            primaryColor: Color(0xFF0386FF),
            bgColor: Color(0xFFDBEAFE),
            textColor: Color(0xFF1E40AF),
            label: "UPCOMING",
          );
        }
    }
  }
}

// Simple data class to hold display styles
class _VisualConfig {
  final Color primaryColor;
  final Color bgColor;
  final Color textColor;
  final String label;

  const _VisualConfig({
    required this.primaryColor,
    required this.bgColor,
    required this.textColor,
    required this.label,
  });
}