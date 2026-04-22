import 'package:flutter/material.dart';

class TimesheetFilterState {
  final String statusFilter;
  final String? teacherFilter;
  final DateTimeRange? dateRange;
  final String searchQuery;
  final bool editedOnly;
  final bool needsAttention;

  const TimesheetFilterState({
    required this.statusFilter,
    this.teacherFilter,
    this.dateRange,
    this.searchQuery = '',
    this.editedOnly = false,
    this.needsAttention = false,
  });

  TimesheetFilterState copyWith({
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
