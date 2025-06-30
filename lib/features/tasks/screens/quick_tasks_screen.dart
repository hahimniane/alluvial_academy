import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/add_edit_task_dialog.dart';

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
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimationController.forward();
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
      floatingActionButton: ScaleTransition(
        scale: _fabAnimationController,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddEditTaskDialog(),
          backgroundColor: const Color(0xff0386FF),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Task',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
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
        title: const Text(
          'Task Management',
          style: TextStyle(
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
        _buildFilterChips(),
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
      ],
    );
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
    return StreamBuilder<List<Task>>(
      stream: _taskService.getTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text('Error: ${snapshot.error}'),
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
          onTap: () => _showAddEditTaskDialog(task: task),
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
    // Handle null or empty assigneeId
    final displayChar =
        assigneeId.isNotEmpty ? assigneeId.substring(0, 1).toUpperCase() : '?';

    return Container(
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
                color: const Color(0xff0386FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt,
                size: 60,
                color: Color(0xff0386FF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No tasks yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first task to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
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
