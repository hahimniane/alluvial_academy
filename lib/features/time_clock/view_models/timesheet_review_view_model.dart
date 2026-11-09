import 'package:flutter/foundation.dart';

import '../enums/timesheet_enums.dart';
import '../controllers/timesheet_review_controller.dart';
import '../models/timesheet_entry.dart';
import '../models/timesheet_filter_state.dart';
import '../services/timesheet_bulk_actions_service.dart';

/// UI state for admin timesheet review (lists, filters, selection, focus).
class TimesheetReviewViewModel extends ChangeNotifier {
  List<TimesheetEntry> _allTimesheets = [];
  TimesheetFilterState _filterState =
      const TimesheetFilterState(statusFilter: 'Pending');
  /// Shared with [TimesheetReviewDataSource] for checkbox two-way updates.
  final Set<String> selectedTimesheetIds = {};
  bool _showBulkFlag = false;
  String? _focusedTimesheetId;
  List<String> _availableTeachers = [];
  bool _isLoading = true;

  List<TimesheetEntry> get allTimesheets => List.unmodifiable(_allTimesheets);
  List<String> get availableTeachers => List.unmodifiable(_availableTeachers);
  TimesheetFilterState get filterState => _filterState;
  String? get focusedTimesheetId => _focusedTimesheetId;
  bool get showBulkActions => _showBulkFlag;
  bool get isLoading => _isLoading;

  List<TimesheetEntry> _computeFiltered() {
    return TimesheetReviewController.applyFilters(
      all: _allTimesheets,
      filterState: _filterState,
      parseEntryDate: TimesheetReviewController.parseEntryDate,
    );
  }

  List<TimesheetEntry> get filteredTimesheets => _computeFiltered();

  /// How many timesheets each area (teachers / leaders) holds.
  Map<TimesheetGroup, int> groupCounts() {
    var leaders = 0;
    for (final e in _allTimesheets) {
      if (e.isLeadership) leaders++;
    }
    return {
      TimesheetGroup.teachers: _allTimesheets.length - leaders,
      TimesheetGroup.leaders: leaders,
    };
  }

  /// People who have timesheets in the area currently shown.
  List<String> get availableTeachersInGroup {
    final names = TimesheetReviewController.inGroup(
            _allTimesheets, _filterState.group)
        .map((e) => e.teacherName)
        .where((n) => n.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// Switch between the teachers' and the leaders' timesheets.
  void setGroup(TimesheetGroup group) {
    if (_filterState.group == group) return;
    _filterState =
        _filterState.copyWith(group: group, clearTeacherFilter: true);
    rebuildFilteredView(clearSelection: true);
  }

  Map<String, int> statusCounts() {
    final inGroup =
        TimesheetReviewController.inGroup(_allTimesheets, _filterState.group);
    final m = <String, int>{
      'All': inGroup.length,
      'Pending': 0,
      'Approved': 0,
      'Rejected': 0,
      'Draft': 0,
    };
    for (final e in inGroup) {
      switch (e.status) {
        case TimesheetStatus.pending:
          m['Pending'] = (m['Pending'] ?? 0) + 1;
          break;
        case TimesheetStatus.approved:
          m['Approved'] = (m['Approved'] ?? 0) + 1;
          break;
        case TimesheetStatus.rejected:
          m['Rejected'] = (m['Rejected'] ?? 0) + 1;
          break;
        case TimesheetStatus.draft:
          m['Draft'] = (m['Draft'] ?? 0) + 1;
          break;
      }
    }
    return m;
  }

  void setLoading(bool v) {
    if (_isLoading == v) return;
    _isLoading = v;
    notifyListeners();
  }

  void ingestProcessedTimesheets(
    List<TimesheetEntry> entries,
    List<String> teachers, {
    bool clearSelection = false,
  }) {
    _allTimesheets = entries;
    _availableTeachers = teachers;
    rebuildFilteredView(clearSelection: clearSelection);
  }

  void rebuildFilteredView({required bool clearSelection}) {
    final filtered = _computeFiltered();
    final nextSelection = clearSelection
        ? <String>{}
        : TimesheetBulkActionsService.reconcileSelectionWithVisibleRows(
            currentSelection: selectedTimesheetIds,
            visibleRows: filtered,
          );
    final focused = _resolveFocusedTimesheet(
      filtered,
      previousFocus: _focusedTimesheetId,
    );

    selectedTimesheetIds
      ..clear()
      ..addAll(nextSelection);
    _showBulkFlag = selectedTimesheetIds.isNotEmpty;
    _focusedTimesheetId = focused?.documentId;
    notifyListeners();
  }

  TimesheetEntry? _resolveFocusedTimesheet(
    List<TimesheetEntry> visibleRows, {
    String? previousFocus,
  }) {
    if (visibleRows.isEmpty) return null;
    if (previousFocus != null) {
      for (final row in visibleRows) {
        if (row.documentId == previousFocus) return row;
      }
    }
    return visibleRows.first;
  }

  TimesheetEntry? getFocusedTimesheet() {
    final id = _focusedTimesheetId;
    if (id == null) return null;
    for (final e in filteredTimesheets) {
      if (e.documentId == id) return e;
    }
    return null;
  }

  void setFilterState(TimesheetFilterState next, {required bool clearSelection}) {
    _filterState = next;
    rebuildFilteredView(clearSelection: clearSelection);
  }

  void patchFilterState(TimesheetFilterState Function(TimesheetFilterState) fn,
      {required bool clearSelection}) {
    _filterState = fn(_filterState);
    rebuildFilteredView(clearSelection: clearSelection);
  }

  void setFocusedTimesheetId(String? id) {
    if (_focusedTimesheetId == id) return;
    _focusedTimesheetId = id;
    notifyListeners();
  }

  void toggleTimesheetSelection(String timesheetId, bool isSelected) {
    if (isSelected) {
      selectedTimesheetIds.add(timesheetId);
    } else {
      selectedTimesheetIds.remove(timesheetId);
    }
    _showBulkFlag = selectedTimesheetIds.isNotEmpty;
    notifyListeners();
  }

  void clearSelection() {
    selectedTimesheetIds.clear();
    _showBulkFlag = false;
    notifyListeners();
  }

  void applyPendingTriState(Iterable<String> ids, bool? v) {
    if (v == true) {
      selectedTimesheetIds.addAll(ids);
    } else {
      for (final id in ids) {
        selectedTimesheetIds.remove(id);
      }
    }
    _showBulkFlag = selectedTimesheetIds.isNotEmpty;
    notifyListeners();
  }

  void selectAllVisiblePending(Iterable<String> ids) {
    if (ids.isEmpty) return;
    selectedTimesheetIds.addAll(ids);
    _showBulkFlag = selectedTimesheetIds.isNotEmpty;
    notifyListeners();
  }

  int pendingCountAll() {
    return _allTimesheets.where((e) => e.status == TimesheetStatus.pending).length;
  }
}
