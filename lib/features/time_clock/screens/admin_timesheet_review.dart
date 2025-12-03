import 'package:flutter/material.dart';
import '../../../core/enums/timesheet_enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../models/timesheet_entry.dart';

import '../../../utility_functions/export_helpers.dart';
import 'dart:async';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class AdminTimesheetReview extends StatefulWidget {
  const AdminTimesheetReview({super.key});

  @override
  State<AdminTimesheetReview> createState() => _AdminTimesheetReviewState();
}

class _AdminTimesheetReviewState extends State<AdminTimesheetReview> {
  List<TimesheetEntry> _allTimesheets = [];
  List<TimesheetEntry> _filteredTimesheets = [];
  TimesheetReviewDataSource? _dataSource;
  String _selectedFilter = 'Pending';
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;
  final Set<String> _selectedTimesheetIds = {};
  bool _showBulkActions = false;
  
  // Advanced filtering
  String? _selectedTeacherFilter;
  List<String> _availableTeachers = [];

  // Real-time listener
  StreamSubscription<QuerySnapshot>? _timesheetListener;

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
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _timesheetListener?.cancel();
    super.dispose();
  }

  /// Setup real-time listener for timesheet changes
  void _setupRealtimeListener() {
    setState(() => _isLoading = true);

    // Listen to real-time changes in timesheet_entries collection
    _timesheetListener = FirebaseFirestore.instance
        .collection('timesheet_entries')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) async {
      await _processTimesheetSnapshot(snapshot);
    }, onError: (error) {
      AppLogger.error('Error in timesheet listener: $error');
      setState(() => _isLoading = false);
    });
  }

  /// Process timesheet snapshot and update UI in real-time
  Future<void> _processTimesheetSnapshot(QuerySnapshot snapshot) async {
    try {
      List<TimesheetEntry> timesheets = [];

      // Process all timesheet entries
      for (QueryDocumentSnapshot doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get user information for hourly rate - use cached data or fetch if needed
        TimesheetEntry? entry = await _createTimesheetEntry(doc, data);
        if (entry != null) {
          timesheets.add(entry);
        }
      }

      if (mounted) {
        setState(() {
          _allTimesheets = timesheets;
          _loadAvailableTeachers(); // Load teachers for filter dropdown
          _applyFilter(_selectedFilter);
          _isLoading = false;
        });

        // Show notification for new pending timesheets if admin was viewing other filters
        _checkForNewPendingTimesheets(timesheets);
      }
    } catch (e) {
      AppLogger.error('Error processing timesheet snapshot: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Create timesheet entry with user data
  Future<TimesheetEntry?> _createTimesheetEntry(
      QueryDocumentSnapshot doc, Map<String, dynamic> data) async {
    try {
      // Get user information for hourly rate - with caching to avoid repeated queries
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(data['teacher_id'])
          .get();

      final userData = userDoc.data();
      // Get the hourly rate from the timesheet entry first, then fallback to user data
      final timesheetHourlyRate = data['hourly_rate'] as double?;
      final userHourlyRate = userData?['hourly_rate'] as double?;
      final hourlyRate = timesheetHourlyRate ?? userHourlyRate ?? 4.0;
      final userName =
          '${userData?['first_name'] ?? ''} ${userData?['last_name'] ?? ''}'
              .trim();

      // Parse new export fields
      final clockInTimestamp = data['clock_in_timestamp'] as Timestamp?;
      final clockOutTimestamp = data['clock_out_timestamp'] as Timestamp?;
      final scheduledStart = data['scheduled_start'] as Timestamp?;
      final scheduledEnd = data['scheduled_end'] as Timestamp?;
      final scheduledDurationMinutes = data['scheduled_duration_minutes'] as int?;
      
      // If scheduled times are missing, try to fetch from shift if shift_id exists
      DateTime? finalScheduledStart = scheduledStart?.toDate();
      DateTime? finalScheduledEnd = scheduledEnd?.toDate();
      int? finalScheduledDurationMinutes = scheduledDurationMinutes;
      
      final shiftId = data['shift_id'] as String?;
      if ((finalScheduledStart == null || finalScheduledEnd == null || finalScheduledDurationMinutes == null) && shiftId != null) {
        try {
          final shiftDoc = await FirebaseFirestore.instance
              .collection('teaching_shifts')
              .doc(shiftId)
              .get();
          if (shiftDoc.exists) {
            final shiftData = shiftDoc.data() as Map<String, dynamic>?;
            if (shiftData != null) {
              if (finalScheduledStart == null && shiftData['shift_start'] != null) {
                finalScheduledStart = (shiftData['shift_start'] as Timestamp).toDate();
              }
              if (finalScheduledEnd == null && shiftData['shift_end'] != null) {
                finalScheduledEnd = (shiftData['shift_end'] as Timestamp).toDate();
              }
              if (finalScheduledDurationMinutes == null) {
                // Calculate from shift times
                if (finalScheduledStart != null && finalScheduledEnd != null) {
                  finalScheduledDurationMinutes = finalScheduledEnd.difference(finalScheduledStart).inMinutes;
                }
              }
            }
          }
        } catch (e) {
          AppLogger.debug('Could not fetch shift data for shift_id $shiftId: $e');
        }
      }

      return TimesheetEntry(
        documentId: doc.id,
        date: data['date'] ?? '',
        subject: data['student_name'] ?? '',
        start: data['start_time'] ?? '',
        end: data['end_time'] ?? '',
        totalHours: data['total_hours'] ?? '00:00',
        description: data['description'] ?? '',
        status: _parseStatus(data['status'] ?? 'draft'),
        teacherId: data['teacher_id'] ?? '',
        teacherName: userName,
        hourlyRate: hourlyRate,
        createdAt: data['created_at'] as Timestamp?,
        submittedAt: data['submitted_at'] as Timestamp?,
        approvedAt: data['approved_at'] as Timestamp?,
        rejectedAt: data['rejected_at'] as Timestamp?,
        rejectionReason: data['rejection_reason'] as String?,
        paymentAmount: data['payment_amount'] as double?,
        source: data['source'] as String? ?? 'manual',
        // NEW: Export fields
        shiftTitle: data['shift_title'] as String?,
        shiftType: data['shift_type'] as String?,
        clockInPlatform: data['clock_in_platform'] as String?,
        clockOutPlatform: data['clock_out_platform'] as String?,
        scheduledStart: finalScheduledStart,
        scheduledEnd: finalScheduledEnd,
        scheduledDurationMinutes: finalScheduledDurationMinutes,
        employeeNotes: data['employee_notes'] as String?,
        managerNotes: data['manager_notes'] as String?,
        // Edit tracking fields
        isEdited: data['is_edited'] == true || data['edited_at'] != null, // Check both is_edited flag and edited_at timestamp
        editApproved: data['edit_approved'] == true,
        originalData: data['original_data'] as Map<String, dynamic>?,
        editedAt: data['edited_at'] as Timestamp?,
        editedBy: data['edited_by'] as String?,
        // Readiness form fields
        formResponseId: data['form_response_id'] as String?,
        formCompleted: data['form_completed'] == true || data['form_response_id'] != null,
        reportedHours: (data['reported_hours'] as num?)?.toDouble(),
        formNotes: data['form_notes'] as String?,
      );
    } catch (e) {
      AppLogger.error('Error creating timesheet entry for doc ${doc.id}: $e');
      return null;
    }
  }

  /// Check for new pending timesheets and notify admin
  void _checkForNewPendingTimesheets(List<TimesheetEntry> timesheets) {
    final newPendingCount =
        timesheets.where((t) => t.status == TimesheetStatus.pending).length;

    // Only show notification if we're not currently viewing pending timesheets
    if (_selectedFilter != 'Pending' && newPendingCount > 0) {
      // Show subtle notification in the app bar or as a badge
      _showPendingNotification(newPendingCount);
    }
  }

  /// Show notification for new pending timesheets
  void _showPendingNotification(int count) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notification_important, color: Colors.white),
            const SizedBox(width: 8),
            Text('$count new timesheet${count > 1 ? 's' : ''} pending review'),
          ],
        ),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _selectedFilter = 'Pending';
              _applyFilter(_selectedFilter);
            });
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  TimesheetStatus _parseStatus(String status) {
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

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _selectedTimesheetIds.clear(); // Clear selections when filter changes

      List<TimesheetEntry> statusFiltered;
      if (filter == 'All') {
        statusFiltered = List.from(_allTimesheets);
      } else {
        TimesheetStatus targetStatus = _parseStatus(filter);
        statusFiltered = _allTimesheets
            .where((timesheet) => timesheet.status == targetStatus)
            .toList();
      }

      // Apply teacher filter if selected
      if (_selectedTeacherFilter != null && _selectedTeacherFilter!.isNotEmpty) {
        statusFiltered = statusFiltered
            .where((entry) => entry.teacherName == _selectedTeacherFilter)
            .toList();
      }

      // Apply date range filter if selected
      if (_selectedDateRange != null) {
        statusFiltered = statusFiltered.where((entry) {
          final entryDate = _parseEntryDate(entry.date);
          if (entryDate == null) return false;

          return entryDate.isAfter(_selectedDateRange!.start
                  .subtract(const Duration(days: 1))) &&
              entryDate.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1)));
        }).toList();
      }

      _filteredTimesheets = statusFiltered;
      _showBulkActions = _selectedTimesheetIds.isNotEmpty;

      _dataSource = TimesheetReviewDataSource(
        timesheets: _filteredTimesheets,
        onApprove: _approveTimesheet,
        onReject: _rejectTimesheet,
        onViewDetails: _viewTimesheetDetails,
        onSelectionChanged: _onTimesheetSelectionChanged,
        selectedIds: _selectedTimesheetIds,
      );
    });
  }
  
  void _loadAvailableTeachers() {
    final teachers = _allTimesheets.map((e) => e.teacherName).toSet().toList();
    teachers.sort();
    setState(() {
      _availableTeachers = teachers;
    });
  }

  void _onTimesheetSelectionChanged(String timesheetId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedTimesheetIds.add(timesheetId);
      } else {
        _selectedTimesheetIds.remove(timesheetId);
      }
      _showBulkActions = _selectedTimesheetIds.isNotEmpty;
    });
  }

  Future<void> _bulkApproveTimesheets() async {
    final selectedTimesheets = _filteredTimesheets
        .where((t) => _selectedTimesheetIds.contains(t.documentId))
        .toList();

    if (selectedTimesheets.isEmpty) return;

    // Check if any timesheets are edited but not approved
    final editedTimesheets = selectedTimesheets
        .where((t) => t.isEdited && !t.editApproved)
        .toList();

    if (editedTimesheets.isNotEmpty) {
      // Show warning about edited timesheets
      final shouldContinue = await _showBulkEditWarningDialog(editedTimesheets);
      if (!shouldContinue) return;
    }

    final confirmed = await _showBulkApprovalDialog(selectedTimesheets);
    if (!confirmed) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
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
          FirebaseFirestore.instance
              .collection('timesheet_entries')
              .doc(timesheet.documentId!),
          updateData,
        );
      }

      await batch.commit();

      _showSuccessSnackBar(
          'Approved ${selectedTimesheets.length} timesheets. Total payment: \$${totalPayment.toStringAsFixed(2)}');

      setState(() {
        _selectedTimesheetIds.clear();
        _showBulkActions = false;
      });

      // Real-time listener will automatically update the UI
    } catch (e) {
      _showErrorSnackBar('Error approving timesheets: $e');
    }
  }

  Future<void> _bulkRejectTimesheets() async {
    final selectedTimesheets = _filteredTimesheets
        .where((t) => _selectedTimesheetIds.contains(t.documentId))
        .toList();

    if (selectedTimesheets.isEmpty) return;

    final reason = await _showBulkRejectionDialog(selectedTimesheets.length);
    if (reason == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var timesheet in selectedTimesheets) {
        batch.update(
          FirebaseFirestore.instance
              .collection('timesheet_entries')
              .doc(timesheet.documentId!),
          {
            'status': 'rejected',
            'rejected_at': FieldValue.serverTimestamp(),
            'rejection_reason': reason,
            'updated_at': FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();

      _showSuccessSnackBar(
          'Rejected ${selectedTimesheets.length} timesheets with feedback');

      setState(() {
        _selectedTimesheetIds.clear();
        _showBulkActions = false;
      });

      // Real-time listener will automatically update the UI
    } catch (e) {
      _showErrorSnackBar('Error rejecting timesheets: $e');
    }
  }

  /// Show warning dialog when bulk approving edited timesheets
  Future<bool> _showBulkEditWarningDialog(List<TimesheetEntry> editedTimesheets) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Edited Timesheets Detected',
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
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: editedTimesheets.length,
                itemBuilder: (context, index) {
                  final ts = editedTimesheets[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.edit, size: 18, color: Color(0xFFF59E0B)),
                    title: Text(
                      ts.teacherName,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${ts.date} - ${ts.totalHours}',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                  );
                },
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
                  const Icon(Icons.info_outline, color: Color(0xFF1E40AF), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'By continuing, you will approve both the edits and the timesheets.',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
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
              'Approve All',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showBulkApprovalDialog(List<TimesheetEntry> timesheets) async {
    final totalPayment = timesheets.fold<double>(
        0.0, (sum, timesheet) => sum + _calculatePayment(timesheet));

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
                const SizedBox(width: 12),
                Text('Bulk Approve Timesheets',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            content: Column(
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
                  child: ListView.builder(
                    itemCount: timesheets.length,
                    itemBuilder: (context, index) {
                      final timesheet = timesheets[index];
                      return ListTile(
                        dense: true,
                        title: Text(timesheet.teacherName,
                            style: GoogleFonts.inter(fontSize: 12)),
                        subtitle: Text(
                            '${timesheet.date} - ${timesheet.totalHours}',
                            style: GoogleFonts.inter(fontSize: 11)),
                        trailing: Text(
                            '\$${_calculatePayment(timesheet).toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Approve All'),
              ),
            ],
          ),
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
            const SizedBox(width: 12),
            Text('Bulk Reject Timesheets',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You are about to reject $count timesheets. Please provide a reason:',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection...',
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
            child: const Text('Cancel'),
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
            child: const Text('Reject All'),
          ),
        ],
      ),
    );
  }

  DateTime? _parseEntryDate(String dateString) {
    final formats = [
      'MMM dd, yyyy', // Standard format: Jan 26, 2025
      'EEE MM/dd/yyyy', // Clock-in format with year: Mon 01/26/2025
      'EEE MM/dd', // Clock-in format without year: Mon 01/26
      'MM/dd/yyyy', // Simple format with year: 01/26/2025
      'MM/dd', // Simple format without year: 01/26
      'yyyy-MM-dd', // ISO format: 2025-01-26
    ];

    for (String format in formats) {
      try {
        DateTime parsed = DateFormat(format).parse(dateString);

        if (format == 'EEE MM/dd' || format == 'MM/dd') {
          parsed = DateTime(DateTime.now().year, parsed.month, parsed.day);
        }

        return parsed;
      } catch (e) {
        continue;
      }
    }

    AppLogger.error('Could not parse date: $dateString');
    return null;
  }

  double _calculatePayment(TimesheetEntry timesheet) {
    try {
      // Parse total hours (format: "HH:MM")
      // This uses the current totalHours which should reflect edited times if the timesheet was edited
      final parts = timesheet.totalHours.split(':');
      if (parts.length != 2) return 0.0;

      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final totalHoursDecimal = hours + (minutes / 60.0);

      // Payment = hours worked × hourly rate
      // Hourly rate comes from the shift or teacher's rate
      return totalHoursDecimal * timesheet.hourlyRate;
    } catch (e) {
      AppLogger.error('Error calculating payment: $e');
      return 0.0;
    }
  }
  
  /// Check if a timesheet is complete (has both clock-in and clock-out times)
  bool _isTimesheetComplete(TimesheetEntry timesheet) {
    // Check if both start and end times are present and valid
    final hasStart = timesheet.start.isNotEmpty && timesheet.start != '--';
    final hasEnd = timesheet.end.isNotEmpty && timesheet.end != '--';
    final hasValidHours = timesheet.totalHours.isNotEmpty && 
                         timesheet.totalHours != '00:00' &&
                         timesheet.totalHours != '--';
    
    return hasStart && hasEnd && hasValidHours;
  }

  Future<void> _approveTimesheet(TimesheetEntry timesheet) async {
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

        await FirebaseFirestore.instance
            .collection('timesheet_entries')
            .doc(timesheet.documentId!)
            .update({
          'status': newStatus,
          'approved_at': isComplete ? FieldValue.serverTimestamp() : null,
          'payment_amount': payment, // Recalculated payment based on edited times
          'updated_at': FieldValue.serverTimestamp(),
          'edit_approved': true, // Mark edit as approved
          'edit_approved_at': FieldValue.serverTimestamp(),
          // Clear edit tracking fields after approval
          'is_edited': false,
          'original_data': FieldValue.delete(),
          'employee_notes': FieldValue.delete(), // Clear employee notes after approval
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
        await FirebaseFirestore.instance
            .collection('timesheet_entries')
            .doc(timesheet.documentId!)
            .update({
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
      
      // Revert to original data
      await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .doc(timesheet.documentId!)
          .update({
        'clock_in_timestamp': original['clock_in_timestamp'],
        'clock_out_timestamp': original['clock_out_timestamp'],
        'start_time': original['start_time'],
        'end_time': original['end_time'],
        'total_hours': original['total_hours'],
        'is_edited': false,
        'edit_approved': false,
        'original_data': FieldValue.delete(), // Remove original data after revert
        'edit_reverted_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackBar('Timesheet reverted to original data');
    } catch (e) {
      _showErrorSnackBar('Error reverting timesheet: $e');
    }
  }

  Future<void> _rejectTimesheetWithReason(TimesheetEntry timesheet, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .doc(timesheet.documentId!)
          .update({
        'status': 'rejected',
        'rejected_at': FieldValue.serverTimestamp(),
        'rejection_reason': reason,
        'updated_at': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackBar('Timesheet rejected with feedback sent to user');
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
    
    // Get original timestamps for better formatting
    if (original['clock_in_timestamp'] != null) {
      final originalClockIn = (original['clock_in_timestamp'] as Timestamp).toDate();
      originalStart = DateFormat('h:mm a').format(originalClockIn);
    }
    if (original['clock_out_timestamp'] != null) {
      final originalClockOut = (original['clock_out_timestamp'] as Timestamp).toDate();
      originalEnd = DateFormat('h:mm a').format(originalClockOut);
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Timesheet Was Edited',
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
              if (timesheet.employeeNotes != null && timesheet.employeeNotes!.isNotEmpty) ...[
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
                          const Icon(Icons.note_outlined, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Reason for Edit:',
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
                'Data Comparison:',
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
                        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Field',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Original',
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
                              'Edited',
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
                    _buildComparisonRow('Clock In', originalStart, timesheet.start),
                    // Clock Out
                    _buildComparisonRow('Clock Out', originalEnd, timesheet.end),
                    // Total Hours
                    _buildComparisonRow('Total Hours', originalHours, timesheet.totalHours),
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
                    const Icon(Icons.info_outline, color: Color(0xFF1E40AF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'By approving, you accept the edited times and the timesheet will be approved.',
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
              'Cancel',
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
              'Approve Edit & Continue',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildComparisonRow(String field, String original, String edited) {
    final isChanged = original != edited;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isChanged ? const Color(0xFFFEF2F2) : Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              field,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              original,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isChanged ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                decoration: isChanged ? TextDecoration.lineThrough : null,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isChanged) ...[
                  const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                ],
                Text(
                  edited,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isChanged ? FontWeight.w600 : FontWeight.normal,
                    color: isChanged ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reject Edited Timesheet',
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
              'This timesheet was edited. Choose an action:',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.undo, color: Color(0xFF0386FF)),
              title: Text(
                'Revert to Original',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Restore original times and keep timesheet pending'),
              onTap: () => Navigator.of(context).pop('revert'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: Text(
                'Reject Timesheet',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Reject the entire timesheet (requires reason)'),
              onTap: () => Navigator.of(context).pop('reject'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
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
                const SizedBox(width: 12),
                Text('Approve Timesheet',
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Approve & Calculate Payment'),
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
            const SizedBox(width: 12),
            Text('Reject Timesheet',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please provide a reason for rejection:',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection...',
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
            child: const Text('Cancel'),
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _viewTimesheetDetails(TimesheetEntry timesheet) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (fixed)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.schedule,
                        color: Color(0xff0386FF), size: 20),
                  ),
                  const SizedBox(width: 12),
                    Expanded(
                      child: Text('Timesheet Details',
                      style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  _buildStatusChip(timesheet.status),
                ],
              ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              _buildDetailRow('Teacher:', timesheet.teacherName),
              _buildDetailRow('Date:', timesheet.date),
              _buildDetailRow('Student:', timesheet.subject),
              _buildDetailRow('Start Time:', timesheet.start),
              _buildDetailRow('End Time:', timesheet.end),
              _buildDetailRow('Total Hours:', timesheet.totalHours),
              _buildDetailRow('Description:', timesheet.description),
                      // Show edit warning if edited but not approved
                      if (timesheet.isEdited && !timesheet.editApproved) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit, color: Color(0xFFD97706), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚠️ This timesheet was edited and requires approval',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
              if (timesheet.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Description:',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(timesheet.description,
                      style: GoogleFonts.inter(fontSize: 14)),
                ),
              ],
                      // Employee Notes (from timesheet edits)
                      if (timesheet.employeeNotes != null && timesheet.employeeNotes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.note_outlined,
                                color: Color(0xFFD97706),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Employee Notes:',
                                style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Text(
                            timesheet.employeeNotes!,
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                      // Original Data Comparison (if edited)
                      if (timesheet.isEdited) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.history,
                                color: Color(0xFF1E40AF),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Edit Information:',
                                style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (timesheet.originalData != null) ...[
                          // Show comparison if original data is available
                          _buildOriginalDataComparison(timesheet),
                        ] else ...[
                          // Show message if original data is not available (old edits)
                          Container(
                            padding: const EdgeInsets.all(16),
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
                                    const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Original data not available',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This timesheet was edited, but the original data was not saved. This may be an older edit made before the tracking system was implemented.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                                if (timesheet.editedAt != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Edited: ${DateFormat('MMM d, yyyy h:mm a').format(timesheet.editedAt!.toDate())}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF92400E),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                      // Manager Notes (admin notes)
                      if (timesheet.managerNotes != null && timesheet.managerNotes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_outlined,
                                color: Color(0xFF1E40AF),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Manager Notes:',
                                style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Text(
                            timesheet.managerNotes!,
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E3A8A)),
                          ),
                        ),
                      ],
                    ], // Close Column children
                  ), // Close Column
                ), // Close SingleChildScrollView
              ), // Close Expanded
              // Footer with actions (fixed)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  if (timesheet.status == TimesheetStatus.pending) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _rejectTimesheet(timesheet);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _approveTimesheet(timesheet);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve'),
                    ),
                  ],
                ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildOriginalDataComparison(TimesheetEntry timesheet) {
    if (timesheet.originalData == null) return const SizedBox.shrink();
    
    final original = timesheet.originalData!;
    
    // Parse original times
    String originalStart = original['start_time'] ?? 'N/A';
    String originalEnd = original['end_time'] ?? 'N/A';
    String originalHours = original['total_hours'] ?? 'N/A';
    
    // Get original timestamps for better formatting
    if (original['clock_in_timestamp'] != null) {
      try {
        final originalClockIn = (original['clock_in_timestamp'] as Timestamp).toDate();
        originalStart = DateFormat('h:mm a').format(originalClockIn);
      } catch (e) {
        // Keep string format if parsing fails
      }
    }
    if (original['clock_out_timestamp'] != null) {
      try {
        final originalClockOut = (original['clock_out_timestamp'] as Timestamp).toDate();
        originalEnd = DateFormat('h:mm a').format(originalClockOut);
      } catch (e) {
        // Keep string format if parsing fails
      }
    }

    return Container(
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Field',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Original',
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
                    'Current',
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
          _buildComparisonRow('Clock In', originalStart, timesheet.start),
          // Clock Out
          _buildComparisonRow('Clock Out', originalEnd, timesheet.end),
          // Total Hours
          _buildComparisonRow('Total Hours', originalHours, timesheet.totalHours),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
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

  void _exportTimesheets() {
    if (_filteredTimesheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    AppLogger.debug('Exporting ${_filteredTimesheets.length} timesheets...');

    // Clean, comprehensive headers
    final detailedHeaders = [
      "Teacher Name",
      "Date",
      "Day",
      "Week Starting",
      "Month",
      "Student / Subject",
      "Scheduled Start",
      "Scheduled End",
      "Clock In",
      "Clock Out",
      "Scheduled Hours",
      "Worked Hours",
      "Difference",
      "Hourly Rate",
      "Total Pay",
      "Status",
      "Form Completed",
      "Employee Notes",
      "Manager Notes",
    ];

    List<List<dynamic>> detailedRows = [];
    
    // Aggregation Maps for summaries
    final Map<String, Map<String, double>> dailyStats = {}; // Teacher|Date -> {scheduled, worked, pay}
    final Map<String, Map<String, double>> weeklyStats = {}; // Teacher|Week -> {scheduled, worked, pay}
    final Map<String, Map<String, double>> monthlyStats = {}; // Teacher|Month -> {scheduled, worked, pay}

    // Helper to update stats
    void updateStats(Map<String, Map<String, double>> map, String key, double scheduled, double worked, double pay) {
      if (!map.containsKey(key)) {
        map[key] = {'scheduled': 0.0, 'worked': 0.0, 'pay': 0.0};
      }
      map[key]!['scheduled'] = (map[key]!['scheduled'] ?? 0.0) + scheduled;
      map[key]!['worked'] = (map[key]!['worked'] ?? 0.0) + worked;
      map[key]!['pay'] = (map[key]!['pay'] ?? 0.0) + pay;
    }

    // Sort entries for consistency
    final sortedEntries = List<TimesheetEntry>.from(_filteredTimesheets);
    sortedEntries.sort((a, b) {
      final nameCompare = a.teacherName.compareTo(b.teacherName);
      if (nameCompare != 0) return nameCompare;
      return _parseEntryDate(a.date)?.compareTo(_parseEntryDate(b.date) ?? DateTime.now()) ?? 0;
    });

    for (var entry in sortedEntries) {
      // Parse Date
      DateTime date = _parseEntryDate(entry.date) ?? DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      
      // Week and Month Keys
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);
      final monthStart = DateTime(date.year, date.month, 1);
      final monthKey = DateFormat('yyyy-MM').format(monthStart);

      // Hours & Pay
      final workedHours = _parseHoursToDecimal(entry.totalHours);
      final pay = workedHours * entry.hourlyRate;
      
      // Scheduled Hours Logic
      double scheduledHours = 0.0;
      String scheduledIn = '--';
      String scheduledOut = '--';
      
      if (entry.scheduledDurationMinutes != null && entry.scheduledDurationMinutes! > 0) {
        scheduledHours = entry.scheduledDurationMinutes! / 60.0;
      } else if (entry.scheduledStart != null && entry.scheduledEnd != null) {
        final duration = entry.scheduledEnd!.difference(entry.scheduledStart!);
        scheduledHours = duration.inMinutes / 60.0;
      }
      
      if (entry.scheduledStart != null) scheduledIn = DateFormat('h:mm a').format(entry.scheduledStart!);
      if (entry.scheduledEnd != null) scheduledOut = DateFormat('h:mm a').format(entry.scheduledEnd!);

      final difference = workedHours - scheduledHours;

      // Add Detailed Row
      detailedRows.add([
        entry.teacherName,
        dateKey,
        DateFormat('EEEE').format(date),
        weekKey,
        DateFormat('MMMM yyyy').format(monthStart),
        entry.subject,
        scheduledIn,
        scheduledOut,
        entry.start,
        entry.end,
        scheduledHours > 0 ? scheduledHours.toStringAsFixed(2) : '--',
        workedHours.toStringAsFixed(2),
        scheduledHours > 0 ? difference.toStringAsFixed(2) : '--',
        entry.hourlyRate.toStringAsFixed(2),
        pay.toStringAsFixed(2),
        entry.status.name,
        entry.formCompleted ? 'Yes' : 'No',
        entry.employeeNotes ?? '',
        entry.managerNotes ?? '',
      ]);

      // Update Aggregates
      final teacher = entry.teacherName;
      updateStats(dailyStats, '$teacher|$dateKey', scheduledHours, workedHours, pay);
      updateStats(weeklyStats, '$teacher|$weekKey', scheduledHours, workedHours, pay);
      updateStats(monthlyStats, '$teacher|$monthKey', scheduledHours, workedHours, pay);
    }

    // Build Summary Sheets
    final dailyHeaders = [
      "Teacher", "Date", "Day", "Total Scheduled", "Total Worked", "Difference", "Daily Pay"
    ];
    List<List<dynamic>> dailyRows = [];
    dailyStats.forEach((key, stats) {
      final parts = key.split('|');
      final teacher = parts[0];
      final dateStr = parts[1];
      final date = DateTime.parse(dateStr);
      dailyRows.add([
        teacher,
        dateStr,
        DateFormat('EEEE').format(date),
        stats['scheduled']!.toStringAsFixed(2),
        stats['worked']!.toStringAsFixed(2),
        (stats['worked']! - stats['scheduled']!).toStringAsFixed(2),
        stats['pay']!.toStringAsFixed(2),
      ]);
    });
    dailyRows.sort((a, b) {
      int cmp = a[0].compareTo(b[0]); // Teacher
      if (cmp != 0) return cmp;
      return a[1].compareTo(b[1]); // Date
    });

    final weeklyHeaders = [
      "Teacher", "Week Starting", "Total Scheduled", "Total Worked", "Difference", "Weekly Pay"
    ];
    List<List<dynamic>> weeklyRows = [];
    weeklyStats.forEach((key, stats) {
      final parts = key.split('|');
      final teacher = parts[0];
      final weekStr = parts[1];
      weeklyRows.add([
        teacher,
        weekStr,
        stats['scheduled']!.toStringAsFixed(2),
        stats['worked']!.toStringAsFixed(2),
        (stats['worked']! - stats['scheduled']!).toStringAsFixed(2),
        stats['pay']!.toStringAsFixed(2),
      ]);
    });
    weeklyRows.sort((a, b) => a[0].compareTo(b[0]) == 0 ? a[1].compareTo(b[1]) : a[0].compareTo(b[0]));

    final monthlyHeaders = [
      "Teacher", "Month", "Total Scheduled", "Total Worked", "Difference", "Monthly Pay"
    ];
    List<List<dynamic>> monthlyRows = [];
    monthlyStats.forEach((key, stats) {
      final parts = key.split('|');
      final teacher = parts[0];
      final monthStr = parts[1]; // yyyy-MM
      final date = DateTime.parse('$monthStr-01');
      monthlyRows.add([
        teacher,
        DateFormat('MMMM yyyy').format(date),
        stats['scheduled']!.toStringAsFixed(2),
        stats['worked']!.toStringAsFixed(2),
        (stats['worked']! - stats['scheduled']!).toStringAsFixed(2),
        stats['pay']!.toStringAsFixed(2),
      ]);
    });
    monthlyRows.sort((a, b) => a[0].compareTo(b[0]) == 0 ? a[1].compareTo(b[1]) : a[0].compareTo(b[0]));

    // Prepare Multi-Sheet Data
    final sheetsHeaders = {
      'Detailed Data': detailedHeaders,
      'Daily Summary': dailyHeaders,
      'Weekly Summary': weeklyHeaders,
      'Monthly Summary': monthlyHeaders,
    };

    final sheetsData = {
      'Detailed Data': detailedRows,
      'Daily Summary': dailyRows,
      'Weekly Summary': weeklyRows,
      'Monthly Summary': monthlyRows,
    };

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

  // Removed _exportConnectTeamStyle - consolidated into _exportTimesheets
  
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
      "Scheduled In",  // Scheduled start time
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
    final Map<String, Map<String, double>> dailyTotals = {}; // employee|date -> hours
    final Map<String, Map<String, double>> weeklyTotals = {}; // employee|week -> hours
    final Map<String, Map<String, double>> dailyScheduled = {}; // employee|date -> scheduled hours
    final Map<String, Map<String, double>> weeklyScheduled = {}; // employee|week -> scheduled hours
    final Map<String, Map<String, double>> dailyOvertime = {}; // employee|date -> overtime hours

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
    for (var entry in _filteredTimesheets) {
      final names = _splitName(entry.teacherName);
      final firstName = names[0];
      final lastName = names[1];

      // Parse dates
      DateTime? startDate;
      DateTime? endDate;
      try {
        startDate = _parseEntryDate(entry.date);
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
      if (entry.scheduledDurationMinutes != null && entry.scheduledDurationMinutes! > 0) {
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
        AppLogger.debug('Using actual hours as scheduled hours fallback for entry: ${entry.documentId}');
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
        scheduledIn,  // Scheduled start time
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
      final entry = _filteredTimesheets[i];
      final names = _splitName(entry.teacherName);
      final employeeKey = entry.teacherName;

      DateTime? entryDate;
      try {
        entryDate = _parseEntryDate(entry.date);
      } catch (e) {
        entryDate = DateTime.now();
      }

      final dateKey = DateFormat('yyyy-MM-dd').format(entryDate!);
      final weekKey = DateFormat('yyyy-MM-dd').format(_getWeekStart(entryDate));

      final dailyTotal = dailyTotals[employeeKey]?[dateKey] ?? 0.0;
      final weeklyTotal = weeklyTotals[employeeKey]?[weekKey] ?? 0.0;
      final dailyScheduledTotal = dailyScheduled[employeeKey]?[dateKey] ?? 0.0;
      final weeklyScheduledTotal = weeklyScheduled[employeeKey]?[weekKey] ?? 0.0;
      final weeklyOvertimeTotal = dailyOvertime[employeeKey]?.values.fold<double>(0.0, (a, b) => a + b) ?? 0.0;
      
      // Column indices (0-based):
      // 20: Daily difference, 21: Daily totals, 22: Weekly totals
      // 23: Total scheduled, 24: Total difference, 25: Total paid hours, 26: Total overtime
      rows[i][20] = (dailyTotal - dailyScheduledTotal).toStringAsFixed(2); // Daily difference
      rows[i][21] = dailyTotal.toStringAsFixed(2); // Daily totals
      rows[i][22] = weeklyTotal.toStringAsFixed(2); // Weekly totals
      rows[i][23] = weeklyScheduledTotal.toStringAsFixed(2); // Total scheduled
      rows[i][24] = (weeklyTotal - weeklyScheduledTotal).toStringAsFixed(2); // Total difference
      rows[i][25] = weeklyTotal.toStringAsFixed(2); // Total paid hours (same as weekly for now)
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
    final summaryHeaders = ['Teacher', 'Total Shifts', 'Total Hours', 'Avg Hours/Shift'];
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
    summaryRows.sort((a, b) => (double.tryParse(b[2].toString()) ?? 0).compareTo(double.tryParse(a[2].toString()) ?? 0));
    
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

  // Re-adding helper method for hour parsing as it is needed for duration calculation
  double _parseHoursToDecimal(String timeString) {
    try {
      if (timeString.isEmpty || timeString.trim().isEmpty) return 0.0;

      final sanitized = timeString
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'(hours|hour|hrs|hr)'), '')
          .trim();
      if (sanitized.isEmpty) return 0.0;

      if (!sanitized.contains(':')) {
        return double.tryParse(sanitized) ?? 0.0;
      }

      final parts = sanitized.split(':');
      if (parts.length != 2) return 0.0;

      final hours = int.tryParse(parts[0].trim()) ?? 0;
      final minutes = int.tryParse(parts[1].trim()) ?? 0;

      return hours + (minutes / 60.0);
    } catch (e) {
      return 0.0;
    }
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
      helpText: 'Select Date Range for Timesheet Review',
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
      setState(() {
        _selectedDateRange = result;
      });

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
                    'Showing ${_filteredTimesheets.length} timesheets from ${DateFormat('MMM dd').format(result.start)} - ${DateFormat('MMM dd, yyyy').format(result.end)}',
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

  Widget _buildDateRangeSelector() {
    final now = DateTime.now();
    final isCurrentMonth = _selectedDateRange == null ||
        (_selectedDateRange!.start.year == now.year &&
            _selectedDateRange!.start.month == now.month);

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedDateRange != null
                ? const Color(0xff0386FF)
                : Colors.grey.shade300,
            width: _selectedDateRange != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _selectedDateRange != null
              ? const Color(0xff0386FF).withOpacity(0.05)
              : Colors.white,
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => _selectDateRange(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xff0386FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Color(0xff0386FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDateRange != null
                                ? '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}'
                                : 'Tap to select date range',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _selectedDateRange != null
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _selectedDateRange != null
                                ? '${_selectedDateRange!.duration.inDays + 1} days selected'
                                : 'Currently showing: ${isCurrentMonth ? "This month" : "All time"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedDateRange != null
                                  ? const Color(0xff0386FF)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_calendar,
                      size: 18,
                      color: Color(0xff0386FF),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedDateRange != null)
              Container(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedDateRange = null;
                          });
                          _applyFilter(_selectedFilter);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Date filter cleared'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear Filter'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectDateRange(context),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Change'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0386FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xff0386FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Color(0xff0386FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timesheet Review',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Review and approve employee timesheets',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Export Button
                    ElevatedButton.icon(
                      onPressed: _exportTimesheets,
                      icon: const Icon(Icons.file_download, size: 18),
                      label: const Text('Export'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _filteredTimesheets.isNotEmpty
                            ? const Color(0xff10B981)
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xff0386FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_filteredTimesheets.length} timesheets',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff0386FF),
                        ),
                      ),
                    ),
                  ],
                ),
                // Bulk Actions Bar
                if (_showBulkActions) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xff0386FF).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_box, color: Color(0xff0386FF)),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedTimesheetIds.length} selected',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff0386FF),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _bulkApproveTimesheets,
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Approve All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _bulkRejectTimesheets,
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Reject All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedTimesheetIds.clear();
                              _showBulkActions = false;
                            });
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Filter Chips
                Row(
                  children: [
                    Icon(Icons.filter_list,
                        size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Filter by Status:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: _filterOptions.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return FilterChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xff0386FF),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) => _applyFilter(filter),
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xff0386FF),
                            checkmarkColor: Colors.white,
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xff0386FF)
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Teacher Filter
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Filter by Teacher:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedTeacherFilter,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        hint: Text(
                          'All Teachers',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Teachers', style: GoogleFonts.inter(fontSize: 13)),
                          ),
                          ..._availableTeachers.map((teacher) => DropdownMenuItem<String>(
                            value: teacher,
                            child: Text(teacher, style: GoogleFonts.inter(fontSize: 13)),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedTeacherFilter = value;
                          });
                          _applyFilter(_selectedFilter);
                        },
                      ),
                    ),
                    if (_selectedTeacherFilter != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        color: Colors.grey.shade600,
                        onPressed: () {
                          setState(() {
                            _selectedTeacherFilter = null;
                          });
                          _applyFilter(_selectedFilter);
                        },
                        tooltip: 'Clear teacher filter',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                // Date Range Picker
                _buildDateRangeSelector(),
              ],
            ),
          ),
          // Data Table Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTimesheets.isEmpty
                    ? Center(
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
                              'No timesheets found',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              'Try changing the filter or check back later',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SfDataGridTheme(
                          data: SfDataGridThemeData(
                            headerColor: Colors.grey.shade50,
                            gridLineColor: Colors.grey.shade200,
                            gridLineStrokeWidth: 1,
                          ),
                          child: SfDataGrid(
                            source: _dataSource!,
                            allowSorting: true,
                            allowFiltering: false,
                            gridLinesVisibility: GridLinesVisibility.both,
                            headerGridLinesVisibility: GridLinesVisibility.both,
                            columnWidthMode: ColumnWidthMode.fill,
                            columns: [
                              GridColumn(
                                columnName: 'select',
                                width: 60,
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.check_box_outline_blank,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              GridColumn(
                                columnName: 'teacher',
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.centerLeft,
                                  child: Text('Teacher',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              GridColumn(
                                columnName: 'date',
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.centerLeft,
                                  child: Text('Date',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              GridColumn(
                                columnName: 'student',
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.centerLeft,
                                  child: Text('Student',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              GridColumn(
                                columnName: 'hours',
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.center,
                                  child: Text('Hours',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              GridColumn(
                                columnName: 'payment',
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.center,
                                  child: Text('Payment',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              GridColumn(
                                columnName: 'source',
                                width: 120, // Fixed width to prevent overflow
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.center,
                                  child: Text('Source',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              GridColumn(
                                columnName: 'status',
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.center,
                                  child: Text('Status',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              GridColumn(
                                columnName: 'actions',
                                width: 140, // Fixed width to prevent overflow
                                label: Container(
                                  padding: const EdgeInsets.all(8.0),
                                  alignment: Alignment.center,
                                  child: Text('Actions',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class TimesheetReviewDataSource extends DataGridSource {
  List<TimesheetEntry> timesheets;
  final Function(TimesheetEntry) onApprove;
  final Function(TimesheetEntry) onReject;
  final Function(TimesheetEntry) onViewDetails;
  final Function(String, bool) onSelectionChanged;
  final Set<String> selectedIds;

  TimesheetReviewDataSource({
    required this.timesheets,
    required this.onApprove,
    required this.onReject,
    required this.onViewDetails,
    required this.onSelectionChanged,
    required this.selectedIds,
  });

  @override
  List<DataGridRow> get rows => timesheets.map<DataGridRow>((timesheet) {
        return DataGridRow(cells: [
          DataGridCell<TimesheetEntry>(columnName: 'select', value: timesheet),
          DataGridCell<String>(
              columnName: 'teacher', value: timesheet.teacherName),
          DataGridCell<String>(columnName: 'date', value: timesheet.date),
          DataGridCell<String>(columnName: 'student', value: timesheet.subject),
          DataGridCell<String>(
              columnName: 'hours', value: timesheet.totalHours),
          DataGridCell<double>(
              columnName: 'payment', value: _calculatePayment(timesheet)),
          DataGridCell<String>(
              columnName: 'source', value: timesheet.source ?? 'manual'),
          DataGridCell<TimesheetStatus>(
              columnName: 'status', value: timesheet.status),
          DataGridCell<TimesheetEntry>(columnName: 'actions', value: timesheet),
        ]);
      }).toList();

  double _calculatePayment(TimesheetEntry timesheet) {
    try {
      final parts = timesheet.totalHours.split(':');
      if (parts.length != 2) return 0.0;

      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final totalHoursDecimal = hours + (minutes / 60.0);

      return totalHoursDecimal * timesheet.hourlyRate;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    // Get timesheet entry for color coding
    final timesheet = row.getCells().firstWhere(
      (cell) => cell.columnName == 'select',
      orElse: () => row.getCells().first,
    ).value as TimesheetEntry?;
    
    // Determine row background color based on status
    Color rowColor = Colors.white;
    if (timesheet != null) {
      switch (timesheet.status) {
        case TimesheetStatus.approved:
          rowColor = const Color(0xFFF0FDF4); // Light green
          break;
        case TimesheetStatus.rejected:
          rowColor = const Color(0xFFFEF2F2); // Light red
          break;
        case TimesheetStatus.pending:
          rowColor = const Color(0xFFFFF7ED); // Light orange
          break;
        case TimesheetStatus.draft:
          rowColor = const Color(0xFFF9FAFB); // Light grey
          break;
      }
    }
    
    return DataGridRowAdapter(
      color: rowColor,
      cells: row.getCells().map<Widget>((dataGridCell) {
        if (dataGridCell.columnName == 'select') {
          final timesheet = dataGridCell.value as TimesheetEntry;
          final isSelected = selectedIds.contains(timesheet.documentId);

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Checkbox(
              value: isSelected,
              onChanged: (value) {
                onSelectionChanged(timesheet.documentId!, value ?? false);
              },
              activeColor: const Color(0xff0386FF),
            ),
          );
        } else if (dataGridCell.columnName == 'teacher') {
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(8.0),
            child: Text(
              dataGridCell.value.toString(),
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          );
        } else if (dataGridCell.columnName == 'payment') {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '\$${dataGridCell.value.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          );
        } else if (dataGridCell.columnName == 'source') {
          final source = dataGridCell.value as String;
          final isClockIn = source == 'clock_in';

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isClockIn
                    ? const Color(0xff10B981).withOpacity(0.1)
                    : const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isClockIn ? Icons.access_time : Icons.edit,
                    size: 12,
                    color: isClockIn
                        ? const Color(0xff10B981)
                        : const Color(0xff0386FF),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isClockIn ? 'Clock In' : 'Unclocked',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isClockIn
                            ? const Color(0xff10B981)
                            : const Color(0xff0386FF),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (dataGridCell.columnName == 'status') {
          final status = dataGridCell.value as TimesheetStatus;
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
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8.0),
            child: Container(
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
            ),
          );
        } else if (dataGridCell.columnName == 'actions') {
          final timesheet = dataGridCell.value as TimesheetEntry;

          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => onViewDetails(timesheet),
                  icon: const Icon(Icons.visibility, size: 18),
                  tooltip: 'View Details',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                if (timesheet.status == TimesheetStatus.pending) ...[
                  IconButton(
                    onPressed: () => onApprove(timesheet),
                    icon: const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                    tooltip: 'Approve',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    onPressed: () => onReject(timesheet),
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                    tooltip: 'Reject',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ],
            ),
          );
        } else {
          return Container(
            alignment: dataGridCell.columnName == 'hours'
                ? Alignment.center
                : Alignment.centerLeft,
            padding: const EdgeInsets.all(8.0),
            child: Text(
              dataGridCell.value.toString(),
              style: GoogleFonts.inter(),
            ),
          );
        }
      }).toList(),
    );
  }
}
