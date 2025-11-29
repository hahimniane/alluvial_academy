import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../../../core/enums/task_enums.dart';

/// ConnectTeam-style task list grouped by assignee
/// Displays tasks in a table format with status, labels, dates
class ConnectTeamTaskList extends StatefulWidget {
  final List<Task> tasks;
  final String groupBy; // 'assignee', 'status', 'priority', 'none'
  final Function(Task) onTaskTap;
  final Function(Task) onTaskStatusChange;
  final Function(String? assigneeId) onAddTask;
  final Map<String, String> userIdToName;
  
  const ConnectTeamTaskList({
    super.key,
    required this.tasks,
    required this.groupBy,
    required this.onTaskTap,
    required this.onTaskStatusChange,
    required this.onAddTask,
    required this.userIdToName,
  });

  @override
  State<ConnectTeamTaskList> createState() => _ConnectTeamTaskListState();
}

class _ConnectTeamTaskListState extends State<ConnectTeamTaskList> {
  final Set<String> _expandedGroups = {};
  final Set<String> _selectedTaskIds = {}; // Track selected tasks for bulk actions
  bool _isSelectAllMode = false; // Whether we're in bulk selection mode
  final Map<String, bool> _expandedParentTasks = {}; // Track which parent tasks are expanded
  final Map<String, List<Task>> _subTasksCache = {}; // Cache sub-tasks for parent tasks
  final Set<String> _fetchingUserNames = {}; // Track user names being fetched

  @override
  void initState() {
    super.initState();
    // Expand all groups by default
    _expandedGroups.addAll(_getGroupKeys());
  }

