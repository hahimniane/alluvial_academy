import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../../../core/models/enrollment_request.dart';
import '../../../core/services/enrollment_service.dart';
import '../../../utility_functions/export_helpers.dart';
import 'dart:async';

class EnrollmentManagementScreen extends StatefulWidget {
  const EnrollmentManagementScreen({super.key});

  @override
  State<EnrollmentManagementScreen> createState() => _EnrollmentManagementScreenState();
}

class _EnrollmentManagementScreenState extends State<EnrollmentManagementScreen> {
  List<EnrollmentRequest> _allEnrollments = [];
  List<EnrollmentRequest> _filteredEnrollments = [];
  EnrollmentDataSource? _dataSource;
  String _selectedFilter = 'Pending';
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;
  final Set<String> _selectedEnrollmentIds = {};
  bool _showBulkActions = false;

  // Real-time listener
  StreamSubscription<QuerySnapshot>? _enrollmentListener;

  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Contacted',
    'Enrolled',
  ];

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _enrollmentListener?.cancel();
    super.dispose();
  }

  /// Setup real-time listener for enrollment changes
  void _setupRealtimeListener() {
    setState(() => _isLoading = true);

    // Listen to real-time changes in enrollments collection
    _enrollmentListener = FirebaseFirestore.instance
        .collection('enrollments')
        .orderBy('metadata.submittedAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      await _processEnrollmentSnapshot(snapshot);
    }, onError: (error) {
      print('Error in enrollment listener: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  /// Process enrollment snapshot and update UI in real-time
  Future<void> _processEnrollmentSnapshot(QuerySnapshot snapshot) async {
    try {
      List<EnrollmentRequest> enrollments = [];

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        try {
          final enrollment = EnrollmentRequest.fromFirestore(doc);
          enrollments.add(enrollment);
        } catch (e) {
          print('Error parsing enrollment ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _allEnrollments = enrollments;
          _applyFilter(_selectedFilter);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error processing enrollment snapshot: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _selectedEnrollmentIds.clear();

      List<EnrollmentRequest> statusFiltered;
      if (filter == 'All') {
        statusFiltered = List.from(_allEnrollments);
      } else {
        statusFiltered = _allEnrollments
            .where((enrollment) => enrollment.status.toLowerCase() == filter.toLowerCase())
            .toList();
      }

      // Apply date range filter if selected
      if (_selectedDateRange != null) {
        statusFiltered = statusFiltered.where((enrollment) {
          return enrollment.submittedAt.isAfter(
                  _selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              enrollment.submittedAt.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1)));
        }).toList();
      }

      _filteredEnrollments = statusFiltered;
      _showBulkActions = _selectedEnrollmentIds.isNotEmpty;

      _dataSource = EnrollmentDataSource(
        enrollments: _filteredEnrollments,
        onStatusUpdate: _updateEnrollmentStatus,
        onViewDetails: _viewEnrollmentDetails,
        onSelectionChanged: _onEnrollmentSelectionChanged,
        selectedIds: _selectedEnrollmentIds,
      );
    });
  }

  void _onEnrollmentSelectionChanged(String enrollmentId, bool selected) {
    setState(() {
      if (selected) {
        _selectedEnrollmentIds.add(enrollmentId);
      } else {
        _selectedEnrollmentIds.remove(enrollmentId);
      }
      _showBulkActions = _selectedEnrollmentIds.isNotEmpty;
    });
  }

  Future<void> _updateEnrollmentStatus(String enrollmentId, String newStatus, {String? notes}) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final enrollmentRef = FirebaseFirestore.instance.collection('enrollments').doc(enrollmentId);
      
      await enrollmentRef.update({
        'metadata.status': newStatus,
        'metadata.reviewedBy': currentUser.uid,
        'metadata.reviewedAt': FieldValue.serverTimestamp(),
        if (notes != null && notes.isNotEmpty) 'metadata.reviewNotes': notes,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewEnrollmentDetails(EnrollmentRequest enrollment) {
    showDialog(
      context: context,
      builder: (context) => _EnrollmentDetailsDialog(enrollment: enrollment),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _applyFilter(_selectedFilter);
      });
    }
  }

  Future<void> _exportEnrollments() async {
    try {
      final headers = [
        'ID',
        'Subject',
        'Language',
        'Grade Level',
        'Email',
        'Phone',
        'Country',
        'Preferred Days',
        'Preferred Time Slots',
        'Timezone',
        'Status',
        'Submitted At',
        'Reviewed By',
        'Review Notes'
      ];

      final rows = _filteredEnrollments.map((e) => [
        e.id ?? '',
        e.subject ?? '',
        e.specificLanguage ?? '',
        e.gradeLevel,
        e.email,
        e.phoneNumber,
        e.countryName,
        e.preferredDays.join(', '),
        e.preferredTimeSlots.join(', '),
        e.timeZone,
        e.status,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(e.submittedAt),
        e.reviewedBy ?? '',
        e.reviewNotes ?? '',
      ]).toList();

      ExportHelpers.showExportDialog(
        context,
        headers,
        rows,
        'enrollments_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEnrollments.isEmpty
                    ? _buildEmptyState()
                    : _buildDataGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Color(0xff3B82F6), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enrollment Management',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                Text(
                  '${_allEnrollments.length} total enrollments',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (_showBulkActions) ...[
            ElevatedButton.icon(
              onPressed: () async {
                for (var id in _selectedEnrollmentIds) {
                  await _updateEnrollmentStatus(id, 'Contacted');
                }
                setState(() {
                  _selectedEnrollmentIds.clear();
                  _showBulkActions = false;
                });
              },
              icon: const Icon(Icons.mark_email_read),
              label: const Text('Mark as Contacted'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: _exportEnrollments,
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          ..._filterOptions.map((filter) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: _selectedFilter == filter,
                  onSelected: (selected) {
                    if (selected) _applyFilter(filter);
                  },
                  selectedColor: const Color(0xff3B82F6).withOpacity(0.2),
                  checkmarkColor: const Color(0xff3B82F6),
                ),
              )),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              _selectedDateRange == null
                  ? 'Select Date Range'
                  : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
            ),
          ),
          if (_selectedDateRange != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDateRange = null;
                  _applyFilter(_selectedFilter);
                });
              },
              child: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No enrollments found',
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataGrid() {
    return SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: const Color(0xffF3F4F6),
        gridLineColor: Colors.grey.shade200,
      ),
      child: SfDataGrid(
        source: _dataSource!,
        columnWidthMode: ColumnWidthMode.fill,
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        columns: [
          GridColumn(
            columnName: 'checkbox',
            width: 60,
            label: Container(
              alignment: Alignment.center,
              child: Checkbox(
                value: _selectedEnrollmentIds.length == _filteredEnrollments.length &&
                    _filteredEnrollments.isNotEmpty,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedEnrollmentIds.addAll(
                          _filteredEnrollments.map((e) => e.id!).where((id) => id.isNotEmpty));
                    } else {
                      _selectedEnrollmentIds.clear();
                    }
                    _showBulkActions = _selectedEnrollmentIds.isNotEmpty;
                  });
                },
              ),
            ),
          ),
          GridColumn(
            columnName: 'subject',
            width: 150,
            label: _buildHeaderCell('Subject'),
          ),
          GridColumn(
            columnName: 'email',
            width: 200,
            label: _buildHeaderCell('Email'),
          ),
          GridColumn(
            columnName: 'phone',
            width: 150,
            label: _buildHeaderCell('Phone'),
          ),
          GridColumn(
            columnName: 'grade',
            width: 150,
            label: _buildHeaderCell('Grade Level'),
          ),
          GridColumn(
            columnName: 'status',
            width: 120,
            label: _buildHeaderCell('Status'),
          ),
          GridColumn(
            columnName: 'submitted',
            width: 180,
            label: _buildHeaderCell('Submitted'),
          ),
          GridColumn(
            columnName: 'actions',
            width: 160,
            label: _buildHeaderCell('Actions'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xff374151),
        ),
      ),
    );
  }
}

