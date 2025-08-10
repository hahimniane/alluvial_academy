import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/add_edit_task_dialog.dart';
import '../widgets/task_details_view.dart';
import '../widgets/user_selection_dialog.dart' as task_filters;
import '../../../core/services/user_role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimationController.forward();
    
    // Start loading immediately and also listen for auth state changes
    _loadUserRoleAndTasks();
    _listenToAuthState();
    _listenToRoleChanges();
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
          print('QuickTasks: Role change detected! Admin: $_isAdmin -> $currentAdmin');
          // Role has changed, reload tasks
          _loadUserRoleAndTasks();
        }
      } catch (e) {
        print('QuickTasks: Error checking role changes: $e');
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
        });
        
        print('Tasks loaded successfully. Admin: $isAdmin');
      }
    } catch (e) {
      print('Error loading user role and tasks: $e');
      
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildModernAppBar(),
          SliverToBoxAdapter(child: _buildSearchAndFilters()),
          _buildTaskGrid(),
        ],
      ),
      // Only show floating action button for admins
      floatingActionButton: _isAdmin
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: FloatingActionButton.extended(
                heroTag: "addTaskFAB", // Unique hero tag to avoid conflicts
                onPressed: () => _showAddEditTaskDialog(),
                backgroundColor: const Color(0xff0386FF),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('New Task',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            )
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
          hintText: 'Search tasks...',
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
        const Text(
          'Filters',
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
          label: 'All Tasks',
          isSelected: _selectedStatus == null && _selectedPriority == null && 
                     _dueDateRange == null && _filterAssignedByUserId == null && 
                     _filterAssignedToUserIds.isEmpty,
          onSelected: () => setState(() {
            _selectedStatus = null;
            _selectedPriority = null;
            _dueDateRange = null;
            _filterAssignedByUserId = null;
            _filterAssignedToUserIds = [];
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
                initialDateRange: DateTimeRange(start: currentMonthStart, end: currentMonthEnd),
                currentDate: now,
                helpText: 'Select Date Range for Tasks',
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
                              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xff0386FF);
                                }
                                return null;
                              }),
                              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
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
        
        // Assigned By filter chip
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
        
        // Assigned To filter chip
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
          label: 'All Tasks',
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
               helpText: 'Select Date Range for Tasks',
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
                             dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                               if (states.contains(WidgetState.selected)) {
                                 return const Color(0xff0386FF);
                               }
                               return null;
                             }),
                             dayForegroundColor: WidgetStateProperty.resolveWith((states) {
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
           onDeleted:
               _dueDateRange != null ? () => setState(() => _dueDateRange = null) : null,
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
    final names = ids.map((id) => _userIdToName[id] ?? '').where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return 'Loading...';
    if (names.length == 1) return names.first;
    return '${names.first} +${names.length - 1}';
  }

  void _fetchUserNameIfMissing(String userId) async {
    if (_userIdToName.containsKey(userId) || _fetchingUserIds.contains(userId)) return;
    _fetchingUserIds.add(userId);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        final d = doc.data() as Map<String, dynamic>;
        final fullName = '${(d['first_name'] ?? '').toString().trim()} ${(d['last_name'] ?? '').toString().trim()}'.trim();
        setState(() => _userIdToName[userId] = fullName.isNotEmpty ? fullName : (d['e-mail'] ?? userId));
      }
    } catch (_) {
      // ignore
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
        final include = userType == 'admin' || (userType == 'teacher' && isAdminTeacher);
        if (!include) continue;
        final fullName = '${(d['first_name'] ?? '').toString().trim()} ${(d['last_name'] ?? '').toString().trim()}'.trim();
        final displayName = fullName.isNotEmpty ? fullName : (d['e-mail'] ?? doc.id);
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
          title: 'Select Assigned By',
          subtitle: 'Choose an admin or promoted teacher',
          availableUsers: options,
          selectedUserIds: _filterAssignedByUserId != null ? [_filterAssignedByUserId!] : [],
          allowMultiple: false,
          onUsersSelected: (userIds) {
            if (mounted) {
              setState(() => _filterAssignedByUserId = userIds.isEmpty ? null : userIds.first);
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
        final fullName = '${(d['first_name'] ?? '').toString().trim()} ${(d['last_name'] ?? '').toString().trim()}'.trim();
        final display = fullName.isNotEmpty ? fullName : (d['e-mail'] ?? doc.id);
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
          title: 'Select Assigned To',
          subtitle: 'Choose users to assign this task to',
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
                  _taskStream == null ? 'Initializing tasks...' : 'Loading tasks...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we load your tasks',
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
                  label: const Text('Retry'),
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
        print('StreamBuilder state: ${snapshot.connectionState}');
        print('Has data: ${snapshot.hasData}');
        print('Data length: ${snapshot.hasData ? snapshot.data!.length : 'N/A'}');
        print('Has error: ${snapshot.hasError}');
        if (snapshot.hasError) {
          print('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                    ),
                    SizedBox(height: 16),
                    Text('Connecting to task database...'),
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
                      'Error loading tasks',
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
                      label: const Text('Retry'),
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
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
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

    if (_filterAssignedByUserId != null && _filterAssignedByUserId!.isNotEmpty) {
      filteredTasks = filteredTasks
          .where((task) => task.createdBy == _filterAssignedByUserId)
          .toList();
    }

    if (_filterAssignedToUserIds.isNotEmpty) {
      filteredTasks = filteredTasks.where((task) {
        return task.assignedTo.any((assignee) =>
            _filterAssignedToUserIds.contains(assignee));
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(task),
                const SizedBox(height: 12),
                _buildTaskTitle(task),
                const SizedBox(height: 8),
                _buildTaskDescription(task),
                const Spacer(),
                _buildDueDateSection(task, daysUntilDue, isOverdue, isDueSoon),
                const SizedBox(height: 12),
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
      children: [
        _buildPriorityIndicator(task.priority),
        const Spacer(),
        _buildTaskActions(task),
      ],
    );
  }

  Widget _buildPriorityIndicator(TaskPriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPriorityColor(priority).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getPriorityLabel(priority),
        style: TextStyle(
          color: _getPriorityColor(priority),
          fontSize: 12,
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
        const PopupMenuItem(value: 'edit', child: Text('Edit Task')),
        const PopupMenuItem(value: 'delete', child: Text('Delete Task')),
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
      maxLines: 2,
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

    if (isOverdue) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    return Row(
      children: [
        _buildStatusChip(task.status),
        const Spacer(),
        _buildMultipleAssigneeAvatars(task.assignedTo),
      ],
    );
  }

  Widget _buildStatusChip(TaskStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    '+$remainingCount',
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
        : (assigneeId.isNotEmpty ? assigneeId.substring(0, 1).toUpperCase() : '?');
    
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
                label: const Text('Create Task'),
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
            const Text(
              'No tasks found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search term',
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

  // Helper methods
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
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

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return const Color(0xFF3B82F6);
      case TaskStatus.inProgress:
        return const Color(0xFF8B5CF6);
      case TaskStatus.done:
        return const Color(0xFF10B981);
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return const Color(0xFF10B981);
      case TaskPriority.medium:
        return const Color(0xFFF59E0B);
      case TaskPriority.high:
        return const Color(0xFFEF4444);
    }
  }

  void _showAddEditTaskDialog({Task? task}) {
    showDialog(
      context: context,
      builder: (context) => AddEditTaskDialog(task: task),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _taskService.deleteTask(task.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
