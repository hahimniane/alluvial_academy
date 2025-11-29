import 'package:flutter/material.dart';
import '../../../core/enums/task_enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/user.dart';
import '../../../core/models/enhanced_recurrence.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../shared/widgets/enhanced_recurrence_picker.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/file_attachment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class AddEditTaskDialog extends StatefulWidget {
  final Task? task;
  final String? preSelectedAssignee;

  const AddEditTaskDialog({super.key, this.task, this.preSelectedAssignee});

  @override
  _AddEditTaskDialogState createState() => _AddEditTaskDialogState();
}

class _AddEditTaskDialogState extends State<AddEditTaskDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _taskService = TaskService();
  final _fileService = FileAttachmentService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late TabController _tabController;

  late DateTime _dueDate;
  DateTime? _startDate; // Start date for ConnectTeam-style display
  TaskPriority _priority = TaskPriority.medium;
  List<String> _assignedTo = [];
  bool _isRecurring = false;
  RecurrenceType _recurrenceType = RecurrenceType.none;
  EnhancedRecurrence _enhancedRecurrence = const EnhancedRecurrence();
  List<AppUser> _users = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingFiles = false;
  List<TaskAttachment> _attachments = [];
  // Draft/Publish and additional fields
  bool _saveAsDraft = false;
  final _locationController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  // Labels and Sub-tasks (ConnectTeam style)
  List<String> _labels = [];
  final _labelController = TextEditingController();
  List<String> _subTaskIds = [];
  final List<TextEditingController> _subTaskControllers = [];
  bool _showMoreDetails = false; // Track if "Add more details" is expanded

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupAnimations();
    _initializeData();
    _fetchUsers();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  void _initializeData() {
    _dueDate =
        widget.task?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    _startDate = widget.task?.startDate ?? DateTime.now(); // Default to today
    _titleController.text = widget.task?.title ?? '';
    _descriptionController.text = widget.task?.description ?? '';
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _assignedTo = List<String>.from(widget.task?.assignedTo ?? []);
    _isRecurring = widget.task?.isRecurring ?? false;
    _recurrenceType = widget.task?.recurrenceType ?? RecurrenceType.none;
    _enhancedRecurrence =
        widget.task?.enhancedRecurrence ?? const EnhancedRecurrence();
    _attachments = List<TaskAttachment>.from(widget.task?.attachments ?? []);
    // Initialize new fields
    _saveAsDraft = widget.task?.isDraft ?? false;
    _locationController.text = widget.task?.location ?? '';
    // Parse time strings if they exist
    if (widget.task?.startTime != null) {
      final parts = widget.task!.startTime!.split(':');
      if (parts.length == 2) {
        _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    if (widget.task?.endTime != null) {
      final parts = widget.task!.endTime!.split(':');
      if (parts.length == 2) {
        _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final users =
          snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      AppLogger.error('Error fetching users: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildModernDialog(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernDialog() {
    return Container(
      width: 480,
      constraints: const BoxConstraints(
        maxWidth: 480,
        maxHeight: 600,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Task title (required)
                  _buildCompactTextField(
                    controller: _titleController,
                    label: 'Task title',
                    hint: 'Type here',
                    isRequired: true,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 20),
                  // Assign to (required)
                  _buildAssignToSection(),
                  const SizedBox(height: 16),
                  // Add more details (expandable)
                  _buildMoreDetailsSection(),
                ],
              ),
            ),
          ),
          _buildCompactActions(),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffE5E7EB))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _closeDialog(),
            icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xff374151)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.task == null ? 'New task' : 'Edit task',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xff111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff374151),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '•',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xffEF4444),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xff9CA3AF),
            ),
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
              borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffEF4444), width: 1),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignToSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Assign to',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff374151),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '•',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xffEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_assignedTo.isEmpty)
          OutlinedButton.icon(
            onPressed: () => _openUserSelectionDialog(),
            icon: const Icon(Icons.add, size: 18, color: Color(0xff0386FF)),
            label: const Text('Add users'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xff0386FF),
              side: const BorderSide(color: Color(0xff0386FF)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._assignedTo.map((userId) {
                final userName = _getUserName(userId);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xffE0F2FE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xff0386FF).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff0386FF),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _assignedTo.remove(userId);
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xff0386FF),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: () => _openUserSelectionDialog(),
                icon: const Icon(Icons.add, size: 16, color: Color(0xff0386FF)),
                label: const Text('Add users'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff0386FF),
                  side: const BorderSide(color: Color(0xff0386FF)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMoreDetailsSection() {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _showMoreDetails = !_showMoreDetails;
            });
          },
          child: Row(
            children: [
              Icon(
                _showMoreDetails ? Icons.remove : Icons.add,
                size: 18,
                color: const Color(0xff0386FF),
              ),
              const SizedBox(width: 6),
              Text(
                'Add more details',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff0386FF),
                ),
              ),
            ],
          ),
        ),
        if (_showMoreDetails) ...[
          const SizedBox(height: 20),
          _buildCompactTextField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Type here',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStartDateSelector()),
              const SizedBox(width: 12),
              Expanded(child: _buildDateSelector()),
            ],
          ),
          const SizedBox(height: 20),
          _buildPrioritySelector(),
          const SizedBox(height: 20),
          _buildCompactTextField(
            controller: _locationController,
            label: 'Location',
            hint: 'Type here',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildTimeSelector('Start Time', _startTime, (time) => setState(() => _startTime = time))),
              const SizedBox(width: 12),
              Expanded(child: _buildTimeSelector('End Time', _endTime, (time) => setState(() => _endTime = time))),
            ],
          ),
          const SizedBox(height: 20),
          // Labels
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tags',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff374151),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._labels.map((label) => Chip(
                    label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
                    onDeleted: () {
                      setState(() => _labels.remove(label));
                    },
                    deleteIcon: const Icon(Icons.close, size: 14),
                    backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
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
                            controller: _labelController,
                            style: GoogleFonts.inter(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Add tag',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty && !_labels.contains(value.trim())) {
                                setState(() {
                                  _labels.add(value.trim());
                                  _labelController.clear();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {
                      if (_labelController.text.trim().isNotEmpty && !_labels.contains(_labelController.text.trim())) {
                        setState(() {
                          _labels.add(_labelController.text.trim());
                          _labelController.clear();
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
        ],
      ],
    );
  }

  Widget _buildCompactActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : () {
                setState(() => _saveAsDraft = false);
                _saveTask();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.task == null ? 'Publish task' : 'Update task',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _isSaving ? null : () {
              setState(() => _saveAsDraft = true);
              _saveTask();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xff374151),
              side: const BorderSide(color: Color(0xffD1D5DB)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save draft',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUserName(String userId) {
    try {
      final user = _users.firstWhere(
        (u) => u.id == userId,
      );
      final name = user.name;
      if (name != null && name.isNotEmpty) {
        return name;
      }
      return user.email ?? userId;
    } catch (e) {
      return userId;
    }
  }

  Future<void> _openUserSelectionDialog() async {
    // Show user selection dialog
    await showDialog(
      context: context,
      builder: (context) => UserSelectionDialog(
        users: _users,
        selectedUserIds: _assignedTo,
        onSelectionChanged: (selectedIds) {
          if (mounted) {
            setState(() {
              _assignedTo = selectedIds;
            });
          }
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff0386FF), Color(0xff0369E3)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
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
                  widget.task == null ? 'Create New Task' : 'Edit Task',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.task == null
                      ? 'Add a new task to your workflow'
                      : 'Update task details',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _closeDialog(),
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDetailsTab() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Title (required)
            _buildModernTextField(
              controller: _titleController,
              label: 'Task title',
              hint: 'Type here',
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter a title' : null,
              isRequired: true,
            ),
            const SizedBox(height: 24),
            // Description
            _buildModernTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Type here',
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            // Assign to
            _buildMultiUserSelector(),
            const SizedBox(height: 24),
            // Start date and Due date side by side
            Row(
              children: [
                Expanded(child: _buildStartDateSelector()),
                const SizedBox(width: 16),
                Expanded(child: _buildDateSelector()),
              ],
            ),
            const SizedBox(height: 24),
            // Priority
            _buildPrioritySelector(),
            const SizedBox(height: 24),
            // Location
            _buildModernTextField(
              controller: _locationController,
              label: 'Location (Optional)',
              hint: 'Enter task location',
            ),
            const SizedBox(height: 24),
            // Start Time and End Time
            Row(
              children: [
                Expanded(child: _buildTimeSelector('Start Time', _startTime, (time) => setState(() => _startTime = time))),
                const SizedBox(width: 16),
                Expanded(child: _buildTimeSelector('End Time', _endTime, (time) => setState(() => _endTime = time))),
              ],
            ),
            const SizedBox(height: 24),
            // Labels
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tags',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff374151),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._labels.map((label) => Chip(
                      label: Text(label),
                      onDeleted: () {
                        setState(() => _labels.remove(label));
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff0386FF),
                      ),
                    )),
                    InputChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 16, color: Color(0xff6B7280)),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _labelController,
                              style: GoogleFonts.inter(fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'Add tag',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty && !_labels.contains(value.trim())) {
                                  setState(() {
                                    _labels.add(value.trim());
                                    _labelController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {
                        if (_labelController.text.trim().isNotEmpty && !_labels.contains(_labelController.text.trim())) {
                          setState(() {
                            _labels.add(_labelController.text.trim());
                            _labelController.clear();
                          });
                        }
                      },
                      backgroundColor: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Recurrence (if needed)
            _buildRecurrenceSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTasksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sub tasks',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff374151),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _subTaskControllers.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add sub task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffE0F2FE),
                  foregroundColor: const Color(0xff0386FF),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_subTaskControllers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.task_alt, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No sub-tasks yet',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click "Add sub task" to create one',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_subTaskControllers.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffE5E7EB)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subTaskControllers[index],
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Sub-task ${index + 1}',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _subTaskControllers[index].dispose();
                          _subTaskControllers.removeAt(index);
                        });
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Remove sub-task',
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Task Details',
              icon: Icons.description_outlined,
              children: [
                _buildModernTextField(
                  controller: _titleController,
                  label: 'Task Title',
                  hint: 'Enter a descriptive title for your task',
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 20),
                _buildModernTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Provide additional details about the task',
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Assignment & Priority',
              icon: Icons.assignment_ind_outlined,
              children: [
                _buildMultiUserSelector(),
                const SizedBox(height: 20),
                _buildPrioritySelector(),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Timeline',
              icon: Icons.schedule_outlined,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStartDateSelector()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDateSelector()),
                  ],
                ),
                const SizedBox(height: 20),
                _buildRecurrenceSection(),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Additional Details (Optional)',
              icon: Icons.add_circle_outline,
              children: [
                _buildModernTextField(
                  controller: _locationController,
                  label: 'Location',
                  hint: 'Enter task location (e.g., Office, Remote, etc.)',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildTimeSelector('Start Time', _startTime, (time) => setState(() => _startTime = time))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTimeSelector('End Time', _endTime, (time) => setState(() => _endTime = time))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Labels & Sub-tasks (Optional)',
              icon: Icons.label_outline,
              children: [
                // Labels section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Labels',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._labels.map((label) => Chip(
                          label: Text(label),
                          onDeleted: () {
                            setState(() => _labels.remove(label));
                          },
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xff0386FF),
                          ),
                        )),
                        InputChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 16, color: Color(0xff6B7280)),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _labelController,
                                  style: GoogleFonts.inter(fontSize: 12),
                                  decoration: const InputDecoration(
                                    hintText: 'Add label',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (value) {
                                    if (value.trim().isNotEmpty && !_labels.contains(value.trim())) {
                                      setState(() {
                                        _labels.add(value.trim());
                                        _labelController.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          onPressed: () {
                            if (_labelController.text.trim().isNotEmpty && !_labels.contains(_labelController.text.trim())) {
                              setState(() {
                                _labels.add(_labelController.text.trim());
                                _labelController.clear();
                              });
                            }
                          },
                          backgroundColor: Colors.grey[100],
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Sub-tasks section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Sub-tasks',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff374151),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _subTaskControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Sub-task'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_subTaskControllers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'No sub-tasks. Click "Add Sub-task" to create one.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_subTaskControllers.length, (index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _subTaskControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'Sub-task ${index + 1}',
                                    prefixIcon: const Icon(Icons.check_box_outline_blank, size: 18),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _subTaskControllers[index].dispose();
                                    _subTaskControllers.removeAt(index);
                                  });
                                },
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Remove sub-task',
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'File Attachments (Optional)',
              icon: Icons.attach_file_outlined,
              children: [
                _buildFileAttachmentSection(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xff0386FF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        hintText: hint,
        labelStyle: TextStyle(
          color: isRequired ? Colors.red : Colors.grey[700],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.all(16),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildMultiUserSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Assign To',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A202C),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showUserSelectionDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Assignees'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff0386FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _assignedTo.isEmpty ? Colors.red : Colors.grey[300]!,
              width: _assignedTo.isEmpty ? 2 : 1,
            ),
          ),
          child: _assignedTo.isEmpty
              ? Row(
                  children: [
                    Icon(Icons.person_add_outlined, color: Colors.grey[400]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No assignees selected. Tap "Add Assignees" to select team members.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _assignedTo.map((userId) {
                    final user = _users.firstWhere(
                      (u) => u.id == userId,
                      orElse: () => AppUser(id: userId, name: 'Unknown User'),
                    );
                    return _buildUserChip(user);
                  }).toList(),
                ),
        ),
        if (_assignedTo.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please assign the task to at least one user',
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserChip(AppUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff0386FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff0386FF).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xff0386FF),
            child: Text(
              (user.name ?? 'U').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            user.name ?? 'Unknown User',
            style: const TextStyle(
              color: Color(0xff0386FF),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _removeAssignee(user.id),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xff0386FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => UserSelectionDialog(
        users: _users,
        selectedUserIds: _assignedTo,
        onSelectionChanged: (selectedIds) {
          setState(() {
            _assignedTo = selectedIds;
          });
        },
      ),
    );
  }

  void _removeAssignee(String userId) {
    setState(() {
      _assignedTo.remove(userId);
    });
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: TaskPriority.values.map((priority) {
            final isSelected = _priority == priority;
            final color = _getPriorityColor(priority);

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _priority = priority),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? color.withOpacity(0.15) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _getPriorityIcon(priority),
                        color: isSelected ? color : Colors.grey[600],
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getPriorityLabel(priority),
                        style: TextStyle(
                          color: isSelected ? color : Colors.grey[600],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStartDateSelector() {
    return InkWell(
      onTap: _selectStartDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow_outlined, color: Color(0xff10B981)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _startDate != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_startDate!)
                        : 'Not set',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _startDate != null ? const Color(0xFF1A202C) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: Color(0xff0386FF)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Due Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_dueDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: CheckboxListTile(
            title: const Text(
              'Recurring Task',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('This task repeats on a schedule'),
            value: _isRecurring,
            onChanged: (value) => setState(() => _isRecurring = value!),
            controlAffinity: ListTileControlAffinity.trailing,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 16),
          EnhancedRecurrencePicker(
            initialRecurrence: _enhancedRecurrence,
            onRecurrenceChanged: (newRecurrence) {
              setState(() {
                _enhancedRecurrence = newRecurrence;
                // Update old recurrence type for backward compatibility
                if (newRecurrence.type == EnhancedRecurrenceType.none) {
                  _recurrenceType = RecurrenceType.none;
                } else if (newRecurrence.type == EnhancedRecurrenceType.daily) {
                  _recurrenceType = RecurrenceType.daily;
                } else if (newRecurrence.type ==
                    EnhancedRecurrenceType.weekly) {
                  _recurrenceType = RecurrenceType.weekly;
                } else if (newRecurrence.type ==
                    EnhancedRecurrenceType.monthly) {
                  _recurrenceType = RecurrenceType.monthly;
                }
              });
            },
            showEndDate: true,
          ),
        ],
      ],
    );
  }

  Widget _buildFileAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Upload Files',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A202C),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isUploadingFiles ? null : _pickAndUploadFiles,
              icon: _isUploadingFiles
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.attach_file, size: 18),
              label: Text(
                _isUploadingFiles ? 'Uploading...' : 'Add Files',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No files attached',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload reference materials, documents, or resources',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: _attachments.map((attachment) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildAttachmentItem(attachment),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentItem(TaskAttachment attachment) {
    final fileIcon = _fileService.getFileIcon(attachment.fileType);
    final fileSize = _fileService.formatFileSize(attachment.fileSize);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                fileIcon,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.originalName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  fileSize,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeAttachment(attachment),
            icon: const Icon(Icons.delete_outline),
            iconSize: 18,
            color: Colors.red[400],
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFiles() async {
    try {
      setState(() => _isUploadingFiles = true);

      final files = await _fileService.pickFiles();
      if (files == null || files.isEmpty) {
        setState(() => _isUploadingFiles = false);
        return;
      }

      // For task creation, we'll generate a temporary task ID
      final tempTaskId =
          FirebaseFirestore.instance.collection('tasks').doc().id;

      for (final file in files) {
        try {
          final attachment = await _fileService.uploadFile(file, tempTaskId);
          setState(() {
            _attachments.add(attachment);
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload ${file.name}: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '${files.length} file(s) uploaded successfully!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingFiles = false);
      }
    }
  }

  void _removeAttachment(TaskAttachment attachment) {
    setState(() {
      _attachments.remove(attachment);
    });

    // Also delete the file from storage
    _fileService.deleteFile(attachment, attachment.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${attachment.originalName} removed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isSaving ? null : _closeDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Save as Draft button
          OutlinedButton(
            onPressed: _isSaving ? null : () {
              setState(() => _saveAsDraft = true);
              _saveTask();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              side: const BorderSide(color: Color(0xff6B7280)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.save_outlined, size: 18, color: Color(0xff6B7280)),
                const SizedBox(width: 6),
                Text(
                  'Save as Draft',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Publish button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () {
                setState(() => _saveAsDraft = false);
                _saveTask();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.publish, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.task == null ? 'Publish Task' : 'Update Task',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
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

  // Helper methods
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

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Icons.keyboard_arrow_down;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.high:
        return Icons.keyboard_arrow_up;
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

  Future<void> _selectStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff10B981),
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
      setState(() => _startDate = pickedDate);
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: _startDate ?? DateTime.now(),
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
      setState(() => _dueDate = pickedDate);
    }
  }

  Widget _buildTimeSelector(String label, TimeOfDay? currentTime, Function(TimeOfDay?) onTimeSelected) {
    return InkWell(
      onTap: () async {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: currentTime ?? TimeOfDay.now(),
        );
        if (pickedTime != null) {
          onTimeSelected(pickedTime);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentTime != null 
                        ? currentTime.format(context)
                        : 'Not set',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: currentTime != null ? const Color(0xFF1A202C) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _closeDialog() {
    _animationController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate() || _assignedTo.isEmpty) {
      if (_assignedTo.isEmpty) {
        _showErrorSnackBar('Please assign the task to at least one user.');
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar('Authentication error. Please log in again.');
        return;
      }

      // Format times as HH:mm strings
      final startTimeStr = _startTime != null 
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
          : null;
      final endTimeStr = _endTime != null
          ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
          : null;

      // Create sub-tasks first if any (only for new tasks)
      final List<String> createdSubTaskIds = [];
      if (_subTaskControllers.isNotEmpty && widget.task == null) {
        for (var controller in _subTaskControllers) {
          if (controller.text.trim().isNotEmpty) {
            final subTask = Task(
              id: FirebaseFirestore.instance.collection('tasks').doc().id,
              title: controller.text.trim(),
              description: 'Sub-task of: ${_titleController.text.trim()}',
              createdBy: currentUser.uid,
              assignedTo: _assignedTo, // Inherit assignees from parent
              dueDate: _dueDate, // Inherit due date from parent
              priority: _priority,
              status: TaskStatus.todo,
              isRecurring: false,
              recurrenceType: RecurrenceType.none,
              enhancedRecurrence: const EnhancedRecurrence(),
              createdAt: Timestamp.now(),
              attachments: const [],
              startDate: _startDate,
              isDraft: _saveAsDraft,
              publishedAt: _saveAsDraft ? null : Timestamp.now(),
              labels: _labels, // Inherit labels from parent
            );
            await _taskService.createTask(subTask);
            createdSubTaskIds.add(subTask.id);
          }
        }
      }

      final task = Task(
        id: widget.task?.id ??
            FirebaseFirestore.instance.collection('tasks').doc().id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        createdBy: currentUser.uid,
        assignedTo: _assignedTo,
        dueDate: _dueDate,
        priority: _priority,
        status: widget.task?.status ?? TaskStatus.todo,
        isRecurring: _isRecurring,
        recurrenceType: _isRecurring ? _recurrenceType : RecurrenceType.none,
        enhancedRecurrence:
            _isRecurring ? _enhancedRecurrence : const EnhancedRecurrence(),
        createdAt: widget.task?.createdAt ?? Timestamp.now(),
        attachments: _attachments,
        startDate: _startDate,
        isDraft: _saveAsDraft,
        publishedAt: _saveAsDraft ? null : (widget.task?.publishedAt ?? Timestamp.now()),
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        startTime: startTimeStr,
        endTime: endTimeStr,
        labels: _labels,
        subTaskIds: widget.task != null ? widget.task!.subTaskIds : createdSubTaskIds,
      );

      if (widget.task == null) {
        await _taskService.createTask(task);
      } else {
        await _taskService.updateTask(task.id, task);
      }

      _showSuccessSnackBar(widget.task == null
          ? 'Task created successfully!'
          : 'Task updated successfully!');

      _closeDialog();
    } catch (e) {
      _showErrorSnackBar('Failed to save task. Please try again.');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// New User Selection Dialog
class UserSelectionDialog extends StatefulWidget {
  final List<AppUser> users;
  final List<String> selectedUserIds;
  final Function(List<String>) onSelectionChanged;

  const UserSelectionDialog({
    super.key,
    required this.users,
    required this.selectedUserIds,
    required this.onSelectionChanged,
  });

  @override
  _UserSelectionDialogState createState() => _UserSelectionDialogState();
}

class _UserSelectionDialogState extends State<UserSelectionDialog> {
  late List<String> _selectedIds;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = List<String>.from(widget.selectedUserIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> get _filteredUsers {
    if (_searchQuery.isEmpty) return widget.users;
    return widget.users.where((user) {
      final name = user.name?.toLowerCase() ?? '';
      final role = user.role?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || role.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildUserList()),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xff0386FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.people_outline,
            color: Color(0xff0386FF),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Select Team Members',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A202C),
            ),
          ),
        ),
        Text(
          '${_selectedIds.length} selected',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search by name or role...',
        prefixIcon: const Icon(Icons.search, color: Color(0xff0386FF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildUserList() {
    final filteredUsers = _filteredUsers;

    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        final isSelected = _selectedIds.contains(user.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected
                ? const Color(0xff0386FF).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _toggleUser(user.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xff0386FF)
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isSelected
                          ? const Color(0xff0386FF)
                          : Colors.grey[300],
                      child: Text(
                        (user.name ?? 'U').substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name ?? 'Unknown User',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xff0386FF)
                                  : Colors.black87,
                            ),
                          ),
                          if (user.role != null)
                            Text(
                              user.role!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xff0386FF),
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              widget.onSelectionChanged(_selectedIds);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Confirm Selection (${_selectedIds.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleUser(String userId) {
    setState(() {
      if (_selectedIds.contains(userId)) {
        _selectedIds.remove(userId);
      } else {
        _selectedIds.add(userId);
      }
    });
  }
}