class EnrollmentDataSource extends DataGridSource {
  final List<EnrollmentRequest> enrollments;
  final Function(String, String, {String? notes}) onStatusUpdate;
  final Function(EnrollmentRequest) onViewDetails;
  final Function(String, bool) onSelectionChanged;
  final Set<String> selectedIds;

  EnrollmentDataSource({
    required this.enrollments,
    required this.onStatusUpdate,
    required this.onViewDetails,
    required this.onSelectionChanged,
    required this.selectedIds,
  }) {
    _enrollmentData = enrollments
        .map((enrollment) => DataGridRow(
              cells: [
                DataGridCell<String>(columnName: 'checkbox', value: enrollment.id ?? ''),
                DataGridCell<String>(columnName: 'subject', value: enrollment.subject ?? ''),
                DataGridCell<String>(columnName: 'email', value: enrollment.email),
                DataGridCell<String>(columnName: 'phone', value: enrollment.phoneNumber),
                DataGridCell<String>(columnName: 'grade', value: enrollment.gradeLevel),
                DataGridCell<String>(columnName: 'status', value: enrollment.status),
                DataGridCell<DateTime>(columnName: 'submitted', value: enrollment.submittedAt),
                DataGridCell<String>(columnName: 'actions', value: enrollment.id ?? ''),
              ],
            ))
        .toList();
  }

