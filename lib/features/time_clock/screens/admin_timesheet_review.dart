import 'package:flutter/material.dart';
import 'package:alluwalacademyadmin/features/time_clock/enums/timesheet_enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/timesheet_admin_repository.dart';
import '../models/timesheet_entry.dart';
import '../models/timesheet_date_preset.dart';
import '../controllers/timesheet_review_controller.dart';
import '../services/timesheet_bulk_actions_service.dart';
import '../services/timesheet_payment_service.dart';
import '../utils/timesheet_entry_review_flags.dart';
import '../view_models/timesheet_review_view_model.dart';
import '../widgets/timesheet_review_bulk_bar.dart';
import '../widgets/timesheet_review_data_source.dart';
import '../widgets/timesheet_review_detail_panel.dart';
import '../widgets/timesheet_review_export_dialog.dart';
import '../widgets/timesheet_review_grid.dart';
import '../widgets/timesheet_review_toolbar.dart';

import 'package:alluwalacademyadmin/core/utils/export_helpers.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/core/utils/performance_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

// Admin system timezone - all times displayed in this timezone for consistency
const String ADMIN_SYSTEM_TIMEZONE = 'UTC';

class AdminTimesheetReview extends StatefulWidget {
  const AdminTimesheetReview({super.key});

  @override
  State<AdminTimesheetReview> createState() => _AdminTimesheetReviewState();
}

/// Utility function to format times in admin system timezone (UTC)
String _formatAdminTime(DateTime? dateTime, {String format = 'h:mm a'}) {
  if (dateTime == null) return 'N/A';

  // Convert to admin system timezone (UTC)
  final adminTime = dateTime.toUtc();

  return DateFormat(format).format(adminTime);
}

/// Utility function to format edited timesheet times in admin timezone
String _formatEditedTime(TimesheetEntry timesheet, String timeType) {
  DateTime? timeValue;

  if (timeType == 'start') {
    // Try to get clock_in_timestamp first, then parse start time string
    if (timesheet.clockInTimestamp != null) {
      timeValue = timesheet.clockInTimestamp!.toDate();
    } else if (timesheet.start.isNotEmpty && timesheet.start != 'N/A') {
      try {
        // Parse the time string and combine with today's date for UTC conversion
        final timeOnly = DateFormat('h:mm a').parse(timesheet.start);
        final today = DateTime.now();
        timeValue = DateTime(
            today.year, today.month, today.day, timeOnly.hour, timeOnly.minute);
      } catch (e) {
        return timesheet.start; // Fallback to original string
      }
    }
  } else if (timeType == 'end') {
    // Try to get clock_out_timestamp first, then parse end time string
    if (timesheet.clockOutTimestamp != null) {
      timeValue = timesheet.clockOutTimestamp!.toDate();
    } else if (timesheet.end.isNotEmpty && timesheet.end != 'N/A') {
      try {
        // Parse the time string and combine with today's date for UTC conversion
        final timeOnly = DateFormat('h:mm a').parse(timesheet.end);
        final today = DateTime.now();
        timeValue = DateTime(
            today.year, today.month, today.day, timeOnly.hour, timeOnly.minute);
      } catch (e) {
        return timesheet.end; // Fallback to original string
      }
    }
  }

  if (timeValue != null) {
    return _formatAdminTime(timeValue, format: 'h:mm a') + ' (UTC)';
  }

  return timeType == 'start' ? timesheet.start : timesheet.end;
}

