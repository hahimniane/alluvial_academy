import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../../core/models/teaching_shift.dart';

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
            // Increase row height slightly to reduce vertical overflows
            timeSlotViewSettings: const TimeSlotViewSettings(
              startHour: 5,
              endHour: 23,
              timeInterval: Duration(minutes: 30),
              timeIntervalHeight: 58,
            ),
            appointmentBuilder: _appointmentBuilder,
            onTap: (details) {
              final hasApps = details.appointments != null && details.appointments!.isNotEmpty;
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
            'Weekly Calendar',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Today',
            onPressed: () {
              _controller.displayDate = DateTime.now();
            },
            icon: const Icon(Icons.today),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Previous',
            onPressed: () {
              _controller.backward!();
            },
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: () {
              _controller.forward!();
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  /// Custom appointment widget styled similar to the provided screenshot.
  Widget _appointmentBuilder(
      BuildContext context, CalendarAppointmentDetails details) {
    final data = details.appointments.first as ShiftAppointment;
    final shift = data.shift;
    final statusColor = _statusColor(shift.status, shift);

    // Determine available height and width to avoid overflow.
    final double h = details.bounds.height;
    final double w = details.bounds.width;

    // Build condensed/expanded variants based on available height and width.
    Widget content;
    if (h < 36 || w < 40) {
      // Extra-compact: only show the time range, centered.
      // Use this for very narrow appointments (width < 40) or short heights.
      content = Center(
        child: Text(
          _timeRange(shift.shiftStart, shift.shiftEnd),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: statusColor.darken(0.4),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    } else if (h < 64) {
      // Compact: time + title (single line each).
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (w >= 60) ...[
                Icon(Icons.bookmark, size: 12, color: statusColor.darken(0.2)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  _timeRange(shift.shiftStart, shift.shiftEnd),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor.darken(0.4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            shift.displayName,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      // Comfortable: time + title + coach line.
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (w >= 60) ...[
                Icon(Icons.bookmark, size: 14, color: statusColor.darken(0.2)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  _timeRange(shift.shiftStart, shift.shiftEnd),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor.darken(0.4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            shift.displayName,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Coach: ${shift.teacherName}',
            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff374151)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    // Make borders more visible and consistent.
    return Container(
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.darken(0.05),
          width: 2.0, // thicker, easier to see
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: content,
    );
  }

  Color _statusColor(ShiftStatus status, TeachingShift shift) {
    if (shift.isClockedIn && shift.canClockOut) return const Color(0xff10B981); // green
    if (shift.needsAutoLogout) return const Color(0xffEF4444); // red
    switch (status) {
      case ShiftStatus.scheduled:
        return const Color(0xffF59E0B); // amber
      case ShiftStatus.active:
        return const Color(0xff10B981); // green
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
      final h = t.hour == 0 ? 12 : t.hour > 12 ? t.hour - 12 : t.hour;
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
  DateTime getStartTime(int index) => (appointments![index] as ShiftAppointment).startTime;

  @override
  DateTime getEndTime(int index) => (appointments![index] as ShiftAppointment).endTime;

  @override
  String getSubject(int index) => (appointments![index] as ShiftAppointment).subject;

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
      case ShiftStatus.completed:
        return const Color(0xff6366F1);
      case ShiftStatus.missed:
        return const Color(0xffEF4444);
      case ShiftStatus.cancelled:
        return const Color(0xff9CA3AF);
    }
  }
}

extension _ColorShade on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }
}
