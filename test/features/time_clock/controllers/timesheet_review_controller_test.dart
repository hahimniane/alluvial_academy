import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/time_clock/enums/timesheet_enums.dart';
import 'package:alluwalacademyadmin/features/time_clock/controllers/timesheet_review_controller.dart';
import 'package:alluwalacademyadmin/features/time_clock/models/timesheet_date_preset.dart';
import 'package:alluwalacademyadmin/features/time_clock/models/timesheet_entry.dart';
import 'package:alluwalacademyadmin/features/time_clock/models/timesheet_filter_state.dart';

TimesheetEntry _entry({
  required String id,
  required String teacher,
  required String student,
  required TimesheetStatus status,
  required String date,
  String start = '9:00 AM',
  String end = '10:00 AM',
  String totalHours = '01:00',
  String? source,
  bool formCompleted = true,
  bool isEdited = false,
  bool editApproved = false,
  String? shiftId,
  String teacherEmail = '',
  String teacherPhone = '',
}) {
  return TimesheetEntry(
    documentId: id,
    date: date,
    subject: student,
    start: start,
    end: end,
    totalHours: totalHours,
    description: 'Class',
    status: status,
    teacherId: teacher,
    teacherName: teacher,
    teacherEmail: teacherEmail,
    teacherPhone: teacherPhone,
    source: source,
    formCompleted: formCompleted,
    isEdited: isEdited,
    editApproved: editApproved,
    shiftId: shiftId,
  );
}

void main() {
  group('TimesheetReviewController', () {
    final entries = [
      _entry(
        id: '1',
        teacher: 'Alice',
        student: 'Karim',
        status: TimesheetStatus.pending,
        date: '2026-04-01',
      ),
      _entry(
        id: '2',
        teacher: 'Bob',
        student: 'Meryem',
        status: TimesheetStatus.approved,
        date: '2026-04-10',
      ),
    ];

    DateTime? parser(String rawDate) => DateTime.tryParse(rawDate);

    test('applies status + teacher + search together', () {
      final filtered = TimesheetReviewController.applyFilters(
        all: entries,
        filterState: const TimesheetFilterState(
          statusFilter: 'Pending',
          teacherFilter: 'Alice',
          searchQuery: 'kar',
        ),
        parseEntryDate: parser,
      );
      expect(filtered.length, 1);
      expect(filtered.first.documentId, '1');
    });

    test('filters by date range', () {
      final filtered = TimesheetReviewController.applyFilters(
        all: entries,
        filterState: TimesheetFilterState(
          statusFilter: 'All',
          dateRange: DateTimeRange(
            start: DateTime(2026, 4, 5),
            end: DateTime(2026, 4, 12),
          ),
        ),
        parseEntryDate: parser,
      );
      expect(filtered.length, 1);
      expect(filtered.first.documentId, '2');
    });

    test('presetDateRange thisMonth covers April 2026', () {
      final ref = DateTime(2026, 4, 17);
      final range = TimesheetReviewController.presetDateRange(
        TimesheetDatePreset.thisMonth,
        reference: ref,
      );
      expect(range.start, DateTime(2026, 4, 1));
      expect(range.end, DateTime(2026, 4, 30));
    });

    test('editedOnly keeps unapproved edits', () {
      final list = [
        _entry(
          id: 'a',
          teacher: 'T',
          student: 'S',
          status: TimesheetStatus.pending,
          date: '2026-04-01',
          isEdited: true,
          editApproved: false,
        ),
        _entry(
          id: 'b',
          teacher: 'T',
          student: 'S',
          status: TimesheetStatus.pending,
          date: '2026-04-02',
          isEdited: false,
        ),
      ];
      final filtered = TimesheetReviewController.applyFilters(
        all: list,
        filterState: const TimesheetFilterState(
          statusFilter: 'All',
          editedOnly: true,
        ),
        parseEntryDate: parser,
      );
      expect(filtered.single.documentId, 'a');
    });

    test('needsAttention filters incomplete pending clock_in without form', () {
      final list = [
        _entry(
          id: 'ok',
          teacher: 'T',
          student: 'S',
          status: TimesheetStatus.pending,
          date: '2026-04-01',
          source: 'clock_in',
          formCompleted: true,
        ),
        _entry(
          id: 'bad',
          teacher: 'T',
          student: 'S',
          status: TimesheetStatus.pending,
          date: '2026-04-02',
          source: 'clock_in',
          formCompleted: false,
        ),
      ];
      final filtered = TimesheetReviewController.applyFilters(
        all: list,
        filterState: const TimesheetFilterState(
          statusFilter: 'All',
          needsAttention: true,
        ),
        parseEntryDate: parser,
      );
      expect(filtered.single.documentId, 'bad');
    });

    test('search matches shiftId substring', () {
      final list = [
        _entry(
          id: '1',
          teacher: 'Alice',
          student: 'Karim',
          status: TimesheetStatus.pending,
          date: '2026-04-01',
          shiftId: 'shift_abc123',
        ),
      ];
      final filtered = TimesheetReviewController.applyFilters(
        all: list,
        filterState: const TimesheetFilterState(
          statusFilter: 'All',
          searchQuery: 'abc12',
        ),
        parseEntryDate: parser,
      );
      expect(filtered.length, 1);
    });

    test('search matches teacher email, normalized phone, and IDs', () {
      final list = [
        _entry(
          id: 'timesheet-2048',
          teacher: 'teacher-1042',
          teacherEmail: 'aminata@example.com',
          teacherPhone: '+224 622 123 456',
          student: 'Karim',
          status: TimesheetStatus.pending,
          date: '2026-04-01',
        ),
      ];

      for (final query in [
        'AMINATA@EXAMPLE',
        '622123456',
        'teacher-1042',
        'timesheet-2048',
      ]) {
        final filtered = TimesheetReviewController.applyFilters(
          all: list,
          filterState: TimesheetFilterState(
            statusFilter: 'All',
            searchQuery: query,
          ),
          parseEntryDate: parser,
        );
        expect(filtered, hasLength(1), reason: 'query: $query');
      }
    });
  });
}
