import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/services/shift_service.dart';
import '../widgets/create_shift_dialog.dart';
import '../widgets/shift_details_dialog.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();

  List<TeachingShift> _allShifts = [];
  List<TeachingShift> _todayShifts = [];
  List<TeachingShift> _upcomingShifts = [];
  List<TeachingShift> _activeShifts = [];

  Map<String, dynamic> _shiftStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadShiftData();
    _loadShiftStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);

    try {
      // Listen to all shifts stream
      ShiftService.getAllShifts().listen((shifts) {
        if (mounted) {
          setState(() {
            _allShifts = shifts;
            _filterShifts();
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      print('Error loading shift data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadShiftStatistics() async {
    try {
      final stats = await ShiftService.getShiftStatistics();
      if (mounted) {
        setState(() {
          _shiftStats = stats;
        });
      }
    } catch (e) {
      print('Error loading shift statistics: $e');
    }
  }

  void _filterShifts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    _todayShifts = _allShifts
        .where((shift) =>
            shift.shiftStart.isAfter(today) &&
            shift.shiftStart.isBefore(tomorrow))
        .toList();

    _upcomingShifts = _allShifts
        .where((shift) =>
            shift.shiftStart.isAfter(now) &&
            shift.status == ShiftStatus.scheduled)
        .toList();

    _activeShifts = _allShifts
        .where((shift) => shift.status == ShiftStatus.active)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildStatsCards(),
          _buildTabContent(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateShiftDialog,
        backgroundColor: const Color(0xff0386FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Create Shift',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.schedule,
              color: Color(0xff0386FF),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shift Management',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage Islamic education teaching shifts and schedules',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (!_isLoading)
            IconButton(
              onPressed: () {
                _loadShiftData();
                _loadShiftStatistics();
              },
              icon: const Icon(Icons.refresh),
              color: const Color(0xff6B7280),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Shifts',
              '${_shiftStats['total_shifts'] ?? 0}',
              Icons.event,
              const Color(0xff0386FF),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Active Now',
              '${_shiftStats['active_shifts'] ?? 0}',
              Icons.play_circle_fill,
              const Color(0xff10B981),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Today',
              '${_shiftStats['today_shifts'] ?? 0}',
              Icons.today,
              const Color(0xffF59E0B),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Upcoming',
              '${_shiftStats['upcoming_shifts'] ?? 0}',
              Icons.upcoming,
              const Color(0xff8B5CF6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Live',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xff0386FF),
                unselectedLabelColor: const Color(0xff6B7280),
                indicatorColor: const Color(0xff0386FF),
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(text: 'All Shifts (${_allShifts.length})'),
                  Tab(text: 'Today (${_todayShifts.length})'),
                  Tab(text: 'Upcoming (${_upcomingShifts.length})'),
                  Tab(text: 'Active (${_activeShifts.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildShiftDataGrid(_allShifts),
                  _buildShiftDataGrid(_todayShifts),
                  _buildShiftDataGrid(_upcomingShifts),
                  _buildShiftDataGrid(_activeShifts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftDataGrid(List<TeachingShift> shifts) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No shifts found',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first shift to get started',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    return SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: const Color(0xffF8FAFC),
        gridLineColor: const Color(0xffE2E8F0),
        gridLineStrokeWidth: 1,
      ),
      child: SfDataGrid(
        key: _dataGridKey,
        source: ShiftDataSource(
          shifts: shifts,
          onViewDetails: _showShiftDetails,
          onEditShift: _editShift,
          onDeleteShift: _deleteShift,
        ),
        columns: [
          GridColumn(
            columnName: 'shiftName',
            label: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: Text(
                'Shift Name',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ),
          ),
          GridColumn(
            columnName: 'teacher',
            label: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: Text(
                'Teacher',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ),
          ),
          GridColumn(
            columnName: 'subject',
            label: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: Text(
                'Subject',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ),
          ),
          GridColumn(
            columnName: 'students',
            label: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: Text(
                'Students',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ),
          ),
          GridColumn(
            columnName: 'schedule',
            label: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: Text(
                'Schedule',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ),
          ),
          GridColumn(
            columnName: 'status',
            label: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                'Status',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ),
          ),
          GridColumn(
            columnName: 'payment',
            label: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerRight,
              child: Text(
                'Payment',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ),
          ),
          GridColumn(
            columnName: 'actions',
            label: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                'Actions',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
            ),
          ),
        ],
        rowHeight: 70,
        headerRowHeight: 60,
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        columnWidthMode: ColumnWidthMode.fill,
      ),
    );
  }

  void _showCreateShiftDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateShiftDialog(
        onShiftCreated: () {
          _loadShiftData();
          _loadShiftStatistics();
        },
      ),
    );
  }

  void _showShiftDetails(TeachingShift shift) {
    showDialog(
      context: context,
      builder: (context) => ShiftDetailsDialog(shift: shift),
    );
  }

  void _editShift(TeachingShift shift) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateShiftDialog(
        shift: shift,
        onShiftCreated: () {
          _loadShiftData();
          _loadShiftStatistics();
        },
      ),
    );
  }

  void _deleteShift(TeachingShift shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Shift',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${shift.displayName}"? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ShiftService.deleteShift(shift.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shift deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting shift: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class ShiftDataSource extends DataGridSource {
  final List<TeachingShift> shifts;
  final Function(TeachingShift) onViewDetails;
  final Function(TeachingShift) onEditShift;
  final Function(TeachingShift) onDeleteShift;

  ShiftDataSource({
    required this.shifts,
    required this.onViewDetails,
    required this.onEditShift,
    required this.onDeleteShift,
  });

  @override
  List<DataGridRow> get rows {
    return shifts.map<DataGridRow>((shift) {
      return DataGridRow(cells: [
        DataGridCell<String>(columnName: 'shiftName', value: shift.displayName),
        DataGridCell<String>(columnName: 'teacher', value: shift.teacherName),
        DataGridCell<String>(
            columnName: 'subject', value: shift.subjectDisplayName),
        DataGridCell<String>(
            columnName: 'students', value: shift.studentNames.join(', ')),
        DataGridCell<String>(
            columnName: 'schedule', value: _formatSchedule(shift)),
        DataGridCell<String>(columnName: 'status', value: shift.status.name),
        DataGridCell<double>(columnName: 'payment', value: shift.totalPayment),
        DataGridCell<TeachingShift>(columnName: 'actions', value: shift),
      ]);
    }).toList();
  }

  String _formatSchedule(TeachingShift shift) {
    final start = shift.shiftStart;
    final end = shift.shiftEnd;
    return '${start.day}/${start.month}/${start.year} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'status') {
          return _buildStatusChip(cell.value.toString());
        } else if (cell.columnName == 'payment') {
          return Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.all(16),
            child: Text(
              '\$${(cell.value as double).toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xff059669),
              ),
            ),
          );
        } else if (cell.columnName == 'actions') {
          return _buildActionButtons(cell.value as TeachingShift);
        } else {
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(16),
            child: Text(
              cell.value.toString(),
              style: GoogleFonts.inter(
                color: const Color(0xff374151),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    Color backgroundColor;

    switch (status.toLowerCase()) {
      case 'scheduled':
        color = const Color(0xff0386FF);
        backgroundColor = const Color(0xff0386FF).withOpacity(0.1);
        break;
      case 'active':
        color = const Color(0xff10B981);
        backgroundColor = const Color(0xff10B981).withOpacity(0.1);
        break;
      case 'completed':
        color = const Color(0xff6B7280);
        backgroundColor = const Color(0xff6B7280).withOpacity(0.1);
        break;
      case 'missed':
        color = const Color(0xffEF4444);
        backgroundColor = const Color(0xffEF4444).withOpacity(0.1);
        break;
      case 'cancelled':
        color = const Color(0xffF59E0B);
        backgroundColor = const Color(0xffF59E0B).withOpacity(0.1);
        break;
      default:
        color = const Color(0xff6B7280);
        backgroundColor = const Color(0xff6B7280).withOpacity(0.1);
    }

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(TeachingShift shift) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onViewDetails(shift),
            icon: const Icon(Icons.visibility, size: 20),
            color: const Color(0xff0386FF),
            tooltip: 'View Details',
          ),
          const SizedBox(width: 8),
          if (shift.status == ShiftStatus.scheduled) ...[
            IconButton(
              onPressed: () => onEditShift(shift),
              icon: const Icon(Icons.edit, size: 20),
              color: const Color(0xffF59E0B),
              tooltip: 'Edit Shift',
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: () => onDeleteShift(shift),
            icon: const Icon(Icons.delete, size: 20),
            color: const Color(0xffEF4444),
            tooltip: 'Delete Shift',
          ),
        ],
      ),
    );
  }
}
