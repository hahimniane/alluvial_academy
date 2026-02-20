import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Calendar view of teacher shifts using Syncfusion SfCalendar
class TeacherShiftCalendar extends StatefulWidget {
  final List<TeachingShift> shifts;
  final void Function(TeachingShift shift)? onSelectShift;
  final DateTime? initialDisplayDate;
  final CalendarView initialView;

  const TeacherShiftCalendar({
    super.key,
    required this.shifts,
    this.onSelectShift,
    this.initialDisplayDate,
    this.initialView = CalendarView.week,
  });

  @override
  State<TeacherShiftCalendar> createState() => _TeacherShiftCalendarState();
}

class _TeacherShiftCalendarState extends State<TeacherShiftCalendar> {
  late ShiftCalendarDataSource _dataSource;
  final CalendarController _controller = CalendarController();
  
  // Toggle between Grid (3-day) and List (Schedule) view
  bool _isScheduleView = false;
  
  // Track if we've already scrolled to next session to prevent re-scrolling
  bool _hasScrolledToNextSession = false;
  
  // Store the last next session time to restore position when widget rebuilds
  DateTime? _lastNextSessionTime;

  @override
  void initState() {
    super.initState();
    _dataSource = ShiftCalendarDataSource(widget.shifts);
    _controller.view = widget.initialView;
    
    // INTELLIGENT FOCUS: For week/day views, always scroll to next session
    // For other views, use the provided date or smart date
    if (widget.initialView == CalendarView.week || widget.initialView == CalendarView.day) {
      // Calculate next session time immediately
      final nextSessionTime = _getNextSessionTime();
      if (nextSessionTime != null) {
        // Store it for later restoration
        _lastNextSessionTime = nextSessionTime;
        
        // Set displayDate immediately
        _controller.displayDate = nextSessionTime;
        
        // Also set it after first frame to ensure it sticks
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _controller.displayDate = nextSessionTime;
            _hasScrolledToNextSession = true;
            
            // Set it one more time after a short delay to prevent any auto-scroll back
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _controller.displayDate = nextSessionTime;
                _hasScrolledToNextSession = true;
              }
            });
          }
        });
      } else {
        // Fallback to smart date if no upcoming sessions
        final targetDate = widget.initialDisplayDate ?? _getSmartInitialDate();
        _controller.displayDate = targetDate;
      }
    } else {
      // For month/schedule views, use normal logic
      final targetDate = widget.initialDisplayDate ?? _getSmartInitialDate();
      _controller.displayDate = targetDate;
    }
  }
  
  /// Get the exact time of the next upcoming session
  /// Returns null if no upcoming sessions
  DateTime? _getNextSessionTime() {
    final now = DateTime.now();
    final upcomingShifts = widget.shifts
        .where((shift) => shift.shiftEnd.toLocal().isAfter(now))
        .toList();
    
    if (upcomingShifts.isEmpty) return null;
    
    upcomingShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
    return upcomingShifts.first.shiftStart;
  }
  
  /// Scroll to the next upcoming session's time in week/day view
  /// Uses displayDate with time component to scroll to specific time
  /// Sets the next session at the TOP of the visible area
  void _scrollToNextSession() {
    if (!mounted || _hasScrolledToNextSession) return;
    
    final nextSessionTime = _getNextSessionTime();
    if (nextSessionTime == null) return;
    
    // Scroll to the EXACT time of the next shift so it appears at the top
    // This ensures the next session is visible at the top of the screen
    _controller.displayDate = nextSessionTime;
    _hasScrolledToNextSession = true;
  }

  @override
  void didUpdateWidget(covariant TeacherShiftCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shifts != widget.shifts) {
      _dataSource = ShiftCalendarDataSource(widget.shifts);
      // For week/day views, always scroll to next session when shifts update
      if (_controller.view == CalendarView.week || _controller.view == CalendarView.day) {
        // Reset flag to allow re-scrolling when shifts change
        _hasScrolledToNextSession = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNextSession();
        });
      }
    }
    // Update view if initialView changed
    if (oldWidget.initialView != widget.initialView) {
      _controller.view = widget.initialView;
      // Reset scroll flag when view changes
      _hasScrolledToNextSession = false;
      // For week/day views, scroll to next session
      if (widget.initialView == CalendarView.week || widget.initialView == CalendarView.day) {
        final nextSessionTime = _getNextSessionTime();
        if (nextSessionTime != null) {
          _lastNextSessionTime = nextSessionTime;
          _controller.displayDate = nextSessionTime;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _controller.displayDate = nextSessionTime;
              _hasScrolledToNextSession = true;
            }
          });
        } else {
          final targetDate = widget.initialDisplayDate ?? _getSmartInitialDate();
          _controller.displayDate = targetDate;
        }
      } else {
        // For other views, use normal logic
        final targetDate = widget.initialDisplayDate ?? _getSmartInitialDate();
        _controller.displayDate = targetDate;
      }
    }
    
    // When widget rebuilds (e.g., tab switch), restore to next session if we were there
    if (_controller.view == CalendarView.week || _controller.view == CalendarView.day) {
      if (_lastNextSessionTime != null && !_hasScrolledToNextSession) {
        // Restore to last known next session position
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final currentNextSession = _getNextSessionTime();
            if (currentNextSession != null) {
              _controller.displayDate = currentNextSession;
              _lastNextSessionTime = currentNextSession;
              _hasScrolledToNextSession = true;
            } else if (_lastNextSessionTime != null) {
              // Use stored position if still valid
              _controller.displayDate = _lastNextSessionTime!;
              _hasScrolledToNextSession = true;
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: SfCalendar(
            controller: _controller,
            // Switch between Schedule (List), Week (Grid), and Month view
            view: _isScheduleView 
                ? CalendarView.schedule 
                : (widget.initialView == CalendarView.month ? CalendarView.month : CalendarView.week),
            allowedViews: const [
              CalendarView.day,
              CalendarView.week,
              CalendarView.workWeek,
              CalendarView.month,
              CalendarView.schedule,
              CalendarView.timelineDay,
              CalendarView.timelineWeek,
              CalendarView.timelineWorkWeek,
            ],
            dataSource: _dataSource,
            showDatePickerButton: false, // Hide default date picker - we'll use custom
            showTodayButton: false, // Hide default today button - we have custom one
            // Optimize time slots - reduce empty space by showing only relevant hours
            timeSlotViewSettings: _isScheduleView
                ? TimeSlotViewSettings(
                    // Schedule view doesn't use numberOfDaysInView
                    startHour: _getEarliestHour().toDouble(),
                    endHour: _getLatestHour().toDouble(),
                    timeInterval: const Duration(minutes: 60),
                    timeIntervalHeight: 70,
                    timeIntervalWidth: 60,
                    timeFormat: 'h a',
                    dateFormat: 'd',
                    dayFormat: 'EEE',
                    timeTextStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : TimeSlotViewSettings(
                    // INTELLIGENT FIX: Show 3 days instead of 7 to triple column width
                    numberOfDaysInView: 3,
                    startHour: _getEarliestHour().toDouble(),
                    endHour: _getLatestHour().toDouble(),
                    timeInterval: const Duration(minutes: 60),
                    timeIntervalHeight: 70, // Slightly taller for better text spacing
                    timeIntervalWidth: 60,
                    timeFormat: 'h a',
                    dateFormat: 'd',
                    dayFormat: 'EEE',
                    timeTextStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            // Schedule view settings (List mode)
            scheduleViewSettings: const ScheduleViewSettings(
              appointmentItemHeight: 70,
              hideEmptyScheduleWeek: true,
              monthHeaderSettings: MonthHeaderSettings(height: 0),
            ),
            // Add cell borders and spacing
            cellBorderColor: const Color(0xffE5E7EB),
            // Make header more visible
            headerStyle: const CalendarHeaderStyle(
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xff111827),
              ),
            ),
            // Style view header (day names)
            viewHeaderStyle: const ViewHeaderStyle(
              dayTextStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xff374151),
              ),
              dateTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xff111827),
              ),
            ),
            headerHeight: 0, // Use custom header
            appointmentBuilder: _isScheduleView ? null : _appointmentBuilder,
            onTap: (details) {
              final hasApps = details.appointments != null &&
                  details.appointments!.isNotEmpty;
              final app = hasApps ? details.appointments!.first : null;
              if (app is ShiftAppointment && widget.onSelectShift != null) {
                widget.onSelectShift!(app.shift);
              }
            },
            // Don't set initialDisplayDate here - we use controller.displayDate instead
            // This prevents the calendar from auto-scrolling back to "now"
            // initialDisplayDate: widget.initialDisplayDate ?? _getSmartInitialDate(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isScheduleView ? (AppLocalizations.of(context)?.weeklyCalendar ?? 'Agenda') : '3-Day Overview',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  'Tap icons to switch view',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Toggle buttons
          IconButton(
            onPressed: () {
              setState(() {
                _isScheduleView = false;
                _controller.view = CalendarView.week;
                // When switching to week view, scroll to next session
                final nextSessionTime = _getNextSessionTime();
                if (nextSessionTime != null) {
                  _lastNextSessionTime = nextSessionTime;
                  _controller.displayDate = nextSessionTime;
                  _hasScrolledToNextSession = true;
                }
              });
            },
            icon: Icon(
              Icons.view_week,
              color: !_isScheduleView ? const Color(0xFF0386FF) : Colors.grey.shade400,
            ),
            tooltip: 'Grid View (3-Day)',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isScheduleView = true;
                _controller.view = CalendarView.schedule;
                // Schedule view doesn't need time scrolling, but keep position
              });
            },
            icon: Icon(
              Icons.view_agenda,
              color: _isScheduleView ? const Color(0xFF0386FF) : Colors.grey.shade400,
            ),
            tooltip: 'List View (Agenda)',
          ),
          const SizedBox(width: 8),
          // Previous period: move visible window back (3 days in grid, 1 day in agenda)
          IconButton(
            tooltip: _isScheduleView ? 'Previous day' : 'Previous 3 days',
            onPressed: () {
              setState(() {
                final d = _controller.displayDate ?? DateTime.now();
                final step = _isScheduleView ? 1 : 3;
                _controller.displayDate = d.subtract(Duration(days: step));
              });
            },
            icon: const Icon(Icons.arrow_back, color: Color(0xff6B7280)),
          ),
          const SizedBox(width: 4),
          // Today / Next session: jump to now or next upcoming shift
          IconButton(
            tooltip: AppLocalizations.of(context)?.dashboardToday ?? 'Today / Next session',
            onPressed: () {
              setState(() {
                final nextSessionTime = _getNextSessionTime();
                if (nextSessionTime != null) {
                  _controller.displayDate = nextSessionTime;
                  _hasScrolledToNextSession = true;
                } else {
                  _controller.displayDate = DateTime.now();
                  _hasScrolledToNextSession = false;
                }
              });
            },
            icon: const Icon(Icons.calendar_today, color: Color(0xff6B7280)),
          ),
          const SizedBox(width: 4),
          // Next period: move visible window forward (3 days in grid, 1 day in agenda)
          IconButton(
            tooltip: _isScheduleView ? 'Next day' : 'Next 3 days',
            onPressed: () {
              setState(() {
                final d = _controller.displayDate ?? DateTime.now();
                final step = _isScheduleView ? 1 : 3;
                _controller.displayDate = d.add(Duration(days: step));
              });
            },
            icon: const Icon(Icons.arrow_forward, color: Color(0xff6B7280)),
          ),
        ],
      ),
    );
  }

  /// Custom appointment widget with improved readability for mobile
  /// OPTIMIZED: Uses pre-calculated UI fields from model (no recalculation on every build)
  Widget _appointmentBuilder(
      BuildContext context, CalendarAppointmentDetails details) {
    final data = details.appointments.first as ShiftAppointment;
    final shift = data.shift;
    
    // PERFORMANCE: Use pre-calculated values instead of recalculating
    // BAD (old): final color = _statusColor(shift.status, shift);
    // BAD (old): final name = _formatStudentNames(shift);
    // GOOD (new): Read from pre-calculated cache
    // For real-time updates (e.g., clock-in), check shift.isClockedIn and override color if needed
    Color statusColor = shift.uiStatusColor;
    if (shift.isClockedIn && shift.canClockOut) {
      statusColor = const Color(0xff10B981); // Override to green if actively clocked in
    } else if (shift.needsAutoLogout) {
      statusColor = const Color(0xffEF4444); // Override to red if needs logout
    }
    
    // Use abbreviated names for month view, full names for other views
    final isMonthView = _controller.view == CalendarView.month;
    final studentNames = isMonthView 
        ? shift.uiStudentNamesAbbreviated 
        : shift.uiStudentNames;

    // INTELLIGENT FIX: Remove fixed height, let it fill the calendar slot
    // Remove time text - calendar grid already shows time on Y-axis
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Priority 1: Student Name (Bold, readable) - Pre-calculated
          // For month view, use abbreviated names; for other views, use full names
          Flexible(
            child: Text(
              studentNames,
              style: GoogleFonts.inter(
                fontSize: isMonthView ? 11 : 12, // Slightly smaller for month view
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: isMonthView ? 1 : 2, // Single line for month view
            ),
          ),
          // Priority 2: Subject (Smaller) - Only show if shift is long enough and not month view
          if (!isMonthView && details.bounds.height > 40 && shift.effectiveSubjectDisplayName.isNotEmpty)
            Text(
              shift.effectiveSubjectDisplayName,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
        ],
      ),
    );
  }

  // NOTE: _statusColor() removed - now using shift.uiStatusColor (pre-calculated)
  // For real-time status updates (clock-in during shift), check shift.isClockedIn in UI

  String _timeRange(DateTime start, DateTime end) {
    String fmt(DateTime t) {
      final h = t.hour == 0
          ? 12
          : t.hour > 12
              ? t.hour - 12
              : t.hour;
      final m = t.minute.toString().padLeft(2, '0');
      final p = t.hour >= 12 ? 'p' : 'a';
      return '$h:$m$p';
    }

    return '${fmt(start)} - ${fmt(end)}';
  }
  
  // NOTE: _formatStudentNames() removed - now using shift.uiStudentNames (pre-calculated for performance)
  
  /// INTELLIGENT FOCUS:
  /// Finds the best time to land the user on - ALWAYS shows upcoming shifts
  /// Returns a DateTime with both date AND time components for proper scrolling
  /// 1. If there is a shift happening RIGHT NOW, show now.
  /// 2. If there is a shift coming up in the future, show that start time (including following ones).
  /// 3. If all shifts are finished, show the very last shift.
  DateTime _getSmartInitialDate() {
    final now = DateTime.now();
    
    // Filter to only upcoming shifts (including today's future shifts)
    final upcomingShifts = widget.shifts
        .where((shift) {
          final shiftEnd = shift.shiftEnd.toLocal();
          return shiftEnd.isAfter(now);
        })
        .toList();
    
    // Sort by start time
    upcomingShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

    if (upcomingShifts.isEmpty) {
      // No upcoming shifts - show the most recent past shift or today
      final pastShifts = widget.shifts
          .where((shift) => shift.shiftEnd.toLocal().isBefore(now))
          .toList();
      if (pastShifts.isNotEmpty) {
        pastShifts.sort((a, b) => b.shiftStart.compareTo(a.shiftStart));
        return pastShifts.first.shiftStart;
      }
      return now;
    }

    // 1. Is there a shift currently active?
    // We want to see it immediately.
    for (var shift in upcomingShifts) {
      if (now.isAfter(shift.shiftStart) && now.isBefore(shift.shiftEnd)) {
        return now; // Return current time with full DateTime
      }
    }

    // 2. Show the NEXT upcoming shift (always show upcoming, including following ones)
    // Return the EXACT start time (not before) so it appears at the top of the screen
    // This DateTime includes both date and time for scrolling
    return upcomingShifts.first.shiftStart;
  }
  
  /// Get earliest hour from shifts to reduce empty space
  /// Gives breathing room so text isn't cut off at edges
  int _getEarliestHour() {
    if (widget.shifts.isEmpty) return 8; // Default to 8 AM
    int earliest = 23;
    for (var shift in widget.shifts) {
      if (shift.shiftStart.hour < earliest) earliest = shift.shiftStart.hour;
    }
    // Subtract 1 hour for padding, but don't go below 0
    return (earliest > 0) ? earliest - 1 : 0;
  }
  
  /// Get latest hour from shifts to reduce empty space
  /// Gives breathing room so text isn't cut off at edges
  int _getLatestHour() {
    if (widget.shifts.isEmpty) return 18; // Default to 6 PM
    int latest = 0;
    for (var shift in widget.shifts) {
      if (shift.shiftEnd.hour > latest) latest = shift.shiftEnd.hour;
    }
    // Add 1 hour for padding, but don't go above 23
    return (latest < 23) ? latest + 1 : 23;
  }
}