  Set<String> _getGroupKeys() {
    if (widget.groupBy == 'none') return {'all'};
    
    final keys = <String>{};
    for (var task in widget.tasks) {
      if (widget.groupBy == 'assignee') {
        for (var id in task.assignedTo) {
          keys.add(id);
        }
        if (task.assignedTo.isEmpty) keys.add('unassigned');
      } else if (widget.groupBy == 'status') {
        keys.add(task.status.name);
      } else if (widget.groupBy == 'priority') {
        keys.add(task.priority.name);
      }
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();

    return Column(
      children: [
        // Header row
        _buildHeaderRow(),
        const Divider(height: 1),
        // Bulk actions bar (appears when tasks are selected)
        if (_selectedTaskIds.isNotEmpty) _buildBulkActionsBar(),
        // Grouped task list
        Expanded(
          child: ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _buildGroup(group);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    final allTasksSelected = _selectedTaskIds.length == widget.tasks.length && widget.tasks.isNotEmpty;
    final someTasksSelected = _selectedTaskIds.isNotEmpty && _selectedTaskIds.length < widget.tasks.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xffF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xffE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          // Select all checkbox
          SizedBox(
            width: 40,
            child: Checkbox(
              value: allTasksSelected,
              tristate: true,
              onChanged: (value) {
                setState(() {
                  if (value == true || allTasksSelected) {
                    // Select all
                    _selectedTaskIds.clear();
                    _selectedTaskIds.addAll(widget.tasks.map((t) => t.id));
                    _isSelectAllMode = true;
                  } else {
                    // Deselect all
                    _selectedTaskIds.clear();
                    _isSelectAllMode = false;
                  }
                });
              },
              activeColor: const Color(0xff0386FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(
                  'Task',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff6B7280),
                    letterSpacing: 0.3,
                  ),
                ),
                if (_selectedTaskIds.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedTaskIds.length} selected',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff0386FF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Center(
              child: Text(
                'Comments',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff6B7280),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Center(
              child: Text(
                'Status',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff6B7280),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Center(
              child: Text(
                'Sub-tasks',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff6B7280),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Center(
              child: Text(
                'Label',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff6B7280),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              'Start date',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xff6B7280),
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              'Due date',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xff6B7280),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TaskGroup> _buildGroups() {
    if (widget.groupBy == 'none') {
      return [
        _TaskGroup(
          id: 'all',
          name: 'All Tasks',
          tasks: widget.tasks,
        ),
      ];
    }

    final Map<String, List<Task>> groupedTasks = {};

    for (var task in widget.tasks) {
      if (widget.groupBy == 'assignee') {
        if (task.assignedTo.isEmpty) {
          groupedTasks.putIfAbsent('unassigned', () => []).add(task);
        } else {
          for (var id in task.assignedTo) {
            groupedTasks.putIfAbsent(id, () => []).add(task);
          }
        }
      } else if (widget.groupBy == 'status') {
        groupedTasks.putIfAbsent(task.status.name, () => []).add(task);
      } else if (widget.groupBy == 'priority') {
        groupedTasks.putIfAbsent(task.priority.name, () => []).add(task);
      }
    }

    return groupedTasks.entries.map((entry) {
      String name;
      if (widget.groupBy == 'assignee') {
        if (entry.key == 'unassigned') {
          name = 'Unassigned';
        } else {
          // Try to get name from userIdToName map
          final userName = widget.userIdToName[entry.key];
          if (userName != null && userName.isNotEmpty && !_looksLikeFirestoreId(userName)) {
            name = userName;
          } else {
            // If no name found, check if it's an email
            if (entry.key.contains('@')) {
              // Extract name from email (e.g., john.doe@email.com -> John Doe)
              final emailParts = entry.key.split('@')[0].split('.');
              name = emailParts.map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1)).join(' ');
            } else if (_looksLikeFirestoreId(entry.key)) {
              // It's a Firestore ID, show "Loading..." or fetch asynchronously
              name = 'Loading...';
              // Trigger async fetch if not already done
              _fetchUserNameAsync(entry.key);
            } else {
              name = entry.key; // Use as-is if it's not an ID
            }
          }
        }
      } else if (widget.groupBy == 'status') {
        name = _formatStatusName(entry.key);
      } else if (widget.groupBy == 'priority') {
        name = _formatPriorityName(entry.key);
      } else {
        name = entry.key;
      }

      return _TaskGroup(
        id: entry.key,
        name: name,
        tasks: entry.value,
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }
  
  /// Check if a string looks like a Firestore document ID (20-28 alphanumeric chars)
  bool _looksLikeFirestoreId(String str) {
    return str.length >= 20 && 
           str.length <= 28 && 
           RegExp(r'^[a-zA-Z0-9]+$').hasMatch(str);
  }
  
  /// Async fetch user name and update state
  void _fetchUserNameAsync(String userId) async {
    if (_fetchingUserNames.contains(userId)) return;
    _fetchingUserNames.add(userId);
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final firstName = (data['first_name'] ?? '').toString().trim();
        final lastName = (data['last_name'] ?? '').toString().trim();
        final email = (data['e-mail'] ?? data['email'] ?? '').toString();
        
        String displayName;
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          displayName = '$firstName $lastName'.trim();
        } else if (email.isNotEmpty && email.contains('@')) {
          final emailParts = email.split('@')[0].split('.');
          displayName = emailParts.map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1)).join(' ');
        } else {
          displayName = 'User';
        }
        
        // Update parent's userIdToName map would be better, but for now just rebuild
        setState(() {});
      }
    } catch (e) {
      // Ignore errors
    } finally {
      _fetchingUserNames.remove(userId);
    }
  }

  Widget _buildGroup(_TaskGroup group) {
    final isExpanded = _expandedGroups.contains(group.id);
    final completedCount = group.tasks.where((t) => t.status == TaskStatus.done).length;
    final totalCount = group.tasks.length;

    return Column(
      children: [
        // Group header
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedGroups.remove(group.id);
              } else {
                _expandedGroups.add(group.id);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xffF3F4F6),
              border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                  color: const Color(0xff6B7280),
                ),
                const SizedBox(width: 8),
                // Avatar for assignee with optional crown/star icon
                if (widget.groupBy == 'assignee' && group.id != 'unassigned')
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _getAvatarColor(group.name),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(group.name),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Optional crown/star icon for special users (can be enhanced)
                      // Positioned(
                      //   right: -2,
                      //   top: -2,
                      //   child: Container(
                      //     width: 14,
                      //     height: 14,
                      //     decoration: BoxDecoration(
                      //       color: Colors.amber,
                      //       shape: BoxShape.circle,
                      //     ),
                      //     child: const Icon(Icons.star, size: 10, color: Colors.white),
                      //   ),
                      // ),
                    ],
                  ),
                Expanded(
                  child: Text(
                    group.name.isNotEmpty ? group.name : 'Unknown',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Progress indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: completedCount == totalCount 
                        ? const Color(0xff10B981).withOpacity(0.1)
                        : const Color(0xffF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$completedCount / $totalCount Done',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: completedCount == totalCount 
                          ? const Color(0xff10B981)
                          : const Color(0xff6B7280),
                    ),
                  ),
                ),
                const Spacer(),
                // Add task button for this group
                TextButton.icon(
                  onPressed: () => widget.onAddTask(
                    widget.groupBy == 'assignee' && group.id != 'unassigned' 
                        ? group.id 
                        : null
                  ),
                  icon: const Icon(Icons.add, size: 16, color: Color(0xff0386FF)),
                  label: Text(
                    'Add task',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff0386FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tasks - separate parent tasks from regular tasks
        if (isExpanded) ...[
          ...group.tasks.where((task) => task.subTaskIds.isNotEmpty).map((task) => _buildParentTaskRow(task)),
          ...group.tasks.where((task) => task.subTaskIds.isEmpty && !_isSubTask(task, group.tasks)).map((task) => _buildTaskRow(task)),
        ],
      ],
    );
  }

  /// Check if a task is a sub-task of any parent task
  bool _isSubTask(Task task, List<Task> allTasks) {
    for (var parentTask in allTasks) {
      if (parentTask.subTaskIds.contains(task.id)) {
        return true;
      }
    }
    return false;
  }

  /// Build a parent task row with expandable sub-tasks
  Widget _buildParentTaskRow(Task parentTask) {
    final isExpanded = _expandedParentTasks[parentTask.id] ?? false;
    final hasSubTasks = parentTask.subTaskIds.isNotEmpty;
    
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedParentTasks[parentTask.id] = !isExpanded;
            });
          },
          hoverColor: const Color(0xffF9FAFB),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                bottom: BorderSide(color: Color(0xffF3F4F6), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Expand/collapse icon
                SizedBox(
                  width: 24,
                  child: Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: const Color(0xff6B7280),
                  ),
                ),
                // Badge with sub-task count
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xffEC4899).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xffEC4899).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${parentTask.subTaskIds.length}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xffEC4899),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Task title - use description if title is empty or looks like an ID
                Expanded(
                  flex: 3,
                  child: Text(
                    _getTaskDisplayName(parentTask),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Comments
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: const Color(0xff9CA3AF),
                    ),
                  ),
                ),
                // Status with sub-task progress
                SizedBox(
                  width: 90,
                  child: FutureBuilder<int>(
                    future: _getSubTaskCount(parentTask.subTaskIds),
                    builder: (context, snapshot) {
                      final done = snapshot.data ?? 0;
                      final total = parentTask.subTaskIds.length;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xffF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$done / $total Done',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Sub-tasks
                SizedBox(
                  width: 90,
                  child: Center(
                    child: Text(
                      '--',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff9CA3AF),
                      ),
                    ),
                  ),
                ),
                // Label
                SizedBox(
                  width: 90,
                  child: Center(
                    child: Text(
                      '--',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff9CA3AF),
                      ),
                    ),
                  ),
                ),
                // Start date
                SizedBox(
                  width: 150,
                  child: Text(
                    '--',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff9CA3AF),
                    ),
                  ),
                ),
                // Due date with "Add task" button
                SizedBox(
                  width: 150,
                  child: TextButton.icon(
                    onPressed: () => widget.onAddTask(null),
                    icon: const Icon(Icons.add, size: 14, color: Color(0xff0386FF)),
                    label: Text(
                      'Add task',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xff0386FF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Sub-tasks (nested with indentation)
        if (isExpanded && hasSubTasks)
          ..._buildSubTasks(parentTask.subTaskIds),
      ],
    );
  }

  /// Build sub-task rows (indented under parent)
  List<Widget> _buildSubTasks(List<String> subTaskIds) {
    return subTaskIds.map((id) {
      // Find the sub-task in all tasks
      final subTask = widget.tasks.firstWhere(
        (t) => t.id == id,
        orElse: () => Task(
          id: id,
          title: 'Loading...',
          description: '',
          createdBy: '',
          assignedTo: [],
          dueDate: DateTime.now(),
          createdAt: Timestamp.now(),
        ),
      );
      
      return Container(
        margin: const EdgeInsets.only(left: 40), // Indent sub-tasks
        child: _buildTaskRow(subTask),
      );
    }).toList();
  }

  Widget _buildTaskRow(Task task) {
    final isOverdue = task.dueDate != null && 
        task.dueDate!.isBefore(DateTime.now()) && 
        task.status != TaskStatus.done;

    return InkWell(
      onTap: () => widget.onTaskTap(task),
      hoverColor: const Color(0xffF9FAFB),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: task.status == TaskStatus.done 
              ? const Color(0xffFAFAFA) 
              : Colors.white,
          border: const Border(
            bottom: BorderSide(color: Color(0xffF3F4F6), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Selection checkbox (shown when in selection mode or when tasks are selected)
            SizedBox(
              width: 40,
              child: _isSelectAllMode || _selectedTaskIds.isNotEmpty
                  ? Checkbox(
                      value: _selectedTaskIds.contains(task.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedTaskIds.add(task.id);
                          } else {
                            _selectedTaskIds.remove(task.id);
                          }
                          if (_selectedTaskIds.isEmpty) {
                            _isSelectAllMode = false;
                          }
                        });
                      },
                      activeColor: const Color(0xff0386FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  : Transform.scale(
                      scale: 0.95,
                      child: Checkbox(
                        value: task.status == TaskStatus.done,
                        onChanged: (value) {
                          widget.onTaskStatusChange(task);
                        },
                        activeColor: const Color(0xff10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
            ),
            // Task title with draft label - flexible width
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  // Draft label (ConnectTeam style)
                  if (task.isDraft)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xff6B7280).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xff6B7280).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Draft',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff6B7280),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _getTaskDisplayName(task),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: task.status == TaskStatus.done
                            ? const Color(0xff9CA3AF)
                            : const Color(0xff111827),
                        decoration: task.status == TaskStatus.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Comments icon
            SizedBox(
              width: 70,
              child: Center(
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: const Color(0xff9CA3AF),
                ),
              ),
            ),
            // Status button (clickable to toggle)
            SizedBox(
              width: 90,
              child: _buildStatusButton(task.status, task),
            ),
            // Sub-tasks (show count like "0 / 1 Done" or "6 / 14 Done")
            SizedBox(
              width: 90,
              child: Center(
                child: task.subTaskIds.isEmpty
                    ? Text(
                        '--',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff9CA3AF),
                        ),
                      )
                    : FutureBuilder<int>(
                        future: _getSubTaskCount(task.subTaskIds),
                        builder: (context, snapshot) {
                          final total = task.subTaskIds.length;
                          final done = snapshot.data ?? 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: done == total
                                  ? const Color(0xff10B981).withOpacity(0.1)
                                  : const Color(0xffF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$done / $total Done',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: done == total
                                    ? const Color(0xff10B981)
                                    : const Color(0xff6B7280),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            // Label (show labels as chips)
            SizedBox(
              width: 90,
              child: Center(
                child: task.labels.isEmpty
                    ? Text(
                        '--',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff9CA3AF),
                        ),
                      )
                    : Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: task.labels.take(2).map((label) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xff0386FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xff0386FF).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff0386FF),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList()
                          ..addAll(task.labels.length > 2
                              ? [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff6B7280).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '+${task.labels.length - 2}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xff6B7280),
                                      ),
                                    ),
                                  ),
                                ]
                              : []),
                      ),
              ),
            ),
            // Start date with time (ConnectTeam style: "Today at 11:28")
            SizedBox(
              width: 150,
              child: Text(
                task.startDate != null 
                    ? _formatDateWithTime(task.startDate!)
                    : '--',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                ),
              ),
            ),
            // Due date with time (ConnectTeam style: "Today at 12:28")
            SizedBox(
              width: 150,
              child: Text(
                task.dueDate != null 
                    ? _formatDateWithTime(task.dueDate!)
                    : '--',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isOverdue ? const Color(0xffEF4444) : const Color(0xff6B7280),
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(TaskStatus status, Task task) {
    Color color;
    String label;
    
    switch (status) {
      case TaskStatus.todo:
        color = const Color(0xff6B7280);
        label = 'Open';
        break;
      case TaskStatus.inProgress:
        color = const Color(0xff3B82F6);
        label = 'In Progress';
        break;
      case TaskStatus.done:
        color = const Color(0xff10B981);
        label = 'Done';
        break;
      default:
        color = const Color(0xff6B7280);
        label = 'Open';
        break;
    }

    return OutlinedButton(
      onPressed: () {
        // Toggle status between Open and Done (ConnectTeam style)
        final newStatus = status == TaskStatus.done 
            ? TaskStatus.todo 
            : TaskStatus.done;
        widget.onTaskStatusChange(task);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 28),
        side: BorderSide(color: color.withOpacity(0.3)),
        backgroundColor: color.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBulkActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xff0386FF),
        border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedTaskIds.length} task${_selectedTaskIds.length == 1 ? '' : 's'} selected',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Mark as Done button
          TextButton.icon(
            onPressed: () {
              _bulkMarkAsDone();
            },
            icon: const Icon(Icons.check_circle, size: 18, color: Colors.white),
            label: Text(
              'Mark as Done',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Cancel selection button
          IconButton(
            onPressed: () {
              setState(() {
                _selectedTaskIds.clear();
                _isSelectAllMode = false;
              });
            },
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Cancel selection',
          ),
        ],
      ),
    );
  }

  void _bulkMarkAsDone() {
    // Get selected tasks
    final selectedTasks = widget.tasks.where((t) => _selectedTaskIds.contains(t.id)).toList();
    
    // Update each task to done status
    for (var task in selectedTasks) {
      if (task.status != TaskStatus.done) {
        widget.onTaskStatusChange(task);
      }
    }
    
    // Clear selection
    setState(() {
      _selectedTaskIds.clear();
      _isSelectAllMode = false;
    });
  }

  Widget _buildStatusChip(TaskStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case TaskStatus.todo:
        color = const Color(0xff6B7280);
        label = 'Open';
        break;
      case TaskStatus.inProgress:
        color = const Color(0xff3B82F6);
        label = 'In Progress';
        break;
      case TaskStatus.done:
        color = const Color(0xff10B981);
        label = 'Done';
        break;
      default:
        color = const Color(0xff6B7280);
        label = 'Open';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(TaskPriority priority) {
    final color = _getPriorityColor(priority);
    final label = priority.name[0].toUpperCase() + priority.name.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return const Color(0xff10B981);
      case TaskPriority.medium:
        return const Color(0xffF59E0B);
      case TaskPriority.high:
        return const Color(0xffEF4444);
    }
  }

  String _formatStatusName(String status) {
    switch (status) {
      case 'todo':
        return 'To Do';
      case 'inProgress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatPriorityName(String priority) {
    return priority[0].toUpperCase() + priority.substring(1);
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xff3B82F6),
      const Color(0xff10B981),
      const Color(0xffF59E0B),
      const Color(0xffEF4444),
      const Color(0xff8B5CF6),
      const Color(0xffEC4899),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Get a meaningful display name for a task
  /// Uses title if available, otherwise description, otherwise a generated name
  String _getTaskDisplayName(Task task) {
    // If title exists and is meaningful (not empty, not just an ID)
    if (task.title.isNotEmpty && !_looksLikeId(task.title, task.id)) {
      return task.title;
    }
    
    // Try description if title is empty or looks like ID
    if (task.description.isNotEmpty && !_looksLikeId(task.description, task.id)) {
      // Use first line of description, max 50 chars
      final desc = task.description.split('\n').first.trim();
      if (desc.isNotEmpty) {
        return desc.length > 50 ? '${desc.substring(0, 50)}...' : desc;
      }
    }
    
    // If both are empty or look like IDs, generate a name from labels
    if (task.labels.isNotEmpty) {
      return 'Task: ${task.labels.first}';
    }
    
    // Last resort: use a generic name with date
    final dateStr = DateFormat('MMM d').format(task.dueDate);
    return 'Task ($dateStr)';
  }
  
  /// Check if a string looks like a Firestore document ID
  bool _looksLikeId(String str, String taskId) {
    // Firestore IDs are typically 20-28 characters, alphanumeric
    // If it matches the task ID exactly, it's probably an ID being used as a title
    return str == taskId || 
           (str.length >= 20 && 
            str.length <= 28 && 
            RegExp(r'^[a-zA-Z0-9]+$').hasMatch(str));
  }

  /// Get sub-task completion count
  Future<int> _getSubTaskCount(List<String> subTaskIds) async {
    if (subTaskIds.isEmpty) return 0;
    try {
      // Query all sub-tasks and count how many are done
      final futures = subTaskIds.map((id) async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('tasks')
              .doc(id)
              .get();
          if (doc.exists) {
            final data = doc.data();
            final status = data?['status']?.toString() ?? '';
            return status.contains('done') ? 1 : 0;
          }
        } catch (e) {
          return 0;
        }
        return 0;
      });
      
      final results = await Future.wait(futures);
      int total = 0;
      for (final count in results) {
        total += count;
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Format date with time in ConnectTeam style: "Today at 11:28" or "Tomorrow at 9:00" or "Dec 15 at 2:30 PM"
  String _formatDateWithTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    String dateStr;
    if (dateOnly == today) {
      dateStr = 'Today';
    } else if (dateOnly == tomorrow) {
      dateStr = 'Tomorrow';
    } else if (dateOnly == yesterday) {
      dateStr = 'Yesterday';
    } else {
      // Format as "Dec 15" for dates within the same year, or "Dec 15, 2024" for other years
      if (date.year == now.year) {
        dateStr = DateFormat('MMM d').format(date);
      } else {
        dateStr = DateFormat('MMM d, yyyy').format(date);
      }
    }
    
    // Format time as "at 11:28" or "at 2:30 PM"
    final timeStr = DateFormat('h:mm a').format(date);
    
    return '$dateStr at $timeStr';
  }
}

class _TaskGroup {
  final String id;
  final String name;
  final List<Task> tasks;

  _TaskGroup({
    required this.id,
    required this.name,
    required this.tasks,
  });
}

