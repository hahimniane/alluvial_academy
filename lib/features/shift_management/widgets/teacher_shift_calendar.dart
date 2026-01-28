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

  @override
  void initState() {
    super.initState();
    _dataSource = ShiftCalendarDataSource(widget.shifts);
    _controller.view = widget.initialView;
  }

  @override
  void didUpdateWidget(covariant TeacherShiftCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shifts != widget.shifts) {
      _dataSource = ShiftCalendarDataSource(widget.shifts);
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
            view: widget.initialView,
            allowedViews: const [
              CalendarView.day,
              CalendarView.week,
              CalendarView.workWeek,
              CalendarView.timelineDay,
              CalendarView.timelineWeek,
              CalendarView.timelineWorkWeek,
            ],
            dataSource: _dataSource,
            showDatePickerButton: true,
            showTodayButton: true,
            // Increase row height and spacing for better visibility
            timeSlotViewSettings: const TimeSlotViewSettings(
              startHour: 3,
              endHour: 23,
              timeInterval: Duration(minutes: 60),
              timeIntervalHeight: 80,
              timeIntervalWidth: 60,
              timeTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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
            appointmentBuilder: _appointmentBuilder,
            onTap: (details) {
              final hasApps = details.appointments != null &&
                  details.appointments!.isNotEmpty;
              final app = hasApps ? details.appointments!.first : null;
              if (app is ShiftAppointment && widget.onSelectShift != null) {
                widget.onSelectShift!(app.shift);
              }
            },
            initialDisplayDate: widget.initialDisplayDate ?? DateTime.now(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context)!.weeklyCalendar,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: AppLocalizations.of(context)!.dashboardToday,
            onPressed: () {
              _controller.displayDate = DateTime.now();
            },
            icon: const Icon(Icons.today),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: AppLocalizations.of(context)!.previous,
            onPressed: () {
              _controller.backward!();
            },
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.commonNext,
            onPressed: () {
              _controller.forward!();
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  /// Custom appointment widget with improved readability for mobile
  Widget _appointmentBuilder(
      BuildContext context, CalendarAppointmentDetails details) {
    final data = details.appointments.first as ShiftAppointment;
    final shift = data.shift;
    final statusColor = _statusColor(shift.status, shift);

    // Constrain to fixed height - card won't expand vertically
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 62, // Reduced height to fit content
        margin: const EdgeInsets.only(top: 2, bottom: 2, left: 1, right: 1),
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        // Use ClipRRect to prevent any overflow
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Time - without icon to save space
                Text(
                  _timeRange(shift.shiftStart, shift.shiftEnd),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                ),
                const SizedBox(height: 2),
                // Shift name
                Text(
                  shift.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                ),
                const SizedBox(height: 1),
                // Subject
                Text(
                  shift.effectiveSubjectDisplayName,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(ShiftStatus status, TeachingShift shift) {
    if (shift.isClockedIn && shift.canClockOut)
      return const Color(0xff10B981); // green
    if (shift.needsAutoLogout) return const Color(0xffEF4444); // red
    switch (status) {
      case ShiftStatus.scheduled:
        return const Color(0xffF59E0B); // amber
      case ShiftStatus.active:
        return const Color(0xff10B981); // green
      case ShiftStatus.partiallyCompleted:
        return const Color(0xffF97316); // orange for partial completion
      case ShiftStatus.fullyCompleted:
        return const Color(0xff6366F1); // indigo
      case ShiftStatus.completed:
        return const Color(0xff6366F1); // indigo
      case ShiftStatus.missed:
        return const Color(0xffEF4444); // red
      case ShiftStatus.cancelled:
        return const Color(0xff9CA3AF); // gray
    }
  }

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
