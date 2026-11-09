import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/time_clock/controllers/timesheet_review_controller.dart';
import 'package:alluwalacademyadmin/features/time_clock/enums/timesheet_enums.dart';
import 'package:alluwalacademyadmin/features/time_clock/models/timesheet_entry.dart';
import 'package:alluwalacademyadmin/features/time_clock/models/timesheet_filter_state.dart';

TimesheetEntry entry(String id, String? category, {List<TimesheetEntry>? children}) =>
    TimesheetEntry(
      documentId: id,
      date: 'Nov 03, 2026',
      subject: 'S',
      start: '1:00 PM',
      end: '2:00 PM',
      totalHours: '01:00',
      description: '',
      status: TimesheetStatus.pending,
      teacherId: 't-$id',
      teacherName: 'Person $id',
      teacherEmail: '',
      teacherPhone: '',
      hourlyRate: 4,
      rawDocumentData:
          children == null ? {if (category != null) 'shift_category': category} : null,
      isConsolidated: children != null,
      childEntries: children,
    );

void main() {
  final teaching = entry('a', 'teaching');
  final noCategory = entry('b', null);
  final leadership = entry('c', 'leadership');
  final meeting = entry('d', 'meeting');
  final groupedLeadership = entry('e', null, children: [entry('e1', 'leadership')]);
  final all = [teaching, noCategory, leadership, meeting, groupedLeadership];

  test('teaching and uncategorised timesheets are in the teachers area', () {
    final ids = TimesheetReviewController.inGroup(all, TimesheetGroup.teachers)
        .map((e) => e.documentId);
    expect(ids, ['a', 'b']);
  });

  test('leadership, meetings and grouped leadership sessions are in the leaders area', () {
    final ids = TimesheetReviewController.inGroup(all, TimesheetGroup.leaders)
        .map((e) => e.documentId);
    expect(ids, ['c', 'd', 'e']);
  });

  test('filters only ever show one area', () {
    final shown = TimesheetReviewController.applyFilters(
      all: all,
      filterState: const TimesheetFilterState(
          statusFilter: 'All', group: TimesheetGroup.leaders),
      parseEntryDate: TimesheetReviewController.parseEntryDate,
    );
    expect(shown.every((e) => e.isLeadership), isTrue);
    expect(shown.length, 3);
  });
}
