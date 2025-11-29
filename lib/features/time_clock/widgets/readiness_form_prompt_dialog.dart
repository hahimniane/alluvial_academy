import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/services/shift_form_service.dart';
import '../../../core/utils/app_logger.dart';

/// Dialog shown after clock-out to prompt teacher to fill the readiness form
class ReadinessFormPromptDialog extends StatefulWidget {
  final String timesheetId;
  final String shiftId;
  final String shiftTitle;
  final String teacherName;
  final DateTime clockInTime;
  final DateTime clockOutTime;
  final VoidCallback? onFormSubmitted;
  final VoidCallback? onSkipped;

  const ReadinessFormPromptDialog({
    super.key,
    required this.timesheetId,
    required this.shiftId,
    required this.shiftTitle,
    required this.teacherName,
    required this.clockInTime,
    required this.clockOutTime,
    this.onFormSubmitted,
    this.onSkipped,
  });

  @override
  State<ReadinessFormPromptDialog> createState() => _ReadinessFormPromptDialogState();
}

class _ReadinessFormPromptDialogState extends State<ReadinessFormPromptDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _formTemplate;
  List<Map<String, dynamic>> _formFields = [];
  final Map<String, dynamic> _responses = {};
  final Map<String, TextEditingController> _textControllers = {};

  // Quick hours input
  double _reportedHours = 0.0;
  final TextEditingController _hoursController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFormTemplate();
    _calculateDefaultHours();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculateDefaultHours() {
    final duration = widget.clockOutTime.difference(widget.clockInTime);
    _reportedHours = duration.inMinutes / 60.0;
    _hoursController.text = _reportedHours.toStringAsFixed(2);
  }

  Future<void> _loadFormTemplate() async {
    try {
      final template = await ShiftFormService.getReadinessFormTemplate();
      if (template != null && mounted) {
        final fieldsData = template['fields'] as Map<String, dynamic>? ?? {};
        
        // Convert fields map to list and sort by order
        final fieldsList = <Map<String, dynamic>>[];
        fieldsData.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            fieldsList.add({
              'id': key,
              ...value,
            });
          }
        });
        fieldsList.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

        setState(() {
          _formTemplate = template;
          _formFields = fieldsList;
          _isLoading = false;
        });

        // Initialize text controllers for text fields
        for (var field in fieldsList) {
          if (field['type'] == 'text' || field['type'] == 'textarea') {
            _textControllers[field['id']] = TextEditingController();
          }
        }
      } else {
        // No form template found, show simple hours input
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.error('ReadinessFormPromptDialog: Error loading form template: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);

    try {
      // Parse hours from controller
      final hoursText = _hoursController.text.trim();
      double? reportedHours;
      if (hoursText.isNotEmpty) {
        reportedHours = double.tryParse(hoursText);
      }

      // Collect text field responses
      _textControllers.forEach((key, controller) {
        _responses[key] = controller.text;
      });

      // Submit the form
      final formResponseId = await ShiftFormService.submitReadinessForm(
        timesheetId: widget.timesheetId,
        shiftId: widget.shiftId,
        formResponses: _responses,
        reportedHours: reportedHours,
      );

      if (formResponseId != null) {
        widget.onFormSubmitted?.call();
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Readiness form submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to submit form');
      }
    } catch (e) {
      AppLogger.error('ReadinessFormPromptDialog: Error submitting form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting form: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 400,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildShiftSummary(),
                        const SizedBox(height: 20),
                        _buildHoursInput(),
                        if (_formFields.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),
                          ..._buildFormFields(),
                        ],
                      ],
                    ),
                  ),
                ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xff0386FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Completion Form',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Please fill this form after your class',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              widget.onSkipped?.call();
              Navigator.of(context).pop(false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShiftSummary() {
    final duration = widget.clockOutTime.difference(widget.clockInTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff0386FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xff0386FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Shift Summary',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff0386FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Class', widget.shiftTitle),
          _buildSummaryRow('Clock In', _formatTime(widget.clockInTime)),
          _buildSummaryRow('Clock Out', _formatTime(widget.clockOutTime)),
          _buildSummaryRow('Duration', '$hours hr ${minutes.toString().padLeft(2, '0')} min'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xff111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Hours Worked',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff374151),
              ),
            ),
            const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the total hours (e.g., 1 for 1hr, 1.5 for 1hr 30min)',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xff6B7280),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _hoursController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '1.5',
            prefixIcon: const Icon(Icons.access_time, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff0386FF), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFormFields() {
    return _formFields.map((field) {
      final label = field['label'] ?? field['id'];
      final type = field['type'] ?? 'text';
      final required = field['required'] ?? false;
      final placeholder = field['placeholder'] ?? '';
      
      // Parse options - can be List or comma-separated string
      List<String> options = [];
      if (field['options'] != null) {
        if (field['options'] is List) {
          options = List<String>.from(field['options']);
        } else if (field['options'] is String) {
          options = (field['options'] as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff374151),
                    ),
                  ),
                ),
                if (required)
                  const Text(' *', style: TextStyle(color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            _buildFieldInput(field['id'], type, options, placeholder, required, label),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildFieldInput(String fieldId, String type, List<String> options, String placeholder, bool required, String label) {
    switch (type) {
      case 'text':
      case 'email':
      case 'phone':
        return TextFormField(
          controller: _textControllers[fieldId] ??= TextEditingController(),
          decoration: InputDecoration(
            hintText: placeholder.isNotEmpty ? placeholder : 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
          ),
          keyboardType: type == 'email' 
              ? TextInputType.emailAddress 
              : type == 'phone' 
                  ? TextInputType.phone 
                  : TextInputType.text,
        );
      case 'textarea':
      case 'multiline':
      case 'long_text':
      case 'description':
        return TextFormField(
          controller: _textControllers[fieldId] ??= TextEditingController(),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: placeholder.isNotEmpty ? placeholder : 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
          ),
        );
      case 'number':
        return TextFormField(
          controller: _textControllers[fieldId] ??= TextEditingController(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: placeholder.isNotEmpty ? placeholder : 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
          ),
        );
      case 'select':
      case 'dropdown':
        return DropdownButtonFormField<String>(
          value: _responses[fieldId] as String?,
          hint: Text(placeholder.isNotEmpty ? placeholder : 'Select $label'),
          items: options.map((opt) => DropdownMenuItem(
            value: opt,
            child: Text(opt),
          )).toList(),
          onChanged: (value) {
            setState(() {
              _responses[fieldId] = value;
            });
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
          ),
        );
      case 'multi_select':
        final selectedValues = (_responses[fieldId] is List) 
            ? List<String>.from(_responses[fieldId] as List)
            : (_responses[fieldId] is String && (_responses[fieldId] as String).isNotEmpty)
                ? (_responses[fieldId] as String).split(',').map((e) => e.trim()).toList()
                : <String>[];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffE5E7EB)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = selectedValues.contains(opt);
              return FilterChip(
                label: Text(opt),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      final newList = [...selectedValues, opt];
                      _responses[fieldId] = newList;
                    } else {
                      final newList = selectedValues.where((v) => v != opt).toList();
                      _responses[fieldId] = newList;
                    }
                  });
                },
                selectedColor: const Color(0xff0386FF).withOpacity(0.2),
                checkmarkColor: const Color(0xff0386FF),
              );
            }).toList(),
          ),
        );
      case 'boolean':
      case 'checkbox':
      case 'yes_no':
      case 'yesNo':
        return Row(
          children: [
            Checkbox(
              value: _responses[fieldId] == true || _responses[fieldId] == 'true' || _responses[fieldId] == 'yes',
              onChanged: (value) {
                setState(() {
                  _responses[fieldId] = value ?? false;
                });
              },
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ],
        );
      case 'date':
        return InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() {
                _responses[fieldId] = DateFormat('yyyy-MM-dd').format(date);
                if (_textControllers[fieldId] != null) {
                  _textControllers[fieldId]!.text = DateFormat('MMM d, yyyy').format(date);
                }
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Color(0xff6B7280)),
                const SizedBox(width: 12),
                Text(
                  _responses[fieldId] != null
                      ? DateFormat('MMM d, yyyy').format(DateTime.parse(_responses[fieldId] as String))
                      : placeholder.isNotEmpty ? placeholder : 'Select date',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _responses[fieldId] != null 
                        ? const Color(0xff111827) 
                        : const Color(0xff9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return TextFormField(
          controller: _textControllers[fieldId] ??= TextEditingController(),
          decoration: InputDecoration(
            hintText: placeholder.isNotEmpty ? placeholder : 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: const Color(0xffF9FAFB),
          ),
        );
    }
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE5E7EB))),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    widget.onSkipped?.call();
                    Navigator.of(context).pop(false);
                  },
            child: Text(
              'Skip for now',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Submit',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $amPm';
  }
}

