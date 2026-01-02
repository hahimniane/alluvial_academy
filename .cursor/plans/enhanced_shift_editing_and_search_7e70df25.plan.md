---
name: Enhanced Shift Editing and Search
overview: Implement comprehensive shift editing, deletion, and search functionality including recurring series management, student-based bulk operations, time-range filtering, and advanced search capabilities.
todos:
  - id: add-series-fields
    content: Add recurrenceSeriesId and seriesCreatedAt fields to TeachingShift model with Firestore serialization
    status: pending
  - id: series-detection-service
    content: Implement findRecurringSeriesId() and getRecurringSeriesShifts() methods in ShiftService
    status: pending
    dependencies:
      - add-series-fields
  - id: student-time-queries
    content: Implement getStudentShiftsByTimeRange() and findShiftsForBulkEdit() query methods
    status: pending
  - id: bulk-update-service
    content: Implement bulkUpdateShifts() method with conflict checking in ShiftService
    status: pending
  - id: update-recurring-creation
    content: Update _createRecurringShifts() to assign recurrenceSeriesId to new recurring shifts
    status: pending
    dependencies:
      - add-series-fields
  - id: enhance-search
    content: Expand _filterShifts() to search by student names, subject, and shift display name
    status: pending
  - id: filter-panel-widget
    content: Create ShiftFilterPanel widget with student, subject, date range, time range, and status filters
    status: pending
  - id: edit-options-dialog
    content: Create ShiftEditOptionsDialog showing single/series/student/time-range/edit options
    status: pending
    dependencies:
      - series-detection-service
  - id: bulk-edit-dialog
    content: Create BulkEditShiftDialog with shift selection, edit form, preview, and conflict detection
    status: pending
    dependencies:
      - bulk-update-service
  - id: student-finder-dialog
    content: Create StudentShiftFinderDialog for finding and operating on student shifts
    status: pending
    dependencies:
      - student-time-queries
  - id: time-range-widget
    content: Create TimeRangeFilterWidget for selecting time ranges (e.g., 10-11 AM)
    status: pending
  - id: integrate-edit-flow
    content: Update _editShift() in shift_management_screen.dart to show edit options dialog for recurring shifts
    status: pending
    dependencies:
      - edit-options-dialog
  - id: enhance-delete
    content: Update _deleteShift() to show options for deleting single shift vs entire series
    status: pending
    dependencies:
      - series-detection-service
  - id: shift-details-series-info
    content: Add series information and View Series button to ShiftDetailsDialog
    status: pending
    dependencies:
      - series-detection-service
---

