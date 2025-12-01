import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../../../core/enums/task_enums.dart';
import '../../../core/utils/connecteam_style.dart';

/// ConnectTeam-style task list grouped by assignee
/// Displays tasks in a table format with status, labels, dates
class ConnectTeamTaskList extends StatefulWidget {
  final List<Task> tasks;
  final String groupBy; // 'assignee', 'status', 'priority', 'none'
  final Function(Task) onTaskTap;
  final Function(Task) onTaskStatusChange;
  final Function(String? assigneeId) onAddTask;
  final Map<String, String> userIdToName;
  final Set<String> selectedTaskIds;
  final Function(String, bool) onSelectionChanged;
  final bool isBulkMode;
  final Function(Task)? onTaskDelete; // Optional delete callback
  final String? currentUserId; // Current user ID for permission checks
  
  const ConnectTeamTaskList({
    super.key,
    required this.tasks,
    required this.groupBy,
    required this.onTaskTap,
    required this.onTaskStatusChange,
    required this.onAddTask,
    required this.userIdToName,
    this.selectedTaskIds = const {},
    required this.onSelectionChanged,
    this.isBulkMode = false,
    this.onTaskDelete,
    this.currentUserId,
  });

  @override
  State<ConnectTeamTaskList> createState() => _ConnectTeamTaskListState();
}

class _ConnectTeamTaskListState extends State<ConnectTeamTaskList> {

  @override
  Widget build(BuildContext context) {
    // Use table-like structure for Connecteam style
    return Container(
      decoration: ConnecteamStyle.containerShadow,
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: widget.tasks.isEmpty 
                ? Center(child: Text('No tasks found', style: ConnecteamStyle.cellText))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80.0), // Space for FAB
                    itemCount: widget.tasks.length,
                    separatorBuilder: (c, i) => const Divider(
                      height: 1,
                      color: ConnecteamStyle.borderColor,
                    ),
                    itemBuilder: (context, index) {
                      return _buildTaskRow(widget.tasks[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final allSelected = widget.tasks.isNotEmpty && 
        widget.selectedTaskIds.length == widget.tasks.length;
    final someSelected = widget.selectedTaskIds.isNotEmpty && 
        widget.selectedTaskIds.length < widget.tasks.length;
    
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xffF9FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: ConnecteamStyle.borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: widget.isBulkMode
                ? Checkbox(
                    value: allSelected,
                    tristate: true,
                    onChanged: (value) {
                      if (value == true || allSelected) {
                        // Select all
                        for (final task in widget.tasks) {
                          widget.onSelectionChanged(task.id, true);
                        }
                      } else {
                        // Deselect all
                        for (final task in widget.tasks) {
                          widget.onSelectionChanged(task.id, false);
                        }
                      }
                    },
                  )
                : const SizedBox(),
          ),
          Expanded(flex: 4, child: Text("TASK NAME", style: ConnecteamStyle.tableHeader)),
          Expanded(flex: 2, child: Text("STATUS", style: ConnecteamStyle.tableHeader)),
          Expanded(flex: 2, child: Text("DUE DATE", style: ConnecteamStyle.tableHeader)),
          Expanded(flex: 1, child: Text("PRIORITY", style: ConnecteamStyle.tableHeader)),
        ],
      ),
    );
  }

  Widget _buildTaskRow(Task task) {
    // Get first assignee for avatar
    final firstAssigneeId = task.assignedTo.isNotEmpty ? task.assignedTo.first : null;
    final assigneeName = firstAssigneeId != null 
        ? (widget.userIdToName[firstAssigneeId] ?? '?')
        : '?';
    final initials = assigneeName.length >= 2 
        ? assigneeName.substring(0, 2).toUpperCase()
        : assigneeName.toUpperCase();

    return InkWell(
      onTap: () => widget.onTaskTap(task),
      hoverColor: ConnecteamStyle.hoverColor,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Checkbox (for bulk selection) or Status checkbox
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: widget.isBulkMode
                  ? Checkbox(
                      value: widget.selectedTaskIds.contains(task.id),
                      onChanged: (value) {
                        widget.onSelectionChanged(task.id, value ?? false);
                      },
                    )
                  : Checkbox(
                      value: task.status == TaskStatus.done,
                      onChanged: (value) {
                        widget.onTaskStatusChange(task);
                      },
                      activeColor: ConnecteamStyle.statusDoneText,
                    ),
            ),
            // Task Title + Avatar
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      initials,
                      style: const TextStyle(fontSize: 10, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.title,
                          style: ConnecteamStyle.cellText.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.isDraft)
                          Text(
                            'Draft',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (task.isRecurring)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.repeat, size: 10, color: ConnecteamStyle.primaryBlue),
                              const SizedBox(width: 2),
                              Text(
                                'Recurring',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: ConnecteamStyle.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Status Pill
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildStatusPill(task.status),
              ),
            ),
            // Due Date
            Expanded(
              flex: 2,
              child: Text(
                _formatDateWithTime(task.dueDate),
                style: ConnecteamStyle.cellText,
              ),
            ),
            // Priority Label
            Expanded(
              flex: 1,
              child: _buildPriorityLabel(task.priority),
            ),
            // Delete button - only show for task creator
            if (widget.onTaskDelete != null) ...[
              Builder(
                builder: (context) {
                  final canDelete = task.isDraft || 
                                   widget.isBulkMode || 
                                   (widget.currentUserId != null && task.createdBy == widget.currentUserId);
                  
                  if (!canDelete) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => widget.onTaskDelete!(task),
                      tooltip: task.isDraft ? 'Delete draft' : 'Delete task',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateWithTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    
    if (taskDate == today) {
      return 'Today ${DateFormat('h:mm a').format(date)}';
    } else if (taskDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, y • h:mm a').format(date);
    }
  }

  Widget _buildStatusPill(TaskStatus status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case TaskStatus.done:
        bg = ConnecteamStyle.statusDoneBg;
        text = ConnecteamStyle.statusDoneText;
        label = "Done";
        break;
      case TaskStatus.inProgress:
        bg = ConnecteamStyle.statusProgressBg;
        text = ConnecteamStyle.statusProgressText;
        label = "Working on it";
        break;
      default:
        bg = ConnecteamStyle.statusTodoBg;
        text = ConnecteamStyle.statusTodoText;
        label = "To Do";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityLabel(TaskPriority priority) {
    String label;
    Color color;

    switch (priority) {
      case TaskPriority.high:
        label = "High";
        color = Colors.red;
        break;
      case TaskPriority.medium:
        label = "Med";
        color = Colors.orange;
        break;
      case TaskPriority.low:
        label = "Low";
        color = Colors.grey;
        break;
    }

    return Text(
      label,
      style: ConnecteamStyle.cellText.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

