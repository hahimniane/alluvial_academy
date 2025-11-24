import 'package:flutter/material.dart';
import '../../../core/enums/task_enums.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';
import '../services/task_service.dart';
import '../services/file_attachment_service.dart';
import 'task_comments_section.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class TaskDetailsView extends StatefulWidget {
  final Task task;
  final VoidCallback onTaskUpdated;

  const TaskDetailsView({
    super.key,
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  State<TaskDetailsView> createState() => _TaskDetailsViewState();
}

class _TaskDetailsViewState extends State<TaskDetailsView>
    with TickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  final FileAttachmentService _fileService = FileAttachmentService();
  final TextEditingController _notesController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isUpdating = false;
  bool _isUploadingFile = false;
  TaskStatus _currentStatus = TaskStatus.todo;
  late Task _currentTask;
  String? _assignedByName;
  List<String> _assignedToNames = [];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.task.status;
    _currentTask = widget.task;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();

    // Resolve user IDs to display names
    _resolveUserNames();
  }

  Future<void> _resolveUserNames() async {
    try {
      // Resolve Assigned By
      if (widget.task.createdBy.isNotEmpty) {
        final creatorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.task.createdBy)
            .get();
        if (creatorDoc.exists) {
          final data = creatorDoc.data() as Map<String, dynamic>;
          final fullName =
              '${(data['first_name'] ?? '').toString().trim()} ${(data['last_name'] ?? '').toString().trim()}'
                  .trim();
          if (mounted)
            setState(() => _assignedByName =
                fullName.isNotEmpty ? fullName : (data['e-mail'] ?? 'Unknown'));
        }
      }

      // Resolve Assigned To (list of user IDs)
      if (widget.task.assignedTo.isNotEmpty) {
        final List<Future<String>> futures =
            widget.task.assignedTo.map<Future<String>>((uid) async {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            if (doc.exists) {
              final d = doc.data() as Map<String, dynamic>;
              final fullName =
                  '${(d['first_name'] ?? '').toString().trim()} ${(d['last_name'] ?? '').toString().trim()}'
                      .trim();
              return fullName.isNotEmpty
                  ? fullName
                  : (d['e-mail']?.toString() ?? uid);
            }
          } catch (_) {}
          return uid; // fallback
        }).toList();

        final List<String> names = await Future.wait<String>(futures);
        if (mounted) {
          setState(() => _assignedToNames = List<String>.from(names));
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        Flexible(child: _buildBody()),
        _buildActions(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(_currentStatus),
            _getStatusColor(_currentStatus).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(_currentStatus),
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.task.title,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatusChip(_currentStatus),
              const SizedBox(width: 12),
              _buildPriorityChip(widget.task.priority),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildDescriptionSection(),
            const SizedBox(height: 24),
            _buildAttachmentsSection(),
            const SizedBox(height: 24),
            _buildStatusUpdateSection(),
            if (_currentStatus != TaskStatus.todo) ...[
              const SizedBox(height: 24),
              _buildNotesSection(),
            ],
            const SizedBox(height: 32),
            TaskCommentsSection(task: _currentTask),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.calendar_today,
            'Due Date',
            DateFormat('MMM dd, yyyy • h:mm a').format(widget.task.dueDate),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.person,
            'Assigned To',
            _assignedToNames.isEmpty
                ? (widget.task.assignedTo.isEmpty ? 'Unassigned' : 'Loading...')
                : _assignedToNames.join(', '),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.person_outline,
            'Assigned By',
            (_assignedByName != null && _assignedByName!.isNotEmpty)
                ? _assignedByName!
                : (widget.task.createdBy.isNotEmpty ? 'Loading...' : 'Unknown'),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.access_time,
            'Created',
            DateFormat('MMM dd, yyyy').format(widget.task.createdAt.toDate()),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xff0386FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xff0386FF), size: 18),
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
                  color: const Color(0xff64748B),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Text(
            widget.task.description.isNotEmpty
                ? widget.task.description
                : 'No description provided',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: widget.task.description.isNotEmpty
                  ? const Color(0xff475569)
                  : const Color(0xff94A3B8),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Attachments',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xff1E293B),
              ),
            ),
            const Spacer(),
            if (_currentStatus != TaskStatus.done)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isUploadingFile
                      ? null
                      : () {
                          AppLogger.debug('Add Files button clicked');
                          _pickAndUploadFiles();
                        },
                  icon: _isUploadingFile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.attach_file, size: 18),
                  label: Text(
                    _isUploadingFile ? 'Uploading...' : 'Add Files',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_currentTask.attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.attach_file,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No attachments yet',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add files to share resources or completed work',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff94A3B8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...List.generate(_currentTask.attachments.length, (index) {
            final attachment = _currentTask.attachments[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAttachmentItem(attachment),
            );
          }),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                fileIcon,
                style: const TextStyle(fontSize: 20),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$fileSize • ${DateFormat('MMM dd, yyyy').format(attachment.uploadedAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _downloadFile(attachment),
                icon: const Icon(Icons.download),
                tooltip: 'Download',
                iconSize: 20,
                color: const Color(0xff0386FF),
              ),
              if (_currentStatus != TaskStatus.done)
                IconButton(
                  onPressed: () => _removeAttachment(attachment),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                  iconSize: 20,
                  color: Colors.red.shade400,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUpdateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Update Status',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: TaskStatus.values.map((status) {
            final isSelected = _currentStatus == status;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _currentStatus = status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getStatusColor(status)
                          : const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _getStatusColor(status)
                            : const Color(0xffE2E8F0),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: isSelected
                              ? Colors.white
                              : _getStatusColor(status),
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusLabel(status),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : _getStatusColor(status),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Notes',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _currentStatus == TaskStatus.done
                  ? 'Add completion notes or summary...'
                  : 'Add progress notes or comments...',
              hintStyle: GoogleFonts.inter(
                color: const Color(0xff94A3B8),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff475569),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final hasChanges = _currentStatus != widget.task.status;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xffF8FAFC),
        borderRadius: BorderRadius.only(
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
                side: const BorderSide(color: Color(0xffE2E8F0)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff64748B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: hasChanges && !_isUpdating ? _updateTask : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasChanges
                    ? _getStatusColor(_currentStatus)
                    : const Color(0xffE2E8F0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: hasChanges ? 4 : 0,
              ),
              child: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentStatus == TaskStatus.done
                              ? Icons.check_circle
                              : Icons.update,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentStatus == TaskStatus.done
                              ? 'Submit Task'
                              : 'Update Status',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  Widget _buildStatusChip(TaskStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusLabel(status),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(TaskPriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.flag,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            _getPriorityLabel(priority),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTask() async {
    setState(() => _isUpdating = true);

    try {
      // Determine completion fields
      Timestamp? completedAt = widget.task.completedAt;
      int? overdueFrozen = widget.task.overdueDaysAtCompletion;

      final wasDone = widget.task.status == TaskStatus.done;
      final willBeDone = _currentStatus == TaskStatus.done;

      if (!wasDone && willBeDone) {
        final now = DateTime.now();
        final overdue = now.isAfter(widget.task.dueDate)
            ? now.difference(widget.task.dueDate).inDays
            : 0;
        completedAt = Timestamp.fromDate(now);
        overdueFrozen = overdue;
      }

      final updatedTask = Task(
        id: widget.task.id,
        title: widget.task.title,
        description: widget.task.description,
        createdBy: widget.task.createdBy,
        assignedTo: widget.task.assignedTo,
        dueDate: widget.task.dueDate,
        priority: widget.task.priority,
        status: _currentStatus,
        isRecurring: widget.task.isRecurring,
        recurrenceType: widget.task.recurrenceType,
        createdAt: widget.task.createdAt,
        attachments: _currentTask.attachments,
        completedAt: completedAt,
        overdueDaysAtCompletion: overdueFrozen,
      );

      await _taskService.updateTask(widget.task.id, updatedTask);

      if (mounted) {
        widget.onTaskUpdated();
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _currentStatus == TaskStatus.done
                      ? Icons.check_circle
                      : Icons.update,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _currentStatus == TaskStatus.done
                      ? 'Task submitted successfully!'
                      : 'Task status updated!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: _getStatusColor(_currentStatus),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Failed to update task. Please try again.',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _pickAndUploadFiles() async {
    AppLogger.debug('_pickAndUploadFiles called');

    try {
      if (mounted) {
        setState(() => _isUploadingFile = true);
      }

      AppLogger.debug('Calling file service to pick files...');
      final files = await _fileService.pickFiles();

      if (files == null || files.isEmpty) {
        AppLogger.debug('No files selected or user cancelled');
        if (mounted) {
          setState(() => _isUploadingFile = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No files selected',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      AppLogger.debug('${files.length} files selected, starting upload...');
      int successfulUploads = 0;

      for (final file in files) {
        try {
          AppLogger.debug('Uploading file: ${file.name}');
          final attachment =
              await _fileService.uploadFile(file, widget.task.id);
          await _taskService.addAttachmentToTask(widget.task.id, attachment);

          if (mounted) {
            setState(() {
              _currentTask = Task(
                id: _currentTask.id,
                title: _currentTask.title,
                description: _currentTask.description,
                createdBy: _currentTask.createdBy,
                assignedTo: _currentTask.assignedTo,
                dueDate: _currentTask.dueDate,
                priority: _currentTask.priority,
                status: _currentTask.status,
                isRecurring: _currentTask.isRecurring,
                recurrenceType: _currentTask.recurrenceType,
                createdAt: _currentTask.createdAt,
                attachments: [..._currentTask.attachments, attachment],
              );
            });
          }

          successfulUploads++;
          AppLogger.error('Successfully uploaded: ${file.name}');
        } catch (e) {
          AppLogger.error('Failed to upload ${file.name}: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to upload ${file.name}: ${e.toString()}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      }

      if (mounted && successfulUploads > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '$successfulUploads file(s) uploaded successfully!',
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
      AppLogger.error('Error in _pickAndUploadFiles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to upload files: ${e.toString()}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingFile = false);
      }
    }
  }

  Future<void> _downloadFile(TaskAttachment attachment) async {
    try {
      await _fileService.downloadFile(attachment);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeAttachment(TaskAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Attachment'),
        content: Text(
            'Are you sure you want to remove "${attachment.originalName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _taskService.removeAttachmentFromTask(
            widget.task.id, attachment.id);

        setState(() {
          _currentTask = Task(
            id: _currentTask.id,
            title: _currentTask.title,
            description: _currentTask.description,
            createdBy: _currentTask.createdBy,
            assignedTo: _currentTask.assignedTo,
            dueDate: _currentTask.dueDate,
            priority: _currentTask.priority,
            status: _currentTask.status,
            isRecurring: _currentTask.isRecurring,
            recurrenceType: _currentTask.recurrenceType,
            createdAt: _currentTask.createdAt,
            attachments: _currentTask.attachments
                .where((a) => a.id != attachment.id)
                .toList(),
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Attachment removed successfully!',
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
              content: Text('Failed to remove attachment: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return const Color(0xff3B82F6);
      case TaskStatus.inProgress:
        return const Color(0xff8B5CF6);
      case TaskStatus.done:
        return const Color(0xff10B981);
    }
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.hourglass_empty;
      case TaskStatus.done:
        return Icons.check_circle;
    }
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
}
