import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/features/tasks/models/task.dart';
import 'package:alluwalacademyadmin/core/enums/task_enums.dart';
import 'package:alluwalacademyadmin/features/tasks/services/task_service.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/task_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class StudentTasksTab extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentTasksTab({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentTasksTab> createState() => _StudentTasksTabState();
}

class _StudentTasksTabState extends State<StudentTasksTab> {
  final TaskService _taskService = TaskService();
  String _filterStatus = 'all'; // 'all', 'pending', 'completed', 'overdue'
  final Map<String, String> _userNameCache = {};

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Stats Header
            StreamBuilder<List<Task>>(
              stream: _taskService.getStudentTasks(widget.studentId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final tasks = snapshot.data!;
                final now = DateTime.now();
                final completed = tasks.where((t) => t.status == TaskStatus.done).length;
                final pending = tasks.where((t) =>
                  t.status != TaskStatus.done &&
                  (t.dueDate.isAfter(now) || t.dueDate.isAtSameMomentAs(now))).length;
                final overdue = tasks.where((t) =>
                  t.status != TaskStatus.done && t.dueDate.isBefore(now)).length;

                return _buildTaskStatsHeader(
                  total: tasks.length,
                  completed: completed,
                  pending: pending,
                  overdue: overdue,
                );
              },
            ),
            const SizedBox(height: 20),

            // Filter Bar
            _buildFilterBar(),
            const SizedBox(height: 20),

            // Task List
            StreamBuilder<List<Task>>(
              stream: _taskService.getStudentTasks(widget.studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ));
                }

                if (snapshot.hasError) {
                  return _errorCard('Failed to load tasks: ${snapshot.error}');
                }

                final allTasks = snapshot.data ?? [];
                final filteredTasks = _filterTasks(allTasks);

                if (filteredTasks.isEmpty) {
                  return _emptyCard(
                    icon: Icons.assignment_rounded,
                    title: AppLocalizations.of(context)!.noTasksFound,
                    subtitle: _filterStatus == 'all'
                        ? 'Your child has no tasks assigned.'
                        : 'No tasks match the selected filter.',
                  );
                }

                return Column(
                  children: filteredTasks.map((task) {
                    return FutureBuilder<String?>(
                      future: _getUserName(task.createdBy),
                      builder: (context, nameSnapshot) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TaskCard(
                            task: task,
                            assignedByName: nameSnapshot.data,
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskStatsHeader({
    required int total,
    required int completed,
    required int pending,
    required int overdue,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem('Total', total, const Color(0xFF111827)),
          _buildStatItem('Completed', completed, const Color(0xFF16A34A)),
          _buildStatItem('Pending', pending, const Color(0xFFF59E0B)),
          _buildStatItem('Overdue', overdue, const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: _buildFilterButton('All', 'all')),
          Expanded(child: _buildFilterButton('Pending', 'pending')),
          Expanded(child: _buildFilterButton('Completed', 'completed')),
          Expanded(child: _buildFilterButton('Overdue', 'overdue')),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _filterStatus == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _filterStatus = value;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF111827)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Task> _filterTasks(List<Task> tasks) {
    final now = DateTime.now();
    
    switch (_filterStatus) {
      case 'pending':
        return tasks.where((t) =>
          t.status != TaskStatus.done &&
          (t.dueDate.isAfter(now) || t.dueDate.isAtSameMomentAs(now))).toList();
      case 'completed':
        return tasks.where((t) => t.status == TaskStatus.done).toList();
      case 'overdue':
        return tasks.where((t) =>
          t.status != TaskStatus.done && t.dueDate.isBefore(now)).toList();
      default:
        return tasks;
    }
  }

  Future<String?> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId];
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final firstName = data?['first_name'] ?? '';
        final lastName = data?['last_name'] ?? '';
        final name = '$firstName $lastName'.trim();
        if (name.isNotEmpty) {
          _userNameCache[userId] = name;
          return name;
        }
      }
    } catch (e) {
      // Ignore errors, return null
    }

    return null;
  }

  Widget _emptyCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Icon(icon, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7F1D1D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

