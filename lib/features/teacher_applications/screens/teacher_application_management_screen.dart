import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../../../core/models/teacher_application.dart';
import '../../../core/services/user_role_service.dart';
import '../../../utility_functions/export_helpers.dart';
import 'dart:async';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TeacherApplicationManagementScreen extends StatefulWidget {
  const TeacherApplicationManagementScreen({super.key});

  @override
  State<TeacherApplicationManagementScreen> createState() => _TeacherApplicationManagementScreenState();
}

class _TeacherApplicationManagementScreenState extends State<TeacherApplicationManagementScreen> {
  List<TeacherApplication> _allApplications = [];
  List<TeacherApplication> _filteredApplications = [];
  ApplicationDataSource? _dataSource;
  String _selectedFilter = 'Pending';
  bool _isLoading = true;
  bool _hasAccess = true;
  DateTimeRange? _selectedDateRange;
  final Set<String> _selectedApplicationIds = {};
  bool _showBulkActions = false;

  // Real-time listener
  StreamSubscription<QuerySnapshot>? _applicationListener;

  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Reviewed',
    'Approved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _checkAccessAndInitialize();
  }

  @override
  void dispose() {
    _applicationListener?.cancel();
    super.dispose();
  }

  Future<void> _checkAccessAndInitialize() async {
    try {
      final role = await UserRoleService.getCurrentUserRole();
      final lower = role?.toLowerCase();
      final isAdmin = lower == 'admin' || lower == 'super_admin';

      if (!mounted) return;

      if (!isAdmin) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      _setupRealtimeListener();
    } catch (e) {
      AppLogger.error('TeacherApplications: error checking access: $e');
      if (!mounted) return;
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
    }
  }

  void _setupRealtimeListener() {
    setState(() => _isLoading = true);

    _applicationListener = FirebaseFirestore.instance
        .collection('teacher_applications')
        .orderBy('submitted_at', descending: true)
        .snapshots()
        .listen((snapshot) async {
      await _processSnapshot(snapshot);
    }, onError: (error) {
      AppLogger.error('TeacherApplications: listener error: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _processSnapshot(QuerySnapshot snapshot) async {
    try {
      List<TeacherApplication> applications = [];

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        try {
          final application = TeacherApplication.fromFirestore(doc);
          applications.add(application);
        } catch (e) {
          AppLogger.error('TeacherApplications: error parsing application ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _allApplications = applications;
          _applyFilter(_selectedFilter);
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('TeacherApplications: error processing snapshot: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _selectedApplicationIds.clear();

      List<TeacherApplication> statusFiltered;
      if (filter == 'All') {
        statusFiltered = List.from(_allApplications);
      } else {
        statusFiltered = _allApplications
            .where((app) => app.status.toLowerCase() == filter.toLowerCase())
            .toList();
      }

      if (_selectedDateRange != null) {
        statusFiltered = statusFiltered.where((app) {
          return app.submittedAt.isAfter(
                  _selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              app.submittedAt.isBefore(
                  _selectedDateRange!.end.add(const Duration(days: 1)));
        }).toList();
      }

      _filteredApplications = statusFiltered;
      _showBulkActions = _selectedApplicationIds.isNotEmpty;

      _dataSource = ApplicationDataSource(
        applications: _filteredApplications,
        onStatusUpdate: _updateStatus,
        onViewDetails: _viewDetails,
        onSelectionChanged: _onSelectionChanged,
        selectedIds: _selectedApplicationIds,
        localizations: AppLocalizations.of(context)!,
      );
    });
  }

  void _onSelectionChanged(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedApplicationIds.add(id);
      } else {
        _selectedApplicationIds.remove(id);
      }
      _showBulkActions = _selectedApplicationIds.isNotEmpty;
    });
  }

  Future<void> _updateStatus(String id, String newStatus, {String? notes}) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorYouMustBeLoggedIn)),
        );
        return;
      }

      final ref = FirebaseFirestore.instance.collection('teacher_applications').doc(id);
      
      await ref.update({
        'status': newStatus,
        'reviewed_by': currentUser.uid,
        'reviewed_at': FieldValue.serverTimestamp(),
        if (notes != null && notes.isNotEmpty) 'review_notes': notes,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.statusUpdatedToNewstatus(newStatus)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorUpdatingStatusE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewDetails(TeacherApplication application) {
    showDialog(
      context: context,
      builder: (context) => _ApplicationDetailsDialog(application: application),
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

  Future<void> _exportApplications() async {
    try {
      final headers = [
        'ID', 'Name', 'Email', 'Phone', 'Location', 'Nationality', 
        'Programs', 'Languages', 'Status', 'Submitted At'
      ];

      final rows = _filteredApplications.map((app) => [
        app.id ?? '',
        app.fullName,
        app.email,
        app.phoneNumber,
        app.currentLocation,
        app.nationality,
        app.teachingPrograms.join(', '),
        app.languages.join(', '),
        app.status,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(app.submittedAt),
      ]).toList();

      ExportHelpers.showExportDialog(
        context,
        headers,
        rows,
        'teacher_applications_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorExportingE)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return Scaffold(
        backgroundColor: Color(0xffF8FAFC),
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.accessRestricted,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xff6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApplications.isEmpty
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
          const Icon(Icons.people_alt, color: Color(0xff8B5CF6), size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                AppLocalizations.of(context)!.teacherApplicants,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
                Text(
                  '${_allApplications.length} total applications',
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
                for (var id in _selectedApplicationIds) {
                  await _updateStatus(id, 'Reviewed');
                }
                setState(() {
                  _selectedApplicationIds.clear();
                  _showBulkActions = false;
                });
              },
              icon: const Icon(Icons.check_circle_outline),
              label: Text(AppLocalizations.of(context)!.markAsReviewed),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff8B5CF6),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: _exportApplications,
            icon: const Icon(Icons.download),
            tooltip: AppLocalizations.of(context)!.exportToCsv,
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
                  selectedColor: const Color(0xff8B5CF6).withOpacity(0.2),
                  checkmarkColor: const Color(0xff8B5CF6),
                ),
              )),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              _selectedDateRange == null
                  ? AppLocalizations.of(context)!.selectDateRange
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
              child: Text(AppLocalizations.of(context)!.commonClear),
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
            AppLocalizations.of(context)!.noApplicationsFound,
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
                value: _selectedApplicationIds.length == _filteredApplications.length &&
                    _filteredApplications.isNotEmpty,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedApplicationIds.addAll(
                          _filteredApplications.map((e) => e.id!).where((id) => id.isNotEmpty));
                    } else {
                      _selectedApplicationIds.clear();
                    }
                    _showBulkActions = _selectedApplicationIds.isNotEmpty;
                  });
                },
              ),
            ),
          ),
          GridColumn(
            columnName: 'name',
            width: 180,
            label: _buildHeaderCell('Name'),
          ),
          GridColumn(
            columnName: 'programs',
            width: 150,
            label: _buildHeaderCell('Programs'),
          ),
          GridColumn(
            columnName: 'languages',
            width: 150,
            label: _buildHeaderCell('Languages'),
          ),
          GridColumn(
            columnName: 'location',
            width: 150,
            label: _buildHeaderCell('Location'),
          ),
          GridColumn(
            columnName: 'status',
            width: 120,
            label: _buildHeaderCell('Status'),
          ),
          GridColumn(
            columnName: 'submitted',
            width: 150,
            label: _buildHeaderCell('Submitted'),
          ),
          GridColumn(
            columnName: 'actions',
            width: 140,
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

class ApplicationDataSource extends DataGridSource {
  final List<TeacherApplication> applications;
  final Function(String, String, {String? notes}) onStatusUpdate;
  final Function(TeacherApplication) onViewDetails;
  final Function(String, bool) onSelectionChanged;
  final Set<String> selectedIds;
  final AppLocalizations localizations;

  ApplicationDataSource({
    required this.applications,
    required this.onStatusUpdate,
    required this.onViewDetails,
    required this.onSelectionChanged,
    required this.selectedIds,
    required this.localizations,
  }) {
    _data = applications
        .map((app) => DataGridRow(
              cells: [
                DataGridCell<String>(columnName: 'checkbox', value: app.id ?? ''),
                DataGridCell<String>(columnName: 'name', value: app.fullName),
                DataGridCell<String>(columnName: 'programs', value: app.teachingPrograms.join(', ')),
                DataGridCell<String>(columnName: 'languages', value: app.languages.join(', ')),
                DataGridCell<String>(columnName: 'location', value: app.currentLocation),
                DataGridCell<String>(columnName: 'status', value: app.status),
                DataGridCell<DateTime>(columnName: 'submitted', value: app.submittedAt),
                DataGridCell<String>(columnName: 'actions', value: app.id ?? ''),
              ],
            ))
        .toList();
  }

  List<DataGridRow> _data = [];

  @override
  List<DataGridRow> get rows => _data;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final app = applications.firstWhere(
      (e) => e.id == row.getCells()[0].value,
      orElse: () => applications.first,
    );
    final isSelected = selectedIds.contains(app.id);

    return DataGridRowAdapter(
      cells: row.getCells().map((cell) {
        if (cell.columnName == 'checkbox') {
          return Container(
            alignment: Alignment.center,
            child: Checkbox(
              value: isSelected,
              onChanged: (value) {
                if (app.id != null) {
                  onSelectionChanged(app.id!, value ?? false);
                }
              },
            ),
          );
        } else if (cell.columnName == 'status') {
          Color statusColor;
          switch (app.status.toLowerCase()) {
            case 'pending':
              statusColor = Colors.orange;
              break;
            case 'reviewed':
              statusColor = Colors.blue;
              break;
            case 'approved':
              statusColor = Colors.green;
              break;
            case 'rejected':
              statusColor = Colors.red;
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
                app.status,
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
              DateFormat('MMM d, yyyy').format(cell.value as DateTime),
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
                  icon: const Icon(Icons.visibility, size: 18),
                  onPressed: () => onViewDetails(app),
                  tooltip: localizations.shiftViewDetails,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (value) => onStatusUpdate(app.id!, value),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'Reviewed', child: Text(localizations.markAsReviewed)),
                    PopupMenuItem(value: 'Approved', child: Text(localizations.approve)),
                    PopupMenuItem(value: 'Rejected', child: Text(localizations.reject)),
                    PopupMenuItem(value: 'Pending', child: Text(localizations.markAsPending)),
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

class _ApplicationDetailsDialog extends StatelessWidget {
  final TeacherApplication application;

  const _ApplicationDetailsDialog({required this.application});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
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
                      AppLocalizations.of(context)!.applicationDetails,
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
              SizedBox(height: 16),
              _buildSection('Personal Info'),
              _buildDetailRow('Name', application.fullName),
              _buildDetailRow('Email', application.email),
              _buildDetailRow('Phone', application.phoneNumber),
              _buildDetailRow('Location', application.currentLocation),
              _buildDetailRow('Nationality', application.nationality),
              _buildDetailRow('Gender', application.gender),
              _buildDetailRow('Status', application.currentStatus),
              
              const SizedBox(height: 16),
              _buildSection('Teaching Program'),
              _buildDetailRow('Programs', application.teachingPrograms.join(', ')),
              if (application.englishSubjects != null && application.englishSubjects!.isNotEmpty)
                _buildDetailRow('English Subjects', application.englishSubjects!.join(', ')),
              _buildDetailRow('Languages', application.languages.join(', ')),
              
              if (application.isIslamicStudiesProgram) ...[
                const SizedBox(height: 16),
                _buildSection('Islamic Studies'),
                if (application.tajwidLevel != null)
                  _buildDetailRow('Tajwid Level', application.tajwidLevel!),
                if (application.quranMemorization != null)
                  _buildDetailRow('Quran Memorization', application.quranMemorization!),
                if (application.arabicProficiency != null)
                  _buildDetailRow('Arabic Proficiency', application.arabicProficiency!),
              ],

              const SizedBox(height: 16),
              _buildSection('Experience & Commitment'),
              _buildDetailRow('Time Discipline', application.timeDiscipline),
              _buildDetailRow('Schedule Balance', application.scheduleBalance),
              _buildDetailRow('Electricity Access', application.electricityAccess),
              _buildDetailRow('Teaching Comfort', application.teachingComfort),
              _buildDetailRow('Start Date', application.availabilityStart),
              
              const SizedBox(height: 16),
              _buildSection('Technical'),
              _buildDetailRow('Device', application.teachingDevice),
              _buildDetailRow('Internet', application.internetAccess),

              const SizedBox(height: 16),
              _buildSection('Motivation'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  application.interestReason,
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.commonClose),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xff8B5CF6),
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
            width: 160,
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
