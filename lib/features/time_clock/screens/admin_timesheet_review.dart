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

    final confirmed = await _showBulkApprovalDialog(selectedTimesheets);
    if (!confirmed) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      double totalPayment = 0.0;

      for (var timesheet in selectedTimesheets) {
        final payment = _calculatePayment(timesheet);
        totalPayment += payment;

        batch.update(
          FirebaseFirestore.instance
              .collection('timesheet_entries')
              .doc(timesheet.documentId!),
          {
            'status': 'approved',
            'approved_at': FieldValue.serverTimestamp(),
            'payment_amount': payment,
            'updated_at': FieldValue.serverTimestamp(),
          },
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

  Future<void> _approveTimesheet(TimesheetEntry timesheet) async {
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
      // Real-time listener will automatically update the UI
    } catch (e) {
      _showErrorSnackBar('Error approving timesheet: $e');
    }
  }

  Future<void> _rejectTimesheet(TimesheetEntry timesheet) async {
    final reason = await _showRejectionDialog();
    if (reason == null) return;

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
      // Real-time listener will automatically update the UI
    } catch (e) {
      _showErrorSnackBar('Error rejecting timesheet: $e');
    }
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
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  Text('Timesheet Details',
                      style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  _buildStatusChip(timesheet.status),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Teacher:', timesheet.teacherName),
              _buildDetailRow('Date:', timesheet.date),
              _buildDetailRow('Student:', timesheet.subject),
              _buildDetailRow('Start Time:', timesheet.start),
              _buildDetailRow('End Time:', timesheet.end),
              _buildDetailRow('Total Hours:', timesheet.totalHours),
              _buildDetailRow('Description:', timesheet.description),
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
              const SizedBox(height: 24),
              Row(
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
    // Sheet 1: Classes (Raw Data)
    final classesHeaders = [
      "Teacher",
      "Student/Group",
      "Date",
      "Start Time",
      "End Time",
      "Duration (Hrs)",
      "Hourly Rate",
      "Amount",
      "Week Start Date",
      "Week Label",
      "Month Start Date",
      "Month Label",
      "Status"
    ];

    List<List<dynamic>> classesData = [];

    // Maps for aggregation
    // Key: Teacher|WeekStart -> Amount
    final Map<String, double> weeklyEarnings = {};
    // Key: Teacher|MonthStart -> Amount
    final Map<String, double> monthlyEarnings = {};

    // Helper to store metadata for sorting later
    final Map<String, DateTime> weekStartDates = {};
    final Map<String, DateTime> monthStartDates = {};
    final Map<String, String> teacherNames = {};

    AppLogger.debug(
        'Processing ${_filteredTimesheets.length} timesheet entries for advanced export...');

    for (var entry in _filteredTimesheets) {
      // Parse date
      DateTime? entryDate;
      try {
        entryDate = _parseEntryDate(entry.date);
      } catch (e) {
        AppLogger.warning('Could not parse date for export: ${entry.date}');
      }
      entryDate ??= DateTime.now();

      // Calculate Week Start (Monday)
      final weekStart =
          entryDate.subtract(Duration(days: entryDate.weekday - 1));
      final weekStartKey = DateFormat('yyyy-MM-dd').format(weekStart);
      final weekLabel = 'Week of ${DateFormat('yyyy-MM-dd').format(weekStart)}';

      // Calculate Month Start
      final monthStart = DateTime(entryDate.year, entryDate.month, 1);
      final monthStartKey = DateFormat('yyyy-MM-dd').format(monthStart);
      final monthLabel = DateFormat('MMM yyyy').format(monthStart);

      // Calculate payment
      final hours = _parseHoursToDecimal(entry.totalHours);
      final payment = _calculatePayment(entry);

      // Add to Classes Data
      classesData.add([
        entry.teacherName,
        entry.subject,
        entryDate, // DateTime object
        entry.start, // String (Time)
        entry.end, // String (Time)
        hours, // double
        entry.hourlyRate, // double
        payment, // double
        weekStart, // DateTime object
        weekLabel,
        monthStart, // DateTime object
        monthLabel,
        entry.status.toString().split('.').last,
      ]);

      // Aggregate Weekly
      final weeklyKey = '${entry.teacherName}|$weekStartKey';
      weeklyEarnings[weeklyKey] = (weeklyEarnings[weeklyKey] ?? 0.0) + payment;
      weekStartDates[weeklyKey] = weekStart;
      teacherNames[weeklyKey] = entry.teacherName;

      // Aggregate Monthly
      final monthlyKey = '${entry.teacherName}|$monthStartKey';
      monthlyEarnings[monthlyKey] =
          (monthlyEarnings[monthlyKey] ?? 0.0) + payment;
      monthStartDates[monthlyKey] = monthStart;
      // teacherNames map can be reused or separate if needed, but teacher name is part of key
    }

    // Sheet 2: Weekly Earnings
    final weeklyHeaders = [
      "Teacher",
      "Week Start Date",
      "Week Label",
      "Weekly Total"
    ];

    List<List<dynamic>> weeklyData = [];
    for (var key in weeklyEarnings.keys) {
      final teacher = key.split('|')[0];
      final date = weekStartDates[key]!;
      final total = weeklyEarnings[key]!;
      final label = 'Week of ${DateFormat('yyyy-MM-dd').format(date)}';

      weeklyData.add([teacher, date, label, total]);
    }

    // Sort Weekly: Teacher (A-Z), then Date (Oldest-Newest)
    weeklyData.sort((a, b) {
      final teacherCompare = (a[0] as String).compareTo(b[0] as String);
      if (teacherCompare != 0) return teacherCompare;
      return (a[1] as DateTime).compareTo(b[1] as DateTime);
    });

    // Sheet 3: Monthly Earnings
    final monthlyHeaders = [
      "Teacher",
      "Month Start Date",
      "Month Label",
      "Monthly Total"
    ];

    List<List<dynamic>> monthlyData = [];
    for (var key in monthlyEarnings.keys) {
      final teacher = key.split('|')[0];
      final date = monthStartDates[key]!;
      final total = monthlyEarnings[key]!;
      final label = DateFormat('MMM yyyy').format(date);

      monthlyData.add([teacher, date, label, total]);
    }

    // Sort Monthly: Teacher (A-Z), then Date (Oldest-Newest)
    monthlyData.sort((a, b) {
      final teacherCompare = (a[0] as String).compareTo(b[0] as String);
      if (teacherCompare != 0) return teacherCompare;
      return (a[1] as DateTime).compareTo(b[1] as DateTime);
    });

    // Prepare Multi-Sheet Data
    final sheetsHeaders = {
      'Classes': classesHeaders,
      'Weekly Earnings': weeklyHeaders,
      'Monthly Earnings': monthlyHeaders,
    };

    final sheetsData = {
      'Classes': classesData,
      'Weekly Earnings': weeklyData,
      'Monthly Earnings': monthlyData,
    };

    String fileName = 'timesheet_export_advanced';
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

  /// ConnectTeam-style export with detailed columns
  void _exportConnectTeamStyle() {
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
                    // Export Button with dropdown
                    Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(12),
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'advanced') {
                            _exportTimesheets();
                          } else if (value == 'connectteam') {
                            _exportConnectTeamStyle();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'advanced',
                            child: Text('Advanced Export (Multi-sheet)'),
                          ),
                          const PopupMenuItem(
                            value: 'connectteam',
                            child: Text('ConnectTeam Style Export'),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _filteredTimesheets.isNotEmpty
                                ? const Color(0xff10B981)
                                : Colors.grey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.file_download,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              const Text(
                                'Export',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down,
                                  size: 18, color: Colors.white),
                            ],
                          ),
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
    return DataGridRowAdapter(
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
