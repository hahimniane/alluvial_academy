import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/enums/task_enums.dart';
import '../../../core/models/user.dart';
import '../../../core/models/enhanced_recurrence.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../../../core/utils/connecteam_style.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Dialog for creating multiple tasks at once (ConnectTeam style)
class MultipleTaskCreationDialog extends StatefulWidget {
  final List<String>? preSelectedAssignees;

  const MultipleTaskCreationDialog({
    super.key,
    this.preSelectedAssignees,
  });

  @override
  State<MultipleTaskCreationDialog> createState() => _MultipleTaskCreationDialogState();
}

class _MultipleTaskCreationDialogState extends State<MultipleTaskCreationDialog> {
  final TaskService _taskService = TaskService();
  final List<_TaskRowData> _taskRows = [];
  List<AppUser> _users = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    // Start with one empty task row
    _taskRows.add(_TaskRowData());
    // Pre-select assignees if provided
    if (widget.preSelectedAssignees != null && widget.preSelectedAssignees!.isNotEmpty) {
      _taskRows[0].assignedToIds = List<String>.from(widget.preSelectedAssignees!);
    }
  }

  Future<void> _fetchUsers() async {
    try {
      // Fetch all users and filter in memory to avoid index issues
      final snapshot = await FirebaseFirestore.instance.collection('users').get();

      _users = snapshot.docs
          .map((doc) => AppUser.fromFirestore(doc))
          .where((user) => user.isActive) // Filter for active users
          .toList();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('Error fetching users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addTaskRow() {
    setState(() {
      _taskRows.add(_TaskRowData());
    });
  }

  void _removeTaskRow(int index) {
    setState(() {
      final row = _taskRows[index];
      row.titleController.dispose();
      row.descriptionController.dispose();
      row.locationController.dispose();
      row.labelController.dispose();
      for (var controller in row.subTaskControllers) {
        controller.dispose();
      }
      _taskRows.removeAt(index);
    });
  }

  Future<void> _saveTasks() async {
    if (_taskRows.isEmpty) {
      _showErrorSnackBar('Please add at least one task');
      return;
    }

    // Validate all rows
    for (int i = 0; i < _taskRows.length; i++) {
      final row = _taskRows[i];
      if (row.titleController.text.trim().isEmpty) {
        _showErrorSnackBar('Task ${i + 1}: Please enter a title');
        return;
      }
      if (row.assignedToIds.isEmpty) {
        _showErrorSnackBar('Task ${i + 1}: Please assign to at least one user');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar('Authentication error. Please log in again.');
        return;
      }

      // Create all tasks
      for (final row in _taskRows) {
        // Create sub-tasks first if any
        final List<String> createdSubTaskIds = [];
        if (row.subTaskControllers.isNotEmpty) {
          for (var controller in row.subTaskControllers) {
            if (controller.text.trim().isNotEmpty) {
              final subTask = Task(
                id: FirebaseFirestore.instance.collection('tasks').doc().id,
                title: controller.text.trim(),
                description: AppLocalizations.of(context)!
                    .taskSubtaskOf(row.titleController.text.trim()),
                createdBy: currentUser.uid,
                assignedTo: row.assignedToIds,
                dueDate: row.dueDate ?? DateTime.now().add(const Duration(days: 1)),
                priority: row.priority,
                status: TaskStatus.todo,
                isRecurring: false,
                recurrenceType: RecurrenceType.none,
                enhancedRecurrence: const EnhancedRecurrence(),
                createdAt: Timestamp.now(),
                attachments: const [],
                startDate: row.startDate,
                isDraft: false,
                publishedAt: Timestamp.now(),
                labels: row.labels,
              );
              await _taskService.createTask(subTask);
              createdSubTaskIds.add(subTask.id);
            }
          }
        }

        final task = Task(
          id: FirebaseFirestore.instance.collection('tasks').doc().id,
          title: row.titleController.text.trim(),
          description: row.descriptionController.text.trim(),
          createdBy: currentUser.uid,
          assignedTo: row.assignedToIds,
          dueDate: row.dueDate ?? DateTime.now().add(const Duration(days: 1)),
          priority: row.priority,
          status: TaskStatus.todo,
          isRecurring: false,
          recurrenceType: RecurrenceType.none,
          enhancedRecurrence: const EnhancedRecurrence(),
          createdAt: Timestamp.now(),
          attachments: const [],
          startDate: row.startDate,
          isDraft: false,
          publishedAt: Timestamp.now(),
          location: row.locationController.text.trim().isEmpty 
              ? null 
              : row.locationController.text.trim(),
          startTime: row.startTime != null
              ? '${row.startTime!.hour.toString().padLeft(2, '0')}:${row.startTime!.minute.toString().padLeft(2, '0')}'
              : null,
          endTime: row.endTime != null
              ? '${row.endTime!.hour.toString().padLeft(2, '0')}:${row.endTime!.minute.toString().padLeft(2, '0')}'
              : null,
          labels: row.labels,
          subTaskIds: createdSubTaskIds,
        );

        await _taskService.createTask(task);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_taskRows.length} task${_taskRows.length == 1 ? '' : 's'} created successfully!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xff10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.error('Error creating multiple tasks: $e');
      if (mounted) {
        _showErrorSnackBar('Error creating tasks: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 1000,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 1000,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xff0386FF).withOpacity(0.1),
                            const Color(0xff10B981).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xff0386FF).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff0386FF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: Color(0xff0386FF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Creating ${_taskRows.length} Task${_taskRows.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff111827),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.fillInTheDetailsForEach,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xff6B7280),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Header Row (Spreadsheet style)
                    _buildHeaderRow(),
                    const SizedBox(height: 12),
                    // Task rows
                    ...List.generate(_taskRows.length, (index) {
                      return _buildTaskRow(index);
                    }),
                    // Add task button
                    const SizedBox(height: 20),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _addTaskRow,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        label: Text(
                          AppLocalizations.of(context)!.addAnotherTask,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          side: const BorderSide(color: Color(0xff0386FF), width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: const Color(0xff0386FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff0386FF), Color(0xff0066CC)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_task,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.createMultipleTasks,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.addMultipleTasksInOneGo,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(AppLocalizations.of(context)!.taskName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          SizedBox(width: 12),
          Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.assignee, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          SizedBox(width: 12),
          Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.dueDate, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  InputDecoration _spreadsheetInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xffE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: ConnecteamStyle.primaryBlue),
      ),
    );
  }

  Widget _buildTaskRow(int index) {
    final row = _taskRows[index];
    final isFirst = index == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffE5E7EB),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row header with remove button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xffF9FAFB),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xffE5E7EB),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff0386FF), Color(0xff0369E3)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff0386FF).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.task_alt, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Task ${index + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!isFirst || _taskRows.length > 1)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => _removeTaskRow(index),
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: AppLocalizations.of(context)!.removeTask,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextField(
                  controller: row.titleController,
                  style: GoogleFonts.inter(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.taskTitle,
                    hintText: AppLocalizations.of(context)!.enterADescriptiveTitle,
                    prefixIcon: const Icon(Icons.title, size: 20, color: Color(0xff6B7280)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xffF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
                // Description
                TextField(
                  controller: row.descriptionController,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 15),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.chatGroupDescription,
                    hintText: AppLocalizations.of(context)!.addMoreDetailsAboutThisTask,
                    prefixIcon: const Icon(Icons.description_outlined, size: 20, color: Color(0xff6B7280)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xffF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),
                // Assignees and Priority
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildAssigneeSelector(row),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 160,
                      child: _buildPrioritySelector(row),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Dates
                Row(
                  children: [
                    Expanded(
                      child: _buildDateSelector('Start Date', row.startDate ?? DateTime.now(), (date) {
                        setState(() => row.startDate = date);
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDateSelector('Due Date *', row.dueDate ?? DateTime.now().add(const Duration(days: 1)), (date) {
                        setState(() => row.dueDate = date);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Location and Times
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: row.locationController,
                        style: GoogleFonts.inter(fontSize: 15),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.locationOptional,
                          hintText: AppLocalizations.of(context)!.eGOfficeRemote,
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xff6B7280)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xffD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
                          ),
                          filled: true,
                          fillColor: const Color(0xffF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeSelector('Start Time', row.startTime, (time) {
                        setState(() => row.startTime = time);
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeSelector('End Time', row.endTime, (time) {
                        setState(() => row.endTime = time);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Labels section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.labelsOptional,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...row.labels.map((label) => Chip(
                          label: Text(label, style: GoogleFonts.inter(fontSize: 11)),
                          onDeleted: () {
                            setState(() => row.labels.remove(label));
                          },
                          deleteIcon: const Icon(Icons.close, size: 14),
                          backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xff0386FF),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        )),
                        InputChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 14, color: Color(0xff6B7280)),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: row.labelController,
                                  style: GoogleFonts.inter(fontSize: 11),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)!.addLabel,
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (value) {
                                    if (value.trim().isNotEmpty && !row.labels.contains(value.trim())) {
                                      setState(() {
                                        row.labels.add(value.trim());
                                        row.labelController.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          onPressed: () {
                            if (row.labelController.text.trim().isNotEmpty && !row.labels.contains(row.labelController.text.trim())) {
                              setState(() {
                                row.labels.add(row.labelController.text.trim());
                                row.labelController.clear();
                              });
                            }
                          },
                          backgroundColor: Colors.grey[100],
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Sub-tasks section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.subTasksOptional,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff374151),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              row.subTaskControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add, size: 14),
                          label: Text(AppLocalizations.of(context)!.add, style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (row.subTaskControllers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.noSubTasksClickAddTo,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(row.subTaskControllers.length, (index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.check_box_outline_blank, size: 16, color: Color(0xff6B7280)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: row.subTaskControllers[index],
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)!
                                        .taskSubtaskHint(index + 1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xffD1D5DB)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xffD1D5DB)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xff0386FF), width: 1.5),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xffF9FAFB),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    row.subTaskControllers[index].dispose();
                                    row.subTaskControllers.removeAt(index);
                                  });
                                },
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: AppLocalizations.of(context)!.remove,
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeSelector(_TaskRowData row) {
    final selectedUsers = _users.where((u) => row.assignedToIds.contains(u.id)).toList();
    
    return InkWell(
      onTap: () async {
        final selectedIds = await showDialog<Set<String>>(
          context: context,
          builder: (context) => _MultiSelectUserDialog(
            users: _users,
            selectedIds: Set<String>.from(row.assignedToIds),
          ),
        );
        if (selectedIds != null) {
          setState(() {
            row.assignedToIds = selectedIds.toList();
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xffF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: row.assignedToIds.isEmpty 
                ? const Color(0xffD1D5DB) 
                : const Color(0xff0386FF).withOpacity(0.3),
            width: row.assignedToIds.isEmpty ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: row.assignedToIds.isEmpty
                    ? const Color(0xffE5E7EB)
                    : const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.people_outline,
                size: 20,
                color: row.assignedToIds.isEmpty
                    ? const Color(0xff6B7280)
                    : const Color(0xff0386FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.assignTo,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (row.assignedToIds.isEmpty)
                    Text(
                      AppLocalizations.of(context)!.tapToSelectUsers,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else if (selectedUsers.length == 1)
                    Text(
                      selectedUsers.first.name ??
                          selectedUsers.first.email ??
                          AppLocalizations.of(context)!.commonUnknown,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Row(
                      children: [
                        ...selectedUsers.take(2).map((user) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xff0386FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.name?.split(' ').first ?? user.email?.split('@').first ?? 'User',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff0386FF),
                              ),
                            ),
                          );
                        }),
                        if (selectedUsers.length > 2)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xff6B7280).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${selectedUsers.length - 2}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff6B7280),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySelector(_TaskRowData row) {
    Color getPriorityColor(TaskPriority priority) {
      switch (priority) {
        case TaskPriority.low:
          return const Color(0xff10B981);
        case TaskPriority.medium:
          return const Color(0xffF59E0B);
        case TaskPriority.high:
          return const Color(0xffEF4444);
      }
    }

    IconData getPriorityIcon(TaskPriority priority) {
      switch (priority) {
        case TaskPriority.low:
          return Icons.keyboard_arrow_down;
        case TaskPriority.medium:
          return Icons.remove;
        case TaskPriority.high:
          return Icons.keyboard_arrow_up;
      }
    }

    return DropdownButtonFormField<TaskPriority>(
      value: row.priority,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.priority,
        prefixIcon: Icon(
          getPriorityIcon(row.priority),
          color: getPriorityColor(row.priority),
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xffF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: TaskPriority.values.map((priority) {
        return DropdownMenuItem(
          value: priority,
          child: Row(
            children: [
              Icon(
                getPriorityIcon(priority),
                color: getPriorityColor(priority),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                priority.name[0].toUpperCase() + priority.name.substring(1),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => row.priority = value);
        }
      },
    );
  }

  Widget _buildDateSelector(String label, DateTime initialDate, Function(DateTime) onDateSelected) {
    final isRequired = label.contains('*');
    
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime(2101),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xff0386FF),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (pickedDate != null) {
          onDateSelected(pickedDate);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xffF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xffD1D5DB),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_today,
                size: 18,
                color: Color(0xff0386FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label.replaceAll(' *', ''),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                      if (isRequired)
                        Text(
                          AppLocalizations.of(context)!.text,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(initialDate),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay? currentTime, Function(TimeOfDay?) onTimeSelected) {
    return InkWell(
      onTap: () async {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: currentTime ?? TimeOfDay.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xff0386FF),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (pickedTime != null) {
          onTimeSelected(pickedTime);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xffF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: currentTime != null
                ? const Color(0xff0386FF).withOpacity(0.3)
                : const Color(0xffD1D5DB),
            width: currentTime != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: currentTime != null
                    ? const Color(0xff0386FF).withOpacity(0.1)
                    : const Color(0xffE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.access_time,
                size: 18,
                color: currentTime != null
                    ? const Color(0xff0386FF)
                    : const Color(0xff6B7280),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentTime != null ? currentTime.format(context) : 'Tap to set',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: currentTime != null ? FontWeight.w600 : FontWeight.normal,
                      color: currentTime != null
                          ? const Color(0xff111827)
                          : Colors.grey[400],
                      fontStyle: currentTime == null ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        border: Border(
          top: BorderSide(
            color: const Color(0xffE5E7EB),
            width: 1,
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xffD1D5DB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.commonCancel,
                style: GoogleFonts.inter(
                  color: const Color(0xff6B7280),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveTasks,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ).copyWith(
                elevation: MaterialStateProperty.all(0),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff0386FF).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Create ${_taskRows.length} Task${_taskRows.length == 1 ? '' : 's'}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final row in _taskRows) {
      row.titleController.dispose();
      row.descriptionController.dispose();
      row.locationController.dispose();
      row.labelController.dispose();
      for (var controller in row.subTaskControllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }
}

class _TaskRowData {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController labelController = TextEditingController();
  final List<TextEditingController> subTaskControllers = [];
  List<String> assignedToIds = [];
  List<String> labels = [];
  TaskPriority priority = TaskPriority.medium;
  DateTime? startDate;
  DateTime? dueDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
}

class _MultiSelectUserDialog extends StatefulWidget {
  final List<AppUser> users;
  final Set<String> selectedIds;

  const _MultiSelectUserDialog({
    required this.users,
    required this.selectedIds,
  });

  @override
  State<_MultiSelectUserDialog> createState() => _MultiSelectUserDialogState();
}

class _MultiSelectUserDialogState extends State<_MultiSelectUserDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff0386FF), Color(0xff0369E3)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.selectUsers2,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedIds.length} selected',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _selectedIds.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.noUsersSelected,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.tapOnUsersBelowToSelect,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: widget.users.length,
                      itemBuilder: (context, index) {
                        final user = widget.users[index];
                        final isSelected = _selectedIds.contains(user.id);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(user.id);
                              } else {
                                _selectedIds.add(user.id);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xff0386FF).withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xff0386FF).withOpacity(0.3)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xff0386FF)
                                        : const Color(0xffE5E7EB),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      (user.name ?? user.email ?? 'U')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: GoogleFonts.inter(
                                        color: isSelected ? Colors.white : const Color(0xff6B7280),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name ?? AppLocalizations.of(context)!.commonUnknownUser,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xff111827),
                                        ),
                                      ),
                                      if (user.email != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          user.email!,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: const Color(0xff6B7280),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xff0386FF)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xff0386FF)
                                          : const Color(0xffD1D5DB),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xffF9FAFB),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xffE5E7EB),
                    width: 1,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xffD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.commonCancel,
                        style: GoogleFonts.inter(
                          color: const Color(0xff6B7280),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_selectedIds),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0386FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Done (${_selectedIds.length})',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
