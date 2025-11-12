import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../models/timesheet_entry.dart';
import '../../../core/constants/app_constants.dart' as constants;
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

  /// Legacy load method (now replaced by real-time listener)
  Future<void> _loadTimesheets() async {
    // This method is kept for manual refresh but real-time listener handles most updates
    _setupRealtimeListener();
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
    List<String> headers = [
      "Teacher",
      "Date",
      "Student",
      "Start Time",
      "End Time",
      "Total Hours",
      "Hourly Rate",
      "Payment Amount",
      "Status",
      "Source",
      "Submitted Date",
      "Approved Date",
      "Rejected Date",
      "Rejection Reason",
      "Description"
    ];

    // Calculate totals per teacher with weekly and monthly breakdowns
    final Map<String, Map<String, dynamic>> teacherTotals = {};
    
    // Track processed entries to avoid duplicates
    final Set<String> processedEntryIds = {};

    AppLogger.debug('Processing ${_filteredTimesheets.length} timesheet entries for totals...');
    
    for (var entry in _filteredTimesheets) {
      // Create unique ID for this entry to prevent duplicates (prefer documentId)
      final entryId = entry.documentId ??
          '${entry.teacherId}|${entry.date}|${entry.start}|${entry.end}|${entry.totalHours}';
      
      if (processedEntryIds.contains(entryId)) {
        AppLogger.warning('Warning: Duplicate entry detected and skipped: $entryId');
        continue;
      }
      processedEntryIds.add(entryId);
      
      final teacherKey = '${entry.teacherName} (ID: ${entry.teacherId})';
      
      if (!teacherTotals.containsKey(teacherKey)) {
        teacherTotals[teacherKey] = {
          'totalHours': 0.0,
          'totalPayment': 0.0,
          'weeklyTotals': <String, double>{},
          'monthlyTotals': <String, double>{},
          'entries': <TimesheetEntry>[],
        };
      }
      
      // Parse total hours (format: "HH:MM" or decimal) with validation
      final hours = _parseHoursToDecimal(entry.totalHours);
      
      // Log suspicious entries
      if (hours == 0.0 && entry.totalHours.isNotEmpty) {
        AppLogger.warning(
            'Warning: Entry for ${entry.teacherName} on ${entry.date} (${entry.start}-${entry.end}) with time "${entry.totalHours}" was parsed as 0 hours (skipping)');
        continue; // Skip entries that can't be parsed sanely
      }
      
      final payment = _calculatePayment(entry);
      
      // Add to overall totals
      teacherTotals[teacherKey]!['totalHours'] = 
          (teacherTotals[teacherKey]!['totalHours'] as double) + hours;
      teacherTotals[teacherKey]!['totalPayment'] = 
          (teacherTotals[teacherKey]!['totalPayment'] as double) + payment;
      
      // Calculate week and month keys
      // Try to parse date - handle multiple possible formats
      DateTime? entryDate;
      try {
        // Try 'yyyy-MM-dd' format first
        entryDate = DateFormat('yyyy-MM-dd').parse(entry.date);
      } catch (e) {
        try {
          // Try 'MMM dd, yyyy' format (e.g., "Nov 02, 2025")
          entryDate = DateFormat('MMM dd, yyyy').parse(entry.date);
        } catch (e2) {
          try {
            // Try 'MM/dd/yyyy' format
            entryDate = DateFormat('MM/dd/yyyy').parse(entry.date);
          } catch (e3) {
            AppLogger.error('Warning: Could not parse date "${entry.date}". Using current date.');
            entryDate = DateTime.now();
          }
        }
      }
      
      final weekKey = _getWeekKey(entryDate);
      final monthKey = DateFormat('MMM yyyy').format(entryDate);
      
      // Add to weekly totals
      final weeklyTotals = teacherTotals[teacherKey]!['weeklyTotals'] as Map<String, double>;
      weeklyTotals[weekKey] = (weeklyTotals[weekKey] ?? 0.0) + hours;
      
      // Add to monthly totals
      final monthlyTotals = teacherTotals[teacherKey]!['monthlyTotals'] as Map<String, double>;
      monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0.0) + hours;
      
      // Store entry
      (teacherTotals[teacherKey]!['entries'] as List<TimesheetEntry>).add(entry);
    }

    // Sort teachers by total hours (descending)
    final sortedTeachers = teacherTotals.keys.toList()
      ..sort((a, b) => (teacherTotals[b]!['totalHours'] as double)
          .compareTo(teacherTotals[a]!['totalHours'] as double));

    // Build export data with summary sections
    List<List<String>> timesheetData = [];
    
    // Add summary header
    timesheetData.add(['═══════════════════════════════════════════════════════════════', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
    timesheetData.add(['TEACHER SUMMARY - TOTAL HOURS BY TEACHER', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
    timesheetData.add(['═══════════════════════════════════════════════════════════════', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
    timesheetData.add(['']);
    
    // Add teacher summary rows
    for (var teacherKey in sortedTeachers) {
      final data = teacherTotals[teacherKey]!;
      final totalHours = data['totalHours'] as double;
      final totalPayment = data['totalPayment'] as double;
      
      timesheetData.add([
        teacherKey,
        '',
        '',
        '',
        '',
        '${totalHours.toStringAsFixed(2)} hours',
        '',
        '\$${totalPayment.toStringAsFixed(2)}',
        'TOTAL',
        '',
        '',
        '',
        '',
        '',
        ''
      ]);
      
      // Add monthly breakdowns
      final monthlyTotals = data['monthlyTotals'] as Map<String, double>;
      final sortedMonths = monthlyTotals.keys.toList()..sort();
      for (var month in sortedMonths) {
        timesheetData.add([
          '  → $month',
          '',
          '',
          '',
          '',
          '${monthlyTotals[month]!.toStringAsFixed(2)} hours',
          '',
          '',
          'Monthly Total',
          '',
          '',
          '',
          '',
          '',
          ''
        ]);
      }
      
      // Add weekly breakdowns
      final weeklyTotals = data['weeklyTotals'] as Map<String, double>;
      final sortedWeeks = weeklyTotals.keys.toList()..sort();
      for (var week in sortedWeeks) {
        timesheetData.add([
          '    ↳ $week',
          '',
          '',
          '',
          '',
          '${weeklyTotals[week]!.toStringAsFixed(2)} hours',
          '',
          '',
          'Weekly Total',
          '',
          '',
          '',
          '',
          '',
          ''
        ]);
      }
      
      timesheetData.add(['']); // Blank row between teachers
    }

    // Add detailed entries section
    timesheetData.add(['']);
    timesheetData.add(['═══════════════════════════════════════════════════════════════', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
    timesheetData.add(['DETAILED TIMESHEET ENTRIES', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
    timesheetData.add(['═══════════════════════════════════════════════════════════════', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
    timesheetData.add(['']);
    
    // Add all individual entries
    for (var entry in _filteredTimesheets) {
      timesheetData.add([
        entry.teacherName,
        entry.date,
        entry.subject,
        entry.start,
        entry.end,
        entry.totalHours,
        '\$${entry.hourlyRate.toStringAsFixed(2)}',
        '\$${_calculatePayment(entry).toStringAsFixed(2)}',
        entry.status.toString().split('.').last,
        entry.source == 'clock_in' ? 'Clock In' : 'Unclocked Hours',
        entry.submittedAt != null
            ? DateFormat('MMM dd, yyyy').format(entry.submittedAt!.toDate())
            : '',
        entry.approvedAt != null
            ? DateFormat('MMM dd, yyyy').format(entry.approvedAt!.toDate())
            : '',
        entry.rejectedAt != null
            ? DateFormat('MMM dd, yyyy').format(entry.rejectedAt!.toDate())
            : '',
        entry.rejectionReason ?? '',
        entry.description,
      ]);
    }

    AppLogger.debug('═══════════════════════════════════════');
    AppLogger.debug('Export Summary:');
    AppLogger.debug('  Total entries processed: ${_filteredTimesheets.length}');
    AppLogger.debug('  Unique entries: ${processedEntryIds.length}');
    AppLogger.debug('  Duplicates skipped: ${_filteredTimesheets.length - processedEntryIds.length}');
    AppLogger.debug('  Teachers found: ${teacherTotals.length}');
    for (var teacherKey in sortedTeachers) {
      final data = teacherTotals[teacherKey]!;
      final totalHours = data['totalHours'] as double;
      AppLogger.debug('  - $teacherKey: ${totalHours.toStringAsFixed(2)} hours');
    }
    AppLogger.debug('═══════════════════════════════════════');

    String fileName = 'timesheet_review_with_totals';
    if (_selectedDateRange != null) {
      fileName +=
          '_${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)}_to_${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}';
    } else {
      fileName += '_${_selectedFilter.toLowerCase()}';
    }
    fileName += '_${DateTime.now().toString().split(' ')[0]}';

    ExportHelpers.showExportDialog(
      context,
      headers,
      timesheetData,
      fileName,
    );
  }
  
  // Helper method to parse hours to decimal
  // Supports:
  //  - HH:MM format (e.g., "01:30")
  //  - Decimal format (e.g., "2.5")
  //  - Strings with units (e.g., "3.25 hours")
  // Includes validation to guard against corrupted values
  double _parseHoursToDecimal(String timeString) {
    try {
      if (timeString.isEmpty || timeString.trim().isEmpty) {
        AppLogger.warning('Warning: Empty timeString, returning 0.0');
        return 0.0;
      }
      
      final trimmed = timeString.trim();
      // Remove any trailing text such as "hours", "hrs", etc.
      final sanitized = trimmed
          .toLowerCase()
          .replaceAll(RegExp(r'(hours|hour|hrs|hr)'), '')
          .trim();

      if (sanitized.isEmpty) {
        AppLogger.warning('Warning: Sanitized timeString is empty for "$timeString"');
        return 0.0;
      }
      
      // Check if it's already a decimal number (e.g., "2.5" or "488406.25")
      if (sanitized.contains('.') && !sanitized.contains(':')) {
        final decimalValue = double.parse(sanitized);
        
        // Validate: if it's an unreasonably large number, it's corrupted
        if (decimalValue > 24.0) {
          AppLogger.error(
              'ERROR: Suspicious decimal hours value "$decimalValue" in "$timeString". This appears to be corrupted data. Skipping entry.');
          return 0.0;
        }
        
        return decimalValue;
      }
      
      // Otherwise, parse as HH:MM format
      final parts = sanitized.split(':');
      if (parts.length != 2) {
        AppLogger.warning(
            'Warning: Invalid time format "$timeString" - expected HH:MM or decimal, returning 0.0');
        return 0.0;
      }
      
      final hoursStr = parts[0].trim();
      final minutesStr = parts[1].trim();
      
      if (hoursStr.isEmpty || minutesStr.isEmpty) {
        AppLogger.warning(
            'Warning: Empty hours or minutes in "$timeString", returning 0.0');
        return 0.0;
      }
      
      final hours = int.parse(hoursStr);
      final minutes = int.parse(minutesStr);
      
      // Validate: hours should be reasonable (max 24 hours per day)
      // If hours > 24, it's likely corrupted data - log and return 0
      if (hours > 24) {
        AppLogger.error(
            'ERROR: Suspicious hours value "$hours" in "$timeString". This appears to be corrupted data. Skipping entry.');
        return 0.0;
      }
      
      // Validate: minutes should be 0-59
      if (minutes < 0 || minutes >= 60) {
        AppLogger.warning(
            'Warning: Invalid minutes "$minutes" in "$timeString", returning 0.0');
        return 0.0;
      }
      
      final result = hours + (minutes / 60.0);
      
      // Final sanity check: total should not exceed 24 hours per day
      if (result > 24.0) {
        AppLogger.error(
            'ERROR: Calculated hours "$result" exceeds 24 hours for "$timeString". This appears to be corrupted data. Skipping entry.');
        return 0.0;
      }
      
      return result;
    } catch (e) {
      AppLogger.error('Error parsing timeString "$timeString": $e');
      return 0.0;
    }
  }
  
  // Helper method to get week key (e.g., "Week of Jan 01, 2025")
  String _getWeekKey(DateTime date) {
    // Get Monday of the week
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return 'Week of ${DateFormat('MMM dd, yyyy').format(monday)}';
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
                    Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(12),
                      child: ElevatedButton.icon(
                        onPressed: _filteredTimesheets.isNotEmpty
                            ? _exportTimesheets
                            : null,
                        icon: const Icon(Icons.file_download, size: 18),
                        label: const Text(
                          'Export',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isClockIn
                    ? const Color(0xff10B981).withOpacity(0.1)
                    : const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isClockIn ? Icons.access_time : Icons.edit,
                    size: 12,
                    color: isClockIn
                        ? const Color(0xff10B981)
                        : const Color(0xff0386FF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isClockIn ? 'Clock In' : 'Unclocked',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isClockIn
                          ? const Color(0xff10B981)
                          : const Color(0xff0386FF),
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
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => onViewDetails(timesheet),
                  icon: const Icon(Icons.visibility, size: 18),
                  tooltip: 'View Details',
                ),
                if (timesheet.status == TimesheetStatus.pending) ...[
                  IconButton(
                    onPressed: () => onApprove(timesheet),
                    icon: const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                    tooltip: 'Approve',
                  ),
                  IconButton(
                    onPressed: () => onReject(timesheet),
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                    tooltip: 'Reject',
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
