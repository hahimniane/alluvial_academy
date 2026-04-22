import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/services/shift_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Calendar view of teacher shifts using Syncfusion SfCalendar
class TeacherShiftCalendar extends StatefulWidget {
  final List<TeachingShift> shifts;
  final void Function(TeachingShift shift)? onSelectShift;
  /// Compact clock-in from agenda/grid cells (same predicate as day view / home).
  final void Function(TeachingShift shift)? onClockIn;
  final DateTime? initialDisplayDate;
  final CalendarView initialView;

  const TeacherShiftCalendar({
    super.key,
    required this.shifts,
    this.onSelectShift,
    this.onClockIn,
    this.initialDisplayDate,
    this.initialView = CalendarView.week,
  });

  @override
  State<TeacherShiftCalendar> createState() => _TeacherShiftCalendarState();
}

class _TeacherShiftCalendarState extends State<TeacherShiftCalendar> {
  late ShiftCalendarDataSource _dataSource;
  final CalendarController _controller = CalendarController();
  
  /// Week tab: list (schedule) by default. Month tab: month grid (not list).
  late bool _isScheduleView;
  
  // Track if we've already scrolled to next session to prevent re-scrolling
  bool _hasScrolledToNextSession = false;
  
  // Store the last next session time to restore position when widget rebuilds
  DateTime? _lastNextSessionTime;

