import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import '../models/timesheet_entry.dart';
import '../models/timesheet_filter_state.dart';
import '../models/timesheet_date_preset.dart';
import '../utils/timesheet_entry_review_flags.dart';
import '../enums/timesheet_enums.dart';

typedef TimesheetDateParser = DateTime? Function(String rawDate);

class TimesheetReviewController {
  const TimesheetReviewController._();

  /// Parses [dateString] from stored timesheet formats (admin grid / exports).
  static DateTime? parseEntryDate(String dateString) {
    final formats = [
      'MMM dd, yyyy',
      'EEE MM/dd/yyyy',
      'EEE MM/dd',
      'MM/dd/yyyy',
      'MM/dd',
      'yyyy-MM-dd',
    ];

    for (final format in formats) {
      try {
        var parsed = DateFormat(format).parse(dateString);
        if (format == 'EEE MM/dd' || format == 'MM/dd') {
          parsed = DateTime(DateTime.now().year, parsed.month, parsed.day);
        }
        return parsed;
      } catch (_) {
        continue;
      }
    }

    AppLogger.error('Could not parse date: $dateString');
    return null;
  }

  /// Parse Firestore / filter chip status string to enum.
  static TimesheetStatus parseStatusLabel(String status) =>
      _parseStatus(status);

  /// Monday-based week range for [reference] calendar day.
  static DateTimeRange presetDateRange(
    TimesheetDatePreset preset, {
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case TimesheetDatePreset.thisWeek:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return DateTimeRange(start: monday, end: sunday);
      case TimesheetDatePreset.lastWeek:
        final thisMonday = today.subtract(Duration(days: today.weekday - 1));
        final lastMonday = thisMonday.subtract(const Duration(days: 7));
        final lastSunday = lastMonday.add(const Duration(days: 6));
        return DateTimeRange(start: lastMonday, end: lastSunday);
      case TimesheetDatePreset.thisMonth:
        final start = DateTime(today.year, today.month, 1);
        final end = DateTime(today.year, today.month + 1, 0);
        return DateTimeRange(start: start, end: end);
    }
  }

  static List<TimesheetEntry> applyFilters({
    required List<TimesheetEntry> all,
    required TimesheetFilterState filterState,
    required TimesheetDateParser parseEntryDate,
  }) {
    List<TimesheetEntry> filtered = List.from(all);

    if (filterState.statusFilter != 'All') {
      final targetStatus = _parseStatus(filterState.statusFilter);
      filtered =
          filtered.where((entry) => entry.status == targetStatus).toList();
    }

    final teacherFilter = filterState.teacherFilter;
    if (teacherFilter != null && teacherFilter.isNotEmpty) {
      filtered = filtered
          .where((entry) =>
              entry.teacherName.toLowerCase() == teacherFilter.toLowerCase())
          .toList();
    }

    final dateRange = filterState.dateRange;
    if (dateRange != null) {
      filtered = filtered.where((entry) {
        final date = parseEntryDate(entry.date);
        if (date == null) return false;
        return date
                .isAfter(dateRange.start.subtract(const Duration(days: 1))) &&
            date.isBefore(dateRange.end.add(const Duration(days: 1)));
      }).toList();
    }

    final query = filterState.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((entry) {
        final shiftId = entry.shiftId?.toLowerCase() ?? '';
        return entry.teacherName.toLowerCase().contains(query) ||
            entry.subject.toLowerCase().contains(query) ||
            entry.shiftTitle?.toLowerCase().contains(query) == true ||
            entry.date.toLowerCase().contains(query) ||
            (shiftId.isNotEmpty && shiftId.contains(query));
      }).toList();
    }

    if (filterState.editedOnly) {
      filtered = filtered
          .where((e) => e.isEdited && !e.editApproved)
          .toList();
    }

    if (filterState.needsAttention) {
      filtered =
          filtered.where(TimesheetEntryReviewFlags.needsAttention).toList();
    }

    return filtered;
  }

  static TimesheetStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return TimesheetStatus.pending;
      case 'approved':
        return TimesheetStatus.approved;
      case 'rejected':
        return TimesheetStatus.rejected;
      default:
        return TimesheetStatus.draft;
    }
  }
}
