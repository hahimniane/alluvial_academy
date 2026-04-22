import '../models/timesheet_entry.dart';

class TimesheetBulkActionsService {
  const TimesheetBulkActionsService._();

  static List<TimesheetEntry> expandToWritableEntries(
      List<TimesheetEntry> selected) {
    final writable = <TimesheetEntry>[];
    final seenDocIds = <String>{};

    void addEntry(TimesheetEntry entry) {
      final id = entry.documentId;
      if (id == null || id.isEmpty || seenDocIds.contains(id)) return;
      seenDocIds.add(id);
      writable.add(entry);
    }

    for (final entry in selected) {
      if (entry.isConsolidated && entry.childEntries != null) {
        for (final child in entry.childEntries!) {
          addEntry(child);
        }
      } else {
        addEntry(entry);
      }
    }

    return writable;
  }

  static Set<String> reconcileSelectionWithVisibleRows({
    required Set<String> currentSelection,
    required List<TimesheetEntry> visibleRows,
  }) {
    final visibleIds = visibleRows
        .map((entry) => entry.documentId)
        .whereType<String>()
        .toSet();

    return currentSelection.where(visibleIds.contains).toSet();
  }
}