  @override
  void initState() {
    super.initState();
    _isScheduleView = widget.initialView != CalendarView.month;
    _dataSource = ShiftCalendarDataSource(widget.shifts);
    _controller.view =
        _isScheduleView ? CalendarView.schedule : widget.initialView;

    final isGridWeekOrDay = !_isScheduleView &&
        (widget.initialView == CalendarView.week ||
            widget.initialView == CalendarView.day);

    if (isGridWeekOrDay) {
      final nextSessionTime = _getNextSessionTime();
      if (nextSessionTime != null) {
        _lastNextSessionTime = nextSessionTime;
        _controller.displayDate = nextSessionTime;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _controller.displayDate = nextSessionTime;
            _hasScrolledToNextSession = true;
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _controller.displayDate = nextSessionTime;
                _hasScrolledToNextSession = true;
              }
            });
          }
        });
      } else {
        _controller.displayDate =
            widget.initialDisplayDate ?? _getSmartInitialDate();
      }
    } else {
      if (widget.initialView == CalendarView.month) {
        _controller.displayDate =
            widget.initialDisplayDate ?? _getSmartInitialDate();
      } else {
        // Schedule list (week tab): anchor on latest shift; appointments are newest-first
        _controller.displayDate =
            widget.initialDisplayDate ?? _anchorDateForLatestShift();
      }
    }
  }

  /// Week anchor for schedule list — latest shift start so the most recent class is in-range.
  DateTime _anchorDateForLatestShift() {
    if (widget.shifts.isEmpty) return DateTime.now();
    var latest = widget.shifts.first;
    for (final s in widget.shifts) {
      if (s.shiftStart.isAfter(latest.shiftStart)) latest = s;
    }
    return latest.shiftStart;
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

    if (oldWidget.initialView != widget.initialView) {
      setState(() {
        _dataSource = ShiftCalendarDataSource(widget.shifts);
        _hasScrolledToNextSession = false;
        if (widget.initialView == CalendarView.month) {
          _isScheduleView = false;
          _controller.view = CalendarView.month;
          _controller.displayDate =
              widget.initialDisplayDate ?? _getSmartInitialDate();
        } else {
          _isScheduleView = true;
          _controller.view = CalendarView.schedule;
          _controller.displayDate =
              widget.initialDisplayDate ?? _anchorDateForLatestShift();
        }
      });
    } else if (oldWidget.shifts != widget.shifts) {
      setState(() {
        _dataSource = ShiftCalendarDataSource(widget.shifts);
      });
      if (_controller.view == CalendarView.week ||
          _controller.view == CalendarView.day) {
        _hasScrolledToNextSession = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNextSession();
        });
      }
    }

    if (_controller.view == CalendarView.week ||
        _controller.view == CalendarView.day) {
      if (_lastNextSessionTime != null && !_hasScrolledToNextSession) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final currentNextSession = _getNextSessionTime();
            if (currentNextSession != null) {
              _controller.displayDate = currentNextSession;
              _lastNextSessionTime = currentNextSession;
              _hasScrolledToNextSession = true;
            } else if (_lastNextSessionTime != null) {
              _controller.displayDate = _lastNextSessionTime!;
              _hasScrolledToNextSession = true;
            }
          }
        });
      }
    }
  }

  static const _calendarSurface = Color(0xFFFFFFFF);
  static const _pageBg = Color(0xFFF1F5F9);
  static const _border = Color(0xFFE2E8F0);
  static const _accent = Color(0xFF0386FF);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBg,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _calendarSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
            backgroundColor: _calendarSurface,
            todayHighlightColor: const Color(0xFFE0F2FE),
            todayTextStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
            // Optimize time slots - reduce empty space by showing only relevant hours
            timeSlotViewSettings: _isScheduleView
                ? TimeSlotViewSettings(
                    // Schedule view doesn't use numberOfDaysInView
                    startHour: _getEarliestHour().toDouble(),
                    endHour: _getLatestHour().toDouble(),
                    timeInterval: const Duration(minutes: 60),
                    timeIntervalHeight: 76,
                    timeIntervalWidth: 56,
                    timeFormat: 'h a',
                    dateFormat: 'd',
                    dayFormat: 'EEE',
                    timeTextStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  )
                : TimeSlotViewSettings(
                    // INTELLIGENT FIX: Show 3 days instead of 7 to triple column width
                    numberOfDaysInView: 3,
                    startHour: _getEarliestHour().toDouble(),
                    endHour: _getLatestHour().toDouble(),
                    timeInterval: const Duration(minutes: 60),
                    timeIntervalHeight: 76,
                    timeIntervalWidth: 56,
                    timeFormat: 'h a',
                    dateFormat: 'd',
                    dayFormat: 'EEE',
                    timeTextStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
            // Schedule view settings (List mode)
            scheduleViewSettings: const ScheduleViewSettings(
              appointmentItemHeight: 78,
              hideEmptyScheduleWeek: true,
              monthHeaderSettings: MonthHeaderSettings(height: 0),
            ),
            cellBorderColor: const Color(0xFFF1F5F9),
            headerStyle: CalendarHeaderStyle(
              textStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            viewHeaderStyle: ViewHeaderStyle(
              backgroundColor: const Color(0xFFF8FAFC),
              dayTextStyle: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: const Color(0xFF64748B),
              ),
              dateTextStyle: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            headerHeight: 0, // Use custom header
            appointmentBuilder: _appointmentBuilder,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _isScheduleView
        ? (l10n?.weeklyCalendar ?? 'Agenda')
        : (l10n?.shiftCalendarThreeDayTitle ?? '3-day schedule');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.3,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n?.shiftCalendarViewModeHint ??
                          'Grid shows three days at a time; list shows your agenda.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.35,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildViewModeToggle(context),
            ],
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _calendarSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navIconButton(
                    context: context,
                    icon: Icons.chevron_left_rounded,
                    tooltip: _isScheduleView ? 'Previous day' : 'Previous 3 days',
                    onPressed: () {
                      setState(() {
                        final d = _controller.displayDate ?? DateTime.now();
                        final step = _isScheduleView ? 1 : 3;
                        _controller.displayDate = d.subtract(Duration(days: step));
                      });
                    },
                  ),
                  _navIconButton(
                    context: context,
                    icon: Icons.event_available_rounded,
                    tooltip: l10n?.dashboardToday ?? 'Today / Next session',
                    filled: true,
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
                  ),
                  _navIconButton(
                    context: context,
                    icon: Icons.chevron_right_rounded,
                    tooltip: _isScheduleView ? 'Next day' : 'Next 3 days',
                    onPressed: () {
                      setState(() {
                        final d = _controller.displayDate ?? DateTime.now();
                        final step = _isScheduleView ? 1 : 3;
                        _controller.displayDate = d.add(Duration(days: step));
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _calendarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _viewTogglePill(
              selected: !_isScheduleView,
              icon: Icons.grid_view_rounded,
              label: l10n?.shiftCalendarViewGrid ?? 'Grid',
              onTap: () {
                setState(() {
                  _isScheduleView = false;
                  _controller.view = CalendarView.week;
                  final nextSessionTime = _getNextSessionTime();
                  if (nextSessionTime != null) {
                    _lastNextSessionTime = nextSessionTime;
                    _controller.displayDate = nextSessionTime;
                    _hasScrolledToNextSession = true;
                  }
                });
              },
            ),
            _viewTogglePill(
              selected: _isScheduleView,
              icon: Icons.view_agenda_rounded,
              label: l10n?.shiftCalendarViewList ?? 'List',
              onTap: () {
                setState(() {
                  _isScheduleView = true;
                  _controller.view = CalendarView.schedule;
                  _controller.displayDate =
                      widget.initialDisplayDate ?? _anchorDateForLatestShift();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewTogglePill({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _accent.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? _accent : const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? _accent : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIconButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: filled ? _accent : const Color(0xFF475569),
          backgroundColor: filled ? _accent.withValues(alpha: 0.1) : Colors.transparent,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
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

    final showTimeChip = !isMonthView && details.bounds.height > 46;
    final showSubject = !isMonthView &&
        details.bounds.height > 40 &&
        shift.effectiveSubjectDisplayName.isNotEmpty;

    final showClockIn = widget.onClockIn != null &&
        ShiftService.canClockInNow(shift) &&
        details.bounds.height >= 40;

    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(2, 1, 2, 1),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showTimeChip)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      _timeRange(shift.shiftStart, shift.shiftEnd),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  studentNames,
                  style: GoogleFonts.inter(
                    fontSize: isMonthView ? 11 : 12,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: isMonthView ? 1 : 2,
                ),
                if (showSubject)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      shift.effectiveSubjectDisplayName,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
          if (showClockIn)
            Tooltip(
              message: l10n?.clockInNow ?? 'Clock in',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onClockIn!(shift),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.login_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
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
    final sorted = List<TeachingShift>.from(shifts)
      ..sort((a, b) => b.shiftStart.compareTo(a.shiftStart));
    appointments = sorted.map((s) => ShiftAppointment(s)).toList();
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
