import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../models/teaching_shift.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Calendar view of teacher shifts.
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
      setState(() {});
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
                  child: _isScheduleView
                      ? _buildSelectableScheduleList()
                      : _buildSelectableGrid(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableGrid() {
    if (widget.initialView == CalendarView.month) {
      return _buildSelectableMonthGrid();
    }

    final anchor = _startOfDay(
      _controller.displayDate ??
          widget.initialDisplayDate ??
          _getSmartInitialDate(),
    );
    final days = List<DateTime>.generate(
      3,
      (index) => anchor.add(Duration(days: index)),
    );
    final startHour = _getEarliestHour();
    final endHour = _getLatestHour();
    final hourCount = (endHour - startHour).clamp(1, 24);
    const hourHeight = 76.0;
    final gridHeight = hourCount * hourHeight;

    return ScrollNotificationObserver(
      child: SelectionArea(
        child: Column(
          children: [
            _buildGridDayHeader(days),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: gridHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Column(
                          children: List<Widget>.generate(hourCount, (index) {
                            final hour = startHour + index;
                            return SizedBox(
                              height: hourHeight,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SelectableText(
                                  _formatGridHour(hour),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final dayWidth = constraints.maxWidth / days.length;
                            final shifts = widget.shifts
                                .where((shift) => days.any(
                                      (day) => _isSameDay(
                                        shift.shiftStart.toLocal(),
                                        day,
                                      ),
                                    ))
                                .toList()
                              ..sort((a, b) =>
                                  a.shiftStart.compareTo(b.shiftStart));

                            return Stack(
                              children: [
                                Row(
                                  children: List<Widget>.generate(
                                    days.length,
                                    (_) => Expanded(
                                      child: Column(
                                        children: List<Widget>.generate(
                                          hourCount,
                                          (_) => Container(
                                            height: hourHeight,
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: Color(0xFFF1F5F9),
                                                ),
                                                bottom: BorderSide(
                                                  color: Color(0xFFF1F5F9),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ...shifts.map((shift) {
                                  final localStart = shift.shiftStart.toLocal();
                                  final localEnd = shift.shiftEnd.toLocal();
                                  final dayIndex = days.indexWhere(
                                      (day) => _isSameDay(localStart, day));
                                  final startMinutes =
                                      localStart.hour * 60 + localStart.minute;
                                  final gridStartMinutes = startHour * 60;
                                  final top =
                                      ((startMinutes - gridStartMinutes) / 60) *
                                          hourHeight;
                                  final durationMinutes =
                                      localEnd.difference(localStart).inMinutes;
                                  final height =
                                      (durationMinutes / 60) * hourHeight;

                                  return Positioned(
                                    left: dayIndex * dayWidth + 3,
                                    top: top.clamp(0.0, gridHeight - 1),
                                    width: dayWidth - 6,
                                    height: height < 46 ? 46 : height,
                                    child: _buildSelectableGridAppointment(
                                      context,
                                      shift,
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridDayHeader(List<DateTime> days) {
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 56),
          ...days.map(
            (day) => Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    DateFormat.E(locale).format(day).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    '${day.day}',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableMonthGrid() {
    final anchor = _controller.displayDate ??
        widget.initialDisplayDate ??
        _getSmartInitialDate();
    final monthStart = DateTime(anchor.year, anchor.month);
    final gridStart =
        monthStart.subtract(Duration(days: monthStart.weekday % 7));
    final nextMonth = DateTime(anchor.year, anchor.month + 1);
    final totalDays = nextMonth.difference(gridStart).inDays;
    final cellCount = totalDays <= 35 ? 35 : 42;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return ScrollNotificationObserver(
      child: SelectionArea(
        child: Column(
          children: [
            Container(
              height: 34,
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: List<Widget>.generate(7, (index) {
                  final day = gridStart.add(Duration(days: index));
                  return Expanded(
                    child: Center(
                      child: SelectableText(
                        DateFormat.E(locale).format(day).toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                itemCount: cellCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                ),
                itemBuilder: (context, index) {
                  final day = gridStart.add(Duration(days: index));
                  final dayShifts = widget.shifts
                      .where((shift) =>
                          _isSameDay(shift.shiftStart.toLocal(), day))
                      .toList()
                    ..sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
                  final inMonth = day.month == monthStart.month;

                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xFFF1F5F9)),
                        bottom: BorderSide(color: Color(0xFFF1F5F9)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          '${day.day}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: inMonth
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 2),
                        ...dayShifts.map(
                          (shift) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: _buildSelectableMonthAppointment(shift),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableGridAppointment(
    BuildContext context,
    TeachingShift shift,
  ) {
    final onSelect = widget.onSelectShift == null
        ? null
        : () => widget.onSelectShift!(shift);

    return SelectionArea(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
            decoration: BoxDecoration(
              color: _gridShiftColor(shift),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  _timeRange(shift.shiftStart, shift.shiftEnd),
                  onTap: onSelect,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  shift.uiStudentNames,
                  onTap: onSelect,
                  maxLines: 2,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (shift.effectiveSubjectDisplayName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  SelectableText(
                    shift.effectiveSubjectDisplayName,
                    onTap: onSelect,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableMonthAppointment(TeachingShift shift) {
    final onSelect = widget.onSelectShift == null
        ? null
        : () => widget.onSelectShift!(shift);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: _gridShiftColor(shift),
            borderRadius: BorderRadius.circular(5),
          ),
          child: SelectableText(
            '${_timeRange(shift.shiftStart, shift.shiftEnd)} ${shift.uiStudentNames}',
            onTap: onSelect,
            maxLines: 2,
            style: GoogleFonts.inter(
              fontSize: 9,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Color _gridShiftColor(TeachingShift shift) {
    if (shift.isClockedIn && shift.canClockOut) return const Color(0xff10B981);
    if (shift.needsAutoLogout) return const Color(0xffEF4444);
    return shift.uiStatusColor;
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  String _formatGridHour(int hour) {
    final normalizedHour = hour % 24;
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: normalizedHour, minute: 0),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _isScheduleView
        ? (l10n?.weeklyCalendar ?? 'Agenda')
        : widget.initialView == CalendarView.month
            ? MaterialLocalizations.of(context).formatMonthYear(
                _controller.displayDate ??
                    widget.initialDisplayDate ??
                    _getSmartInitialDate(),
              )
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
                    tooltip:
                        _isScheduleView ? 'Previous day' : 'Previous 3 days',
                    onPressed: () {
                      setState(() {
                        final d = _controller.displayDate ?? DateTime.now();
                        final step = _isScheduleView ? 1 : 3;
                        _controller.displayDate =
                            d.subtract(Duration(days: step));
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
              Icon(icon,
                  size: 18,
                  color: selected ? _accent : const Color(0xFF94A3B8)),
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
          backgroundColor:
              filled ? _accent.withValues(alpha: 0.1) : Colors.transparent,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
      ),
    );
  }

  Widget _buildSelectableScheduleList() {
    final shifts = List<TeachingShift>.from(widget.shifts)
      ..sort((a, b) => b.shiftStart.compareTo(a.shiftStart));

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: shifts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final shift = shifts[index];
        var statusColor = shift.uiStatusColor;
        if (shift.isClockedIn && shift.canClockOut) {
          statusColor = const Color(0xff10B981);
        } else if (shift.needsAutoLogout) {
          statusColor = const Color(0xffEF4444);
        }

        return SelectionArea(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onSelectShift == null
                  ? null
                  : () => widget.onSelectShift!(shift),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(shift.shiftStart),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      _timeRange(shift.shiftStart, shift.shiftEnd),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      shift.uiStudentNames,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (shift.effectiveSubjectDisplayName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      SelectableText(
                        shift.effectiveSubjectDisplayName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    final upcomingShifts = widget.shifts.where((shift) {
      final shiftEnd = shift.shiftEnd.toLocal();
      return shiftEnd.isAfter(now);
    }).toList();

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
