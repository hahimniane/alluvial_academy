import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../../core/services/timezone_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ShiftTimeDisplay extends StatefulWidget {
  final TeachingShift shift;
  final bool showDate;
  final bool showTimezone;

  const ShiftTimeDisplay({
    super.key,
    required this.shift,
    this.showDate = true,
    this.showTimezone = true,
  });

  @override
  State<ShiftTimeDisplay> createState() => _ShiftTimeDisplayState();
}

class _ShiftTimeDisplayState extends State<ShiftTimeDisplay> {
  String _userTimezone = 'UTC';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserTimezone();
  }

  Future<void> _loadUserTimezone() async {
    try {
      final timezone = await TimezoneService.getCurrentUserTimezone();
      if (mounted) {
        setState(() {
          _userTimezone = timezone;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('ShiftTimeDisplay: Error loading user timezone: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Convert shift times to user's timezone
    final startInUserTz = TimezoneUtils.convertToTimezone(
      widget.shift.shiftStart.toUtc(),
      _userTimezone,
    );
    final endInUserTz = TimezoneUtils.convertToTimezone(
      widget.shift.shiftEnd.toUtc(),
      _userTimezone,
    );

    // Check if timezone conversion changes the date
    final dateChanged = startInUserTz.day != widget.shift.shiftStart.day ||
        startInUserTz.month != widget.shift.shiftStart.month ||
        startInUserTz.year != widget.shift.shiftStart.year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDate)
          Text(
            '${startInUserTz.day}/${startInUserTz.month}/${startInUserTz.year}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff374151),
            ),
          ),
        Row(
          children: [
            Text(
              '${_formatTime(startInUserTz)} - ${_formatTime(endInUserTz)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xff6B7280),
              ),
            ),
            if (widget.showTimezone) ...[
              const SizedBox(width: 4),
              Text(
                '(${TimezoneUtils.getTimezoneAbbreviation(_userTimezone)})',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xff9CA3AF),
                ),
              ),
            ],
          ],
        ),
        if (dateChanged && widget.shift.adminTimezone != _userTimezone)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xffFEF3C7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Originally: ${widget.shift.shiftStart.day}/${widget.shift.shiftStart.month} in ${widget.shift.adminTimezone}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xff92400E),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

/// Static version for use in data grids where we can't use stateful widgets
class ShiftTimeStaticDisplay extends StatelessWidget {
  final TeachingShift shift;
  final String userTimezone;
  final bool showDate;
  final bool showTimezone;

  const ShiftTimeStaticDisplay({
    super.key,
    required this.shift,
    required this.userTimezone,
    this.showDate = true,
    this.showTimezone = true,
  });

  @override
  Widget build(BuildContext context) {
    // Convert shift times to user's timezone
    final startInUserTz = TimezoneUtils.convertToTimezone(
      shift.shiftStart.toUtc(),
      userTimezone,
    );
    final endInUserTz = TimezoneUtils.convertToTimezone(
      shift.shiftEnd.toUtc(),
      userTimezone,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDate)
          Text(
            '${startInUserTz.day}/${startInUserTz.month}/${startInUserTz.year}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xff374151),
            ),
          ),
        Row(
          children: [
            Text(
              '${_formatTime(startInUserTz)} - ${_formatTime(endInUserTz)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xff6B7280),
              ),
            ),
            if (showTimezone) ...[
              const SizedBox(width: 4),
              Text(
                '(${TimezoneUtils.getTimezoneAbbreviation(userTimezone)})',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xff9CA3AF),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
