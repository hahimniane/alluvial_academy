import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/shift_form_service.dart';
import '../../../core/utils/app_logger.dart';

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

  @override
  void initState() {
    super.initState();
    _calculateDefaultHours();
    _loadFormTemplate();
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
          const SnackBar(
            content: Text('Class Report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                          'Class Report',
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
                      child: Text('Skip', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
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
                        : Text('Submit Report', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
          Text('Verify Duration', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clock In', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                    Text(DateFormat('h:mm a').format(widget.clockInTime), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF94A3B8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Clock Out', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
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
              labelText: 'Billable Hours',
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffix: Text('hrs', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    final id = field['id'];
    final label = field['label'] ?? 'Field';
    final type = field['type'] ?? 'text';
    final placeholder = field['placeholder'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
          const SizedBox(height: 8),
          if (type == 'textarea' || type == 'long_text')
            TextFormField(
              controller: _textControllers.putIfAbsent(id, () => TextEditingController()),
              maxLines: 3,
              decoration: _inputDecoration(placeholder),
            )
          else
            TextFormField(
              controller: _textControllers.putIfAbsent(id, () => TextEditingController()),
              decoration: _inputDecoration(placeholder),
            ),
        ],
      ),
    );
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
