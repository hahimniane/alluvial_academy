import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_constants.dart' as constants;
import '../models/timesheet_entry.dart';

class TimesheetTable extends StatefulWidget {
  final List<dynamic>? clockInEntries;

  const TimesheetTable({
    super.key,
    this.clockInEntries,
  });

  @override
  State<TimesheetTable> createState() => _TimesheetTableState();
}

class _TimesheetTableState extends State<TimesheetTable> {
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
    _loadTimesheetData();
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
              breakDuration: '15 min', // Default break from clock-in
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
          breakDuration: data['break_duration'] ?? '15 min',
          totalHours: data['total_hours'] ?? '00:00',
          description: data['description'] ?? '',
          status: _parseStatus(data['status'] ?? 'draft'),
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
        'break_duration': entry.breakDuration,
        'total_hours': entry.totalHours,
        'description': entry.description,
        'status': entry.status.name,
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
            _buildDetailRow('Break Duration:', entry.breakDuration),
            _buildDetailRow('Total Hours:', entry.totalHours),
            _buildDetailRow('Status:', _getStatusText(entry.status)),
            if (entry.description.isNotEmpty)
              _buildDetailRow('Description:', entry.description),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                      columnName: 'break',
                      label: Container(
                        padding: const EdgeInsets.all(8.0),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Break',
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
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _selectDateRange(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
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
                          : 'Select custom range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _selectedDateRange != null
                            ? Colors.black87
                            : Colors.grey.shade600,
                      ),
                    ),
                    if (_selectedDateRange != null)
                      Text(
                        '${_selectedDateRange!.duration.inDays + 1} days selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: const Color(0xff0386FF),
              ),
            ],
          ),
        ),
      ),
    );
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
              try {
                DateTime entryDate = DateFormat('yyyy-MM-dd').parse(entry.date);
                return entryDate
                        .isAfter(startDate.subtract(const Duration(days: 1))) &&
                    entryDate.isBefore(startDate.add(const Duration(days: 1)));
              } catch (e) {
                return false;
              }
            }).toList();
            break;

          case 'This Week':
            startDate = now.subtract(Duration(days: now.weekday - 1));
            startDate =
                DateTime(startDate.year, startDate.month, startDate.day);
            filteredData = filteredData.where((entry) {
              try {
                DateTime entryDate = DateFormat('yyyy-MM-dd').parse(entry.date);
                return entryDate
                        .isAfter(startDate.subtract(const Duration(days: 1))) &&
                    entryDate.isBefore(now.add(const Duration(days: 1)));
              } catch (e) {
                return false;
              }
            }).toList();
            break;

          case 'This Month':
            startDate = DateTime(now.year, now.month, 1);
            filteredData = filteredData.where((entry) {
              try {
                DateTime entryDate = DateFormat('yyyy-MM-dd').parse(entry.date);
                return entryDate
                        .isAfter(startDate.subtract(const Duration(days: 1))) &&
                    entryDate.isBefore(DateTime(now.year, now.month + 1, 1));
              } catch (e) {
                return false;
              }
            }).toList();
            break;
        }
      }

      // Apply custom date range filter if selected
      if (_selectedDateRange != null) {
        filteredData = filteredData.where((entry) {
          try {
            DateTime entryDate = DateFormat('yyyy-MM-dd').parse(entry.date);
            return entryDate.isAfter(_selectedDateRange!.start
                    .subtract(const Duration(days: 1))) &&
                entryDate.isBefore(
                    _selectedDateRange!.end.add(const Duration(days: 1)));
          } catch (e) {
            return false;
          }
        }).toList();
      }

      // Sort by date (newest first)
      filteredData.sort((a, b) => b.date.compareTo(a.date));

      // Update the data source
      _timesheetDataSource = TimesheetDataSource(
        timesheetData: filteredData,
        onEdit: _editEntry,
        onView: _viewEntry,
      );
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
              );
            });

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Timesheet entry saved successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving entry: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _exportTimesheet() {
    // Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality will be implemented')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No draft entries to submit'),
            backgroundColor: Colors.orange,
          ),
        );
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
              breakDuration: timesheetData[i].breakDuration,
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
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${draftEntries.length} entries submitted for approval'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting timesheet: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2025),
      initialDateRange: _selectedDateRange,
      helpText: 'Select Date Range',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      saveText: 'Apply Range',
      builder: (context, child) {
        return Theme(
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
              ),
              dayStyle: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              yearStyle: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
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
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff0386FF),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedDateRange = result;
      });

      // Also apply the filter when date range is selected
      _filterTimesheetData(_selectedFilter);

      // Show feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Date range applied: ${DateFormat('MMM dd').format(result.start)} - ${DateFormat('MMM dd, yyyy').format(result.end)}',
          ),
          backgroundColor: const Color(0xff0386FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class TimesheetDataSource extends DataGridSource {
  List<DataGridRow> _timesheetData = [];
  final Function(TimesheetEntry)? onEdit;
  final Function(TimesheetEntry)? onView;

  TimesheetDataSource({
    required List<TimesheetEntry> timesheetData,
    this.onEdit,
    this.onView,
  }) {
    _timesheetData = timesheetData
        .map<DataGridRow>((entry) => DataGridRow(
              cells: [
                DataGridCell(columnName: 'date', value: entry),
                DataGridCell(columnName: 'subject', value: entry),
                DataGridCell(columnName: 'start', value: entry),
                DataGridCell(columnName: 'end', value: entry),
                DataGridCell(columnName: 'break', value: entry),
                DataGridCell(columnName: 'totalHours', value: entry),
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
            entry.breakDuration,
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

  @override
  void initState() {
    super.initState();
    _loadStudents();

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

      // Parse break duration
      final breakStr = entry.breakDuration.replaceAll(' min', '');
      _breakMinutes = int.tryParse(breakStr) ?? 30;
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
                          ? 'Edit Teaching Hours'
                          : 'Add Teaching Hours',
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
    return Row(
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
            onPressed: _saveEntry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Save Draft',
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
            onPressed: _saveAndSubmitEntry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Save & Submit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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

    if (_formKey.currentState!.validate()) {
      final entry = TimesheetEntry(
        documentId:
            widget.entry?.documentId, // Keep the same documentId when editing
        date: DateFormat('MMM dd, yyyy').format(_selectedDate),
        subject: _selectedStudent,
        start: _startTime.format(context),
        end: _endTime.format(context),
        breakDuration: '$_breakMinutes min',
        totalHours: _calculateTotalHours(),
        description: _descriptionController.text,
        status: TimesheetStatus.draft,
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

    if (_formKey.currentState!.validate()) {
      final entry = TimesheetEntry(
        documentId:
            widget.entry?.documentId, // Keep the same documentId when editing
        date: DateFormat('MMM dd, yyyy').format(_selectedDate),
        subject: _selectedStudent,
        start: _startTime.format(context),
        end: _endTime.format(context),
        breakDuration: '$_breakMinutes min',
        totalHours: _calculateTotalHours(),
        description: _descriptionController.text,
        status: TimesheetStatus.pending,
      );

      widget.onSave(entry);
      Navigator.of(context).pop();
    }
  }
}
