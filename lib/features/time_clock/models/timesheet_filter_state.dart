import 'package:flutter/material.dart';

/// Teaching timesheets and leadership timesheets are reviewed separately.
enum TimesheetGroup { teachers, leaders }

class TimesheetFilterState {
  final TimesheetGroup group;
  final String statusFilter;
  final String? teacherFilter;
  final DateTimeRange? dateRange;
  final String searchQuery;
  final bool editedOnly;
  final bool needsAttention;

  const TimesheetFilterState({
    this.group = TimesheetGroup.teachers,
    required this.statusFilter,
    this.teacherFilter,
    this.dateRange,
    this.searchQuery = '',
    this.editedOnly = false,
    this.needsAttention = false,
  });

  TimesheetFilterState copyWith({
    TimesheetGroup? group,
    String? statusFilter,
    String? teacherFilter,
    bool clearTeacherFilter = false,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    String? searchQuery,
    bool? editedOnly,
    bool? needsAttention,
  }) {
    return TimesheetFilterState(
      group: group ?? this.group,
      statusFilter: statusFilter ?? this.statusFilter,
      teacherFilter:
          clearTeacherFilter ? null : (teacherFilter ?? this.teacherFilter),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      searchQuery: searchQuery ?? this.searchQuery,
      editedOnly: editedOnly ?? this.editedOnly,
      needsAttention: needsAttention ?? this.needsAttention,
    );
  }
}
