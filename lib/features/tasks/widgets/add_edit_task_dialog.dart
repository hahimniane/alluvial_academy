import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user.dart';
import '../../../core/models/enhanced_recurrence.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/enums/task_enums.dart';
import '../../../shared/widgets/enhanced_recurrence_picker.dart';
import '../../../core/utils/connecteam_style.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/file_attachment_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class AddEditTaskDialog extends StatefulWidget {
  final Task? task;
  final String? preSelectedAssignee;

  const AddEditTaskDialog({super.key, this.task, this.preSelectedAssignee});

  @override
  _AddEditTaskDialogState createState() => _AddEditTaskDialogState();
}

class _AddEditTaskDialogState extends State<AddEditTaskDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  // Services (non utilisés dans l'UI directe mais gardés pour la logique)
  final _taskService = TaskService();
  final _fileService = FileAttachmentService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _labelController = TextEditingController();

  late DateTime _dueDate;
  late DateTime _startDate;
  TaskPriority _priority = TaskPriority.medium;
  List<String> _assignedTo = [];
  bool _isSaving = false;
  bool _saveAsDraft = false;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<String> _labels = [];
  
  // Recurrence
  EnhancedRecurrence _enhancedRecurrence = const EnhancedRecurrence();
  RecurrenceType _recurrenceType = RecurrenceType.none;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // UI State
  bool _showAdvanced = false;

  // Mock data placeholders (Remplacez par vos vraies données)
  List<AppUser> _users = [];
  bool _isLoading = true;
  bool _isCreator = false; // Whether current user is the task creator

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeData();
    _fetchUsers();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack);
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
  }

  void _initializeData() {
    // Check if current user is the creator
    final currentUser = FirebaseAuth.instance.currentUser;
    _isCreator = widget.task == null || 
                 currentUser == null || 
                 widget.task!.createdBy == currentUser.uid;
    
    // Initialisation basée sur votre code original
    _dueDate = widget.task?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    _startDate = widget.task?.startDate ?? DateTime.now();
    _titleController.text = widget.task?.title ?? '';
    _descriptionController.text = widget.task?.description ?? '';
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _assignedTo = List<String>.from(widget.task?.assignedTo ?? []);
    if (widget.preSelectedAssignee != null && _assignedTo.isEmpty) {
      _assignedTo.add(widget.preSelectedAssignee!);
    }
    _labels = List<String>.from(widget.task?.labels ?? []);
    _locationController.text = widget.task?.location ?? '';
    // Initialize _saveAsDraft from existing task (important for editing drafts)
    _saveAsDraft = widget.task?.isDraft ?? false;
    
    // Initialize recurrence
    if (widget.task != null) {
      _enhancedRecurrence = widget.task!.enhancedRecurrence;
      _recurrenceType = widget.task!.recurrenceType;
      
      // Fix case where enhancedRecurrence has data but type is "none"
      // (This can happen with old data or incorrectly saved data)
      if (_enhancedRecurrence.type == EnhancedRecurrenceType.none) {
        if (_enhancedRecurrence.selectedMonthDays.isNotEmpty) {
          _enhancedRecurrence = _enhancedRecurrence.copyWith(
            type: EnhancedRecurrenceType.monthly,
          );
        } else if (_enhancedRecurrence.selectedWeekdays.isNotEmpty) {
          _enhancedRecurrence = _enhancedRecurrence.copyWith(
            type: EnhancedRecurrenceType.weekly,
          );
        } else if (_enhancedRecurrence.selectedMonths.isNotEmpty) {
          _enhancedRecurrence = _enhancedRecurrence.copyWith(
            type: EnhancedRecurrenceType.yearly,
          );
        } else if (_recurrenceType != RecurrenceType.none) {
          // Convert old recurrenceType to enhancedRecurrence
          final taskStartDate = widget.task!.startDate ?? _startDate;
          EnhancedRecurrenceType enhancedType = EnhancedRecurrenceType.none;
          switch (_recurrenceType) {
            case RecurrenceType.daily:
              enhancedType = EnhancedRecurrenceType.daily;
              _enhancedRecurrence = _enhancedRecurrence.copyWith(type: enhancedType);
              break;
            case RecurrenceType.weekly:
              enhancedType = EnhancedRecurrenceType.weekly;
              _enhancedRecurrence = _enhancedRecurrence.copyWith(
                type: enhancedType,
                selectedWeekdays: [WeekDay.values[taskStartDate.weekday - 1]],
              );
              break;
            case RecurrenceType.monthly:
              enhancedType = EnhancedRecurrenceType.monthly;
              _enhancedRecurrence = _enhancedRecurrence.copyWith(
                type: enhancedType,
                selectedMonthDays: [taskStartDate.day],
              );
              break;
            // Note: RecurrenceType doesn't have yearly, but EnhancedRecurrenceType does
            // For old yearly tasks, we'll treat them as monthly for backward compatibility
            default:
              break;
          }
        }
      }
    }
    
    // Gestion des heures (simplifiée pour l'exemple)
  }

  Future<void> _fetchUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final users = snapshot.docs
          .map((doc) => AppUser.fromFirestore(doc))
          .where((user) => user.isActive)
          .toList();
      
      if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
      }
    } catch (e) {
      AppLogger.error('Error fetching users: $e');
      if (mounted) {
      setState(() {
        _isLoading = false;
      });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  // --- SAVE LOGIC ---
  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill in all required fields.');
      return;
    }
    
    if (_assignedTo.isEmpty) {
      _showErrorSnackBar('Please assign the task to at least one user.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar('Authentication error. Please log in again.');
        setState(() => _isSaving = false);
        return;
      }

      // Format times as HH:mm strings
      final startTimeStr = _startTime != null 
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
          : null;
      final endTimeStr = _endTime != null
          ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
          : null;

      // For assigned users (non-creators), preserve original values for restricted fields
      final task = Task(
        id: widget.task?.id ?? FirebaseFirestore.instance.collection('tasks').doc().id,
        title: _isCreator 
            ? _titleController.text.trim()
            : (widget.task?.title ?? ''),
        description: _descriptionController.text.trim(), // All users can edit description
        createdBy: widget.task?.createdBy ?? currentUser.uid, // Preserve original creator
        assignedTo: _isCreator 
            ? _assignedTo
            : (widget.task?.assignedTo ?? []), // Preserve original assignees
        dueDate: _isCreator 
            ? _dueDate
            : (widget.task?.dueDate ?? DateTime.now()), // Preserve original due date
        priority: _isCreator 
            ? _priority
            : (widget.task?.priority ?? TaskPriority.medium), // Preserve original priority
        status: widget.task?.status ?? TaskStatus.todo,
        isRecurring: _isCreator
            ? (_enhancedRecurrence.type != EnhancedRecurrenceType.none)
            : (widget.task?.isRecurring ?? false), // Preserve original recurrence
        recurrenceType: _isCreator
            ? _recurrenceType
            : (widget.task?.recurrenceType ?? RecurrenceType.none),
        enhancedRecurrence: _isCreator
            ? _enhancedRecurrence
            : (widget.task?.enhancedRecurrence ?? const EnhancedRecurrence()),
        createdAt: widget.task?.createdAt ?? Timestamp.now(),
        attachments: const [],
        startDate: _isCreator
            ? _startDate
            : (widget.task?.startDate ?? DateTime.now()),
        isDraft: _saveAsDraft,
        publishedAt: _saveAsDraft ? null : (widget.task?.publishedAt ?? Timestamp.now()),
        location: _isCreator
            ? (_locationController.text.trim().isEmpty ? null : _locationController.text.trim())
            : widget.task?.location, // Preserve original location
        startTime: _isCreator ? startTimeStr : widget.task?.startTime,
        endTime: _isCreator ? endTimeStr : widget.task?.endTime,
        labels: _isCreator ? _labels : (widget.task?.labels ?? []), // Preserve original labels
        subTaskIds: const [],
      );

      if (widget.task == null) {
        await _taskService.createTask(task);
      } else {
        await _taskService.updateTask(task.id, task);
      }

      _showSuccessSnackBar(widget.task == null
          ? (_saveAsDraft ? 'Draft saved successfully!' : 'Task published successfully!')
          : 'Task updated successfully!');

      _closeDialog();
    } catch (e) {
      AppLogger.error('Error saving task: $e');
      _showErrorSnackBar('Failed to save task. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _closeDialog() {
    _animationController.reverse().then((_) => Navigator.of(context).pop());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.black.withOpacity(0.4), // Fond plus sombre pour le focus
              child: Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                child: _buildConnecteamDialog(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnecteamDialog() {
    return Container(
      width: 500, // Largeur confortable style "Modal Desktop"
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // 1. LE TITRE (Style "Document" - Gros et sans bordure)
                    // Only creators can edit title
                    if (_isCreator)
                      _buildTitleInput()
                    else
                      _buildReadOnlyField('Title', widget.task?.title ?? ''),
                    
                    const SizedBox(height: 24),
                    
                    // 2. META DATA (Assignation & Priorité) - Style "Row"
                    // Only creators can edit assignees and priority
                    if (_isCreator) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAssigneeSection()),
                          const SizedBox(width: 16),
                          _buildPriorityBadge(),
                        ],
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildReadOnlyField('Assigned To', _assignedTo.map((id) => _getUserName(id)).join(', '))),
                          const SizedBox(width: 16),
                          _buildReadOnlyField('Priority', _priority.toString().split('.').last.toUpperCase()),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xffF3F4F6)),
                    const SizedBox(height: 24),

                    // 3. DATE & TIME SECTION (Style "Grid" avec icônes)
                    // Only creators can edit dates and recurrence
                    if (_isCreator) ...[
                      Text('SCHEDULE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xff9CA3AF), letterSpacing: 1.0)),
                      const SizedBox(height: 12),
                      _buildDateTimeGrid(),
                      const SizedBox(height: 16),
                      _buildRecurrenceSection(),
                    ] else ...[
                      Text('SCHEDULE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xff9CA3AF), letterSpacing: 1.0)),
                      const SizedBox(height: 12),
                      _buildReadOnlyField('Due Date', DateFormat('MMM dd, yyyy • h:mm a').format(_dueDate)),
                      if (widget.task?.isRecurring == true) ...[
                        const SizedBox(height: 12),
                        _buildReadOnlyField('Recurrence', widget.task!.enhancedRecurrence.description),
                      ],
                    ],

                    const SizedBox(height: 24),

                    // 4. DESCRIPTION & DETAILS
                    _buildDescriptionInput(),
                    
                    const SizedBox(height: 16),
                    
                    // 5. EXPANDABLE ADVANCED (Location, Tags)
                    if (!_showAdvanced)
                      TextButton.icon(
                        onPressed: () => setState(() => _showAdvanced = true),
                        icon: const Icon(Icons.add_circle_outline, size: 16),
                        label: const Text('Add location & tags'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xff6B7280)),
                      ),
                    
                    if (_showAdvanced) ...[
                      const SizedBox(height: 16),
                      // Location and Tags - only creators can edit
                      if (_isCreator) ...[
                        _buildLocationInput(),
                        const SizedBox(height: 16),
                        _buildTagsInput(),
                      ] else ...[
                        if (widget.task?.location != null && widget.task!.location!.isNotEmpty)
                          _buildReadOnlyField('Location', widget.task!.location!),
                        const SizedBox(height: 16),
                        if (widget.task?.labels != null && widget.task!.labels!.isNotEmpty)
                          _buildReadOnlyField('Tags', widget.task!.labels!.join(', ')),
                      ],
                    ]
            ],
          ),
        ),
            ),
          ),
          _buildFooterActions(),
        ],
      ),
    );
  }

  // --- WIDGETS SPECIFIQUES ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffF3F4F6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
        children: [
          Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xffEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.task_alt, size: 18, color: Color(0xff0386FF)),
              ),
              const SizedBox(width: 12),
                Text(
                widget.task == null ? 'New Task' : 'Edit Task',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xff111827)),
              ),
            ],
          ),
          IconButton(
            onPressed: _closeDialog,
            icon: const Icon(Icons.close, size: 20, color: Color(0xff9CA3AF)),
            style: IconButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return TextFormField(
              controller: _titleController,
      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xff111827)),
      decoration: InputDecoration(
        hintText: 'What needs to be done?',
        hintStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w400, color: const Color(0xffD1D5DB)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      validator: (val) => val!.isEmpty ? 'Title is required' : null,
    );
  }

  Widget _buildAssigneeSection() {
    return InkWell(
      onTap: _isCreator ? _openUserSelectionDialog : null, // Only creators can change assignees
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xffE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ASSIGNED TO', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xff9CA3AF))),
                    const SizedBox(height: 8),
            if (_assignedTo.isEmpty)
                    Row(
                      children: [
                      Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(color: Color(0xffF3F4F6), shape: BoxShape.circle),
                    child: const Icon(Icons.person_add_outlined, size: 16, color: Color(0xff6B7280)),
                  ),
                            const SizedBox(width: 8),
                  Text('Select users', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff6B7280))),
                ],
                      )
                    else
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _assignedTo.map((id) => Chip(
                  avatar: CircleAvatar(
                    backgroundColor: const Color(0xff0386FF),
                    child: Text(id.substring(0,1).toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                  label: Text(_getUserName(id), style: const TextStyle(fontSize: 12)), // Votre fonction existante
                  backgroundColor: const Color(0xffEFF6FF),
                  side: BorderSide.none,
                  padding: const EdgeInsets.all(4),
                  visualDensity: VisualDensity.compact,
                )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge() {
    // Une dropdown stylisée simple
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
        color: _getPriorityColor(_priority).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaskPriority>(
          value: _priority,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: _getPriorityColor(_priority)),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _getPriorityColor(_priority)),
          items: TaskPriority.values.map((p) {
            return DropdownMenuItem(
              value: p,
              child: Text(p.toString().split('.').last.toUpperCase()),
            );
          }).toList(),
          onChanged: _isCreator ? (val) => setState(() => _priority = val!) : null, // Only creators can change priority
        ),
      ),
    );
  }

  Widget _buildDateTimeGrid() {
    return Row(
      children: [
        Expanded(child: _buildDateBox('STARTS', _startDate, Icons.calendar_today_outlined, true)),
                    const SizedBox(width: 12),
        Expanded(child: _buildDateBox('DUE DATE', _dueDate, Icons.event_available_outlined, false)),
      ],
    );
  }

  Widget _buildDateBox(String label, DateTime date, IconData icon, bool isStart) {
    return InkWell(
      onTap: _isCreator ? () async {
        final picked = await showDatePicker(
      context: context,
          initialDate: date, 
          firstDate: DateTime(2020), 
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(primary: Color(0xff0386FF)),
              ),
              child: child!,
            );
          }
        );
        if(picked != null) setState(() => isStart ? _startDate = picked : _dueDate = picked);
      } : null, // Disable if not creator
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xffF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xffF3F4F6)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xff6B7280)),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xff9CA3AF))),
                const SizedBox(height: 2),
                  Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xff374151)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
        Row(
          children: [
            const Icon(Icons.sort, size: 18, color: Color(0xff9CA3AF)),
            const SizedBox(width: 8),
            Text('Description', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xff374151))),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          minLines: 2,
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff4B5563)),
          decoration: InputDecoration(
            hintText: 'Add details, subtasks, or files...',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xffD1D5DB)),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xff0386FF))),
          ),
        ),
      ],
    );
  }
  
  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xff9CA3AF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInput() {
    return TextFormField(
      controller: _locationController,
      enabled: _isCreator, // Only creators can edit location
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xff9CA3AF)),
        hintText: 'Add location',
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffE5E7EB))),
      ),
    );
  }

  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ..._labels.map((l) => Chip(
              label: Text(l, style: GoogleFonts.inter(fontSize: 11)),
              onDeleted: _isCreator ? () => setState(() => _labels.remove(l)) : null, // Only creators can delete tags
              backgroundColor: const Color(0xffF3F4F6),
              deleteIconColor: const Color(0xff9CA3AF),
            )),
            if (_isCreator) // Only show add tag button for creators
              ActionChip(
                label: Text('+ Add Tag', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff0386FF))),
                backgroundColor: const Color(0xffEFF6FF),
                onPressed: () {
                  // Logique simplifiée pour l'exemple
                   showDialog(context: context, builder: (c) => AlertDialog(
                     title: const Text('Add Tag'),
                     content: TextField(controller: _labelController, onSubmitted: (v) {
                       setState(() => _labels.add(v));
                       _labelController.clear();
                       Navigator.pop(c);
                     }),
                   ));
                },
              )
          ],
        )
      ],
    );
  }

  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE5E7EB))),
        color: Color(0xffF9FAFB),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _isSaving ? null : () {
              _saveAsDraft = true;
              _saveTask();
            },
            child: Text('Save Draft', style: GoogleFonts.inter(color: const Color(0xff6B7280), fontWeight: FontWeight.w600)),
          ),
          Row(
              children: [
              OutlinedButton(
                onPressed: _closeDialog,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xffD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xff374151), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
              ElevatedButton(
              onPressed: _isSaving ? null : () {
                  _saveAsDraft = false;
                _saveTask();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      widget.task == null 
                        ? 'Publish Task' 
                        : (widget.task!.isDraft ? 'Publish Draft' : 'Update'), 
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)
                          ),
                        ),
                      ],
          )
        ],
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.repeat, size: 18, color: Color(0xff9CA3AF)),
            const SizedBox(width: 8),
            Text(
              'Recurrence',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xff374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xffF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffE5E7EB)),
          ),
          child: EnhancedRecurrencePicker(
            initialRecurrence: _enhancedRecurrence,
            showEndDate: true,
            onRecurrenceChanged: (recurrence) {
              setState(() {
                _enhancedRecurrence = recurrence;
                // Map enhanced recurrence type back to old recurrenceType for backward compatibility
                switch (recurrence.type) {
                  case EnhancedRecurrenceType.daily:
                    _recurrenceType = RecurrenceType.daily;
                    break;
                  case EnhancedRecurrenceType.weekly:
                    _recurrenceType = RecurrenceType.weekly;
                    break;
                  case EnhancedRecurrenceType.monthly:
                    _recurrenceType = RecurrenceType.monthly;
                    break;
                  case EnhancedRecurrenceType.yearly:
                    // RecurrenceType doesn't have yearly, so we'll use monthly for backward compatibility
                    // The enhancedRecurrence will still have the correct yearly type
                    _recurrenceType = RecurrenceType.monthly;
                    break;
                  default:
                    _recurrenceType = RecurrenceType.none;
                }
              });
            },
          ),
        ),
        if (_enhancedRecurrence.type != EnhancedRecurrenceType.none) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ConnecteamStyle.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ConnecteamStyle.primaryBlue.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: ConnecteamStyle.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _enhancedRecurrence.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: ConnecteamStyle.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Helper pour les couleurs de priorité
  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high: return const Color(0xffEF4444);
      case TaskPriority.medium: return const Color(0xffF59E0B);
      case TaskPriority.low: return const Color(0xff10B981);
      default: return const Color(0xff6B7280);
    }
  }

  // Helper pour le nom (simulé)
  String _getUserName(String id) => _users.firstWhere((u) => u.id == id, orElse: () => AppUser(id: id, email: 'User')).email ?? 'User';

  Future<void> _openUserSelectionDialog() async {
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
}

// User Selection Dialog
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
