import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/shift_form_service.dart';
import '../../../core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

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
  List<Map<String, dynamic>> _formFields = [];
  final Map<String, dynamic> _responses = {};
  final Map<String, TextEditingController> _textControllers = {};
  final TextEditingController _hoursController = TextEditingController();
  
  // Auto-filled context data (read-only, shown to user)
  late final Map<String, String> _autoFilledContext;

  @override
  void initState() {
    super.initState();
    _initAutoFilledContext();
    _calculateDefaultHours();
    _loadFormTemplate();
  }
  
  void _initAutoFilledContext() {
    final duration = widget.clockOutTime.difference(widget.clockInTime);
    final durationStr = '${duration.inHours}h ${duration.inMinutes % 60}m';
    
    _autoFilledContext = {
      'Teacher': widget.teacherName,
      'Class': widget.shiftTitle,
      'Date': DateFormat('EEEE, MMM d, yyyy').format(widget.clockInTime),
      'Duration': durationStr,
    };
  }

  @override
  void dispose() {
    _hoursController.dispose();
    for (var c in _textControllers.values) c.dispose();
    super.dispose();
  }

  void _calculateDefaultHours() {
    final duration = widget.clockOutTime.difference(widget.clockInTime);
    // Use seconds for precision - even short sessions are captured
    final hours = duration.inSeconds / 3600.0;
    _hoursController.text = hours.toStringAsFixed(4); // More precision for short sessions
  }

  Future<void> _loadFormTemplate() async {
    try {
      final template = await ShiftFormService.getReadinessFormTemplate();
      if (template != null && mounted) {
        final fieldsData = template['fields'] as Map<String, dynamic>? ?? {};
        final fieldsList = <Map<String, dynamic>>[];
        
        fieldsData.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            fieldsList.add({'id': key, ...value});
          }
        });
        
        // Sort by order
        fieldsList.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
        setState(() {
          _formFields = fieldsList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('Error loading form: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    try {
      // Sync text controllers to responses
      _textControllers.forEach((key, controller) {
        _responses[key] = controller.text;
      });

      final reportedHours = double.tryParse(_hoursController.text.trim());

      await ShiftFormService.submitReadinessForm(
        timesheetId: widget.timesheetId,
        shiftId: widget.shiftId,
        formResponses: _responses,
        reportedHours: reportedHours,
      );

      widget.onFormSubmitted?.call();
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.formSubmittedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorE)));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.formClassReport,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                        ),
                        Text(
                          widget.shiftTitle,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: _isLoading 
                ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Auto-filled context (read-only info)
                        _buildAutoFilledContext(),
                        const SizedBox(height: 16),
                        _buildDurationCard(),
                        const SizedBox(height: 24),
                        if (_formFields.isNotEmpty) ...[
                          const Divider(height: 1),
                          const SizedBox(height: 24),
                          ..._formFields.map(_buildField),
                        ],
                      ],
                    ),
                  ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        widget.onSkipped?.call();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text(AppLocalizations.of(context)!.formSkip, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(AppLocalizations.of(context)!.formSubmitReport, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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

  /// Shows auto-filled context info (teacher, class, date) - read-only
  Widget _buildAutoFilledContext() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high, size: 14, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.formAutoFilled,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: _autoFilledContext.entries.map((e) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${e.key}: ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    e.value,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.formVerifyDuration, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.clockIn, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                    Text(DateFormat('h:mm a').format(widget.clockInTime), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF94A3B8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(AppLocalizations.of(context)!.clockOut, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                    Text(DateFormat('h:mm a').format(widget.clockOutTime), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _hoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.formBillableHours,
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffix: Text(AppLocalizations.of(context)!.shiftHrs, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    final id = field['id'] as String;
    final label = field['label'] ?? 'Field';
    final type = field['type'] ?? 'text';
    final placeholder = field['placeholder'] ?? '';
    final required = field['required'] ?? false;
    final options = (field['options'] as List<dynamic>?)?.cast<String>() ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                Text(AppLocalizations.of(context)!.requiredAsterisk, style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _buildFieldInput(id, type, placeholder, options),
        ],
      ),
    );
  }
  
  Widget _buildFieldInput(String id, String type, String placeholder, List<String> options) {
    switch (type) {
      case 'radio':
        // Radio button group
        return Column(
          children: options.map((option) {
            final isSelected = _responses[id] == option;
            return InkWell(
              onTap: () => setState(() => _responses[id] = option),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 20,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      option,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
        
      case 'dropdown':
        // Dropdown selector
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            value: _responses[id] as String?,
            decoration: InputDecoration(
              hintText: placeholder.isEmpty
                  ? AppLocalizations.of(context)!.formSelectOption
                  : placeholder,
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: options.map((option) {
              return DropdownMenuItem(value: option, child: Text(option));
            }).toList(),
            onChanged: (value) => setState(() => _responses[id] = value),
          ),
        );
        
      case 'number':
        // Number input
        return TextFormField(
          controller: _textControllers.putIfAbsent(id, () => TextEditingController()),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDecoration(placeholder),
          onChanged: (value) => _responses[id] = int.tryParse(value) ?? 0,
        );
        
      case 'textarea':
      case 'long_text':
        // Multi-line text
        return TextFormField(
          controller: _textControllers.putIfAbsent(id, () => TextEditingController()),
          maxLines: 3,
          decoration: _inputDecoration(placeholder),
        );
        
      default:
        // Single-line text
        return TextFormField(
          controller: _textControllers.putIfAbsent(id, () => TextEditingController()),
          decoration: _inputDecoration(placeholder),
        );
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    );
  }
}
