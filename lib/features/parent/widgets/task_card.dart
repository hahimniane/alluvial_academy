import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/tasks/models/task.dart';
import 'package:alluwalacademyadmin/core/enums/task_enums.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final String? assignedByName;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.assignedByName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = task.dueDate.isBefore(now) && task.status != TaskStatus.done;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final dueDateStr = dateFormat.format(task.dueDate);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFE5E7EB),
            ),
          ),
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
                          task.title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPriorityBadge(task.priority),
                  const SizedBox(width: 8),
                  _buildStatusBadge(task.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dueDateStr,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
                    ),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.overdue2,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                  if (task.attachments.isNotEmpty) ...[
                    const Spacer(),
                    Icon(Icons.attach_file, size: 14, color: const Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(
                      '${task.attachments.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
              if (assignedByName != null && assignedByName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: const Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.assignedByAssignedbyname,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (priority) {
      case TaskPriority.high:
        backgroundColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        label = 'High';
        break;
      case TaskPriority.medium:
        backgroundColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        label = 'Med';
        break;
      case TaskPriority.low:
        backgroundColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF2563EB);
        label = 'Low';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TaskStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case TaskStatus.done:
        backgroundColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        label = 'Done';
        break;
      case TaskStatus.inProgress:
        backgroundColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
        label = 'In Progress';
        break;
      case TaskStatus.todo:
        backgroundColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
        label = 'To Do';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