class _AdminTimesheetReviewState extends State<AdminTimesheetReview> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final TimesheetAdminRepository _repository;
  late final TimesheetReviewViewModel _vm;
  final TextEditingController _searchController = TextEditingController();

  // Real-time listener
  StreamSubscription<QuerySnapshot>? _timesheetListener;

  String? _initialLoadOpId;
  bool _initialLoadCompleted = false;

  String get _selectedFilter => _vm.filterState.statusFilter;
  DateTimeRange? get _selectedDateRange => _vm.filterState.dateRange;
  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
    'Draft'
  ];

  @override
  void initState() {
    super.initState();
    _repository = TimesheetAdminRepository();
    _vm = TimesheetReviewViewModel();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _vm.dispose();
    _timesheetListener?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Setup real-time listener for timesheet changes
  void _setupRealtimeListener() {
    _vm.setLoading(true);
    setState(() {});

    final initialOpId =
        PerformanceLogger.newOperationId('AdminTimesheetReview._initialLoad');
    _initialLoadOpId = initialOpId;
    _initialLoadCompleted = false;
    PerformanceLogger.startTimer(initialOpId);

    // Listen to real-time changes in timesheet_entries collection
    // Removed orderBy to avoid Firestore internal assertion errors
    // We'll sort client-side instead
    _timesheetListener = _buildTimesheetQuery().snapshots().listen((snapshot) async {
      final summary = await _processTimesheetSnapshot(snapshot);

      if (!_initialLoadCompleted && _initialLoadOpId == initialOpId) {
        _initialLoadCompleted = true;
        PerformanceLogger.endTimer(initialOpId, metadata: summary);
      }
    }, onError: (error) {
      AppLogger.error('Error in timesheet listener: $error');
      if (!_initialLoadCompleted &&
          _initialLoadOpId != null &&
          _initialLoadOpId == initialOpId) {
        _initialLoadCompleted = true;
        PerformanceLogger.endTimer(initialOpId, metadata: {
          'error': error.toString(),
        });
      }
      if (mounted) {
        _vm.setLoading(false);
        setState(() {});
      }
    });
  }

  Query<Map<String, dynamic>> _buildTimesheetQuery() {
    return _repository.timesheetEntriesQuery(_vm.filterState.statusFilter);
  }

  void _restartRealtimeListener() {
    _timesheetListener?.cancel();
    _setupRealtimeListener();
  }

  /// Process timesheet snapshot and update UI in real-time
  Future<Map<String, dynamic>> _processTimesheetSnapshot(
      QuerySnapshot snapshot) async {
    try {
      final result = await _repository.processTimesheetSnapshot(snapshot);
      if (!mounted) return result.summary;
      _vm.ingestProcessedTimesheets(
        result.timesheets,
        result.teachers,
        clearSelection: false,
      );
      _vm.setLoading(false);
      return result.summary;
    } catch (e) {
      AppLogger.error('Error processing timesheet snapshot: $e');
      final summary = <String, dynamic>{'error': e.toString()};
      if (mounted) {
        _vm.setLoading(false);
        setState(() {});
      }
      return summary;
    }
  }

  void _applyFilter(String filter) {
    final previousStatus = _selectedFilter;
    _vm.patchFilterState((f) => f.copyWith(statusFilter: filter),
        clearSelection: true);
    if (previousStatus != filter) {
      _restartRealtimeListener();
    }
  }

  void _updateSearchQuery(String query) {
    _vm.patchFilterState((f) => f.copyWith(searchQuery: query),
        clearSelection: false);
  }

  void _onTimesheetSelectionChanged(String timesheetId, bool isSelected) {
    _vm.toggleTimesheetSelection(timesheetId, isSelected);
  }

  List<TimesheetEntry> _selectedWritableTimesheets() {
    final selectedRows = _vm.filteredTimesheets
        .where((entry) => _vm.selectedTimesheetIds.contains(entry.documentId))
        .toList();
    return TimesheetBulkActionsService.expandToWritableEntries(selectedRows);
  }

  double _selectedPaymentTotal() {
    return _selectedWritableTimesheets()
        .fold(0.0, (sum, entry) => sum + _calculatePayment(entry));
  }

  Future<void> _bulkApproveTimesheets() async {
    final selectedRows = _vm.filteredTimesheets
        .where((t) => _vm.selectedTimesheetIds.contains(t.documentId))
        .toList();
    final selectedTimesheets =
        TimesheetBulkActionsService.expandToWritableEntries(selectedRows);

    if (selectedTimesheets.isEmpty) return;

    // Check if any timesheets are edited but not approved
    final editedTimesheets =
        selectedTimesheets.where((t) => t.isEdited && !t.editApproved).toList();

    if (editedTimesheets.isNotEmpty) {
      // Show warning about edited timesheets
      final shouldContinue = await _showBulkEditWarningDialog(editedTimesheets);
      if (!shouldContinue) return;
    }

    final confirmed = await _showBulkApprovalDialog(selectedTimesheets);
    if (!confirmed) return;

    try {
      final batch = _repository.newWriteBatch();
      double totalPayment = 0.0;

      for (var timesheet in selectedTimesheets) {
        // IMPORTANT: Recalculate payment based on current times (which may be edited)
        // Payment = edited hours × hourly rate
        final payment = _calculatePayment(timesheet);
        totalPayment += payment;

        // Check if timesheet is complete (has both clock-in and clock-out)
        final isComplete = _isTimesheetComplete(timesheet);

        // Determine status: approved if complete, otherwise keep as pending
        final newStatus = isComplete ? 'approved' : 'pending';

        final updateData = <String, dynamic>{
          'status': newStatus,
          'approved_at': isComplete ? FieldValue.serverTimestamp() : null,
          'payment_amount': payment, // Recalculated payment
          'updated_at': FieldValue.serverTimestamp(),
        };

        // If edited, also approve the edit and clear edit tracking
        if (timesheet.isEdited && !timesheet.editApproved) {
          updateData['edit_approved'] = true;
          updateData['edit_approved_at'] = FieldValue.serverTimestamp();
          updateData['is_edited'] = false;
          updateData['original_data'] = FieldValue.delete();
          updateData['employee_notes'] = FieldValue.delete();
        }

        batch.update(
          _repository.timesheetDoc(timesheet.documentId!),
          updateData,
        );
      }

      await batch.commit();

      _showSuccessSnackBar(
          'Approved ${selectedTimesheets.length} timesheets. Total payment: \$${totalPayment.toStringAsFixed(2)}');

      _vm.clearSelection();

      // Real-time listener will automatically update the UI
    } catch (e) {
      _showErrorSnackBar('Error approving timesheets: $e');
    }
  }

  Future<void> _bulkRejectTimesheets() async {
    final selectedRows = _vm.filteredTimesheets
        .where((t) => _vm.selectedTimesheetIds.contains(t.documentId))
        .toList();
    final selectedTimesheets =
        TimesheetBulkActionsService.expandToWritableEntries(selectedRows);

    if (selectedTimesheets.isEmpty) return;

    final reason = await _showBulkRejectionDialog(selectedTimesheets.length);
    if (reason == null) return;

    try {
      var batch = _repository.newWriteBatch();
      var ops = 0;

      for (var timesheet in selectedTimesheets) {
        final ref = _repository.timesheetDoc(timesheet.documentId!);
        final snap = await ref.get();
        final data = snap.data();
        if (data != null &&
            data['is_edited'] == true &&
            data['original_data'] != null) {
          batch.update(
            ref,
            TimesheetAdminRepository.buildEditRejectionUpdate(data, reason),
          );
        } else {
          batch.update(ref, {
            'status': 'rejected',
            'rejected_at': FieldValue.serverTimestamp(),
            'rejection_reason': reason,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
        ops++;
        if (ops >= 400) {
          await batch.commit();
          batch = _repository.newWriteBatch();
          ops = 0;
        }
      }

      if (ops > 0) {
        await batch.commit();
      }

      _showSuccessSnackBar(
          'Rejected ${selectedTimesheets.length} timesheets with feedback');

      _vm.clearSelection();

      // Real-time listener will automatically update the UI
    } catch (e) {
      _showErrorSnackBar('Error rejecting timesheets: $e');
    }
  }

  /// Show warning dialog when bulk approving edited timesheets
  Future<bool> _showBulkEditWarningDialog(
      List<TimesheetEntry> editedTimesheets) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final contentWidth = math.min(
              MediaQuery.sizeOf(context).width - 48,
              520.0,
            );
            return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.editedTimesheetsDetected,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: contentWidth,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${editedTimesheets.length} of the selected timesheets were edited and require approval:',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final ts in editedTimesheets)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.edit,
                                  size: 18, color: Color(0xFFF59E0B)),
                              title: Text(
                                ts.teacherName,
                                style: GoogleFonts.inter(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${ts.date} - ${ts.totalHours}',
                                style: GoogleFonts.inter(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFF1E40AF), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!
                              .byContinuingYouWillApproveBoth,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  AppLocalizations.of(context)!.commonCancel,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  AppLocalizations.of(context)!.approveAll,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
          },
        ) ??
        false;
  }

  Future<bool> _showBulkApprovalDialog(List<TimesheetEntry> timesheets) async {
    final totalPayment = timesheets.fold<double>(
        0.0, (sum, timesheet) => sum + _calculatePayment(timesheet));

    return await showDialog<bool>(
          context: context,
          builder: (context) {
            final contentWidth = math.min(
              MediaQuery.sizeOf(context).width - 48,
              520.0,
            );
            return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.bulkApproveTimesheets,
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            content: SizedBox(
              width: contentWidth,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'You are about to approve ${timesheets.length} timesheets:',
                    style: GoogleFonts.inter(fontSize: 14)),
                const SizedBox(height: 16),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final timesheet in timesheets)
                            ListTile(
                              dense: true,
                              title: Text(timesheet.teacherName,
                                  style: GoogleFonts.inter(fontSize: 12)),
                              subtitle: Text(
                                  '${timesheet.date} - ${timesheet.totalHours}',
                                  style: GoogleFonts.inter(fontSize: 11)),
                              trailing: Text(
                                  '\$${_calculatePayment(timesheet).toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Total Payment: \$${totalPayment.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.commonCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(AppLocalizations.of(context)!.approveAll),
              ),
            ],
          );
          },
        ) ??
        false;
  }

  Future<String?> _showBulkRejectionDialog(int count) async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cancel, color: Colors.red, size: 20),
            ),
            SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.bulkRejectTimesheets,
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.youAreAboutToRejectCount(count),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.enterReasonForRejection,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.rejectAll),
          ),
        ],
      ),
    );
  }

  double _calculatePayment(TimesheetEntry timesheet) {
    return TimesheetPaymentService.calculatePayment(timesheet);
  }

  /// Check if a timesheet is complete (has both clock-in and clock-out times)
  bool _isTimesheetComplete(TimesheetEntry timesheet) {
    return TimesheetEntryReviewFlags.isTimesheetComplete(timesheet);
  }

  Future<void> _approveTimesheet(TimesheetEntry timesheet) async {
    // Handle consolidated entries
    if (timesheet.isConsolidated && timesheet.childEntries != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.approveConsolidatedShift),
          content: Text(
              'This will approve all ${timesheet.childEntries!.length} entries for this shift.\n\nTotal Payment: \$${timesheet.paymentAmount?.toStringAsFixed(2) ?? "0.00"}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.commonCancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: Text(AppLocalizations.of(context)!.approveAll),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        for (final child in timesheet.childEntries!) {
          await _approveTimesheet(child);
        }
      }
      return;
    }

    // Check if timesheet was edited but edit not yet approved
    if (timesheet.isEdited && !timesheet.editApproved) {
      // Show dialog with original data comparison
      final shouldApprove = await _showEditApprovalDialog(timesheet);
      if (shouldApprove != true) return; // Handle null or false

      // IMPORTANT: Recalculate payment based on edited times
      // The timesheet object should already have updated totalHours from the real-time listener
      // after the edit was saved. Payment = edited hours × hourly rate
      final payment = _calculatePayment(timesheet);
      final confirmed = await _showApprovalDialog(timesheet, payment);
      if (!confirmed) return;

      try {
        // Check if timesheet is complete (has both clock-in and clock-out)
        final isComplete = _isTimesheetComplete(timesheet);

        // Determine status: approved if complete, otherwise keep as pending
        final newStatus = isComplete ? 'approved' : 'pending';

        await _repository.updateTimesheet(timesheet.documentId!, {
          'status': newStatus,
          'approved_at': isComplete ? FieldValue.serverTimestamp() : null,
          'payment_amount':
              payment, // Recalculated payment based on edited times
          'updated_at': FieldValue.serverTimestamp(),
          'edit_approved': true, // Mark edit as approved
          'edit_approved_at': FieldValue.serverTimestamp(),
          // Clear edit tracking fields after approval
          'is_edited': false,
          'original_data': FieldValue.delete(),
          'employee_notes':
              FieldValue.delete(), // Clear employee notes after approval
        });

        if (isComplete) {
          _showSuccessSnackBar(
              'Timesheet and edit approved successfully! Payment: \$${payment.toStringAsFixed(2)}');
        } else {
          _showSuccessSnackBar(
              'Edit approved. Timesheet remains pending (incomplete). Payment: \$${payment.toStringAsFixed(2)}');
        }
      } catch (e) {
        _showErrorSnackBar('Error approving timesheet: $e');
      }
    } else {
      // Normal approval flow (not edited or edit already approved)
      final payment = _calculatePayment(timesheet);
      final confirmed = await _showApprovalDialog(timesheet, payment);
      if (!confirmed) return;

      try {
        await _repository.updateTimesheet(timesheet.documentId!, {
          'status': 'approved',
          'approved_at': FieldValue.serverTimestamp(),
          'payment_amount': payment,
          'updated_at': FieldValue.serverTimestamp(),
        });

        _showSuccessSnackBar(
            'Timesheet approved successfully! Payment: \$${payment.toStringAsFixed(2)}');
      } catch (e) {
        _showErrorSnackBar('Error approving timesheet: $e');
      }
    }
  }

  Future<void> _rejectTimesheet(TimesheetEntry timesheet) async {
    // Handle consolidated entries
    if (timesheet.isConsolidated && timesheet.childEntries != null) {
      final reason = await _showRejectionDialog();
      if (reason == null) return;

      for (final child in timesheet.childEntries!) {
        await _rejectTimesheetWithReason(child, reason);
      }
      return;
    }

    // If edited but not approved, we can reject the edit (revert) or reject the timesheet
    if (timesheet.isEdited && !timesheet.editApproved) {
      final action = await _showEditRejectionDialog(timesheet);
      if (action == null) return;

      if (action == 'revert') {
        // Revert to original data
        await _revertTimesheetEdit(timesheet);
      } else {
        // Reject the timesheet
        final reason = await _showRejectionDialog();
        if (reason == null) return;
        await _rejectTimesheetWithReason(timesheet, reason);
      }
    } else {
      // Normal rejection flow
      final reason = await _showRejectionDialog();
      if (reason == null) return;
      await _rejectTimesheetWithReason(timesheet, reason);
    }
  }

  Future<void> _revertTimesheetEdit(TimesheetEntry timesheet) async {
    if (timesheet.originalData == null) {
      _showErrorSnackBar('Cannot revert: Original data not found');
      return;
    }

    try {
      final original = timesheet.originalData!;

      final revertData = <String, dynamic>{
        'clock_in_timestamp': original['clock_in_timestamp'],
        'clock_out_timestamp': original['clock_out_timestamp'],
        'start_time': original['start_time'],
        'end_time': original['end_time'],
        'total_hours': original['total_hours'],
        'is_edited': false,
        'edit_approved': false,
        'original_data':
            FieldValue.delete(), // Remove original data after revert
        'edit_reverted_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Restore pay fields if the original snapshot captured them
      if (original.containsKey('payment_amount') &&
          original['payment_amount'] != null) {
        revertData['payment_amount'] = original['payment_amount'];
      }
      if (original.containsKey('total_pay') && original['total_pay'] != null) {
        revertData['total_pay'] = original['total_pay'];
      }
      if (original.containsKey('effective_end_timestamp')) {
        revertData['effective_end_timestamp'] = original['effective_end_timestamp'];
      }

      await _repository.updateTimesheet(timesheet.documentId!, revertData);

      _showSuccessSnackBar('Timesheet reverted to original data');
    } catch (e) {
      _showErrorSnackBar('Error reverting timesheet: $e');
    }
  }

  Future<void> _rejectTimesheetWithReason(
      TimesheetEntry timesheet, String reason) async {
    try {
      final ref = _repository.timesheetDoc(timesheet.documentId!);
      final snap = await ref.get();
      final data = snap.data();
      if (data != null &&
          data['is_edited'] == true &&
          data['original_data'] != null) {
        await ref.update(
            TimesheetAdminRepository.buildEditRejectionUpdate(data, reason));
        if (mounted) {
          _showSuccessSnackBar(
              'Edit declined — timesheet restored to values before the teacher edit.');
        }
        return;
      }

      await ref.update({
        'status': 'rejected',
        'rejected_at': FieldValue.serverTimestamp(),
        'rejection_reason': reason,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccessSnackBar('Timesheet rejected with feedback sent to user');
      }
    } catch (e) {
      _showErrorSnackBar('Error rejecting timesheet: $e');
    }
  }

  /// Show dialog when approving an edited timesheet (shows original vs edited data)
  /// Returns true if edit should be approved, false if rejected, null if cancelled
  Future<bool?> _showEditApprovalDialog(TimesheetEntry timesheet) async {
    if (timesheet.originalData == null) {
      // If no original data, proceed with normal approval
      return true;
    }

    final original = timesheet.originalData!;

    // Parse original times
    String originalStart = original['start_time'] ?? 'N/A';
    String originalEnd = original['end_time'] ?? 'N/A';
    String originalHours = original['total_hours'] ?? 'N/A';

    // Get original timestamps for better formatting (in admin system time)
    if (original['clock_in_timestamp'] != null) {
      final originalClockIn =
          (original['clock_in_timestamp'] as Timestamp).toDate();
      originalStart =
          _formatAdminTime(originalClockIn, format: 'h:mm a') + ' (UTC)';
    }
    if (original['clock_out_timestamp'] != null) {
      final originalClockOut =
          (original['clock_out_timestamp'] as Timestamp).toDate();
      originalEnd =
          _formatAdminTime(originalClockOut, format: 'h:mm a') + ' (UTC)';
    }

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit,
                      color: Color(0xFFF59E0B), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.timesheetWasEdited,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Employee Notes (reason for edit)
                  if (timesheet.employeeNotes != null &&
                      timesheet.employeeNotes!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.note_outlined,
                                  color: Color(0xFFD97706), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.reasonForEdit,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            timesheet.employeeNotes!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Comparison Table
                  Text(
                    AppLocalizations.of(context)!.dataComparison,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.field,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.original,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.edited,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Clock In
                        timesheetAdminComparisonRow('Clock In (UTC)', originalStart,
                            _formatEditedTime(timesheet, 'start')),
                        // Clock Out
                        timesheetAdminComparisonRow('Clock Out (UTC)', originalEnd,
                            _formatEditedTime(timesheet, 'end')),
                        // Total Hours
                        timesheetAdminComparisonRow(
                            'Total Hours', originalHours, timesheet.totalHours),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Color(0xFF1E40AF), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!
                                .byApprovingYouAcceptTheEdited,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  AppLocalizations.of(context)!.commonCancel,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  AppLocalizations.of(context)!.approveEditContinue,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show dialog when rejecting an edited timesheet (choose to revert or reject)
  Future<String?> _showEditRejectionDialog(TimesheetEntry timesheet) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.rejectEditedTimesheet,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.thisTimesheetWasEditedChooseAn,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.undo, color: Color(0xFF0386FF)),
              title: Text(
                AppLocalizations.of(context)!.revertToOriginal,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(AppLocalizations.of(context)!
                  .restoreOriginalTimesAndKeepTimesheet),
              onTap: () => Navigator.of(context).pop('revert'),
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.red),
              title: Text(
                AppLocalizations.of(context)!.rejectTimesheet,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(AppLocalizations.of(context)!
                  .rejectTheEntireTimesheetRequiresReason),
              onTap: () => Navigator.of(context).pop('reject'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showApprovalDialog(
      TimesheetEntry timesheet, double payment) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 20),
                ),
                SizedBox(width: 12),
                Text(AppLocalizations.of(context)!.approveTimesheet,
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Teacher:', timesheet.teacherName),
                _buildInfoRow('Date:', timesheet.date),
                _buildInfoRow('Student:', timesheet.subject),
                _buildInfoRow('Hours:', timesheet.totalHours),
                _buildInfoRow('Rate:',
                    '\$${timesheet.hourlyRate.toStringAsFixed(2)}/hour'),
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Payment: \$${payment.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.commonCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child:
                    Text(AppLocalizations.of(context)!.approveCalculatePayment),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _showRejectionDialog() async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cancel, color: Colors.red, size: 20),
            ),
            SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.rejectTimesheet,
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.pleaseProvideAReasonForRejection,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.enterReasonForRejection,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.reject),
          ),
        ],
      ),
    );
  }

  void _viewTimesheetDetails(TimesheetEntry timesheet) {
    if (timesheet.isConsolidated && timesheet.childEntries != null) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(
                            AppLocalizations.of(context)!
                                .shiftDetailsConsolidated,
                            style: GoogleFonts.inter(
                                fontSize: 20, fontWeight: FontWeight.bold))),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!
                    .timesheetTotalEntries(timesheet.childEntries!.length)),
                Text(AppLocalizations.of(context)!
                    .timesheetTotalHours(timesheet.totalHours.toString())),
                Text(AppLocalizations.of(context)!.timesheetTotalPayment(
                    timesheet.paymentAmount?.toStringAsFixed(2) ?? '0.00')),
                const SizedBox(height: 16),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    itemCount: timesheet.childEntries!.length,
                    separatorBuilder: (c, i) => const Divider(),
                    itemBuilder: (context, index) {
                      final child = timesheet.childEntries![index];
                      return ListTile(
                        title: Text(AppLocalizations.of(context)!
                            .timesheetTimeRange(child.start, child.end)),
                        subtitle: Text(AppLocalizations.of(context)!
                            .timesheetEntrySummary(
                                child.totalHours.toString(),
                                child.paymentAmount?.toStringAsFixed(2) ??
                                    '0.00')),
                        trailing: _buildStatusChip(child.status),
                        onTap: () {
                          // Allow drilling down into individual entry
                          Navigator.pop(context); // Close consolidated view
                          _viewTimesheetDetails(child); // Open individual view
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    _openDetailDrawer(timesheet);
  }

  void _openDetailDrawer(TimesheetEntry timesheet) {
    _vm.setFocusedTimesheetId(timesheet.documentId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scaffoldKey.currentState?.openEndDrawer();
      }
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey.shade600)),
          ),
          Text(value,
              style:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(TimesheetStatus status) {
    Color color;
    String text;

    switch (status) {
      case TimesheetStatus.approved:
        color = Colors.green;
        text = 'Approved';
        break;
      case TimesheetStatus.rejected:
        color = Colors.red;
        text = 'Rejected';
        break;
      case TimesheetStatus.pending:
        color = Colors.orange;
        text = 'Pending';
        break;
      case TimesheetStatus.draft:
        color = Colors.grey;
        text = 'Draft';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _exportFileBaseName() {
    var fileName = 'timesheet_export';
    if (_selectedDateRange != null) {
      fileName +=
          '_${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)}_to_${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}';
    } else {
      fileName += '_${_selectedFilter.toLowerCase()}';
    }
    fileName += '_${DateTime.now().toString().split(' ')[0]}';
    return fileName;
  }

  void _openExportDialog() {
    if (_vm.filteredTimesheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noDataToExport)),
      );
      return;
    }
    AppLogger.debug(
        'Export dialog: visible rows=${_vm.filteredTimesheets.length}');
    showTimesheetReviewExportDialog(
      context: context,
      visibleEntries: _vm.filteredTimesheets,
      parseEntryDate: TimesheetReviewController.parseEntryDate,
      baseFileName: _exportFileBaseName(),
    );
  }

  List<String> _visiblePendingRowIds() {
    return _vm.filteredTimesheets
        .where((e) =>
            e.status == TimesheetStatus.pending &&
            e.documentId != null &&
            e.documentId!.isNotEmpty)
        .map((e) => e.documentId!)
        .toList();
  }

  bool? _headerPendingTriState() {
    final ids = _visiblePendingRowIds();
    if (ids.isEmpty) return false;
    final n = ids.where(_vm.selectedTimesheetIds.contains).length;
    if (n == 0) return false;
    if (n == ids.length) return true;
    return null;
  }

  void _toggleSelectAllPendingTri(bool? v) {
    final ids = _visiblePendingRowIds();
    _vm.applyPendingTriState(ids, v);
  }

  void _selectAllPendingVisible() {
    final ids = _visiblePendingRowIds();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noTimesheetsFound),
        ),
      );
      return;
    }
    _vm.selectAllVisiblePending(ids);
  }

  String _dateRangeSummary() {
    final r = _selectedDateRange;
    if (r == null) return '';
    return '${DateFormat('MMM dd').format(r.start)} – ${DateFormat('MMM dd, yyyy').format(r.end)}';
  }

  void _applyDatePreset(TimesheetDatePreset preset) {
    _vm.patchFilterState(
      (f) => f.copyWith(
        dateRange: TimesheetReviewController.presetDateRange(preset),
      ),
      clearSelection: false,
    );
    _applyFilter(_selectedFilter);
  }

  void _clearDateRangeFilter() {
    _vm.patchFilterState(
      (f) => f.copyWith(clearDateRange: true),
      clearSelection: false,
    );
    _applyFilter(_selectedFilter);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.dateFilterCleared),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Removed _exportConnectTeamStyle - legacy export path retained below for reference.

  // ignore: unused_element
  void _old_exportConnectTeamStyle() {
    // ConnectTeam-style headers (enhanced with more columns)
    final headers = [
      "First name",
      "Last name",
      "Scheduled shift title",
      "Type",
      "Sub-job",
      "Start Date",
      "Scheduled In", // Scheduled start time
      "In",
      "Start - device",
      "End Date",
      "Scheduled Out", // Scheduled end time
      "Out",
      "End - device",
      "Employee notes",
      "Manager notes",
      "Shift hours",
      "Scheduled hours", // Scheduled duration
      "Form completed", // NEW: Whether readiness form was filled
      "Reported hours", // NEW: Hours reported in form
      "Hours difference", // NEW: Actual vs reported from form
      "Daily difference", // Actual vs scheduled for day
      "Daily totals",
      "Weekly totals",
      "Total scheduled", // Total scheduled hours for week
      "Total difference", // Total actual vs scheduled
      "Total paid hours",
      "Total overtime", // Hours over 8/day
    ];

    List<List<dynamic>> rows = [];

    // Group by employee and date for calculations
    final Map<String, Map<String, double>> dailyTotals =
        {}; // employee|date -> hours
    final Map<String, Map<String, double>> weeklyTotals =
        {}; // employee|week -> hours
    final Map<String, Map<String, double>> dailyScheduled =
        {}; // employee|date -> scheduled hours
    final Map<String, Map<String, double>> weeklyScheduled =
        {}; // employee|week -> scheduled hours
    final Map<String, Map<String, double>> dailyOvertime =
        {}; // employee|date -> overtime hours

    // Helper to get first/last name from full name
    List<String> _splitName(String fullName) {
      final parts = fullName.trim().split(' ');
      if (parts.isEmpty) return ['', ''];
      if (parts.length == 1) return [parts[0], ''];
      return [parts[0], parts.sublist(1).join(' ')];
    }

    // Helper to parse hours string to decimal
    double _parseHours(String timeString) {
      try {
        if (timeString.isEmpty) return 0.0;
        final parts = timeString.split(':');
        if (parts.length != 2) return 0.0;
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return hours + (minutes / 60.0);
      } catch (e) {
        return 0.0;
      }
    }

    // Helper to get week start (Monday)
    DateTime _getWeekStart(DateTime date) {
      return date.subtract(Duration(days: date.weekday - 1));
    }

    // Process each timesheet entry
    for (var entry in _vm.filteredTimesheets) {
      final names = _splitName(entry.teacherName);
      final firstName = names[0];
      final lastName = names[1];

      // Parse dates
      DateTime? startDate;
      DateTime? endDate;
      try {
        startDate = TimesheetReviewController.parseEntryDate(entry.date);
        endDate = startDate; // Same day for start/end
      } catch (e) {
        startDate = DateTime.now();
        endDate = DateTime.now();
      }

      // Parse times
      String inTime = entry.start;
      String outTime = entry.end;

      // Get device info
      final clockInPlatform = entry.clockInPlatform ?? 'unknown';
      final clockOutPlatform = entry.clockOutPlatform ?? 'unknown';

      // Get shift info
      final shiftTitle = entry.shiftTitle ?? entry.subject;
      final shiftType = entry.shiftType ?? '';
      final subJob = entry.subject; // Student name as sub-job

      // Notes
      final employeeNotes = entry.employeeNotes ?? '';
      final managerNotes = entry.managerNotes ?? '';

      // Hours
      final shiftHours = _parseHours(entry.totalHours);

      // Scheduled times - try multiple sources
      String scheduledIn = '--';
      String scheduledOut = '--';
      double scheduledHours = 0.0;

      // First, try to get from timesheet entry fields (most reliable)
      if (entry.scheduledStart != null) {
        scheduledIn = DateFormat('HH:mm').format(entry.scheduledStart!);
      }
      if (entry.scheduledEnd != null) {
        scheduledOut = DateFormat('HH:mm').format(entry.scheduledEnd!);
      }

      // Calculate scheduled hours - prioritize scheduledDurationMinutes
      if (entry.scheduledDurationMinutes != null &&
          entry.scheduledDurationMinutes! > 0) {
        scheduledHours = entry.scheduledDurationMinutes! / 60.0;
      } else if (entry.scheduledStart != null && entry.scheduledEnd != null) {
        // Calculate from start/end times
        final duration = entry.scheduledEnd!.difference(entry.scheduledStart!);
        scheduledHours = duration.inMinutes / 60.0;
      } else if (entry.shiftTitle != null && entry.shiftTitle!.isNotEmpty) {
        // If we have shift title but no scheduled times, try to parse from shift title
        // This is a fallback - ideally scheduled times should be in the entry
        // For now, use actual hours as fallback
        scheduledHours = shiftHours;
        AppLogger.debug(
            'Using actual hours as scheduled hours fallback for entry: ${entry.documentId}');
      }

      // Form data
      final formCompleted = entry.formCompleted ? 'Yes' : 'No';
      final reportedHours = entry.reportedHours;
      final hoursDifference = reportedHours != null
          ? (shiftHours - reportedHours).toStringAsFixed(2)
          : '--';

      // Add row
      rows.add([
        firstName,
        lastName,
        shiftTitle,
        shiftType,
        subJob,
        startDate,
        scheduledIn, // Scheduled start time
        inTime,
        clockInPlatform,
        endDate,
        scheduledOut, // Scheduled end time
        outTime,
        clockOutPlatform,
        employeeNotes,
        managerNotes,
        shiftHours,
        scheduledHours, // Scheduled hours
        formCompleted, // Form completed
        reportedHours ?? '--', // Reported hours from form
        hoursDifference, // Difference between actual and reported
        '', // Daily difference (calculated below)
        '', // Daily totals (calculated below)
        '', // Weekly totals (calculated below)
        '', // Total scheduled (calculated below)
        '', // Total difference (calculated below)
        '', // Total paid hours (calculated below)
        '', // Total overtime (calculated below)
      ]);

      // Track totals
      final employeeKey = entry.teacherName;
      final dateKey = DateFormat('yyyy-MM-dd').format(startDate!);
      final weekKey = DateFormat('yyyy-MM-dd').format(_getWeekStart(startDate));

      dailyTotals.putIfAbsent(employeeKey, () => {});
      dailyTotals[employeeKey]![dateKey] =
          (dailyTotals[employeeKey]![dateKey] ?? 0.0) + shiftHours;

      weeklyTotals.putIfAbsent(employeeKey, () => {});
      weeklyTotals[employeeKey]![weekKey] =
          (weeklyTotals[employeeKey]![weekKey] ?? 0.0) + shiftHours;

      // Track scheduled hours
      dailyScheduled.putIfAbsent(employeeKey, () => {});
      dailyScheduled[employeeKey]![dateKey] =
          (dailyScheduled[employeeKey]![dateKey] ?? 0.0) + scheduledHours;

      weeklyScheduled.putIfAbsent(employeeKey, () => {});
      weeklyScheduled[employeeKey]![weekKey] =
          (weeklyScheduled[employeeKey]![weekKey] ?? 0.0) + scheduledHours;

      // Track overtime (hours over 8 per day)
      dailyOvertime.putIfAbsent(employeeKey, () => {});
      final currentDayTotal = dailyTotals[employeeKey]![dateKey] ?? 0.0;
      if (currentDayTotal > 8.0) {
        dailyOvertime[employeeKey]![dateKey] = currentDayTotal - 8.0;
      }
    }

    // Fill in daily and weekly totals
    for (int i = 0; i < rows.length; i++) {
      final entry = _vm.filteredTimesheets[i];
      final employeeKey = entry.teacherName;

      DateTime? entryDate;
      try {
        entryDate = TimesheetReviewController.parseEntryDate(entry.date);
      } catch (e) {
        entryDate = DateTime.now();
      }

      final dateKey = DateFormat('yyyy-MM-dd').format(entryDate!);
      final weekKey = DateFormat('yyyy-MM-dd').format(_getWeekStart(entryDate));

      final dailyTotal = dailyTotals[employeeKey]?[dateKey] ?? 0.0;
      final weeklyTotal = weeklyTotals[employeeKey]?[weekKey] ?? 0.0;
      final dailyScheduledTotal = dailyScheduled[employeeKey]?[dateKey] ?? 0.0;
      final weeklyScheduledTotal =
          weeklyScheduled[employeeKey]?[weekKey] ?? 0.0;
      final weeklyOvertimeTotal = dailyOvertime[employeeKey]
              ?.values
              .fold<double>(0.0, (a, b) => a + b) ??
          0.0;

      // Column indices (0-based):
      // 20: Daily difference, 21: Daily totals, 22: Weekly totals
      // 23: Total scheduled, 24: Total difference, 25: Total paid hours, 26: Total overtime
      rows[i][20] = (dailyTotal - dailyScheduledTotal)
          .toStringAsFixed(2); // Daily difference
      rows[i][21] = dailyTotal.toStringAsFixed(2); // Daily totals
      rows[i][22] = weeklyTotal.toStringAsFixed(2); // Weekly totals
      rows[i][23] = weeklyScheduledTotal.toStringAsFixed(2); // Total scheduled
      rows[i][24] = (weeklyTotal - weeklyScheduledTotal)
          .toStringAsFixed(2); // Total difference
      rows[i][25] = weeklyTotal
          .toStringAsFixed(2); // Total paid hours (same as weekly for now)
      rows[i][26] = weeklyOvertimeTotal.toStringAsFixed(2); // Total overtime
    }

    // Sort by employee name, then by date
    rows.sort((a, b) {
      final nameCompare = (a[0] as String).compareTo(b[0] as String);
      if (nameCompare != 0) return nameCompare;
      final dateCompare = (a[5] as DateTime).compareTo(b[5] as DateTime);
      return dateCompare;
    });

    // Create sheets: 1 summary sheet + 1 sheet per teacher
    final Map<String, List<String>> sheetsHeaders = {};
    final Map<String, List<List<dynamic>>> sheetsData = {};

    // Summary sheet (all data)
    sheetsHeaders['All Teachers'] = headers;
    sheetsData['All Teachers'] = rows;

    // Group by employee for individual sheets
    final Map<String, List<List<dynamic>>> employeeRows = {};
    for (var row in rows) {
      final employeeName = '${row[0]} ${row[1]}';
      employeeRows.putIfAbsent(employeeName, () => []);
      employeeRows[employeeName]!.add(row);
    }

    // Create a sheet for each employee (limit name length for sheet name)
    for (var entry in employeeRows.entries) {
      String sheetName = entry.key;
      // Excel sheet names max 31 chars, no special chars
      if (sheetName.length > 28) {
        sheetName = '${sheetName.substring(0, 28)}...';
      }
      sheetName = sheetName.replaceAll(RegExp(r'[\\/*?\[\]:]'), '_');

      sheetsHeaders[sheetName] = headers;
      sheetsData[sheetName] = entry.value;
    }

    // Add summary statistics sheet
    final summaryHeaders = [
      'Teacher',
      'Total Shifts',
      'Total Hours',
      'Avg Hours/Shift'
    ];
    final summaryRows = <List<dynamic>>[];

    for (var entry in employeeRows.entries) {
      final teacherRows = entry.value;
      final totalShifts = teacherRows.length;
      final totalHours = teacherRows.fold<double>(0.0, (sum, row) {
        // row[15] is shiftHours (double)
        final hours = row[15];
        if (hours is double) {
          return sum + hours;
        } else if (hours is num) {
          return sum + hours.toDouble();
        } else if (hours is String) {
          return sum + (double.tryParse(hours) ?? 0.0);
        }
        return sum;
      });
      final avgHours = totalShifts > 0 ? totalHours / totalShifts : 0.0;

      summaryRows.add([
        entry.key,
        totalShifts,
        totalHours.toStringAsFixed(2),
        avgHours.toStringAsFixed(2),
      ]);
    }

    // Sort summary by total hours descending
    summaryRows.sort((a, b) => (double.tryParse(b[2].toString()) ?? 0)
        .compareTo(double.tryParse(a[2].toString()) ?? 0));

    sheetsHeaders['Summary'] = summaryHeaders;
    sheetsData['Summary'] = summaryRows;

    String fileName = 'timesheet_export';
    if (_selectedDateRange != null) {
      fileName +=
          '_${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)}_to_${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}';
    } else {
      fileName += '_${_selectedFilter.toLowerCase()}';
    }
    fileName += '_${DateTime.now().toString().split(' ')[0]}';

    ExportHelpers.showExportDialog(
      context,
      sheetsHeaders,
      sheetsData,
      fileName,
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);

    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: currentMonthStart,
            end: currentMonthEnd,
          ),
      currentDate: now,
      helpText: AppLocalizations.of(context)!.selectDateRangeForTimesheetReview,
      cancelText: 'Cancel',
      confirmText: 'Apply Filter',
      saveText: 'Apply',
      builder: (context, child) {
        return Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 450,
                maxHeight: 650,
              ),
              margin: const EdgeInsets.all(16),
              child: Material(
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: const Color(0xff0386FF),
                          onPrimary: Colors.white,
                          onSurface: Colors.black87,
                          onSurfaceVariant: Colors.grey.shade700,
                          surface: Colors.white,
                          surfaceContainerHighest: Colors.grey.shade50,
                        ),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: Colors.white,
                      headerBackgroundColor: const Color(0xff0386FF),
                      headerForegroundColor: Colors.white,
                      weekdayStyle: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      dayStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      yearStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      headerHelpStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff0386FF),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result != null) {
      _vm.patchFilterState(
        (f) => f.copyWith(dateRange: result),
        clearSelection: false,
      );

      // Apply the filter with the new date range
      _applyFilter(_selectedFilter);

      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing ${_vm.filteredTimesheets.length} timesheets from ${DateFormat('MMM dd').format(result.start)} - ${DateFormat('MMM dd, yyyy').format(result.end)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xff0386FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Consumer<TimesheetReviewViewModel>(
        builder: (context, vm, _) {
          final wide = MediaQuery.sizeOf(context).width >= 1200;
          final sw = MediaQuery.sizeOf(context).width;
          final focused = vm.getFocusedTimesheet();

          final dataSource = TimesheetReviewDataSource(
            timesheets: vm.filteredTimesheets,
            onApprove: _approveTimesheet,
            onReject: _rejectTimesheet,
            onViewDetails: _viewTimesheetDetails,
            onSelectionChanged: _onTimesheetSelectionChanged,
            selectedIds: vm.selectedTimesheetIds,
            context: context,
            enableRichTooltips: timesheetReviewEnableHoverTooltips(),
            compact: true,
          );

          final Widget gridBody;
          if (vm.isLoading) {
            gridBody = const Center(child: CircularProgressIndicator());
          } else if (vm.filteredTimesheets.isEmpty) {
            gridBody = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noTimesheetsFound,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.tryChangingTheFilterOrCheck,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          } else {
            gridBody = TimesheetReviewGrid(
              dataSource: dataSource,
              selectAllPendingTriState: _headerPendingTriState(),
              onSelectAllPendingChanged: _toggleSelectAllPendingTri,
              selectAllPendingEnabled: _visiblePendingRowIds().isNotEmpty,
              enableHeaderTooltips: timesheetReviewEnableHoverTooltips(),
              rowHeight: 44,
              margin: EdgeInsets.fromLTRB(wide ? 8 : 12, 4, wide ? 16 : 12, 12),
              onCardExport: _openExportDialog,
              onCardSelectAllPending: () => _toggleSelectAllPendingTri(true),
              onDataCellTap: _openDetailDrawer,
            );
          }

          final showBulk = vm.showBulkActions &&
              !vm.isLoading &&
              vm.filteredTimesheets.isNotEmpty;

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.grey[50],
            endDrawer: Drawer(
              width: sw >= 500 ? 440 : sw * 0.92,
              child: focused == null
                  ? const SizedBox.shrink()
                  : TimesheetReviewDetailDrawer(
                      timesheet: focused,
                      onClose: () => Navigator.of(context).pop(),
                      onApprove: () {
                        Navigator.of(context).pop();
                        _approveTimesheet(focused);
                      },
                      onReject: () {
                        Navigator.of(context).pop();
                        _rejectTimesheet(focused);
                      },
                    ),
            ),
            body: Column(
              children: [
                Material(
                  color: Colors.white,
                  elevation: 0.5,
                  child: TimesheetReviewToolbar(
                    searchController: _searchController,
                    onSearchChanged: _updateSearchQuery,
                    statusOptions: _filterOptions,
                    onStatusChanged: _applyFilter,
                    onExport: _openExportDialog,
                    onSelectAllPendingVisible: _selectAllPendingVisible,
                    onPresetThisWeek: () =>
                        _applyDatePreset(TimesheetDatePreset.thisWeek),
                    onPresetLastWeek: () =>
                        _applyDatePreset(TimesheetDatePreset.lastWeek),
                    onPresetThisMonth: () =>
                        _applyDatePreset(TimesheetDatePreset.thisMonth),
                    onClearDateRange: _clearDateRangeFilter,
                    onPickDateRange: () => _selectDateRange(context),
                    hasDateRange: _selectedDateRange != null,
                    dateRangeSummary: _dateRangeSummary(),
                    onTeacherChanged: (value) {
                      _vm.patchFilterState(
                        (f) => f.copyWith(teacherFilter: value),
                        clearSelection: false,
                      );
                    },
                    onEditedOnlyChanged: (v) {
                      _vm.patchFilterState(
                        (f) => f.copyWith(editedOnly: v),
                        clearSelection: false,
                      );
                    },
                    onNeedsAttentionChanged: (v) {
                      _vm.patchFilterState(
                        (f) => f.copyWith(needsAttention: v),
                        clearSelection: false,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(child: gridBody),
                      if (showBulk)
                        TimesheetReviewBulkBar(
                          selectedCount: _selectedWritableTimesheets().length,
                          summarySecondaryLine:
                              'Total pay: \$${_selectedPaymentTotal().toStringAsFixed(2)}'
                              '${_selectedDateRange != null ? ' • ${DateFormat('MMM dd').format(_selectedDateRange!.start)}-${DateFormat('MMM dd').format(_selectedDateRange!.end)}' : ''}',
                          onApprove: _bulkApproveTimesheets,
                          onReject: _bulkRejectTimesheets,
                          onClear: () => _vm.clearSelection(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

