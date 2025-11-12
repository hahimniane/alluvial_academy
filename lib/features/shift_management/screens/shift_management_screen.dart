import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/user_role_service.dart';
import '../widgets/create_shift_dialog.dart';
import '../widgets/teacher_shift_calendar.dart';
import '../../settings/pay_settings_dialog.dart';
import '../widgets/shift_details_dialog.dart';
import '../widgets/subject_management_dialog.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

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
  bool _isAdmin = false;
  String? _currentUserId;
  bool _isCalendarView = false; // Admin can toggle Grid/Week view

  // Bulk selection state
  final Set<String> _selectedShiftIds = {};
  bool _isSelectionMode = false;

  // Teacher deletion state
  List<Employee> _availableTeachers = [];
  Map<String, String> _teacherEmailToIdMap = {}; // email -> document ID
  String? _selectedTeacherForDeletion;

  // Search functionality
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Filtered shifts
  List<TeachingShift> _filteredAllShifts = [];
  List<TeachingShift> _filteredTodayShifts = [];
  List<TeachingShift> _filteredUpcomingShifts = [];
  List<TeachingShift> _filteredActiveShifts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeUserRole();
  }

  Future<void> _initializeUserRole() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      final isAdmin = await UserRoleService.isAdmin();

      if (mounted) {
        setState(() {
          _currentUserId = currentUser.uid;
          _isAdmin = isAdmin;
        });

        // Load data based on role
        await _loadShiftData();
        await _loadShiftStatistics();
        if (_isAdmin) {
          await _loadTeachers();
        }
      }
    } catch (e) {
      AppLogger.error('Error initializing user role: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);

    try {
      Stream<List<TeachingShift>> shiftsStream;

      if (_isAdmin) {
        // Admins see all shifts
        shiftsStream = ShiftService.getAllShifts();
      } else {
        // Teachers only see their own shifts
        if (_currentUserId == null) {
          throw Exception('User ID not available');
        }
        shiftsStream = ShiftService.getTeacherShifts(_currentUserId!);
      }

      shiftsStream.listen((shifts) async {
        if (mounted) {
          setState(() {
            _allShifts = shifts;
            _categorizeShifts();
            _isLoading = false;
          });
          
          // Reload statistics when shifts change
          await _loadShiftStatistics();
        }
      });
    } catch (e) {
      AppLogger.error('Error loading shift data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadShiftStatistics() async {
    try {
      Map<String, dynamic> stats;
      
      if (_isAdmin) {
        // Admins see all shift statistics
        stats = await ShiftService.getShiftStatistics();
      } else {
        // Teachers only see their own shift statistics
        if (_currentUserId == null) {
          throw Exception('User ID not available');
        }
        stats = await ShiftService.getTeacherShiftStatistics(_currentUserId!);
      }
      
      if (mounted) {
        setState(() {
          _shiftStats = stats;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading shift statistics: $e');
    }
  }

  Future<void> _loadTeachers() async {
    AppLogger.error('ShiftManagement: Loading teachers using ShiftService...');
    try {
      // Use the same method as CreateShiftDialog
      final teachers = await ShiftService.getAvailableTeachers();
      AppLogger.debug(
          'ShiftManagement: ShiftService returned ${teachers.length} teachers');

      // Build email to document ID mapping by querying each teacher's document
      final emailToIdMap = <String, String>{};
      for (final teacher in teachers) {
        try {
          final teacherSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('e-mail', isEqualTo: teacher.email)
              .limit(1)
              .get();

          if (teacherSnapshot.docs.isNotEmpty) {
            emailToIdMap[teacher.email] = teacherSnapshot.docs.first.id;
            AppLogger.debug(
                'ShiftManagement: ✅ Mapped ${teacher.email} -> ${teacherSnapshot.docs.first.id}');
          } else {
            AppLogger.error(
                'ShiftManagement: ❌ No document found for email: ${teacher.email}');
          }
        } catch (e) {
          AppLogger.error('ShiftManagement: Error mapping teacher email to ID: $e');
        }
      }

      if (mounted) {
        setState(() {
          _availableTeachers = teachers;
          _teacherEmailToIdMap = emailToIdMap;
        });
        AppLogger.info(
            'ShiftManagement: ✅ Successfully loaded ${teachers.length} teachers');
        for (final teacher in teachers) {
          AppLogger.error(
              'ShiftManagement: Teacher: ${teacher.firstName} ${teacher.lastName} (${teacher.email})');
        }
      }
    } catch (e) {
      AppLogger.error('ShiftManagement: ❌ Error loading teachers: $e');
    }
  }

  void _categorizeShifts() {
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

    // Apply search filter
    _filterShifts();
  }

  void _filterShifts() {
    if (_searchQuery.isEmpty) {
      _filteredAllShifts = List.from(_allShifts);
      _filteredTodayShifts = List.from(_todayShifts);
      _filteredUpcomingShifts = List.from(_upcomingShifts);
      _filteredActiveShifts = List.from(_activeShifts);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredAllShifts = _allShifts
          .where((shift) => shift.teacherName.toLowerCase().contains(query))
          .toList();
      _filteredTodayShifts = _todayShifts
          .where((shift) => shift.teacherName.toLowerCase().contains(query))
          .toList();
      _filteredUpcomingShifts = _upcomingShifts
          .where((shift) => shift.teacherName.toLowerCase().contains(query))
          .toList();
      _filteredActiveShifts = _activeShifts
          .where((shift) => shift.teacherName.toLowerCase().contains(query))
          .toList();
    }
  }

  int _getFilteredShiftsCount() {
    return _filteredAllShifts.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = constraints.maxHeight;
          return Scrollbar(
            thumbVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewportHeight),
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildStatsCards(),
                    _buildTabContentScrollable(context, viewportHeight),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Scroll-friendly tab content: avoids Expanded and gives TabBarView a bounded height
  Widget _buildTabContentScrollable(BuildContext context, double viewportHeight) {
    final tabViewHeight = math.max(420.0, viewportHeight * 0.6);

    return Container(
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
          // Teacher Search Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _filterShifts();
                        });
                      },
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by teacher name...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF6B7280),
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _filterShifts();
                                  });
                                },
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_getFilteredShiftsCount()} results',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0386FF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // View toggle + Tabs
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toggle aligned right
                Row(
                  children: [
                    const Spacer(),
                    _buildAdminViewToggle(),
                  ],
                ),
                const SizedBox(height: 8),
                TabBar(
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
                    Tab(text: 'All Shifts (${_filteredAllShifts.length})'),
                    Tab(text: 'Today (${_filteredTodayShifts.length})'),
                    Tab(text: 'Upcoming (${_filteredUpcomingShifts.length})'),
                    Tab(text: 'Active (${_filteredActiveShifts.length})'),
                  ],
                ),
              ],
            ),
          ),
          // Tab contents - fixed, scrollable region
          SizedBox(
            height: tabViewHeight,
            child: TabBarView(
              controller: _tabController,
              children: [
                _isCalendarView
                    ? _buildShiftCalendar(_filteredAllShifts)
                    : _buildShiftDataGrid(_filteredAllShifts),
                _isCalendarView
                    ? _buildShiftCalendar(_filteredTodayShifts)
                    : _buildShiftDataGrid(_filteredTodayShifts),
                _isCalendarView
                    ? _buildShiftCalendar(_filteredUpcomingShifts)
                    : _buildShiftDataGrid(_filteredUpcomingShifts),
                _isCalendarView
                    ? _buildShiftCalendar(_filteredActiveShifts)
                    : _buildShiftDataGrid(_filteredActiveShifts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xffF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            icon: Icons.grid_on,
            label: 'Grid',
            selected: !_isCalendarView,
            onTap: () => setState(() => _isCalendarView = false),
          ),
          _buildToggleButton(
            icon: Icons.calendar_view_week,
            label: 'Week',
            selected: _isCalendarView,
            onTap: () => setState(() => _isCalendarView = true),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff0386FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xff6B7280)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xff6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCalendar(List<TeachingShift> shifts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: TeacherShiftCalendar(
        shifts: shifts,
        onSelectShift: _showShiftDetails,
        initialView: CalendarView.week,
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAdmin ? 'Shift Management' : 'My Shifts',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isAdmin
                                ? 'Manage Islamic education teaching shifts and schedules'
                                : 'View your assigned teaching shifts and schedules',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xff6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    if (!_isLoading) ...[
                      // Only show admin controls for admins
                      if (_isAdmin) ...[
                        ElevatedButton.icon(
                          onPressed: _showCreateShiftDialog,
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(
                            'Create Shift',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff0386FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'manage_subjects') {
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    const SubjectManagementDialog(),
                              ).then((_) => _loadShiftData());
                            } else if (value == 'pay_settings') {
                              showDialog(
                                context: context,
                                builder: (context) => const PaySettingsDialog(),
                              );
                            } else if (value == 'dst_adjustment') {
                              _showDSTAdjustmentDialog();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'manage_subjects',
                              child: Row(
                                children: [
                                  Icon(Icons.subject,
                                      size: 20, color: Color(0xff0386FF)),
                                  SizedBox(width: 8),
                                  Text('Manage Subjects'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'pay_settings',
                              child: Row(
                                children: [
                                  Icon(Icons.attach_money,
                                      size: 20, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Pay Settings'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'dst_adjustment',
                              child: Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 20, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('DST Time Adjustment'),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xffE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.settings,
                              size: 20,
                              color: Color(0xff6B7280),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: _toggleSelectionMode,
                          icon: Icon(
                            _isSelectionMode ? Icons.close : Icons.checklist,
                            size: 20,
                          ),
                          label: Text(
                            _isSelectionMode ? 'Cancel' : 'Select',
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _isSelectionMode
                                ? Colors.red
                                : const Color(0xff0386FF),
                          ),
                        ),
                        if (_isSelectionMode &&
                            _selectedShiftIds.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _deleteSelectedShifts,
                            icon: const Icon(Icons.delete, size: 20),
                            label: Text(
                              'Delete (${_selectedShiftIds.length})',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                        if (!_isSelectionMode) ...[
                          const SizedBox(width: 12),
                          // Teacher selection searchable dropdown
                          Container(
                            width: 200,
                            height: 44,
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xffE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _availableTeachers.isNotEmpty
                                    ? _showTeacherSearchDialog
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedTeacherForDeletion != null
                                              ? _getTeacherDisplayName(
                                                  _selectedTeacherForDeletion!)
                                              : _availableTeachers.isEmpty
                                                  ? 'Loading teachers...'
                                                  : 'Search Teacher (${_availableTeachers.length})',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color:
                                                _selectedTeacherForDeletion !=
                                                        null
                                                    ? const Color(0xff111827)
                                                    : const Color(0xff6B7280),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        _selectedTeacherForDeletion != null
                                            ? Icons.person
                                            : Icons.search,
                                        color: const Color(0xff6B7280),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete teacher shifts button
                          ElevatedButton.icon(
                            onPressed: _selectedTeacherForDeletion != null
                                ? _deleteTeacherShifts
                                : null,
                            icon: const Icon(Icons.person_remove, size: 20),
                            label: Text(
                              'Delete Teacher Shifts',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selectedTeacherForDeletion != null
                                      ? Colors.red
                                      : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ],
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
            // Teacher Search Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _filterShifts();
                          });
                        },
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by teacher name...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF9CA3AF),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _filterShifts();
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Color(0xFF6B7280),
                                    size: 18,
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0386FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_getFilteredShiftsCount()} results',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF0386FF),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
                  Tab(text: 'All Shifts (${_filteredAllShifts.length})'),
                  Tab(text: 'Today (${_filteredTodayShifts.length})'),
                  Tab(text: 'Upcoming (${_filteredUpcomingShifts.length})'),
                  Tab(text: 'Active (${_filteredActiveShifts.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildShiftDataGrid(_filteredAllShifts),
                  _buildShiftDataGrid(_filteredTodayShifts),
                  _buildShiftDataGrid(_filteredUpcomingShifts),
                  _buildShiftDataGrid(_filteredActiveShifts),
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
              _searchQuery.isEmpty
                  ? 'No shifts found'
                  : 'No shifts found for "$_searchQuery"',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Create your first shift to get started'
                  : 'Try searching with a different teacher name',
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
      data: const SfDataGridThemeData(
        headerColor: Color(0xffF8FAFC),
        gridLineColor: Color(0xffE2E8F0),
        gridLineStrokeWidth: 1,
      ),
      child: SfDataGrid(
        key: _dataGridKey,
        source: ShiftDataSource(
          shifts: shifts,
          onViewDetails: _showShiftDetails,
          onEditShift: _editShift,
          onDeleteShift: _deleteShift,
          isSelectionMode: _isSelectionMode,
          selectedShiftIds: _selectedShiftIds,
          onSelectionChanged: _onShiftSelectionChanged,
          isAdmin: _isAdmin,
        ),
        columns: [
          if (_isSelectionMode && _isAdmin)
            GridColumn(
              columnName: 'checkbox',
              width: 60,
              label: Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: Checkbox(
                  value: _selectedShiftIds.isNotEmpty &&
                      _selectedShiftIds.length == _getCurrentShifts().length,
                  tristate: true,
                  onChanged: _selectAllShifts,
                ),
              ),
            ),
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
        // Show loading state
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Deleting shift...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }

        await ShiftService.deleteShift(shift.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Force refresh statistics
          _loadShiftStatistics();
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

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedShiftIds.clear();
      }
    });
  }

  void _onShiftSelectionChanged(String shiftId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedShiftIds.add(shiftId);
      } else {
        _selectedShiftIds.remove(shiftId);
      }
    });
  }

  Future<void> _deleteSelectedShifts() async {
    if (_selectedShiftIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Multiple Shifts',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedShiftIds.length} selected shifts? This action cannot be undone.',
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
              'Delete All',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading state
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleting ${_selectedShiftIds.length} shifts...'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Delete all selected shifts
        await ShiftService.deleteMultipleShifts(_selectedShiftIds.toList());

        if (mounted) {
          setState(() {
            _selectedShiftIds.clear();
            _isSelectionMode = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All selected shifts deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Force refresh statistics
          _loadShiftStatistics();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting shifts: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<TeachingShift> _getCurrentShifts() {
    switch (_tabController.index) {
      case 0:
        return _allShifts;
      case 1:
        return _todayShifts;
      case 2:
        return _upcomingShifts;
      case 3:
        return _activeShifts;
      default:
        return _allShifts;
    }
  }

  void _selectAllShifts(bool? value) {
    setState(() {
      if (value == true) {
        // Select all shifts in current tab
        _selectedShiftIds.addAll(_getCurrentShifts().map((shift) => shift.id));
      } else {
        // Deselect all
        _selectedShiftIds.clear();
      }
    });
  }

  String _getTeacherDisplayName(String email) {
    final teacher = _availableTeachers.firstWhere(
      (t) => t.email == email,
      orElse: () => Employee(
        firstName: 'Unknown',
        lastName: 'Teacher',
        email: email,
        countryCode: '',
        mobilePhone: '',
        userType: 'teacher',
        title: '',
        employmentStartDate: '',
        kioskCode: '',
        dateAdded: '',
        lastLogin: '',
        documentId: '', // Add missing documentId parameter
      ),
    );
    return '${teacher.firstName} ${teacher.lastName}';
  }

  void _showTeacherSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _TeacherSearchDialog(
          teachers: _availableTeachers,
          onTeacherSelected: (email) {
            setState(() {
              _selectedTeacherForDeletion = email.isEmpty ? null : email;
            });
          },
          currentlySelected: _selectedTeacherForDeletion,
        );
      },
    );
  }

  Future<void> _deleteTeacherShifts() async {
    if (_selectedTeacherForDeletion == null) return;

    // Find the selected teacher
    final selectedTeacher = _availableTeachers.firstWhere(
      (teacher) => teacher.email == _selectedTeacherForDeletion,
    );

    // Get the teacher's document ID
    final teacherId = _teacherEmailToIdMap[_selectedTeacherForDeletion];
    if (teacherId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teacher ID not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Count shifts for this teacher
    final teacherShifts =
        _allShifts.where((shift) => shift.teacherId == teacherId).length;

    if (teacherShifts == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No shifts found for ${selectedTeacher.firstName} ${selectedTeacher.lastName}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete All Teacher Shifts',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
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
              'Are you sure you want to delete all shifts for:',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xff374151),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xffF59E0B).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xffF59E0B),
                    child: Text(
                      '${selectedTeacher.firstName[0]}${selectedTeacher.lastName[0]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedTeacher.firstName} ${selectedTeacher.lastName}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff92400E),
                          ),
                        ),
                        Text(
                          selectedTeacher.email,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xff92400E).withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$teacherShifts shifts will be permanently deleted. This action cannot be undone.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
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
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete, size: 18),
            label: Text(
              'Delete All ($teacherShifts)',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading state
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Deleting all shifts for ${selectedTeacher.firstName} ${selectedTeacher.lastName}...'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Delete all shifts for the teacher
        final deletedCount =
            await ShiftService.deleteAllShiftsByTeacher(teacherId);

        if (mounted) {
          setState(() {
            _selectedTeacherForDeletion = null; // Reset selection
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Successfully deleted $deletedCount shifts for ${selectedTeacher.firstName} ${selectedTeacher.lastName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Force refresh both statistics and shift data
          _loadShiftStatistics();
          _loadShiftData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting teacher shifts: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _showDSTAdjustmentDialog() async {
    // Show confirmation dialog for DST adjustment
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.access_time,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Daylight Saving Time Adjustment',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will adjust ALL future scheduled shifts by 1 hour',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Adjustment:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
            const SizedBox(height: 12),
            // DST Options
            InkWell(
              onTap: () => _performDSTAdjustment(1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xffE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline,
                        color: Color(0xff10B981), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spring Forward (+1 hour)',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff111827),
                            ),
                          ),
                          Text(
                            'Move all shifts 1 hour later',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xff6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward,
                        color: Color(0xff6B7280), size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _performDSTAdjustment(-1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xffE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.remove_circle_outline,
                        color: Color(0xffF59E0B), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fall Back (-1 hour)',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff111827),
                            ),
                          ),
                          Text(
                            'Move all shifts 1 hour earlier',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xff6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_back,
                        color: Color(0xff6B7280), size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xff0386FF), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only scheduled shifts that haven\'t started yet will be adjusted. Completed or active shifts will not be affected.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff0386FF),
                        height: 1.4,
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDSTAdjustment(int hours) async {
    // Close the dialog
    Navigator.pop(context);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(
              hours > 0
                ? 'Adding $hours hour to all future shifts...'
                : 'Subtracting ${-hours} hour from all future shifts...',
              style: GoogleFonts.inter(),
            ),
          ],
        ),
      ),
    );

    try {
      // Get current user ID for tracking
      final currentUser = FirebaseAuth.instance.currentUser;

      // Call the DST adjustment service
      final result = await ShiftService.adjustAllShiftTimes(
        adjustmentHours: hours,
        onlyFutureShifts: true,
        adminUserId: currentUser?.uid,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show results dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: result['success'] == true
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    result['success'] == true
                        ? Icons.check_circle
                        : Icons.error,
                    color: result['success'] == true
                        ? Colors.green
                        : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'DST Adjustment Complete',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result['message'] ?? 'Adjustment completed',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 16),
                // Statistics
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xffE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow('Total Shifts Found',
                          '${result['totalShifts'] ?? 0}'),
                      const Divider(height: 16),
                      _buildStatRow('Shifts Adjusted',
                          '${result['adjustedShifts'] ?? 0}',
                          color: Colors.green),
                      const Divider(height: 16),
                      _buildStatRow('Shifts Skipped',
                          '${result['skippedShifts'] ?? 0}',
                          color: Colors.orange),
                    ],
                  ),
                ),
                if (result['errors'] != null &&
                    (result['errors'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Errors:',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...((result['errors'] as List).take(3).map((error) =>
                          Text(
                            '• $error',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          )
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Reload shift data to show updated times
                  _loadShiftData();
                  _loadShiftStatistics();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0386FF),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adjusting shifts: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xff6B7280),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? const Color(0xff111827),
          ),
        ),
      ],
    );
  }
}

class ShiftDataSource extends DataGridSource {
  final List<TeachingShift> shifts;
  final Function(TeachingShift) onViewDetails;
  final Function(TeachingShift) onEditShift;
  final Function(TeachingShift) onDeleteShift;
  final bool isSelectionMode;
  final Set<String> selectedShiftIds;
  final Function(String, bool) onSelectionChanged;
  final bool isAdmin;

  ShiftDataSource({
    required this.shifts,
    required this.onViewDetails,
    required this.onEditShift,
    required this.onDeleteShift,
    required this.isSelectionMode,
    required this.selectedShiftIds,
    required this.onSelectionChanged,
    required this.isAdmin,
  });

  @override
  List<DataGridRow> get rows {
    return shifts.map<DataGridRow>((shift) {
      final cells = <DataGridCell>[];

      // Add checkbox cell if in selection mode and user is admin
      if (isSelectionMode && isAdmin) {
        cells.add(DataGridCell<bool>(
            columnName: 'checkbox',
            value: selectedShiftIds.contains(shift.id)));
      }

      // Add regular cells
      cells.addAll([
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

      return DataGridRow(cells: cells);
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
        if (cell.columnName == 'checkbox') {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Checkbox(
              value: cell.value as bool,
              onChanged: (bool? value) {
                final shift = _getShiftFromRow(row);
                if (shift != null) {
                  onSelectionChanged(shift.id, value ?? false);
                }
              },
            ),
          );
        } else if (cell.columnName == 'status') {
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
    // Hide action buttons in selection mode
    if (isSelectionMode) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          'Select items',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xff6B7280),
          ),
        ),
      );
    }

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
          // Only show edit and delete buttons for admins
          if (isAdmin) ...[
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
        ],
      ),
    );
  }

  TeachingShift? _getShiftFromRow(DataGridRow row) {
    // Get the shift from the actions cell which contains the TeachingShift object
    final actionsCell = row.getCells().firstWhere(
          (cell) => cell.columnName == 'actions',
          orElse: () =>
              const DataGridCell<TeachingShift>(columnName: 'actions', value: null),
        );
    return actionsCell.value as TeachingShift?;
  }
}

class _TeacherSearchDialog extends StatefulWidget {
  final List<Employee> teachers;
  final Function(String) onTeacherSelected;
  final String? currentlySelected;

  const _TeacherSearchDialog({
    required this.teachers,
    required this.onTeacherSelected,
    this.currentlySelected,
  });

  @override
  State<_TeacherSearchDialog> createState() => _TeacherSearchDialogState();
}

class _TeacherSearchDialogState extends State<_TeacherSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Employee> _filteredTeachers = [];

  @override
  void initState() {
    super.initState();
    _filteredTeachers = widget.teachers;
    _searchController.addListener(_filterTeachers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTeachers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTeachers = widget.teachers.where((teacher) {
        final fullName =
            '${teacher.firstName} ${teacher.lastName}'.toLowerCase();
        final email = teacher.email.toLowerCase();
        return fullName.contains(query) || email.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.search,
                  color: Color(0xff0386FF),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search Teachers',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xff6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search field
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xffE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff9CA3AF),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xff6B7280),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Results count
            Text(
              '${_filteredTeachers.length} teachers found',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xff6B7280),
              ),
            ),
            const SizedBox(height: 12),

            // Teachers list
            Expanded(
              child: _filteredTeachers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No teachers found',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xff6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xff9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredTeachers.length,
                      itemBuilder: (context, index) {
                        final teacher = _filteredTeachers[index];
                        final isSelected =
                            teacher.email == widget.currentlySelected;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xff0386FF).withOpacity(0.1)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xff0386FF)
                                  : const Color(0xffE2E8F0),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                widget.onTeacherSelected(teacher.email);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xff0386FF),
                                      child: Text(
                                        '${teacher.firstName[0]}${teacher.lastName[0]}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${teacher.firstName} ${teacher.lastName}',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xff111827),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            teacher.email,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: const Color(0xff6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xff0386FF),
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Clear selection button
            if (widget.currentlySelected != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    widget.onTeacherSelected(''); // Clear selection
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: Text(
                    'Clear Selection',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
