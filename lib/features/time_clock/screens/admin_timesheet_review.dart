import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../models/timesheet_entry.dart';
import '../../../core/constants/app_constants.dart' as constants;

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
    _loadTimesheets();
  }

  Future<void> _loadTimesheets() async {
    setState(() => _isLoading = true);

    try {
      // Load all timesheet entries with user information
      final QuerySnapshot timesheetSnapshot = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .orderBy('created_at', descending: true)
          .get();

      List<TimesheetEntry> timesheets = [];

      for (QueryDocumentSnapshot doc in timesheetSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Get user information for hourly rate
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['teacher_id'])
            .get();

        final userData = userDoc.data() as Map<String, dynamic>?;
        final hourlyRate =
            userData?['hourly_rate'] as double? ?? 15.0; // Default rate
        final userName =
            '${userData?['first_name'] ?? ''} ${userData?['last_name'] ?? ''}'
                .trim();

        timesheets.add(TimesheetEntry(
          documentId: doc.id,
          date: data['date'] ?? '',
          subject: data['student_name'] ?? '',
          start: data['start_time'] ?? '',
          end: data['end_time'] ?? '',
          breakDuration: data['break_duration'] ?? '15 min',
          totalHours: data['total_hours'] ?? '00:00',
          description: data['description'] ?? '',
          status: _parseStatus(data['status'] ?? 'draft'),
          teacherId: data['teacher_id'] ?? '',
          teacherName: userName,
          hourlyRate: hourlyRate,
          createdAt: data['created_at'] as Timestamp?,
          submittedAt: data['submitted_at'] as Timestamp?,
        ));
      }

      setState(() {
        _allTimesheets = timesheets;
        _applyFilter(_selectedFilter);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading timesheets: $e');
      setState(() => _isLoading = false);
    }
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

      if (filter == 'All') {
        _filteredTimesheets = List.from(_allTimesheets);
      } else {
        TimesheetStatus targetStatus = _parseStatus(filter);
        _filteredTimesheets = _allTimesheets
            .where((timesheet) => timesheet.status == targetStatus)
            .toList();
      }

      _dataSource = TimesheetReviewDataSource(
        timesheets: _filteredTimesheets,
        onApprove: _approveTimesheet,
        onReject: _rejectTimesheet,
        onViewDetails: _viewTimesheetDetails,
      );
    });
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
      _loadTimesheets();
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
      _loadTimesheets();
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
              _buildDetailRow('Break Duration:', timesheet.breakDuration),
              _buildDetailRow('Total Hours:', timesheet.totalHours),
              _buildDetailRow('Hourly Rate:',
                  '\$${timesheet.hourlyRate.toStringAsFixed(2)}'),
              _buildDetailRow('Calculated Payment:',
                  '\$${_calculatePayment(timesheet).toStringAsFixed(2)}'),
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

  TimesheetReviewDataSource({
    required this.timesheets,
    required this.onApprove,
    required this.onReject,
    required this.onViewDetails,
  });

  @override
  List<DataGridRow> get rows => timesheets.map<DataGridRow>((timesheet) {
        return DataGridRow(cells: [
          DataGridCell<String>(
              columnName: 'teacher', value: timesheet.teacherName),
          DataGridCell<String>(columnName: 'date', value: timesheet.date),
          DataGridCell<String>(columnName: 'student', value: timesheet.subject),
          DataGridCell<String>(
              columnName: 'hours', value: timesheet.totalHours),
          DataGridCell<double>(
              columnName: 'payment', value: _calculatePayment(timesheet)),
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
        if (dataGridCell.columnName == 'teacher') {
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
