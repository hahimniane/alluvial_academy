import 'package:flutter/material.dart';
import '../../../core/models/user.dart';
import '../models/quick_task.dart';
import '../services/quick_task_service.dart';

class QuickTaskForm extends StatefulWidget {
  final AppUser currentUser;
  const QuickTaskForm({super.key, required this.currentUser});

  @override
  State<QuickTaskForm> createState() => _QuickTaskFormState();
}

class _QuickTaskFormState extends State<QuickTaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  RepeatInterval _repeat = RepeatInterval.none;
  List<String> _selectedAssignees = [];

  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Quick Task',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                _buildAssigneeSelector(context),
                const SizedBox(height: 8),
                _buildDueDatePicker(context),
                const SizedBox(height: 8),
                _buildPrioritySelector(),
                const SizedBox(height: 8),
                _buildRepeatSelector(),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: const Text('Create'),
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssigneeSelector(BuildContext context) {
    // For brevity, using simple text field for comma separated IDs.
    return TextFormField(
      decoration: const InputDecoration(
          labelText: 'Assignee IDs (comma separated userIds)'),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      onSaved: (v) {
        _selectedAssignees = v!
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      },
    );
  }

  Widget _buildDueDatePicker(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(_dueDate == null
              ? 'No due date chosen'
              : 'Due: ${_dueDate!.toLocal().toString().split(' ').first}'),
        ),
        TextButton(
          child: const Text('Select'),
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              firstDate: now,
              lastDate: DateTime(now.year + 5),
              initialDate: now,
            );
            if (picked != null) {
              setState(() => _dueDate = picked);
            }
          },
        )
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return DropdownButtonFormField<TaskPriority>(
      value: _priority,
      decoration: const InputDecoration(labelText: 'Priority'),
      items: TaskPriority.values
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.name.toUpperCase()),
              ))
          .toList(),
      onChanged: (v) => setState(() => _priority = v!),
    );
  }

  Widget _buildRepeatSelector() {
    return DropdownButtonFormField<RepeatInterval>(
      value: _repeat,
      decoration: const InputDecoration(labelText: 'Repeat'),
      items: RepeatInterval.values
          .map((r) => DropdownMenuItem(
                value: r,
                child: Text(r.name.toUpperCase()),
              ))
          .toList(),
      onChanged: (v) => setState(() => _repeat = v!),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _dueDate == null) return;
    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);

    final task = QuickTask(
      id: '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      createdBy: widget.currentUser.id,
      assigneeIds: _selectedAssignees,
      dueDate: _dueDate!,
      priority: _priority,
      repeat: _repeat,
      createdAt: DateTime.now(),
    );
    try {
      await QuickTaskService().createTask(task);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