/// Calendar data source mapping TeachingShift to appointments
class ShiftCalendarDataSource extends CalendarDataSource {
  ShiftCalendarDataSource(List<TeachingShift> shifts) {
    appointments = shifts.map((s) => ShiftAppointment(s)).toList();
  }

  @override
  DateTime getStartTime(int index) =>
      (appointments![index] as ShiftAppointment).startTime;

  @override
  DateTime getEndTime(int index) =>
      (appointments![index] as ShiftAppointment).endTime;

  @override
  String getSubject(int index) =>
      (appointments![index] as ShiftAppointment).subject;

  @override
  Color getColor(int index) => (appointments![index] as ShiftAppointment).color;
}

class ShiftAppointment {
  final TeachingShift shift;
  ShiftAppointment(this.shift);

  DateTime get startTime => shift.shiftStart;
  DateTime get endTime => shift.shiftEnd;
  String get subject => shift.displayName;
  Color get color {
    switch (shift.status) {
      case ShiftStatus.scheduled:
        return const Color(0xffF59E0B);
      case ShiftStatus.active:
        return const Color(0xff10B981);
      case ShiftStatus.partiallyCompleted:
        return const Color(0xffF97316);
      case ShiftStatus.fullyCompleted:
        return const Color(0xff6366F1);
      case ShiftStatus.completed:
        return const Color(0xff6366F1);
      case ShiftStatus.missed:
        return const Color(0xffEF4444);
      case ShiftStatus.cancelled:
        return const Color(0xff9CA3AF);
    }
  }
}
