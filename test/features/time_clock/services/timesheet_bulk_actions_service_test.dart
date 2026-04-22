import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/core/enums/timesheet_enums.dart';
import 'package:alluwalacademyadmin/features/time_clock/models/timesheet_entry.dart';
import 'package:alluwalacademyadmin/features/time_clock/services/timesheet_bulk_actions_service.dart';

TimesheetEntry _entry(String id) => TimesheetEntry(
      documentId: id,
      date: 'Apr 10, 2026',
      subject: 'Math',
      start: '9:00 AM',
      end: '10:00 AM',
      totalHours: '01:00',
      description: 'Class',
      status: TimesheetStatus.pending,
      teacherId: 't1',
      teacherName: 'Teacher',
    );

void main() {
  group('TimesheetBulkActionsService', () {
    test('expands consolidated rows into writable children', () {
      final childA = _entry('a');
      final childB = _entry('b');
      final consolidated = TimesheetEntry(
        documentId: 'consolidated_shift-1',
        date: 'Apr 10, 2026',
        subject: 'Math',
        start: '9:00 AM',
        end: '11:00 AM',
        totalHours: '02:00',
        description: 'Consolidated',
        status: TimesheetStatus.pending,
        teacherId: 't1',
        teacherName: 'Teacher',
        isConsolidated: true,
        childEntries: [childA, childB],
      );

      final expanded =
          TimesheetBulkActionsService.expandToWritableEntries([consolidated]);
      expect(expanded.map((e) => e.documentId), ['a', 'b']);
    });

    test('reconcileSelectionWithVisibleRows drops hidden selections', () {
      final selection = {'a', 'missing'};
      final visible = [_entry('a'), _entry('b')];
      final reconciled =
          TimesheetBulkActionsService.reconcileSelectionWithVisibleRows(
        currentSelection: selection,
        visibleRows: visible,
      );
      expect(reconciled, {'a'});
    });
  });
}
