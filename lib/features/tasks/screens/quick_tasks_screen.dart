import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/enums/task_enums.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/add_edit_task_dialog.dart';
import '../widgets/task_details_view.dart';
import '../widgets/connectteam_task_list.dart';
import '../widgets/multiple_task_creation_dialog.dart';
import '../widgets/user_selection_dialog.dart' as task_filters;
import '../../../core/services/user_role_service.dart';
import '../../../core/models/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import '../../../core/utils/connecteam_style.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class QuickTasksScreen extends StatefulWidget {
  const QuickTasksScreen({super.key});

  @override
  _QuickTasksScreenState createState() => _QuickTasksScreenState();
}

class _QuickTasksScreenState extends State<QuickTasksScreen>
    with TickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  TaskStatus? _selectedStatus;
  TaskPriority? _selectedPriority;
  String _searchQuery = '';
  DateTimeRange? _dueDateRange;
  String? _filterAssignedByUserId;
  List<String> _filterAssignedToUserIds = [];
  final Map<String, String> _userIdToName = {};
  final Set<String> _fetchingUserIds = {};
  bool _isLoadingAssignedBy = false;
  bool _isLoadingAssignedTo = false;
  late AnimationController _fabAnimationController;
  bool _isAdmin = false;
  Stream<List<Task>>? _taskStream;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  
  // NEW: Tab navigation and view mode
  late TabController _tabController;
  String _viewMode = 'list'; // 'grid' or 'list' - default to list for ConnectTeam style
  String _groupBy = 'assignee'; // 'none' or 'assignee' - default to assignee for ConnectTeam style
  String _selectedTab = 'all'; // 'created_by_me', 'my_tasks', 'all', 'archived'
  
  // Bulk selection
  Set<String> _selectedTaskIds = {};
  bool _isBulkMode = false;
  bool? _filterRecurring; // null = all, true = recurring only, false = non-recurring only
  List<String> _filterLabels = []; // Filter by labels/tags

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimationController.forward();
    
    // NEW: Initialize tab controller (5 tabs: created_by_me, my_tasks, all, archived, drafts)
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _getTabKey(_tabController.index);
        });
      }
    });

    // Start loading immediately and also listen for auth state changes
    _loadUserRoleAndTasks();
    _listenToAuthState();
    _listenToRoleChanges();
  }
  
  String _getTabKey(int index) {
    switch (index) {
      case 0:
        return 'created_by_me';
      case 1:
        return 'my_tasks';
      case 2:
        return 'all';
      case 3:
        return 'archived';
      case 4:
        return 'drafts';
      default:
        return 'all';
    }
  }

  void _listenToAuthState() {
    // Listen for auth state changes to reload tasks when user logs in
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        // User is authenticated, reload tasks
        _loadUserRoleAndTasks();
      }
    });
  }

  void _listenToRoleChanges() {
    // Poll for role changes every few seconds to detect role switching
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final currentAdmin = await UserRoleService.isAdmin();
        if (currentAdmin != _isAdmin) {
          AppLogger.error(
              'QuickTasks: Role change detected! Admin: $_isAdmin -> $currentAdmin');
          // Role has changed, reload tasks
          _loadUserRoleAndTasks();
        }
      } catch (e) {
        AppLogger.error('QuickTasks: Error checking role changes: $e');
      }
    });
  }

  Future<void> _loadUserRoleAndTasks() async {
    if (!mounted) return;

    try {
      // Set loading state immediately
      setState(() {
        _isLoading = true;
      });

      // Wait for auth to be ready with a timeout
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Wait briefly for auth state to initialize
        await Future.delayed(const Duration(milliseconds: 500));
        final newUser = FirebaseAuth.instance.currentUser;
        if (newUser == null) {
          throw Exception('No authenticated user found');
        }
      }

      // Load user role and task stream
      final isAdmin = await UserRoleService.isAdmin();
      final taskStream = await _taskService.getRoleBasedTasks();

      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _taskStream = taskStream;
          _isLoading = false;

          // Clear admin-only filters for non-admin users
          if (!isAdmin) {
            _filterAssignedByUserId = null;
            _filterAssignedToUserIds = [];
          }
        });

        AppLogger.error('Tasks loaded successfully. Admin: $isAdmin');
      }
    } catch (e) {
      AppLogger.error('Error loading user role and tasks: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Retry after a delay if there's an error
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _loadUserRoleAndTasks();
        }
      }
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ConnecteamStyle.background,
      body: SafeArea(
        child: Column(
          children: [
            // Connecteam Header
            _buildConnecteamHeader(),
            // Filter Tabs
            _buildFilterTabs(),
            // Comprehensive Filter Bar
            _buildComprehensiveFilterBar(),
            // Bulk Actions Bar (when tasks are selected)
            if (_selectedTaskIds.isNotEmpty) _buildBulkActionsBar(),
            // Task content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: _isAdmin ? 80.0 : 16.0, // Extra space for FAB
                ),
                child: StreamBuilder<List<Task>>(
                  stream: _taskStream,
                  builder: (context, snapshot) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(AppLocalizations.of(context)!.commonErrorWithDetails(snapshot.error ?? 'Unknown error')),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildNoResultsState();
                }

                var tasks = _filterTasks(snapshot.data!);
                tasks = _applyTabFilter(tasks);
                
                // Pre-fetch all user names for assignees
                _prefetchUserNamesForTasks(tasks);

                if (tasks.isEmpty) {
                  return _buildNoResultsState();
                }

                // Calculate task summary statistics
                final totalTasks = tasks.length;
                final openTasks = tasks.where((t) => t.status == TaskStatus.todo || t.status == TaskStatus.inProgress).length;
                final doneTasks = tasks.where((t) => t.status == TaskStatus.done).length;

                // Switch between grid and list view
                return Column(
                  children: [
                    // Task summary statistics (ConnectTeam style)
                    _buildTaskSummary(totalTasks, openTasks, doneTasks),
                    const SizedBox(height: 16),
                    // Task list
                    Expanded(
                      child: _viewMode == 'list'
                          ? _buildGroupedTaskList(tasks)
                          : _buildTaskGridView(tasks),
                    ),
                    // Bulk Mode Toggle Button
                    if (_isAdmin)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isBulkMode = !_isBulkMode;
                                  if (!_isBulkMode) {
                                    _selectedTaskIds.clear();
                                  }
                                });
                              },
                              icon: Icon(_isBulkMode ? Icons.check_box : Icons.check_box_outline_blank),
                              label: Text(
                                _isBulkMode
                                    ? AppLocalizations.of(context)!.taskExitSelection
                                    : AppLocalizations.of(context)!.taskSelectMultiple,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: ConnecteamStyle.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating action button with dropdown menu
      floatingActionButton: _isAdmin
          ? _buildAddTaskButton()
          : null,
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _isAdmin ? 'Task Management' : 'My Tasks',
          style: const TextStyle(
            color: Color(0xFF1A202C),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
          ),
        ),
      ),
    );
  }

  /// Connecteam Header
  Widget _buildConnecteamHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Text(AppLocalizations.of(context)!.navTasks, style: ConnecteamStyle.headerTitle),
          const SizedBox(width: 12),
          // Search Bar (Pill shaped) - Made flexible for mobile
          Expanded(
            child: Container(
              height: 40,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: ConnecteamStyle.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ConnecteamStyle.borderColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchTasks,
                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(top: 8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filter Tabs (Simplified Connecteam style)
  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabItem("All Tasks", 'all', isActive: _selectedTab == 'all'),
            _buildTabItem("My Tasks", 'my_tasks', isActive: _selectedTab == 'my_tasks'),
            _buildTabItem("Today", 'today', isActive: _selectedTab == 'today'),
            if (_isAdmin) _buildTabItem("Drafts", 'drafts', isActive: _selectedTab == 'drafts'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, String tabKey, {bool isActive = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tabKey;
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 24.0),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? ConnecteamStyle.primaryBlue : ConnecteamStyle.textGrey,
              ),
            ),
            if (isActive)
              Container(
                height: 2,
                width: 20,
                margin: const EdgeInsets.only(top: 4),
                color: ConnecteamStyle.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }

  /// Comprehensive Filter Bar (Connecteam style) - Mobile-friendly with Wrap
  Widget _buildComprehensiveFilterBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      // Use Wrap to make all filters visible without scrolling
      child: Wrap(
        spacing: 8.0, // Horizontal space between chips
        runSpacing: 8.0, // Vertical space between lines
        children: [
          // Status Filter
          _buildFilterChip(
            label: AppLocalizations.of(context)!.status,
            icon: Icons.flag_outlined,
            isActive: _selectedStatus != null,
            onTap: () => _showStatusFilter(),
            activeLabel: _selectedStatus != null ? _getStatusLabel(_selectedStatus!) : null,
          ),
          // Priority Filter
          _buildFilterChip(
            label: AppLocalizations.of(context)!.priority,
            icon: Icons.priority_high,
            isActive: _selectedPriority != null,
            onTap: () => _showPriorityFilter(),
            activeLabel: _selectedPriority != null ? _getPriorityLabel(_selectedPriority!) : null,
          ),
          // Assigned To Filter
          _buildFilterChip(
            label: AppLocalizations.of(context)!.assignedTo,
            icon: Icons.person_outline,
            isActive: _filterAssignedToUserIds.isNotEmpty,
            onTap: () => _showAssignedToFilter(),
            activeLabel: _filterAssignedToUserIds.isNotEmpty 
                ? '${_filterAssignedToUserIds.length} selected' 
                : null,
          ),
          // Assigned By Filter (Admin only)
          if (_isAdmin)
            _buildFilterChip(
              label: AppLocalizations.of(context)!.quickTasksAssignedby,
              icon: Icons.person_add_outlined,
              isActive: _filterAssignedByUserId != null,
              onTap: () => _showAssignedByFilter(),
              activeLabel: _filterAssignedByUserId != null 
                  ? _userIdToName[_filterAssignedByUserId] ??
                      AppLocalizations.of(context)!.commonUnknown
                  : null,
            ),
          // Due Date Filter
          _buildFilterChip(
            label: AppLocalizations.of(context)!.dueDate,
            icon: Icons.calendar_today_outlined,
            isActive: _dueDateRange != null,
            onTap: () => _showDueDateFilter(),
            activeLabel: _dueDateRange != null
                ? '${DateFormat('MMM d').format(_dueDateRange!.start)} - ${DateFormat('MMM d').format(_dueDateRange!.end)}'
                : null,
          ),
          // Recurring Filter
          _buildFilterChip(
            label: AppLocalizations.of(context)!.recurring,
            icon: Icons.repeat,
            isActive: _filterRecurring != null,
            onTap: () => _showRecurringFilter(),
            activeLabel: _filterRecurring == true 
                ? 'Recurring Only'
                : _filterRecurring == false 
                    ? 'One-time Only'
                    : null,
          ),
          // Labels/Tags Filter
          _buildFilterChip(
            label: AppLocalizations.of(context)!.quickTasksLabels,
            icon: Icons.label_outline,
            isActive: _filterLabels.isNotEmpty,
            onTap: () => _showLabelsFilter(),
            activeLabel: _filterLabels.isNotEmpty 
                ? '${_filterLabels.length} label${_filterLabels.length == 1 ? '' : 's'}'
                : null,
          ),
          // Clear All Filters Button
          if (_hasActiveFilters())
            InkWell(
              onTap: _clearAllFilters,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.clear, size: 16, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context)!.clearAll,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    String? activeLabel,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Reduced padding
        decoration: BoxDecoration(
          color: isActive 
              ? ConnecteamStyle.primaryBlue.withOpacity(0.1)
              : ConnecteamStyle.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive 
                ? ConnecteamStyle.primaryBlue
                : ConnecteamStyle.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14, // Smaller icon
              color: isActive ? ConnecteamStyle.primaryBlue : ConnecteamStyle.textGrey,
            ),
            const SizedBox(width: 5), // Reduced spacing
            Text(
              activeLabel ?? label,
              style: GoogleFonts.inter(
                fontSize: 12, // Smaller font
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? ConnecteamStyle.primaryBlue : ConnecteamStyle.textGrey,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.close,
                size: 14,
                color: ConnecteamStyle.primaryBlue,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Bulk Actions Bar
  Widget _buildBulkActionsBar() {
    return Container(
      color: ConnecteamStyle.primaryBlue.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '${_selectedTaskIds.length} selected',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ConnecteamStyle.primaryBlue,
            ),
          ),
          const Spacer(),
          // Bulk Status Change
          TextButton.icon(
            onPressed: () => _showBulkStatusChange(),
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: Text(AppLocalizations.of(context)!.changeStatus),
            style: TextButton.styleFrom(
              foregroundColor: ConnecteamStyle.primaryBlue,
            ),
          ),
          const SizedBox(width: 8),
          // Bulk Priority Change
          TextButton.icon(
            onPressed: () => _showBulkPriorityChange(),
            icon: const Icon(Icons.priority_high, size: 16),
            label: Text(AppLocalizations.of(context)!.changePriority),
            style: TextButton.styleFrom(
              foregroundColor: ConnecteamStyle.primaryBlue,
            ),
          ),
          const SizedBox(width: 8),
          // Bulk Delete
          TextButton.icon(
            onPressed: () => _showBulkDeleteConfirmation(),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(AppLocalizations.of(context)!.commonDelete),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          // Cancel Selection
          IconButton(
            onPressed: () {
              setState(() {
                _selectedTaskIds.clear();
                _isBulkMode = false;
              });
            },
            icon: const Icon(Icons.close, size: 20),
            color: ConnecteamStyle.textGrey,
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedStatus != null ||
        _selectedPriority != null ||
        _filterAssignedToUserIds.isNotEmpty ||
        _filterAssignedByUserId != null ||
        _dueDateRange != null ||
        _filterRecurring != null ||
        _filterLabels.isNotEmpty;
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedPriority = null;
      _filterAssignedToUserIds = [];
      _filterAssignedByUserId = null;
      _dueDateRange = null;
      _filterRecurring = null;
      _filterLabels.clear();
    });
  }

  /// NEW: Tab bar for task filtering (ConnectTeam style with counts)
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
      ),
      child: Row(
        children: [
          // Icon + Title
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.task_alt, color: Color(0xff0386FF), size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context)!.quickTasks,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(width: 32),
          // Tabs with counts
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabWithCount('Tasks Created By Me', 'created_by_me', 0),
                  _buildTabWithCount('My Tasks', 'my_tasks', 1),
                  _buildTabWithCount('All Tasks', 'all', 2),
                  _buildTabWithCount('Archived', 'archived', 3),
                  _buildTabWithCount('Drafts', 'drafts', 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabWithCount(String label, String tabKey, int index) {
    final isSelected = _selectedTab == tabKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tabKey;
          _tabController.animateTo(index);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff0386FF).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xff0386FF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? const Color(0xff0386FF) : const Color(0xff6B7280),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, String tabKey, int index) {
    final isSelected = _selectedTab == tabKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tabKey;
          _tabController.animateTo(index);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff0386FF) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// NEW: Toolbar with view toggle and filters (ConnectTeam style)
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
      ),
      child: Row(
        children: [
          // View toggle
          _buildViewToggle(),
          const SizedBox(width: 12),
          // Group By dropdown
          _buildGroupByDropdown(),
          const SizedBox(width: 12),
          // Date filter
          _buildDateFilter(),
          const Spacer(),
          // Search
          Container(
            width: 200,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xffF3F4F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffE5E7EB)),
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.commonSearch,
                hintStyle: GoogleFonts.inter(color: const Color(0xff9CA3AF), fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xff9CA3AF), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          // Overdue badge
          _buildOverdueBadge(),
          const SizedBox(width: 12),
          // Add Task button
          if (_isAdmin)
            ElevatedButton.icon(
              onPressed: () => _showAddEditTaskDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocalizations.of(context)!.addTask, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupByDropdown() {
    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _groupBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.groupBy,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff6B7280)),
            ),
            SizedBox(width: 4),
            Text(
              _groupBy == 'none' ? 'None' : (_groupBy == 'assignee' ? 'Assigned to' : _groupBy),
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xff6B7280)),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'none', child: Text(AppLocalizations.of(context)!.commonNone)),
        PopupMenuItem(value: 'assignee', child: Text(AppLocalizations.of(context)!.assignedTo)),
        PopupMenuItem(value: 'status', child: Text(AppLocalizations.of(context)!.userStatus)),
        PopupMenuItem(value: 'priority', child: Text(AppLocalizations.of(context)!.priority)),
      ],
    );
  }

  Widget _buildDateFilter() {
    return InkWell(
      onTap: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: _dueDateRange,
        );
        if (range != null) {
          setState(() => _dueDateRange = range);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Color(0xff6B7280)),
            const SizedBox(width: 8),
            Text(
              _dueDateRange != null
                  ? '${DateFormat('M/d').format(_dueDateRange!.start)} to ${DateFormat('M/d').format(_dueDateRange!.end)}'
                  : 'Dates',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff374151)),
            ),
            if (_dueDateRange != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: InkWell(
                  onTap: () => setState(() => _dueDateRange = null),
                  child: const Icon(Icons.close, size: 16, color: Color(0xff9CA3AF)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _viewMode = 'list';
              // Auto-set groupBy to assignee for ConnectTeam-style list view
              if (_groupBy == 'none') {
                _groupBy = 'assignee';
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _viewMode == 'list' ? const Color(0xff0386FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.view_list,
                size: 18,
                color: _viewMode == 'list' ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _viewMode = 'grid'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _viewMode == 'grid' ? const Color(0xff0386FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.grid_view,
                size: 18,
                color: _viewMode == 'grid' ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueBadge() {
    return StreamBuilder<List<Task>>(
      stream: _taskStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final overdueTasks = snapshot.data!.where((task) {
          if (task.isArchived || task.status == TaskStatus.done) return false;
          return task.dueDate != null && task.dueDate!.isBefore(DateTime.now());
        }).length;
        
        if (overdueTasks == 0) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.overduetasksOverdue,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// NEW: Task grid view (existing card-based layout)
  Widget _buildTaskGridView(List<Task> tasks) {
    if (tasks.isEmpty) {
      return _buildNoResultsState();
    }
    
    return GridView.builder(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: _isAdmin ? 96.0 : 16, // Extra space for FAB
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return _buildModernTaskCard(tasks[index]);
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 20),
          _buildFilterSection(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchTasks,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.filters,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 12),
        _buildBeautifulFilters(),
      ],
    );
  }

  Widget _buildBeautifulFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // All Tasks chip
        _buildModernFilterChip(
          label: AppLocalizations.of(context)!.allTasks,
          isSelected: _selectedStatus == null &&
              _selectedPriority == null &&
              _dueDateRange == null &&
              (_isAdmin
                  ? (_filterAssignedByUserId == null &&
                      _filterAssignedToUserIds.isEmpty)
                  : true),
          onSelected: () => setState(() {
            _selectedStatus = null;
            _selectedPriority = null;
            _dueDateRange = null;
            if (_isAdmin) {
              _filterAssignedByUserId = null;
              _filterAssignedToUserIds = [];
            }
          }),
          color: Colors.grey[600]!,
        ),

        // Status filters
        ...TaskStatus.values.map((status) => _buildModernFilterChip(
              label: _getStatusLabel(status),
              isSelected: _selectedStatus == status,
              onSelected: () => setState(() =>
                  _selectedStatus = _selectedStatus == status ? null : status),
              color: _getStatusColor(status),
            )),

        // Priority filters
        ...TaskPriority.values.map((priority) => _buildModernFilterChip(
              label: _getPriorityLabel(priority),
              isSelected: _selectedPriority == priority,
              onSelected: () => setState(() => _selectedPriority =
                  _selectedPriority == priority ? null : priority),
              color: _getPriorityColor(priority),
            )),

        // Due Date filter chip
        _buildModernFilterChip(
          label: _dueDateRange == null
              ? 'Due Date'
              : '${DateFormat('MMM dd').format(_dueDateRange!.start)} - ${DateFormat('MMM dd').format(_dueDateRange!.end)}',
          isSelected: _dueDateRange != null,
          onSelected: () async {
            if (_dueDateRange != null) {
              // Clear filter if already set
              setState(() => _dueDateRange = null);
            } else {
              // Open date picker
              final now = DateTime.now();
              final currentMonthStart = DateTime(now.year, now.month, 1);
              final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(now.year + 5),
                initialDateRange: DateTimeRange(
                    start: currentMonthStart, end: currentMonthEnd),
                currentDate: now,
                helpText: AppLocalizations.of(context)!.selectDateRangeForTasks,
                cancelText: 'Cancel',
                confirmText: 'Apply Filter',
                saveText: 'Apply',
                builder: (context, child) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 450,
                          maxHeight: 600,
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            datePickerTheme: DatePickerThemeData(
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.white,
                              headerBackgroundColor: const Color(0xff0386FF),
                              headerForegroundColor: Colors.white,
                              headerHeadlineStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              headerHelpStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                              dayStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              rangeSelectionBackgroundColor:
                                  const Color(0xff0386FF).withOpacity(0.1),
                              rangeSelectionOverlayColor:
                                  WidgetStateProperty.all(
                                const Color(0xff0386FF).withOpacity(0.1),
                              ),
                              dayBackgroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xff0386FF);
                                }
                                return null;
                              }),
                              dayForegroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return null;
                              }),
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
                  );
                },
              );
              if (picked != null) setState(() => _dueDateRange = picked);
            }
          },
          color: const Color(0xFF4CAF50),
        ),

        // Assigned By Me - Quick Filter
        if (_isAdmin)
          _buildModernFilterChip(
            label: AppLocalizations.of(context)!.quickTasksAssignedbyme,
            isSelected: _filterAssignedByUserId ==
                FirebaseAuth.instance.currentUser?.uid,
            onSelected: () {
              final myId = FirebaseAuth.instance.currentUser?.uid;
              if (myId == null) return;
              setState(() {
                if (_filterAssignedByUserId == myId) {
                  _filterAssignedByUserId = null;
                } else {
                  _filterAssignedByUserId = myId;
                  _fetchUserNameIfMissing(myId);
                }
              });
            },
            color: const Color(0xFF2196F3),
          ),

        // Assigned To Me - Quick Filter
        if (_isAdmin)
          _buildModernFilterChip(
            label: AppLocalizations.of(context)!.quickTasksAssignedtome,
            isSelected: _filterAssignedToUserIds.length == 1 &&
                _filterAssignedToUserIds.first ==
                    FirebaseAuth.instance.currentUser?.uid,
            onSelected: () {
              final myId = FirebaseAuth.instance.currentUser?.uid;
              if (myId == null) return;
              setState(() {
                if (_filterAssignedToUserIds.contains(myId) &&
                    _filterAssignedToUserIds.length == 1) {
                  _filterAssignedToUserIds = [];
                } else {
                  _filterAssignedToUserIds = [myId];
                  _fetchUserNameIfMissing(myId);
                }
              });
            },
            color: const Color(0xFF9C27B0),
          ),

        // Assigned By filter chip - only show for admins
        if (_isAdmin)
          _buildModernFilterChip(
            label: _filterAssignedByUserId == null
                ? 'Assigned By'
                : 'By: ${_userIdToName[_filterAssignedByUserId] ?? 'Loading...'}',
            isSelected: _filterAssignedByUserId != null,
            onSelected: () async {
              if (_filterAssignedByUserId != null) {
                // Clear filter if already set
                setState(() => _filterAssignedByUserId = null);
              } else {
                // Open user picker
                await _openAssignedByPicker();
              }
            },
            color: const Color(0xFF2196F3),
          ),

        // Assigned To filter chip - only show for admins
        if (_isAdmin)
          _buildModernFilterChip(
            label: _filterAssignedToUserIds.isEmpty
                ? 'Assigned To'
                : 'To: ${_formatAssigneesLabel(_filterAssignedToUserIds)}',
            isSelected: _filterAssignedToUserIds.isNotEmpty,
            onSelected: () async {
              if (_filterAssignedToUserIds.isNotEmpty) {
                // Clear filter if already set
                setState(() => _filterAssignedToUserIds = []);
              } else {
                // Open user picker
                await _openAssignedToPicker();
              }
            },
            color: const Color(0xFF9C27B0),
          ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildModernFilterChip(
          label: AppLocalizations.of(context)!.allTasks,
          isSelected: _selectedStatus == null && _selectedPriority == null,
          onSelected: () => setState(() {
            _selectedStatus = null;
            _selectedPriority = null;
          }),
          color: Colors.grey[600]!,
        ),
        ...TaskStatus.values.map((status) => _buildModernFilterChip(
              label: _getStatusLabel(status),
              isSelected: _selectedStatus == status,
              onSelected: () => setState(() =>
                  _selectedStatus = _selectedStatus == status ? null : status),
              color: _getStatusColor(status),
            )),
        ...TaskPriority.values.map((priority) => _buildModernFilterChip(
              label: _getPriorityLabel(priority),
              isSelected: _selectedPriority == priority,
              onSelected: () => setState(() => _selectedPriority =
                  _selectedPriority == priority ? null : priority),
              color: _getPriorityColor(priority),
            )),
        // Due date filter (reuse app pattern)
        InputChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(_dueDateRange == null
              ? 'Due date'
              : '${DateFormat('MM/dd').format(_dueDateRange!.start)} - ${DateFormat('MM/dd').format(_dueDateRange!.end)}'),
          onPressed: () async {
            final now = DateTime.now();
            final currentMonthStart = DateTime(now.year, now.month, 1);
            final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 5),
              initialDateRange: _dueDateRange ??
                  DateTimeRange(start: currentMonthStart, end: currentMonthEnd),
              currentDate: now,
              helpText: AppLocalizations.of(context)!.selectDateRangeForTasks,
              cancelText: 'Cancel',
              confirmText: 'Apply Filter',
              saveText: 'Apply',
              builder: (context, child) {
                return Center(
                  child: SingleChildScrollView(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 450,
                        maxHeight: 600,
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          datePickerTheme: DatePickerThemeData(
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.white,
                            headerBackgroundColor: const Color(0xff0386FF),
                            headerForegroundColor: Colors.white,
                            headerHeadlineStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            headerHelpStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                            dayStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            rangeSelectionBackgroundColor:
                                const Color(0xff0386FF).withOpacity(0.1),
                            rangeSelectionOverlayColor: WidgetStateProperty.all(
                              const Color(0xff0386FF).withOpacity(0.1),
                            ),
                            dayBackgroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xff0386FF);
                              }
                              return null;
                            }),
                            dayForegroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return null;
                            }),
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
                );
              },
            );
            if (picked != null) setState(() => _dueDateRange = picked);
          },
          onDeleted: _dueDateRange != null
              ? () => setState(() => _dueDateRange = null)
              : null,
        ),
        // Assigned by (single select user picker)
        InputChip(
          avatar: const Icon(Icons.person_outline, size: 18),
          label: Text(
            _filterAssignedByUserId == null
                ? 'Assigned by'
                : 'By: ${_userIdToName[_filterAssignedByUserId] ?? 'Loading...'}',
          ),
          onPressed: _openAssignedByPicker,
          onDeleted: _filterAssignedByUserId != null
              ? () => setState(() => _filterAssignedByUserId = null)
              : null,
        ),
        // Assigned to (multi-select user picker)
        InputChip(
          avatar: const Icon(Icons.group_outlined, size: 18),
          label: Text(
            _filterAssignedToUserIds.isEmpty
                ? 'Assigned to'
                : 'To: ${_formatAssigneesLabel(_filterAssignedToUserIds)}',
          ),
          onPressed: _openAssignedToPicker,
          onDeleted: _filterAssignedToUserIds.isNotEmpty
              ? () => setState(() => _filterAssignedToUserIds = [])
              : null,
        ),
      ],
    );
  }

  String _formatAssigneesLabel(List<String> ids) {
    if (ids.isEmpty) return '';
    final names = ids
        .map((id) => _userIdToName[id] ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'Loading...';
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1}';
  }

  /// Pre-fetch all user names for tasks to avoid showing user IDs
  void _prefetchUserNamesForTasks(List<Task> tasks) {
    // Collect all unique user IDs from tasks
    final userIds = <String>{};
    for (final task in tasks) {
      userIds.addAll(task.assignedTo);
      if (task.createdBy.isNotEmpty) {
        userIds.add(task.createdBy);
      }
    }
    
    // Fetch names for IDs we don't have yet
    for (final userId in userIds) {
      if (userId.isNotEmpty && 
          !_userIdToName.containsKey(userId) && 
          !_fetchingUserIds.contains(userId)) {
        _fetchUserNameIfMissing(userId);
      }
    }
  }

  void _fetchUserNameIfMissing(String userId) async {
    if (_userIdToName.containsKey(userId) ||
        _fetchingUserIds.contains(userId) ||
        userId.isEmpty) {
      return;
    }
    _fetchingUserIds.add(userId);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final d = doc.data() as Map<String, dynamic>;
        final fullName =
            '${(d['first_name'] ?? '').toString().trim()} ${(d['last_name'] ?? '').toString().trim()}'
                .trim();
        final email = d['e-mail'] ?? d['email'] ?? '';
        
        // Use full name, or email username, or user ID as last resort
        String displayName;
        if (fullName.isNotEmpty) {
          displayName = fullName;
        } else if (email.isNotEmpty && email.contains('@')) {
          // Extract name from email (e.g., john.doe@email.com -> John Doe)
          final emailParts = email.split('@')[0].split('.');
          displayName = emailParts.map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1)).join(' ');
        } else {
          displayName = 'User ${userId.substring(0, 6)}...';
        }
        
        if (mounted) {
          setState(() => _userIdToName[userId] = displayName);
        }
      } else {
        // User document doesn't exist, use a fallback
        if (mounted) {
          setState(() =>
              _userIdToName[userId] = AppLocalizations.of(context)!.commonUnknownUser);
        }
      }
    } catch (e) {
      // On error, set a fallback name
      if (mounted) {
        setState(() => _userIdToName[userId] = 'User');
      }
    } finally {
      _fetchingUserIds.remove(userId);
    }
  }

  Future<void> _openAssignedByPicker() async {
    setState(() => _isLoadingAssignedBy = true);
    try {
      // Admins and Teachers promoted to Admin
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('is_active', isEqualTo: true)
          .where('user_type', whereIn: ['admin', 'teacher']).get();

      // Filter: include user_type == 'admin' OR (teacher with is_admin_teacher == true)
      final options = <Map<String, dynamic>>[];
      for (final doc in query.docs) {
        final d = doc.data();
        final userType = (d['user_type'] ?? '').toString();
        final isAdminTeacher = d['is_admin_teacher'] == true;
        final include =
            userType == 'admin' || (userType == 'teacher' && isAdminTeacher);
        if (!include) continue;
        final fullName =
            '${(d['first_name'] ?? '').toString().trim()} ${(d['last_name'] ?? '').toString().trim()}'
                .trim();
        final displayName =
            fullName.isNotEmpty ? fullName : (d['e-mail'] ?? doc.id);
        options.add({
          'id': doc.id,
          'name': displayName,
          'email': d['e-mail'] ?? '',
        });
        _userIdToName[doc.id] = displayName;
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => task_filters.UserSelectionDialog(
          title: AppLocalizations.of(context)!.selectAssignedBy,
          subtitle: AppLocalizations.of(context)!.chooseAnAdminOrPromotedTeacher,
          availableUsers: options,
          selectedUserIds:
              _filterAssignedByUserId != null ? [_filterAssignedByUserId!] : [],
          allowMultiple: false,
          onUsersSelected: (userIds) {
            if (mounted) {
              setState(() => _filterAssignedByUserId =
                  userIds.isEmpty ? null : userIds.first);
            }
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingAssignedBy = false);
    }
  }

  Future<void> _openAssignedToPicker() async {
    setState(() => _isLoadingAssignedTo = true);
    try {
      // Everyone active
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('is_active', isEqualTo: true)
          .get();

      final options = <Map<String, dynamic>>[];
      for (final doc in query.docs) {
        final d = doc.data();
        final fullName =
            '${(d['first_name'] ?? '').toString().trim()} ${(d['last_name'] ?? '').toString().trim()}'
                .trim();
        final display =
            fullName.isNotEmpty ? fullName : (d['e-mail'] ?? doc.id);
        options.add({
          'id': doc.id,
          'name': display,
          'email': d['e-mail'] ?? '',
        });
        _userIdToName[doc.id] = display;
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => task_filters.UserSelectionDialog(
          title: AppLocalizations.of(context)!.selectAssignedTo,
          subtitle: AppLocalizations.of(context)!.chooseUsersToAssignThisTask,
          availableUsers: options,
          selectedUserIds: _filterAssignedToUserIds,
          allowMultiple: true,
          onUsersSelected: (userIds) {
            if (mounted) {
              setState(() => _filterAssignedToUserIds = userIds);
            }
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingAssignedTo = false);
    }
  }

  Widget _buildModernFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskGrid() {
    // Return loading if task stream is not ready yet or still loading user role
    if (_taskStream == null || _isLoading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                ),
                const SizedBox(height: 16),
                Text(
                  _taskStream == null
                      ? 'Initializing tasks...'
                      : 'Loading tasks...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.pleaseWaitWhileWeLoadYour,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    _loadUserRoleAndTasks();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.commonRetry),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff0386FF),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<Task>>(
      stream: _taskStream,
      builder: (context, snapshot) {
        // Debug logging
        AppLogger.debug('StreamBuilder state: ${snapshot.connectionState}');
        AppLogger.debug('Has data: ${snapshot.hasData}');
        AppLogger.debug(
            'Data length: ${snapshot.hasData ? snapshot.data!.length : 'N/A'}');
        AppLogger.error('Has error: ${snapshot.hasError}');
        if (snapshot.hasError) {
          AppLogger.error('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                    ),
                    SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.connectingToTaskDatabase),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.errorLoadingTasks,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _loadUserRoleAndTasks(),
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context)!.commonRetry),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0386FF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        var tasks = _filterTasks(snapshot.data!);

        if (tasks.isEmpty) {
          return SliverToBoxAdapter(child: _buildNoResultsState());
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context),
              childAspectRatio: _getAspectRatio(context),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildModernTaskCard(tasks[index]),
              childCount: tasks.length,
            ),
          ),
        );
      },
    );
  }

  List<Task> _applyTabFilter(List<Task> tasks) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return tasks;

    switch (_selectedTab) {
      case 'created_by_me':
        return tasks.where((t) => 
            t.createdBy == currentUser.uid && 
            !t.isArchived && 
            !t.isDraft).toList();
      case 'my_tasks':
        return tasks.where((t) => 
            t.assignedTo.contains(currentUser.uid) && 
            !t.isArchived &&
            !t.isDraft).toList();
      case 'today':
        // Filter tasks due today (same date, ignoring time)
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));
        return tasks.where((t) {
          if (t.isArchived || t.isDraft) return false;
          final dueDate = t.dueDate;
          return dueDate.isAfter(todayStart) && dueDate.isBefore(todayEnd);
        }).toList();
      case 'archived':
        return tasks.where((t) => t.isArchived).toList();
      case 'drafts':
        return tasks.where((t) => 
            t.isDraft && 
            !t.isArchived &&
            t.createdBy == currentUser.uid).toList(); // Only show drafts created by current user
      case 'all':
      default:
        return tasks.where((t) => !t.isArchived && !t.isDraft).toList();
    }
  }

  List<Task> _filterTasks(List<Task> tasks) {
    var filteredTasks = tasks;

    if (_selectedStatus != null) {
      filteredTasks = filteredTasks
          .where((task) => task.status == _selectedStatus)
          .toList();
    }

    if (_selectedPriority != null) {
      filteredTasks = filteredTasks
          .where((task) => task.priority == _selectedPriority)
          .toList();
    }

    if (_dueDateRange != null) {
      filteredTasks = filteredTasks.where((task) {
        return !task.dueDate.isBefore(_dueDateRange!.start) &&
            !task.dueDate.isAfter(_dueDateRange!.end);
      }).toList();
    }

    if (_filterAssignedByUserId != null &&
        _filterAssignedByUserId!.isNotEmpty) {
      filteredTasks = filteredTasks
          .where((task) => task.createdBy == _filterAssignedByUserId)
          .toList();
    }

    if (_filterAssignedToUserIds.isNotEmpty) {
      filteredTasks = filteredTasks.where((task) {
        return task.assignedTo
            .any((assignee) => _filterAssignedToUserIds.contains(assignee));
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredTasks = filteredTasks
          .where((task) =>
              task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              task.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Recurring filter
    if (_filterRecurring != null) {
      filteredTasks = filteredTasks
          .where((task) => task.isRecurring == _filterRecurring)
          .toList();
    }

    // Labels filter
    if (_filterLabels.isNotEmpty) {
      filteredTasks = filteredTasks.where((task) {
        return task.labels.any((label) => _filterLabels.contains(label));
      }).toList();
    }

    return filteredTasks;
  }

  Widget _buildModernTaskCard(Task task) {
    final daysUntilDue = task.dueDate.difference(DateTime.now()).inDays;
    final isOverdue = daysUntilDue < 0;
    final isDueSoon = daysUntilDue <= 3 && daysUntilDue >= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showTaskDetailsDialog(task),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                _buildCardHeader(task),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTaskTitle(task),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: _buildTaskDescription(task),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: _buildDueDateSection(
                          task,
                          daysUntilDue,
                          isOverdue,
                          isDueSoon,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildCardFooter(task),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(Task task) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Priority pill at top left (ConnectTeam style)
        _buildPriorityIndicator(task.priority),
        const Spacer(),
        // Actions at top right
        _buildTaskActions(task),
      ],
    );
  }

  Widget _buildPriorityIndicator(TaskPriority priority) {
    // ConnectTeam style: pill-shaped, colored background
    final color = _getPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getPriorityLabel(priority),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTaskActions(Task task) {
    // Only show actions for admins
    if (!_isAdmin) {
      return const SizedBox.shrink();
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final canDelete = currentUser != null && task.createdBy == currentUser.uid;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _showAddEditTaskDialog(task: task);
            break;
          case 'delete':
            _showDeleteConfirmation(task);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(context)!.editTask)),
        if (canDelete)
          PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(context)!.deleteTask)),
      ],
    );
  }

  Widget _buildTaskTitle(Task task) {
    return Text(
      task.title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A202C),
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTaskDescription(Task task) {
    return Text(
      task.description,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDueDateSection(
      Task task, int daysUntilDue, bool isOverdue, bool isDueSoon) {
    String dueDateText;
    Color dateColor;

    // If the task is completed, stop dynamic overdue counting and show
    // the frozen overdue days captured at completion (if any)
    if (task.status == TaskStatus.done) {
      int frozenOverdue = task.overdueDaysAtCompletion ?? 0;
      // If not stored yet but we have a completedAt timestamp, compute once
      if (frozenOverdue == 0 && task.completedAt != null) {
        final completed = task.completedAt!.toDate();
        if (completed.isAfter(task.dueDate)) {
          frozenOverdue = completed.difference(task.dueDate).inDays;
        }
      }

      if (frozenOverdue > 0) {
        dueDateText = '$frozenOverdue days overdue • Completed';
      } else {
        dueDateText = 'Completed on time';
      }
      dateColor = const Color(0xFF10B981); // green for completed
    } else if (isOverdue) {
      dueDateText = '${daysUntilDue.abs()} days overdue';
      dateColor = Colors.red[600]!;
    } else if (daysUntilDue == 0) {
      dueDateText = 'Due today';
      dateColor = Colors.orange[600]!;
    } else if (isDueSoon) {
      dueDateText = 'Due in $daysUntilDue days';
      dateColor = Colors.orange[600]!;
    } else {
      dueDateText = DateFormat.MMMd().format(task.dueDate);
      dateColor = Colors.grey[600]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: dateColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: dateColor),
          const SizedBox(width: 4),
          Text(
            dueDateText,
            style: TextStyle(
              color: dateColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFooter(Task task) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Labels/Tags display
        if (task.labels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: task.labels.map((label) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xff0386FF).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.label, size: 12, color: const Color(0xff0386FF)),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xff0386FF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        // Status and Assignees
        Row(
          children: [
            Flexible(
              child: _buildStatusChip(task.status),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _buildMultipleAssigneeAvatars(task.assignedTo),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(TaskStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMultipleAssigneeAvatars(List<String> assigneeIds) {
    if (assigneeIds.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[300],
        child: Icon(
          Icons.person_outline,
          size: 16,
          color: Colors.grey[600],
        ),
      );
    }

    if (assigneeIds.length == 1) {
      return _buildSingleAssigneeAvatar(assigneeIds.first);
    }

    // Show first 2 avatars + count if more than 2
    const maxVisible = 2;
    final visibleAssignees = assigneeIds.take(maxVisible).toList();
    final remainingCount = assigneeIds.length - maxVisible;

    return SizedBox(
      height: 36,
      width:
          (visibleAssignees.length * 24) + (remainingCount > 0 ? 24 : 0) + 16,
      child: Stack(
        children: [
          // Show first avatars with overlap
          ...visibleAssignees.asMap().entries.map((entry) {
            final index = entry.key;
            final assigneeId = entry.value;
            return Positioned(
              left: index * 24.0, // 32px avatar width - 8px overlap
              child: _buildSingleAssigneeAvatar(assigneeId),
            );
          }),
          // Show count if there are more assignees
          if (remainingCount > 0)
            Positioned(
              left: visibleAssignees.length * 24.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xff0386FF),
                  child: Text(
                    AppLocalizations.of(context)!.remainingcount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleAssigneeAvatar(String assigneeId) {
    // Use initials from resolved name; lazy fetch if missing
    final name = _userIdToName[assigneeId];
    if (name == null) {
      _fetchUserNameIfMissing(assigneeId);
    }
    final displayChar = (name != null && name.isNotEmpty)
        ? name.substring(0, 1).toUpperCase()
        : (assigneeId.isNotEmpty
            ? assigneeId.substring(0, 1).toUpperCase()
            : '?');

    return Tooltip(
      message: name ?? assigneeId,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
          child: Text(
            displayChar,
            style: const TextStyle(
              color: Color(0xff0386FF),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds clickable assignee avatars with names that show a user picker dialog
  Widget _buildClickableAssigneeAvatars(List<String> assigneeIds) {
    if (assigneeIds.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build mini avatars with names
    return GestureDetector(
      onTap: () => _showAssigneeDetailsPopup(assigneeIds),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show up to 3 mini avatars
          ...assigneeIds.take(3).map((id) {
            final name = _userIdToName[id];
            if (name == null) _fetchUserNameIfMissing(id);
            final displayChar = (name != null && name.isNotEmpty)
                ? name.substring(0, 1).toUpperCase()
                : (id.isNotEmpty ? id.substring(0, 1).toUpperCase() : '?');
            
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: CircleAvatar(
                radius: 10,
                backgroundColor: const Color(0xff0386FF).withOpacity(0.15),
                child: Text(
                  displayChar,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff0386FF),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          // Show names or count
          if (assigneeIds.length == 1)
            Text(
              _userIdToName[assigneeIds.first] ?? 'Loading...',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              assigneeIds.length <= 2
                  ? assigneeIds.map((id) => (_userIdToName[id] ?? '...').split(' ').first).join(', ')
                  : '${(_userIdToName[assigneeIds.first] ?? '...').split(' ').first} +${assigneeIds.length - 1}',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  /// Shows a popup with all assignee details
  void _showAssigneeDetailsPopup(List<String> assigneeIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.people_outline, color: Color(0xff0386FF)),
            const SizedBox(width: 8),
            Text(
              'Assigned To (${assigneeIds.length})',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: assigneeIds.map((id) {
              final name = _userIdToName[id] ?? 'Loading...';
              final displayChar = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
                  child: Text(
                    displayChar,
                    style: const TextStyle(
                      color: Color(0xff0386FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Filter tasks by this assignee
                  setState(() {
                    _filterAssignedToUserIds = [id];
                  });
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xff0386FF).withOpacity(0.1),
                    const Color(0xff0386FF).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xff0386FF).withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.task_alt,
                size: 60,
                color: Color(0xff0386FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isAdmin ? 'No tasks yet' : 'No tasks assigned',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isAdmin
                  ? 'Create your first task to get started'
                  : 'You don\'t have any tasks assigned yet.\nCheck back later or contact your administrator.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showAddEditTaskDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocalizations.of(context)!.createTask),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0386FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 50,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noTasksFound,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.tryAdjustingYourFiltersOrSearch,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Task summary statistics (ConnectTeam style) - Clickable stats
  Widget _buildTaskSummary(int totalTasks, int openTasks, int doneTasks) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xffE5E7EB),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.theViewContains,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xff6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xff111827).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$totalTasks task${totalTasks == 1 ? '' : 's'} in total',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xff111827),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Clickable Open Tasks
          InkWell(
            onTap: () {
              setState(() {
                _selectedStatus = TaskStatus.todo; // Filter to open tasks
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$openTasks open task${openTasks == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xff0386FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Clickable Done Tasks
          InkWell(
            onTap: () {
              setState(() {
                _selectedStatus = TaskStatus.done; // Filter to done tasks
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xff10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$doneTasks done task${doneTasks == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xff10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mobile-friendly list view to prevent overflow
  Widget _buildGroupedTaskList(List<Task> tasks) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100), // Space for FAB
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isSelected = _selectedTaskIds.contains(task.id);

        return InkWell(
          onTap: _isBulkMode 
              ? () => _toggleTaskSelection(task.id)
              : () => _showTaskDetailsDialog(task),
          child: Container(
            color: isSelected ? ConnecteamStyle.primaryBlue.withOpacity(0.05) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox for bulk mode or quick complete
                if (_isBulkMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: Icon(
                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                      color: isSelected ? ConnecteamStyle.primaryBlue : Colors.grey,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: InkWell(
                      onTap: () => _toggleTaskStatus(task, task.status != TaskStatus.done),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: task.status == TaskStatus.done 
                                ? ConnecteamStyle.statusDoneText 
                                : Colors.grey.shade400,
                            width: 2
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: task.status == TaskStatus.done 
                              ? ConnecteamStyle.statusDoneText 
                              : Colors.transparent,
                        ),
                        child: task.status == TaskStatus.done
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                
                // Task Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Title and Priority Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: task.status == TaskStatus.done 
                                    ? TextDecoration.lineThrough 
                                    : null,
                                color: task.status == TaskStatus.done 
                                    ? Colors.grey 
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (task.priority == TaskPriority.high)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.high,
                                style: GoogleFonts.inter(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Meta info row (Due date, assignee)
                      Row(
                        children: [
                          if (task.dueDate != null) ...[
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d, h:mm a').format(task.dueDate!),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: task.dueDate!.isBefore(DateTime.now()) && task.status != TaskStatus.done
                                    ? Colors.red 
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (task.assignedTo.isNotEmpty) ...[
                            _buildClickableAssigneeAvatars(task.assignedTo),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method for toggling task selection in bulk mode
  void _toggleTaskSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  Widget _buildGroupedByAssignee(List<Task> tasks) {
    // Group tasks by assignee
    final grouped = <String, List<Task>>{};
    for (final task in tasks) {
      if (task.assignedTo.isEmpty) {
        // Unassigned tasks
        grouped.putIfAbsent('unassigned', () => []).add(task);
      } else {
        for (final assigneeId in task.assignedTo) {
          grouped.putIfAbsent(assigneeId, () => []).add(task);
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final assigneeId = grouped.keys.elementAt(index);
        final assigneeTasks = grouped[assigneeId]!;
        final completedCount = assigneeTasks.where((t) => t.status == TaskStatus.done).length;
        
        return _buildAssigneeGroup(
          assigneeId: assigneeId,
          tasks: assigneeTasks,
          completedCount: completedCount,
        );
      },
    );
  }

  Widget _buildAssigneeGroup({
    required String assigneeId,
    required List<Task> tasks,
    required int completedCount,
  }) {
    return Column(
      children: [
        // Assignee Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xffF9FAFB),
          child: Row(
            children: [
              Checkbox(value: false, onChanged: null), // Multi-select placeholder
              const SizedBox(width: 8),
              _buildUserAvatar(assigneeId),
              const SizedBox(width: 12),
              FutureBuilder<String>(
                future: _getUserName(assigneeId),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? (assigneeId == 'unassigned' ? 'Unassigned' : 'Loading...'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  );
                },
              ),
              const SizedBox(width: 16),
              // Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: Text(
                  '⟳ $completedCount/${tasks.length} Done',
                  style: const TextStyle(fontSize: 12, color: Color(0xff6B7280)),
                ),
              ),
              const Spacer(),
              // Table headers
              _buildTableHeader('Status', 80),
              _buildTableHeader('Sub-tasks', 80),
              _buildTableHeader('Label', 100),
              _buildTableHeader('Start date', 120),
              _buildTableHeader('Due date', 120),
            ],
          ),
        ),
        // Task rows
        ...tasks.map((task) => _buildTaskRow(task)),
        // Add task button
        if (_isAdmin) _buildAddTaskRow(assigneeId),
      ],
    );
  }

  Widget _buildUserAvatar(String userId) {
    if (userId == 'unassigned') {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Color(0xffE2E8F0),
        child: Icon(Icons.person_outline, size: 20, color: Color(0xff6B7280)),
      );
    }
    
    return FutureBuilder<String>(
      future: _getUserName(userId),
      builder: (context, snapshot) {
        final name = snapshot.data ?? '';
        final initials = name.isNotEmpty 
            ? name.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
            : userId.substring(0, 2).toUpperCase();
        
        return CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xff0386FF),
            ),
          ),
        );
      },
    );
  }

  Future<String> _getUserName(String userId) async {
    if (userId == 'unassigned') return 'Unassigned';
    if (_userIdToName.containsKey(userId)) {
      return _userIdToName[userId]!;
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final firstName = data['first_name'] ?? '';
        final lastName = data['last_name'] ?? '';
        final name = '$firstName $lastName'.trim();
        _userIdToName[userId] = name;
        return name;
      }
    } catch (e) {
      AppLogger.error('Error fetching user name: $e');
    }
    
    return userId;
  }

  Widget _buildTableHeader(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xff6B7280),
        ),
      ),
    );
  }

  Widget _buildTaskRow(Task task) {
    final isOverdue = task.dueDate.isBefore(DateTime.now()) && 
                      task.status != TaskStatus.done;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.status == TaskStatus.done,
            onChanged: (value) {
              // Toggle task status
              _toggleTaskStatus(task, value ?? false);
            },
          ),
          const SizedBox(width: 8),
          // Priority indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _getPriorityColor(task.priority),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Task title and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(task.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Second row: Status, Labels, Dates, Assignees
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    // Chat icon
                    Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[400]),
                    // Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusLabel(task.status),
                        style: TextStyle(
                          fontSize: 11,
                          color: _getStatusColor(task.status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Sub-tasks count
                    Text(AppLocalizations.of(context)!.text3, style: TextStyle(fontSize: 12, color: Color(0xff6B7280))),
                    // Labels display
                    if (task.labels.isNotEmpty)
                      ...task.labels.take(2).map((label) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xff0386FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xff0386FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.label, size: 10, color: const Color(0xff0386FF)),
                            const SizedBox(width: 3),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xff0386FF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )),
                    // Start date → Due date
                    if (task.startDate != null)
                      Text(
                        '${DateFormat('M/d').format(task.startDate!)} → ${DateFormat('M/d').format(task.dueDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : const Color(0xff6B7280),
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                      )
                    else
                      Text(
                        DateFormat('M/d').format(task.dueDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : const Color(0xff6B7280),
                          fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    // Assignees with avatars (ConnectTeam style)
                    _buildMultipleAssigneeAvatars(task.assignedTo),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTaskRow(String assigneeId) {
    return InkWell(
      onTap: () => _showAddEditTaskDialog(preSelectedAssignee: assigneeId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
        ),
        child: Row(children: [
            Icon(Icons.add_circle_outline, color: Color(0xff0386FF)),
            SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.addTask2,
              style: TextStyle(
                color: Color(0xff0386FF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTaskList(List<Task> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return _buildTaskRow(tasks[index]);
      },
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.done:
        return Colors.green;
    }
  }

  Future<void> _toggleTaskStatus(Task task, bool isDone) async {
    try {
      final updatedTask = task.copyWith(
        status: isDone ? TaskStatus.done : TaskStatus.todo,
      );
      await _taskService.updateTask(task.id, updatedTask);
    } catch (e) {
      AppLogger.error('Error toggling task status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingTaskE)),
        );
      }
    }
  }

  Future<void> _archiveTask(Task task) async {
    try {
      await _taskService.archiveTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.taskArchived)),
        );
      }
    } catch (e) {
      AppLogger.error('Error archiving task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorArchivingTaskE)),
        );
      }
    }
  }

  Future<void> _unarchiveTask(Task task) async {
    try {
      await _taskService.unarchiveTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.taskUnarchived)),
        );
      }
    } catch (e) {
      AppLogger.error('Error unarchiving task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorUnarchivingTaskE)),
        );
      }
    }
  }

  // Helper methods
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 4;
    if (width > 1000) return 3;
    if (width > 700) return 2;
    return 1;
  }

  double _getAspectRatio(BuildContext context) {
    final crossAxisCount = _getCrossAxisCount(context);
    final width = MediaQuery.of(context).size.width;

    // Lower aspect ratio = taller card
    if (crossAxisCount == 1) {
      // Single column on mobile
      if (width < 400) return 1.4; // Very small screens
      return 1.6; // Regular mobile screens
    }
    if (crossAxisCount == 2) {
      // Two columns on tablet
      if (width < 800) return 1.45; // Small tablets
      return 1.55; // Regular tablets
    }
    if (crossAxisCount == 3) return 1.45; // Three columns
    return 1.35; // Four columns on large desktop
  }

  String _getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Completed';
    }
  }

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  // Filter Dialog Methods
  void _showStatusFilter() {
    // If already filtered, clicking again clears it
    if (_selectedStatus != null) {
      setState(() => _selectedStatus = null);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.filterByStatus, style: ConnecteamStyle.headerTitle.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.of(context)!.allStatuses),
              leading: Radio<TaskStatus?>(
                value: null,
                groupValue: _selectedStatus,
                onChanged: (value) {
                  setState(() => _selectedStatus = null);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskStatus.values.map((status) => ListTile(
              title: Text(_getStatusLabel(status)),
              leading: Radio<TaskStatus>(
                value: status,
                groupValue: _selectedStatus,
                onChanged: (value) {
                  setState(() => _selectedStatus = value);
                  Navigator.pop(context);
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showPriorityFilter() {
    // If already filtered, clicking again clears it
    if (_selectedPriority != null) {
      setState(() => _selectedPriority = null);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.filterByPriority, style: ConnecteamStyle.headerTitle.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.of(context)!.allPriorities),
              leading: Radio<TaskPriority?>(
                value: null,
                groupValue: _selectedPriority,
                onChanged: (value) {
                  setState(() => _selectedPriority = null);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskPriority.values.map((priority) => ListTile(
              title: Text(_getPriorityLabel(priority)),
              leading: Radio<TaskPriority>(
                value: priority,
                groupValue: _selectedPriority,
                onChanged: (value) {
                  setState(() => _selectedPriority = value);
                  Navigator.pop(context);
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showAssignedToFilter() async {
    // If already filtered, clicking again clears it
    if (_filterAssignedToUserIds.isNotEmpty) {
      setState(() => _filterAssignedToUserIds = []);
      return;
    }
    
    final users = await _getAllUsers();
    final selectedIds = List<String>.from(_filterAssignedToUserIds);
    
    await showDialog(
      context: context,
      builder: (context) => task_filters.UserSelectionDialog(
        title: AppLocalizations.of(context)!.filterByAssignedTo,
        subtitle: AppLocalizations.of(context)!.selectUsersToFilterTasks,
        availableUsers: users.map<Map<String, dynamic>>((u) => {
          'id': u.id,
          'name': u.name,
          'email': u.email,
        }).toList(),
        selectedUserIds: selectedIds,
        allowMultiple: true,
        onUsersSelected: (ids) {
          setState(() => _filterAssignedToUserIds = ids);
        },
      ),
    );
  }

  void _showAssignedByFilter() async {
    // If already filtered, clicking again clears it
    if (_filterAssignedByUserId != null) {
      setState(() => _filterAssignedByUserId = null);
      return;
    }
    
    final users = await _getAllUsers();
    final currentSelected = _filterAssignedByUserId;
    
    await showDialog(
      context: context,
      builder: (context) => task_filters.UserSelectionDialog(
        title: AppLocalizations.of(context)!.filterByAssignedBy,
        subtitle: AppLocalizations.of(context)!.selectUserWhoCreatedTheTasks,
        availableUsers: users.map<Map<String, dynamic>>((u) => {
          'id': u.id,
          'name': u.name,
          'email': u.email,
        }).toList(),
        selectedUserIds: currentSelected != null ? [currentSelected] : [],
        allowMultiple: false,
        onUsersSelected: (ids) {
          setState(() => _filterAssignedByUserId = ids.isNotEmpty ? ids.first : null);
        },
      ),
    );
  }

  void _showDueDateFilter() async {
    // If already filtered, clicking again clears it
    if (_dueDateRange != null) {
      setState(() => _dueDateRange = null);
      return;
    }
    
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _dueDateRange,
      currentDate: now,
      helpText: AppLocalizations.of(context)!.selectDueDateRange,
    );
    if (range != null) {
      setState(() => _dueDateRange = range);
    }
  }

  void _showLabelsFilter() async {
    // If already filtered, clicking again clears it
    if (_filterLabels.isNotEmpty) {
      setState(() => _filterLabels.clear());
      return;
    }
    
    // Get all unique labels from tasks
    if (_taskStream == null) return;
    
    final snapshot = await _taskStream!.first;
    final allLabels = <String>{};
    for (var task in snapshot) {
      allLabels.addAll(task.labels);
    }
    
    final selectedLabels = List<String>.from(_filterLabels);
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.filterByLabels, style: ConnecteamStyle.headerTitle.copyWith(fontSize: 18)),
          content: SizedBox(
            width: double.maxFinite,
            child: allLabels.isEmpty
                ? Text(AppLocalizations.of(context)!.noLabelsAvailable)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allLabels.length,
                    itemBuilder: (context, index) {
                      final label = allLabels.elementAt(index);
                      final isSelected = selectedLabels.contains(label);
                      return CheckboxListTile(
                        title: Text(label),
                        value: isSelected,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedLabels.add(label);
                            } else {
                              selectedLabels.remove(label);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            TextButton(
              onPressed: () {
                setState(() => _filterLabels = selectedLabels);
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.commonApply),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecurringFilter() {
    // If already filtered, clicking again clears it
    if (_filterRecurring != null) {
      setState(() => _filterRecurring = null);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.filterRecurringTasks, style: ConnecteamStyle.headerTitle.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.of(context)!.allTasks),
              leading: Radio<bool?>(
                value: null,
                groupValue: _filterRecurring,
                onChanged: (value) {
                  setState(() => _filterRecurring = null);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.recurringOnly),
              leading: Radio<bool?>(
                value: true,
                groupValue: _filterRecurring,
                onChanged: (value) {
                  setState(() => _filterRecurring = true);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.oneTimeOnly),
              leading: Radio<bool?>(
                value: false,
                groupValue: _filterRecurring,
                onChanged: (value) {
                  setState(() => _filterRecurring = false);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<AppUser>> _getAllUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      return snapshot.docs
          .map((doc) => AppUser.fromFirestore(doc))
          .where((user) => user.isActive)
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching users: $e');
      return [];
    }
  }

  // Bulk Operation Methods
  void _showBulkStatusChange() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!
            .taskBulkChangeStatus(_selectedTaskIds.length),
            style: ConnecteamStyle.headerTitle.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskStatus.values.map((status) => ListTile(
            title: Text(_getStatusLabel(status)),
            onTap: () async {
              Navigator.pop(context);
              await _bulkChangeStatus(status);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showBulkPriorityChange() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!
            .taskBulkChangePriority(_selectedTaskIds.length),
            style: ConnecteamStyle.headerTitle.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskPriority.values.map((priority) => ListTile(
            title: Text(_getPriorityLabel(priority)),
            onTap: () async {
              Navigator.pop(context);
              await _bulkChangePriority(priority);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showBulkDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteTasks),
        content: Text(AppLocalizations.of(context)!
            .taskBulkDeleteConfirm(_selectedTaskIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _bulkDeleteTasks();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.commonDelete),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkChangeStatus(TaskStatus status) async {
    try {
      final selectedCount = _selectedTaskIds.length;
      // Get tasks from Firestore and update them
      final batch = FirebaseFirestore.instance.batch();
      for (final taskId in _selectedTaskIds) {
        final taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
        batch.update(taskRef, {'status': status.name});
      }
      await batch.commit();
      
      setState(() {
        _selectedTaskIds.clear();
        _isBulkMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.updatedSelectedcountTaskS)),
        );
      }
    } catch (e) {
      AppLogger.error('Error bulk changing status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingTasksE)),
        );
      }
    }
  }

  Future<void> _bulkChangePriority(TaskPriority priority) async {
    try {
      final selectedCount = _selectedTaskIds.length;
      // Get tasks from Firestore and update them
      final batch = FirebaseFirestore.instance.batch();
      for (final taskId in _selectedTaskIds) {
        final taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
        batch.update(taskRef, {'priority': priority.name});
      }
      await batch.commit();
      
      setState(() {
        _selectedTaskIds.clear();
        _isBulkMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.updatedSelectedcountTaskS)),
        );
      }
    } catch (e) {
      AppLogger.error('Error bulk changing priority: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingTasksE)),
        );
      }
    }
  }

  Future<void> _bulkDeleteTasks() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.youMustBeLoggedInTo),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Filter tasks to only those created by current user
    final tasksToDelete = <String>[];
    for (final taskId in _selectedTaskIds) {
      try {
        final taskDoc = await FirebaseFirestore.instance
            .collection('tasks')
            .doc(taskId)
            .get();
        if (taskDoc.exists) {
          final task = Task.fromFirestore(taskDoc);
          if (task.createdBy == currentUser.uid) {
            tasksToDelete.add(taskId);
          }
        }
      } catch (e) {
        AppLogger.error('Error checking task $taskId: $e');
      }
    }

    if (tasksToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.youCanOnlyDeleteTasksYou),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int count = 0;
    int failed = 0;
    for (final taskId in tasksToDelete) {
      try {
        await _taskService.deleteTask(taskId);
        count++;
      } catch (e) {
        AppLogger.error('Error deleting task $taskId: $e');
        failed++;
      }
    }

    setState(() {
      _selectedTaskIds.clear();
      _isBulkMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed > 0
                ? 'Deleted $count task(s), $failed failed'
                : 'Deleted $count task(s)',
          ),
          backgroundColor: failed > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  void _showAddEditTaskDialog({Task? task, String? preSelectedAssignee}) {
    showDialog(
      context: context,
      builder: (context) => AddEditTaskDialog(
        task: task,
        preSelectedAssignee: preSelectedAssignee,
      ),
    ).then((_) {
      // Reload tasks after dialog closes
      _loadUserRoleAndTasks();
    });
  }

  void _showMultipleTaskCreationDialog({List<String>? preSelectedAssignees}) {
    showDialog(
      context: context,
      builder: (context) => MultipleTaskCreationDialog(
        preSelectedAssignees: preSelectedAssignees,
      ),
    ).then((_) {
      // Reload tasks after dialog closes
      _loadUserRoleAndTasks();
    });
  }

  /// Build Add Task button with dropdown menu
  Widget _buildAddTaskButton() {
    return PopupMenuButton<String>(
      offset: const Offset(0, -60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: FloatingActionButton.extended(
        backgroundColor: ConnecteamStyle.primaryBlue,
        label: Text(
          AppLocalizations.of(context)!.addTask,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.add),
        onPressed: () {
          // Default action: show single task dialog
          _showAddEditTaskDialog();
        },
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'single',
          child: Row(
            children: [
              const Icon(Icons.add_task, size: 20),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.addSingleTask, style: GoogleFonts.inter()),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'multiple',
          child: Row(
            children: [
              const Icon(Icons.post_add, size: 20),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.addMultipleTasks, style: GoogleFonts.inter()),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'multiple') {
          _showMultipleTaskCreationDialog();
        } else {
          _showAddEditTaskDialog();
        }
      },
    );
  }

  void _showTaskDetailsDialog(Task task) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _buildTaskDetailsDialog(task),
    );
  }

  Widget _buildTaskDetailsDialog(Task task) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(
          maxHeight: 700,
          maxWidth: 600,
        ),
        child: TaskDetailsView(
          task: task,
          onTaskUpdated: () {
            // Refresh the task list when task is updated
            setState(() {});
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Task task) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final canDelete = currentUser != null && task.createdBy == currentUser.uid;
    
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.onlyTheTaskCreatorCanDelete),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(AppLocalizations.of(context)!.deleteTask),
        content:
            Text(AppLocalizations.of(context)!.taskDeleteConfirm(task.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _taskService.deleteTask(task.id);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.taskDeletedSuccessfully),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.commonDelete),
          ),
        ],
      ),
    );
  }
}