  List<DataGridRow> _enrollmentData = [];

  @override
  List<DataGridRow> get rows => _enrollmentData;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final enrollment = enrollments.firstWhere(
      (e) => e.id == row.getCells()[0].value,
      orElse: () => enrollments.first,
    );
    final isSelected = selectedIds.contains(enrollment.id);

    return DataGridRowAdapter(
      cells: row.getCells().map((cell) {
        if (cell.columnName == 'checkbox') {
          return Container(
            alignment: Alignment.center,
            child: Checkbox(
              value: isSelected,
              onChanged: (value) {
                if (enrollment.id != null) {
                  onSelectionChanged(enrollment.id!, value ?? false);
                }
              },
            ),
          );
        } else if (cell.columnName == 'status') {
          Color statusColor;
          switch (enrollment.status.toLowerCase()) {
            case 'pending':
              statusColor = Colors.orange;
              break;
            case 'contacted':
              statusColor = Colors.blue;
              break;
            case 'enrolled':
              statusColor = Colors.green;
              break;
            default:
              statusColor = Colors.grey;
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                enrollment.status,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          );
        } else if (cell.columnName == 'submitted') {
          return Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.centerLeft,
            child: Text(
              DateFormat('MMM d, yyyy HH:mm').format(cell.value as DateTime),
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff374151)),
            ),
          );
        } else if (cell.columnName == 'actions') {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 20),
                  onPressed: () => onViewDetails(enrollment),
                  tooltip: 'View Details',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (value) {
                    if (value == 'contacted') {
                      onStatusUpdate(enrollment.id!, 'Contacted');
                    } else if (value == 'enrolled') {
                      onStatusUpdate(enrollment.id!, 'Enrolled');
                    } else if (value == 'pending') {
                      onStatusUpdate(enrollment.id!, 'Pending');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'contacted', child: Text('Mark as Contacted')),
                    const PopupMenuItem(value: 'enrolled', child: Text('Mark as Enrolled')),
                    const PopupMenuItem(value: 'pending', child: Text('Mark as Pending')),
                  ],
                ),
              ],
            ),
          );
        } else {
          return Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.centerLeft,
            child: Text(
              cell.value.toString(),
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff374151)),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }
      }).toList(),
    );
  }
}

class _EnrollmentDetailsDialog extends StatelessWidget {
  final EnrollmentRequest enrollment;

  const _EnrollmentDetailsDialog({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Enrollment Details',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow('Subject', enrollment.subject ?? 'N/A'),
              if (enrollment.specificLanguage != null)
                _buildDetailRow('Specific Language', enrollment.specificLanguage!),
              _buildDetailRow('Grade Level', enrollment.gradeLevel),
              _buildDetailRow('Email', enrollment.email),
              _buildDetailRow('Phone', enrollment.phoneNumber),
              _buildDetailRow('Country', '${enrollment.countryName} (${enrollment.countryCode})'),
              _buildDetailRow('Preferred Days', enrollment.preferredDays.join(', ')),
              _buildDetailRow('Preferred Time Slots', enrollment.preferredTimeSlots.join(', ')),
              _buildDetailRow('Timezone', enrollment.timeZone),
              _buildDetailRow('Status', enrollment.status),
              _buildDetailRow('Submitted', DateFormat('MMM d, yyyy HH:mm:ss').format(enrollment.submittedAt)),
              if (enrollment.reviewedBy != null)
                _buildDetailRow('Reviewed By', enrollment.reviewedBy!),
              if (enrollment.reviewedAt != null)
                _buildDetailRow('Reviewed At', DateFormat('MMM d, yyyy HH:mm:ss').format(enrollment.reviewedAt!)),
              if (enrollment.reviewNotes != null)
                _buildDetailRow('Review Notes', enrollment.reviewNotes!),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            width: 150,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

