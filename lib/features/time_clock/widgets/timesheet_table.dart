import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_constants.dart' as constants;
import '../models/timesheet_entry.dart';
import '../../../core/services/location_service.dart';
import '../../../utility_functions/export_helpers.dart';

class TimesheetTable extends StatefulWidget {
  final List<dynamic>? clockInEntries;

  const TimesheetTable({
    super.key,
    this.clockInEntries,
  });

  @override
  State<TimesheetTable> createState() => _TimesheetTableState();

  // Static method to refresh data from outside
  static void refreshData(GlobalKey<State<TimesheetTable>> key) {
    final state = key.currentState;
    if (state != null && state is _TimesheetTableState) {
      state.refreshData();
    }
  }
}

class _TimesheetTableState extends State<TimesheetTable>
    with WidgetsBindingObserver {
  DateTimeRange? _selectedDateRange;
  List<TimesheetEntry> timesheetData = [];
  TimesheetDataSource? _timesheetDataSource;
  String _selectedFilter = 'All Time';

  final List<String> _filterOptions = [
    'All Time',
    'Today',
    'This Week',
    'This Month',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTimesheetData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh timesheet data when app comes back to foreground
    if (state == AppLifecycleState.resumed && mounted) {
      _loadTimesheetData();
    }
  }

  // Public method to manually refresh data
  void refreshData() {
    if (mounted) {
      print('TimesheetTable: Refreshing data from Firebase...');
      _loadTimesheetData();
    }
  }

  @override
  void didUpdateWidget(TimesheetTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh data when clock-in entries change
    if (widget.clockInEntries != oldWidget.clockInEntries) {
      _loadTimesheetData();
    }
  }

  void _loadTimesheetData() {
    // Load saved timesheet entries from Firebase first
    print('TimesheetTable: Loading timesheet entries from Firebase...');
    _loadSavedTimesheetEntries().then((savedEntries) {
      if (!mounted) return;

      // Convert clock-in entries to timesheet format (only if not already in Firebase)
      List<TimesheetEntry> clockInData = [];
      if (widget.clockInEntries != null) {
        for (var entry in widget.clockInEntries!) {
          // Handle both Map and TimesheetEntry objects
          if (entry is Map<String, dynamic>) {
            final clockInEntry = TimesheetEntry(
              date: entry['date'] ?? '',
              subject:
                  entry['type'] ?? '', // type field contains the student name
              start: entry['start'] ?? '',
              end: entry['end'] ?? '',
              totalHours: entry['totalHours'] ?? '00:00',
              description:
                  'Teaching session with ${entry['type'] ?? 'Unknown Student'}',
              status: TimesheetStatus.draft, // Clock-in entries start as draft
            );

            // Check if this entry already exists in Firebase entries
            bool existsInFirebase = savedEntries.any((firebaseEntry) =>
                firebaseEntry.date == clockInEntry.date &&
                firebaseEntry.subject == clockInEntry.subject &&
                firebaseEntry.start == clockInEntry.start &&
                firebaseEntry.end == clockInEntry.end);

            // Only add clock-in entry if it doesn't exist in Firebase
            if (!existsInFirebase) {
              clockInData.add(clockInEntry);
            }
          } else if (entry is TimesheetEntry) {
            clockInData.add(entry);
          }
        }
      }

      setState(() {
        // Combine Firebase entries (priority) with unique clock-in entries
        timesheetData = [...savedEntries, ...clockInData];
        _timesheetDataSource = TimesheetDataSource(
          timesheetData: timesheetData,
          onEdit: _editEntry,
          onView: _viewEntry,
          onSubmit: _submitEntry,
        );
      });
    });
  }

  Future<List<TimesheetEntry>> _loadSavedTimesheetEntries() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: user.uid)
          .get();

      List<TimesheetEntry> entries = [];
      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        entries.add(TimesheetEntry(
          documentId: doc.id, // Include the document ID
          date: data['date'] ?? '',
          subject: data['student_name'] ?? '',
          start: data['start_time'] ?? '',
          end: data['end_time'] ?? '',
          totalHours: data['total_hours'] ?? '00:00',
          description: data['description'] ?? '',
          status: _parseStatus(data['status'] ?? 'draft'),
          source: data['source'] as String? ?? 'manual',
          // Location data
          clockInLatitude: data['clock_in_latitude'] as double?,
          clockInLongitude: data['clock_in_longitude'] as double?,
          clockInAddress: data['clock_in_address'] as String?,
          clockOutLatitude: data['clock_out_latitude'] as double?,
          clockOutLongitude: data['clock_out_longitude'] as double?,
          clockOutAddress: data['clock_out_address'] as String?,
        ));
      }

      // Sort by created_at if available, otherwise by date
      entries.sort((a, b) {
        try {
          return b.date.compareTo(a.date); // Most recent first
        } catch (e) {
          return 0;
        }
      });

      return entries;
    } catch (e) {
      print('Error loading timesheet entries: $e');
      return [];
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

  String _getStatusText(TimesheetStatus status) {
    switch (status) {
      case TimesheetStatus.draft:
        return 'Draft';
      case TimesheetStatus.pending:
        return 'Pending';
      case TimesheetStatus.approved:
        return 'Approved';
      case TimesheetStatus.rejected:
        return 'Rejected';
    }
  }

  Future<void> _saveTimesheetEntry(TimesheetEntry entry) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final entryData = {
        'teacher_id': user.uid,
        'teacher_email': user.email,
        'date': entry.date,
        'student_name': entry.subject,
        'start_time': entry.start,
        'end_time': entry.end,
        'total_hours': entry.totalHours,
        'description': entry.description,
        'status': entry.status.name,
        'source': 'manual', // Mark as manually added entry
        // Location data (preserve existing values if available)
        'clock_in_latitude': entry.clockInLatitude,
        'clock_in_longitude': entry.clockInLongitude,
        'clock_in_address': entry.clockInAddress,
        'clock_out_latitude': entry.clockOutLatitude,
        'clock_out_longitude': entry.clockOutLongitude,
        'clock_out_address': entry.clockOutAddress,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (entry.documentId != null) {
        // Update existing entry
        await FirebaseFirestore.instance
            .collection('timesheet_entries')
            .doc(entry.documentId!)
            .update(entryData);
        print('Timesheet entry updated successfully');
      } else {
        // Create new entry
        entryData['created_at'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('timesheet_entries')
            .add(entryData);
        print('Timesheet entry created successfully');
      }
    } catch (e) {
      print('Error saving timesheet entry: $e');
      throw e;
    }
  }

  void _editEntry(TimesheetEntry entry) {
    showDialog(
      context: context,
      builder: (context) => TimesheetEntryDialog(
        entry: entry, // Pass the existing entry for editing
        onSave: (editedEntry) async {
          try {
            // Save edited entry to Firebase
            await _saveTimesheetEntry(editedEntry);

            // Reload timesheet data to reflect changes
            _loadTimesheetData();

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entry updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            // Show error message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating entry: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _submitEntry(TimesheetEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.send, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Submit for Review',
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to submit this timesheet entry for admin review?',
              style: constants.openSansHebrewTextStyle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Date:', entry.date),
                  _buildDetailRow('Student:', entry.subject),
                  _buildDetailRow('Hours:', entry.totalHours),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Once submitted, you cannot edit this entry until it\'s reviewed.',
                      style: constants.openSansHebrewTextStyle.copyWith(
                        fontSize: 12,
                        color: Colors.amber.shade700,
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit for Review'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update the entry status to pending
      final updatedEntry = TimesheetEntry(
        documentId: entry.documentId,
        date: entry.date,
        subject: entry.subject,
        start: entry.start,
        end: entry.end,
        totalHours: entry.totalHours,
        description: entry.description,
        status: TimesheetStatus.pending,
      );

      await _saveTimesheetEntry(updatedEntry);

      // Reload timesheet data
      _loadTimesheetData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Timesheet submitted for review successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error submitting timesheet: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _viewEntry(TimesheetEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Timesheet Entry Details',
          style: constants.openSansHebrewTextStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Date:', entry.date),
            _buildDetailRow('Student:', entry.subject),
            _buildDetailRow('Start Time:', entry.start),
            _buildDetailRow('End Time:', entry.end),
            _buildDetailRow('Total Hours:', entry.totalHours),
            _buildDetailRow('Status:', _getStatusText(entry.status)),
            if (entry.description.isNotEmpty)
              _buildDetailRow('Description:', entry.description),
            // Location information
            if (entry.clockInLatitude != null ||
                entry.clockOutLatitude != null) ...[
              const SizedBox(height: 8),
              _buildLocationSection(entry),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(TimesheetEntry entry) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xff10B981).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xff10B981),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Location Information',
                style: constants.openSansHebrewTextStyle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entry.clockInLatitude != null &&
              entry.clockInLongitude != null) ...[
            Text(
              '📍 Clock-in Location:',
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xff064E3B),
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<String>(
              future: _getDetailedLocationText(
                entry.clockInLatitude!,
                entry.clockInLongitude!,
                entry.clockInAddress,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text(
                    'Loading location...',
                    style: constants.openSansHebrewTextStyle.copyWith(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return Text(
                  snapshot.data ?? 'Location unavailable',
                  style: constants.openSansHebrewTextStyle.copyWith(
                    fontSize: 12,
                    color: const Color(0xff6B7280),
                  ),
                );
              },
            ),
          ],
          if (entry.clockOutLatitude != null &&
              entry.clockOutLongitude != null) ...[
            const SizedBox(height: 8),
            Text(
              '📍 Clock-out Location:',
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xff064E3B),
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<String>(
              future: _getDetailedLocationText(
                entry.clockOutLatitude!,
                entry.clockOutLongitude!,
                entry.clockOutAddress,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Text(
                    'Loading location...',
                    style: constants.openSansHebrewTextStyle.copyWith(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }
                return Text(
                  snapshot.data ?? 'Location unavailable',
                  style: constants.openSansHebrewTextStyle.copyWith(
                    fontSize: 12,
                    color: const Color(0xff6B7280),
                  ),
                );
              },
            ),
          ],
          if ((entry.clockInLatitude == null ||
                  entry.clockInLongitude == null) &&
              (entry.clockOutLatitude == null ||
                  entry.clockOutLongitude == null)) ...[
            Text(
              '⚠️ Location information was not captured for this session',
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 12,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          elevation: 4,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const Divider(height: 1),
              Expanded(
                child: SfDataGridTheme(
                  data: SfDataGridThemeData(
                    headerColor: Colors.grey[50],
                    gridLineColor: Colors.grey[300]!,
                    gridLineStrokeWidth: 1,
                  ),
                  child: SfDataGrid(
                    source: _timesheetDataSource ??
                        TimesheetDataSource(
                          timesheetData: [],
                          onEdit: _editEntry,
                          onView: _viewEntry,
                          onSubmit: _submitEntry,
                        ),
                    columnWidthMode: ColumnWidthMode.fill,
                    columns: [
                      GridColumn(
                        columnName: 'date',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Date',
                            style: constants.openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'subject',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Student',
                            style: constants.openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'start',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Start Time',
                            style: constants.openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'end',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'End Time',
                            style: constants.openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'totalHours',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Total Hours',
                            style: constants.openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'location',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Location',
                            style: constants.openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'status',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Status',
                            style: constants.openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      GridColumn(
                        columnName: 'actions',
                        label: Container(
                          padding: const EdgeInsets.all(8.0),
                          alignment: Alignment.center,
                          child: Text(
                            'Actions',
                            style: constants.openSansHebrewTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and main actions row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Icons.schedule,
                      color: Color(0xff0386FF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teaching Sessions',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Manage your teaching hours and sessions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.file_download_outlined,
                    label: 'Export',
                    onPressed: _exportTimesheet,
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.add,
                    label: 'Add Hours',
                    onPressed: _addNewEntry,
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.send,
                    label: 'Submit',
                    onPressed: _submitTimesheet,
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters section
          Row(
            children: [
              // Time period filters
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.filter_list,
                            size: 18, color: const Color(0xff0386FF)),
                        const SizedBox(width: 8),
                        Text(
                          'Filter by Period',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filterOptions.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return _buildFilterChip(filter, isSelected);
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Date range selector
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.date_range,
                            size: 18, color: const Color(0xff0386FF)),
                        const SizedBox(width: 8),
                        Text(
                          'Custom Date Range',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDateRangeSelector(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter, bool isSelected) {
    return Material(
      elevation: isSelected ? 3 : 1,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: FilterChip(
          label: Text(
            filter,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xff0386FF),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          selected: isSelected,
          onSelected: (bool selected) {
            setState(() {
              _selectedFilter = filter;
            });
            _filterTimesheetData(filter);
          },
          backgroundColor: Colors.white,
          selectedColor: const Color(0xff0386FF),
          checkmarkColor: Colors.white,
          side: BorderSide(
            color: isSelected ? const Color(0xff0386FF) : Colors.grey.shade300,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
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
                      child: Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: const Color(0xff0386FF),
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
                    Icon(
                      Icons.edit_calendar,
                      size: 18,
                      color: const Color(0xff0386FF),
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
                            _selectedFilter = 'All Time';
                          });
                          _filterTimesheetData('All Time');
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

  DateTime? _parseEntryDate(String dateString) {
    // Try multiple date formats to handle different sources
    final formats = [
      'yyyy-MM-dd', // Standard format: 2025-01-26
      'EEE MM/dd/yyyy', // Clock-in format with year: Mon 01/26/2025
      'EEE MM/dd', // Clock-in format without year: Mon 01/26
      'MM/dd/yyyy', // Simple format with year: 01/26/2025
      'MM/dd', // Simple format without year: 01/26
    ];

    for (String format in formats) {
      try {
        DateTime parsed = DateFormat(format).parse(dateString);

        // If the parsed date doesn't have a year (for formats without year),
        // assume it's the current year
        if (format == 'EEE MM/dd' || format == 'MM/dd') {
          parsed = DateTime(DateTime.now().year, parsed.month, parsed.day);
        }

        return parsed;
      } catch (e) {
        // Try next format
        continue;
      }
    }

    print('Could not parse date: $dateString');
    return null;
  }

  int _getFilteredEntriesCount(String filter) {
    List<TimesheetEntry> filteredData = [...timesheetData];

    // Apply time period filter
    if (filter != 'All Time') {
      DateTime now = DateTime.now();

      switch (filter) {
        case 'Today':
          filteredData = filteredData.where((entry) {
            DateTime? entryDate = _parseEntryDate(entry.date);
            if (entryDate == null) return false;

            return entryDate.year == now.year &&
                entryDate.month == now.month &&
                entryDate.day == now.day;
          }).toList();
          break;

        case 'This Week':
          DateTime startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          DateTime endDate = startDate.add(const Duration(days: 6));

          filteredData = filteredData.where((entry) {
            DateTime? entryDate = _parseEntryDate(entry.date);
            if (entryDate == null) return false;

            return entryDate
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entryDate.isBefore(endDate.add(const Duration(days: 1)));
          }).toList();
          break;

        case 'This Month':
          DateTime startDate = DateTime(now.year, now.month, 1);
          DateTime endDate = DateTime(now.year, now.month + 1, 1)
              .subtract(const Duration(days: 1));

          filteredData = filteredData.where((entry) {
            DateTime? entryDate = _parseEntryDate(entry.date);
            if (entryDate == null) return false;

            return entryDate
                    .isAfter(startDate.subtract(const Duration(days: 1))) &&
                entryDate.isBefore(endDate.add(const Duration(days: 1)));
          }).toList();
          break;

        case 'Custom Date Range':
          if (_selectedDateRange != null) {
            filteredData = filteredData.where((entry) {
              DateTime? entryDate = _parseEntryDate(entry.date);
              if (entryDate == null) return false;

              return entryDate.isAfter(_selectedDateRange!.start
                      .subtract(const Duration(days: 1))) &&
                  entryDate.isBefore(
                      _selectedDateRange!.end.add(const Duration(days: 1)));
            }).toList();
          }
          break;
      }
    }

    return filteredData.length;
  }

  void _filterTimesheetData(String filter) {
    print('Filtering by: $filter');

    setState(() {
      List<TimesheetEntry> filteredData = [...timesheetData];

      // Apply time period filter
      if (filter != 'All Time') {
        DateTime now = DateTime.now();
        DateTime startDate;

        switch (filter) {
          case 'Today':
            startDate = DateTime(now.year, now.month, now.day);
            filteredData = filteredData.where((entry) {
              DateTime? entryDate = _parseEntryDate(entry.date);
              if (entryDate == null) return false;

              return entryDate.year == now.year &&
                  entryDate.month == now.month &&
                  entryDate.day == now.day;
            }).toList();
            break;

          case 'This Week':
            startDate = now.subtract(Duration(days: now.weekday - 1));
            startDate =
                DateTime(startDate.year, startDate.month, startDate.day);
            DateTime endDate = startDate.add(const Duration(days: 6));

            filteredData = filteredData.where((entry) {
              DateTime? entryDate = _parseEntryDate(entry.date);
              if (entryDate == null) return false;

              return entryDate
                      .isAfter(startDate.subtract(const Duration(days: 1))) &&
                  entryDate.isBefore(endDate.add(const Duration(days: 1)));
            }).toList();
            break;

          case 'This Month':
            startDate = DateTime(now.year, now.month, 1);
            DateTime endDate = DateTime(now.year, now.month + 1, 1)
                .subtract(const Duration(days: 1));

            filteredData = filteredData.where((entry) {
              DateTime? entryDate = _parseEntryDate(entry.date);
              if (entryDate == null) return false;

              return entryDate.year == now.year && entryDate.month == now.month;
            }).toList();
            break;
        }
      }

      // Apply custom date range filter if selected
      if (_selectedDateRange != null) {
        filteredData = filteredData.where((entry) {
          DateTime? entryDate = _parseEntryDate(entry.date);
          if (entryDate == null) return false;

          return entryDate.isAfter(_selectedDateRange!.start
                  .subtract(const Duration(days: 1))) &&
              entryDate.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1)));
        }).toList();
      }

      // Sort by date (newest first) - use parsed dates for proper sorting
      filteredData.sort((a, b) {
        DateTime? dateA = _parseEntryDate(a.date);
        DateTime? dateB = _parseEntryDate(b.date);

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA);
      });

      // Update the data source
      _timesheetDataSource = TimesheetDataSource(
        timesheetData: filteredData,
        onEdit: _editEntry,
        onView: _viewEntry,
        onSubmit: _submitEntry,
      );

      print(
          'Filter applied. Total entries: ${timesheetData.length}, Filtered: ${filteredData.length}');
    });
  }

  void _addNewEntry() {
    showDialog(
      context: context,
      builder: (context) => TimesheetEntryDialog(
        onSave: (entry) async {
          try {
            // Save to Firebase
            await _saveTimesheetEntry(entry);

            // Update local state
            setState(() {
              timesheetData.add(entry);
              _timesheetDataSource = TimesheetDataSource(
                timesheetData: timesheetData,
                onEdit: _editEntry,
                onView: _viewEntry,
                onSubmit: _submitEntry,
              );
            });

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Timesheet entry saved successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            // Show error message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving entry: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _exportTimesheet() async {
    // Get current user information
    final user = FirebaseAuth.instance.currentUser;
    String teacherName = 'Unknown Teacher';

    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final firstName = userData['first_name'] ?? '';
          final lastName = userData['last_name'] ?? '';
          teacherName = '$firstName $lastName'.trim();
          if (teacherName.isEmpty) {
            teacherName = userData['e-mail'] ?? user.email ?? 'Current Teacher';
          }
        }
      } catch (e) {
        print('Error fetching teacher name: $e');
        teacherName = user.email ?? 'Current Teacher';
      }
    }

    List<String> headers = [
      "Date",
      "Student",
      "Start Time",
      "End Time",
      "Total Hours",
      "Description",
      "Status",
      "Teacher",
      "Location"
    ];

    List<List<String>> timesheetData = this
        .timesheetData
        .map((entry) => [
              entry.date,
              entry.subject,
              entry.start,
              entry.end,
              entry.totalHours,
              entry.description,
              entry.status.toString().split('.').last, // Get enum name
              entry.teacherName?.isNotEmpty == true
                  ? entry.teacherName!
                  : teacherName,
              entry.clockInAddress ?? 'Location not available',
            ])
        .toList();

    print('Exporting timesheet with teacher name: $teacherName');

    ExportHelpers.showExportDialog(
      context,
      headers,
      timesheetData,
      "timesheet_${DateTime.now().toString().split(' ')[0]}",
    );
  }

  void _submitTimesheet() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get all draft entries
      final draftEntries = timesheetData
          .where((entry) => entry.status == TimesheetStatus.draft)
          .toList();

      if (draftEntries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No draft entries to submit'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Update all draft entries to pending status in Firebase
      final batch = FirebaseFirestore.instance.batch();

      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'draft')
          .get();

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'status': 'pending',
          'submitted_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Update local state
      setState(() {
        for (int i = 0; i < timesheetData.length; i++) {
          if (timesheetData[i].status == TimesheetStatus.draft) {
            timesheetData[i] = TimesheetEntry(
              date: timesheetData[i].date,
              subject: timesheetData[i].subject,
              start: timesheetData[i].start,
              end: timesheetData[i].end,
              totalHours: timesheetData[i].totalHours,
              description: timesheetData[i].description,
              status: TimesheetStatus.pending,
            );
          }
        }
        _timesheetDataSource = TimesheetDataSource(
          timesheetData: timesheetData,
          onEdit: _editEntry,
          onView: _viewEntry,
          onSubmit: _submitEntry,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${draftEntries.length} entries submitted for approval'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting timesheet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);

    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5), // Allow 5 years into the future
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: currentMonthStart,
            end: currentMonthEnd,
          ), // Default to current month
      currentDate: now, // Highlight current date
      helpText: 'Select Date Range for Timesheet',
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
                          surfaceVariant: Colors.grey.shade50,
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
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      yearStyle: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      rangeSelectionBackgroundColor:
                          const Color(0xff0386FF).withOpacity(0.1),
                      rangeSelectionOverlayColor: MaterialStateProperty.all(
                        const Color(0xff0386FF).withOpacity(0.1),
                      ),
                      todayBackgroundColor: MaterialStateProperty.resolveWith(
                        (states) {
                          if (states.contains(MaterialState.selected)) {
                            return const Color(0xff0386FF);
                          }
                          return const Color(0xff0386FF).withOpacity(0.2);
                        },
                      ),
                      todayForegroundColor: MaterialStateProperty.resolveWith(
                        (states) {
                          if (states.contains(MaterialState.selected)) {
                            return Colors.white;
                          }
                          return const Color(0xff0386FF);
                        },
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      headerHeadlineStyle: const TextStyle(
                        fontSize: 20,
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
        _selectedFilter = 'Custom Date Range';
      });

      // Apply the custom date range filter
      _filterTimesheetData('Custom Date Range');

      // Show feedback to user with entry count
      final filteredCount = _getFilteredEntriesCount('Custom Date Range');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date filter applied',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${DateFormat('MMM dd').format(result.start)} - ${DateFormat('MMM dd, yyyy').format(result.end)} • $filteredCount entries',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xff10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<String> _getDetailedLocationText(
      double latitude, double longitude, String? storedAddress) async {
    // If we have a good stored address, use it
    if (storedAddress != null &&
        storedAddress.isNotEmpty &&
        !storedAddress.contains(RegExp(r'^\d+\.\d+, \d+\.\d+'))) {
      return storedAddress;
    }

    // Convert coordinates to full address using geocoding
    try {
      LocationData? locationData = await LocationService.coordinatesToLocation(
        latitude,
        longitude,
      );

      if (locationData != null &&
          locationData.address != 'Unknown location' &&
          !locationData.address.contains(RegExp(r'^\d+\.\d+, \d+\.\d+'))) {
        return locationData.address;
      }
    } catch (e) {
      print('Error getting detailed location: $e');
    }

    // Fallback to coordinates with more precision for detailed view
    return 'Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}

class TimesheetDataSource extends DataGridSource {
  List<DataGridRow> _timesheetData = [];
  final Function(TimesheetEntry)? onEdit;
  final Function(TimesheetEntry)? onView;
  final Function(TimesheetEntry)? onSubmit;

  TimesheetDataSource({
    required List<TimesheetEntry> timesheetData,
    this.onEdit,
    this.onView,
    this.onSubmit,
  }) {
    _timesheetData = timesheetData
        .map<DataGridRow>((entry) => DataGridRow(
              cells: [
                DataGridCell(columnName: 'date', value: entry),
                DataGridCell(columnName: 'subject', value: entry),
                DataGridCell(columnName: 'start', value: entry),
                DataGridCell(columnName: 'end', value: entry),
                DataGridCell(columnName: 'totalHours', value: entry),
                DataGridCell(columnName: 'location', value: entry),
                DataGridCell(columnName: 'status', value: entry),
                DataGridCell(columnName: 'actions', value: entry),
              ],
            ))
        .toList();
  }

  @override
  List<DataGridRow> get rows => _timesheetData;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final entry = row.getCells().first.value as TimesheetEntry;

    return DataGridRowAdapter(
      cells: [
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(
            entry.date,
            style: constants.openSansHebrewTextStyle,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(
            entry.subject,
            style: constants.openSansHebrewTextStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(
            entry.start,
            style: constants.openSansHebrewTextStyle,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(
            entry.end,
            style: constants.openSansHebrewTextStyle,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(
            entry.totalHours,
            style: constants.openSansHebrewTextStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: _buildLocationCell(entry),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(entry.status),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _getStatusText(entry.status),
              style: constants.openSansHebrewTextStyle.copyWith(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.status == TimesheetStatus.draft ||
                  entry.status == TimesheetStatus.rejected)
                IconButton(
                  onPressed: () => onEdit?.call(entry),
                  icon: const Icon(Icons.edit, size: 16),
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              if (entry.status == TimesheetStatus.draft)
                IconButton(
                  onPressed: () => onSubmit?.call(entry),
                  icon: const Icon(Icons.send, size: 16, color: Colors.blue),
                  tooltip: 'Submit for Review',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              IconButton(
                onPressed: () => onView?.call(entry),
                icon: const Icon(Icons.visibility, size: 16),
                tooltip: 'View Details',
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(TimesheetStatus status) {
    switch (status) {
      case TimesheetStatus.draft:
        return Colors.grey;
      case TimesheetStatus.pending:
        return Colors.orange;
      case TimesheetStatus.approved:
        return Colors.green;
      case TimesheetStatus.rejected:
        return Colors.red;
    }
  }

  String _getStatusText(TimesheetStatus status) {
    switch (status) {
      case TimesheetStatus.draft:
        return 'Draft';
      case TimesheetStatus.pending:
        return 'Pending';
      case TimesheetStatus.approved:
        return 'Approved';
      case TimesheetStatus.rejected:
        return 'Rejected';
    }
  }

  Widget _buildLocationCell(TimesheetEntry entry) {
    // Check if we have any location data
    bool hasClockInLocation =
        entry.clockInLatitude != null && entry.clockInLongitude != null;
    bool hasClockOutLocation =
        entry.clockOutLatitude != null && entry.clockOutLongitude != null;

    if (!hasClockInLocation && !hasClockOutLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off,
              size: 12,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              'Not captured',
              style: constants.openSansHebrewTextStyle.copyWith(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<String>(
      future: _getLocationDisplayText(entry),
      builder: (context, snapshot) {
        String locationText = 'Loading...';

        if (snapshot.connectionState == ConnectionState.done) {
          locationText = snapshot.data ?? 'Location unavailable';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xff10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xff10B981).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                size: 12,
                color: Color(0xff10B981),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  locationText,
                  style: constants.openSansHebrewTextStyle.copyWith(
                    fontSize: 11,
                    color: const Color(0xff064E3B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _getLocationDisplayText(TimesheetEntry entry) async {
    // Always try to convert coordinates to actual location names first
    if (entry.clockInLatitude != null && entry.clockInLongitude != null) {
      try {
        String locationName =
            await LocationService.getLocationDisplayFromCoordinates(
          entry.clockInLatitude!,
          entry.clockInLongitude!,
        );

        // Only use this result if it's not just coordinates
        if (locationName != 'Location unavailable' &&
            !locationName.startsWith('Lat:') &&
            !locationName.startsWith('Coordinates:') &&
            !locationName.contains(RegExp(r'^\d+\.\d+'))) {
          return locationName;
        }
      } catch (e) {
        print('Error converting coordinates to location: $e');
      }
    }

    // Fallback to stored address if geocoding failed but filter out coordinate strings
    if (entry.clockInAddress != null &&
        entry.clockInAddress!.isNotEmpty &&
        !entry.clockInAddress!.contains(RegExp(r'^\d+\.\d+')) &&
        !entry.clockInAddress!.toLowerCase().contains('lat') &&
        !entry.clockInAddress!.toLowerCase().contains('coordinates')) {
      return _extractNeighborhood(entry.clockInAddress!);
    }

    // Last resort: show coordinates in readable format
    if (entry.clockInLatitude != null && entry.clockInLongitude != null) {
      return 'Lat: ${entry.clockInLatitude!.toStringAsFixed(4)}, Lng: ${entry.clockInLongitude!.toStringAsFixed(4)}';
    }

    return 'Location unavailable';
  }

  String _extractNeighborhood(String fullAddress) {
    // Extract neighborhood from full address
    // Address format is usually: "Street, Neighborhood, City, State"
    final parts = fullAddress.split(', ');
    if (parts.length >= 2) {
      return parts[1]; // Return the neighborhood part
    } else if (parts.isNotEmpty) {
      return parts[0]; // Return first part if only one part
    }
    return 'Location';
  }
}

class TimesheetEntryDialog extends StatefulWidget {
  final Function(TimesheetEntry) onSave;
  final TimesheetEntry? entry;

  const TimesheetEntryDialog({
    super.key,
    required this.onSave,
    this.entry,
  });

  @override
  State<TimesheetEntryDialog> createState() => _TimesheetEntryDialogState();
}

class _TimesheetEntryDialogState extends State<TimesheetEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String _selectedStudent = '';
  int _breakMinutes = 30;
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoadingStudents = true;

  // Location data for manual entries
  LocationData? _currentLocation;
  bool _isGettingLocation = false;
  String _locationStatus = 'Getting location...';

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _getCurrentLocation(); // Get location when dialog opens

    if (widget.entry != null) {
      // Editing existing entry - populate fields
      final entry = widget.entry!;

      // Fix date parsing by using a proper format that includes year
      try {
        // Try to parse the date with year first
        _selectedDate = DateFormat('EEE MM/dd/yyyy')
            .parse('${entry.date}/${DateTime.now().year}');
        // If that fails, fall back to current year
        if (_selectedDate.year < 2020) {
          _selectedDate = DateTime(
              DateTime.now().year, _selectedDate.month, _selectedDate.day);
        }
      } catch (e) {
        _selectedDate = DateTime.now();
      }

      try {
        _startTime =
            TimeOfDay.fromDateTime(DateFormat('h:mm a').parse(entry.start));
      } catch (e) {
        _startTime = const TimeOfDay(hour: 9, minute: 0);
      }

      try {
        _endTime =
            TimeOfDay.fromDateTime(DateFormat('h:mm a').parse(entry.end));
      } catch (e) {
        _endTime = const TimeOfDay(hour: 13, minute: 0);
      }

      _selectedStudent = entry.subject;
      _descriptionController.text = entry.description;

      // Break duration removed - no longer used
      _breakMinutes = 0;
    } else {
      // Creating new entry - use defaults
      _selectedDate = DateTime.now();
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 13, minute: 0);
    }
  }

  Future<void> _loadStudents() async {
    try {
      final QuerySnapshot studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('user_type', isEqualTo: 'student')
          .get();

      setState(() {
        _students = studentsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name':
                '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
            'email': data['e-mail'] ?? '',
            'grade': data['grade'] ?? '',
            'kiosk_code': data['kiosk_code'] ?? '',
          };
        }).toList();

        _students.sort((a, b) => a['name'].compareTo(b['name']));
        _filteredStudents = List.from(_students);
        _isLoadingStudents = false;
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() {
        _isLoadingStudents = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationStatus = 'Getting location...';
    });

    try {
      LocationData? location = await LocationService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _currentLocation = location;
          _isGettingLocation = false;
          if (location != null) {
            _locationStatus =
                'Location: ${LocationService.formatLocationForDisplay(location.address, location.neighborhood)}';
          } else {
            _locationStatus = 'Location not available';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
          _locationStatus = 'Location error: $e';
        });
      }
    }
  }

  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = List.from(_students);
      } else {
        _filteredStudents = _students.where((student) {
          final name = student['name'].toLowerCase();
          final email = student['email'].toLowerCase();
          final grade = student['grade'].toString().toLowerCase();
          final kioskCode = student['kiosk_code'].toString().toLowerCase();
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) ||
              email.contains(searchLower) ||
              grade.contains(searchLower) ||
              kioskCode.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.entry != null
                          ? 'Edit Unclocked Hours'
                          : 'Add Unclocked Hours (Location Required)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date and Student Selection
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateSelector(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStudentSelector(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Time Selection
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimeSelector('Start Time', _startTime,
                                (time) {
                              setState(() => _startTime = time);
                            }),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTimeSelector('End Time', _endTime,
                                (time) {
                              setState(() => _endTime = time);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Break Duration
                      _buildBreakSelector(),
                      const SizedBox(height: 24),

                      // Description
                      _buildDescriptionField(),
                      const SizedBox(height: 24),

                      // Location Display
                      _buildLocationDisplay(),
                      const SizedBox(height: 24),

                      // Total Hours Display
                      _buildTotalHoursDisplay(),
                      const SizedBox(height: 32),

                      // Action Buttons
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today,
                size: 16, color: const Color(0xff0386FF)),
            const SizedBox(width: 8),
            Text(
              'Date',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () async {
              // Ensure we have a valid initial date
              DateTime initialDate = _selectedDate;
              if (initialDate.year < 2020 || initialDate.year > 2025) {
                initialDate = DateTime.now();
              }

              print('Showing date picker with initialDate: $initialDate');

              final date = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime(2025, 12, 31),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: const Color(0xff0386FF),
                          ),
                    ),
                    child: child!,
                  );
                },
              );

              print('Date picker returned: $date');

              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_month,
                      size: 20, color: const Color(0xff0386FF)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, size: 16, color: const Color(0xff0386FF)),
            const SizedBox(width: 8),
            Text(
              'Student',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingStudents)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('Loading students...',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          )
        else
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                // Search field
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search students...',
                      prefixIcon:
                          Icon(Icons.search, color: const Color(0xff0386FF)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: _filterStudents,
                  ),
                ),
                const SizedBox(height: 8),

                // Selected student display or student list
                if (_selectedStudent.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      border: Border.all(
                          color: const Color(0xff0386FF).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person,
                            color: const Color(0xff0386FF), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedStudent,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xff0386FF),
                                ),
                              ),
                              if (_students
                                  .any((s) => s['name'] == _selectedStudent))
                                Text(
                                  _students.firstWhere((s) =>
                                      s['name'] == _selectedStudent)['email'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedStudent = '';
                              _searchController.clear();
                              _filteredStudents = List.from(_students);
                            });
                          },
                          icon: Icon(Icons.clear, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  // Student list
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _filteredStudents.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No students found',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      const Color(0xff0386FF).withOpacity(0.1),
                                  child: Icon(
                                    Icons.person,
                                    color: const Color(0xff0386FF),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  student['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: student['email'].isNotEmpty
                                    ? Text(
                                        student['email'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      )
                                    : null,
                                trailing: student['grade'].toString().isNotEmpty
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xff0386FF)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Grade ${student['grade']}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xff0386FF),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedStudent = student['name'];
                                    _searchController.clear();
                                    _filteredStudents = List.from(_students);
                                  });
                                },
                              );
                            },
                          ),
                  ),

                // Validation message
                if (_selectedStudent.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 8, left: 16),
                    child: Text(
                      'Please select a student',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTimeSelector(
      String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, size: 16, color: const Color(0xff0386FF)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () async {
              final selectedTime = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (selectedTime != null) {
                onChanged(selectedTime);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    time.format(context),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.schedule,
                      size: 20, color: const Color(0xff0386FF)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.coffee, size: 16, color: const Color(0xff0386FF)),
            const SizedBox(width: 8),
            Text(
              'Break Duration',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<int>(
              value: _breakMinutes,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                suffixIcon:
                    Icon(Icons.expand_more, color: const Color(0xff0386FF)),
              ),
              onChanged: (value) {
                setState(() {
                  _breakMinutes = value!;
                });
              },
              items: [0, 15, 30, 45, 60, 90].map((minutes) {
                return DropdownMenuItem(
                  value: minutes,
                  child: Text('$minutes minutes'),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notes, size: 16, color: const Color(0xff0386FF)),
            const SizedBox(width: 8),
            Text(
              'Description (Optional)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter lesson details, notes, or observations...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xff0386FF), width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: const Color(0xff10B981)),
            const SizedBox(width: 8),
            Text(
              'Location Information (Required)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _currentLocation != null
                ? const Color(0xff10B981).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _currentLocation != null
                  ? const Color(0xff10B981).withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              if (_isGettingLocation)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xff10B981)),
                  ),
                )
              else
                Icon(
                  _currentLocation != null
                      ? Icons.location_on
                      : Icons.location_off,
                  color: _currentLocation != null
                      ? const Color(0xff10B981)
                      : Colors.grey[600],
                  size: 20,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentLocation != null
                          ? 'Location Captured'
                          : 'Location Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _currentLocation != null
                            ? const Color(0xff064E3B)
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _locationStatus,
                      style: TextStyle(
                        fontSize: 11,
                        color: _currentLocation != null
                            ? const Color(0xff6B7280)
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isGettingLocation && _currentLocation == null)
                TextButton(
                  onPressed: _getCurrentLocation,
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: const Color(0xff10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalHoursDisplay() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xff0386FF).withOpacity(0.1),
            const Color(0xff0386FF).withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff0386FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff0386FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.timer, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Teaching Hours',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _calculateTotalHours(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff0386FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool isLocationAvailable = _currentLocation != null;
    final bool isLocationLoading = _isGettingLocation;

    return Column(
      children: [
        // Warning message when location is not available
        if (!isLocationAvailable && !isLocationLoading)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location is mandatory for all timesheet entries. Please wait for location or grant permission.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isLocationAvailable ? _saveEntry : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLocationAvailable
                      ? Colors.orange
                      : Colors.grey.shade300,
                  foregroundColor:
                      isLocationAvailable ? Colors.white : Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isLocationAvailable ? 2 : 0,
                ),
                child: Text(
                  isLocationLoading ? 'Getting Location...' : 'Save Draft',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isLocationAvailable ? _saveAndSubmitEntry : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLocationAvailable
                      ? const Color(0xff0386FF)
                      : Colors.grey.shade300,
                  foregroundColor:
                      isLocationAvailable ? Colors.white : Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isLocationAvailable ? 2 : 0,
                ),
                child: Text(
                  isLocationLoading ? 'Getting Location...' : 'Save & Submit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _calculateTotalHours() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final totalMinutes = endMinutes - startMinutes - _breakMinutes;

    if (totalMinutes <= 0) return '00:00';

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _saveEntry() {
    // Custom validation for student selection
    if (_selectedStudent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a student'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mandatory location validation
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location is mandatory. Please wait for location to be captured or grant location permission.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final entry = TimesheetEntry(
        documentId:
            widget.entry?.documentId, // Keep the same documentId when editing
        date: DateFormat('MMM dd, yyyy').format(_selectedDate),
        subject: _selectedStudent,
        start: _startTime.format(context),
        end: _endTime.format(context),
        totalHours: _calculateTotalHours(),
        description: _descriptionController.text,
        status: TimesheetStatus.draft,
        // Include captured location data
        clockInLatitude: _currentLocation?.latitude,
        clockInLongitude: _currentLocation?.longitude,
        clockInAddress: _currentLocation?.address,
        clockOutLatitude: null, // Manual entries don't have clock-out location
        clockOutLongitude: null,
        clockOutAddress: null,
      );

      widget.onSave(entry);
      Navigator.of(context).pop();
    }
  }

  void _saveAndSubmitEntry() {
    // Custom validation for student selection
    if (_selectedStudent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a student'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mandatory location validation
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location is mandatory. Please wait for location to be captured or grant location permission.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final entry = TimesheetEntry(
        documentId:
            widget.entry?.documentId, // Keep the same documentId when editing
        date: DateFormat('MMM dd, yyyy').format(_selectedDate),
        subject: _selectedStudent,
        start: _startTime.format(context),
        end: _endTime.format(context),
        totalHours: _calculateTotalHours(),
        description: _descriptionController.text,
        status: TimesheetStatus.pending,
        // Include captured location data
        clockInLatitude: _currentLocation?.latitude,
        clockInLongitude: _currentLocation?.longitude,
        clockInAddress: _currentLocation?.address,
        clockOutLatitude: null, // Manual entries don't have clock-out location
        clockOutLongitude: null,
        clockOutAddress: null,
      );

      widget.onSave(entry);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
