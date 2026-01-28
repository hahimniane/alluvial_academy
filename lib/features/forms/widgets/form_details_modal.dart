import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/form_labels_cache_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Reusable form details modal for teachers
class FormDetailsModal {
  FormDetailsModal._(); // Private constructor to prevent instantiation

  static void show(BuildContext context, {
    required String formId,
    required String shiftId,
    required Map<String, dynamic> responses,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.formDetails,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _FormDetailsContent(
                  formId: formId,
                  shiftId: shiftId,
                  responses: responses,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormDetailsContent extends StatefulWidget {
  final String formId;
  final String shiftId;
  final Map<String, dynamic> responses;

  const _FormDetailsContent({
    required this.formId,
    required this.shiftId,
    required this.responses,
  });

  @override
  State<_FormDetailsContent> createState() => _FormDetailsContentState();
}

class _FormDetailsContentState extends State<_FormDetailsContent> {
  Map<String, String>? _fieldLabels;
  bool _isLoadingLabels = true;
  TeachingShift? _shift;
  bool _isLoadingShift = true;

  @override
  void initState() {
    super.initState();
    _loadFieldLabels();
    _loadShiftData();
  }
  
  Future<void> _loadShiftData() async {
    if (widget.shiftId == 'N/A' || widget.shiftId.isEmpty) {
      setState(() {
        _isLoadingShift = false;
      });
      return;
    }
    
    try {
      final shiftDoc = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(widget.shiftId)
          .get();

      if (shiftDoc.exists) {
        final shift = TeachingShift.fromFirestore(shiftDoc);
        if (mounted) {
          setState(() {
            _shift = shift;
            _isLoadingShift = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingShift = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading shift data: $e');
      if (mounted) {
        setState(() {
          _isLoadingShift = false;
        });
      }
    }
  }

  Future<void> _loadFieldLabels() async {
    try {
      // First, try to get the form response document to extract templateId/formId
      final formResponseDoc = await FirebaseFirestore.instance
          .collection('form_responses')
          .doc(widget.formId)
          .get();
      
      if (!formResponseDoc.exists) {
        debugPrint('⚠️ Form response document not found: ${widget.formId}');
        setState(() {
          _isLoadingLabels = false;
        });
        return;
      }
      
      final formResponseData = formResponseDoc.data() ?? {};
      final templateId = formResponseData['templateId'] as String?;
      final formId = formResponseData['formId'] as String?;
      
      debugPrint('📋 Form response ${widget.formId}: templateId=$templateId, formId=$formId');
      
      // Use the cache service which handles both old and new systems
      final labels = await FormLabelsCacheService().getLabelsForFormResponse(widget.formId);
      
      if (labels.isNotEmpty) {
        debugPrint('✅ Loaded ${labels.length} field labels');
        setState(() {
          _fieldLabels = labels;
          _isLoadingLabels = false;
        });
      } else {
        debugPrint('⚠️ No field labels found for form response ${widget.formId}');
        setState(() {
          _isLoadingLabels = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading field labels: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _isLoadingLabels = false;
      });
    }
  }

  String _getDayOfWeekString(int weekday) {
    if (weekday < 1 || weekday > 7) {
      return AppLocalizations.of(context)!.commonUnknown;
    }
    final date = DateTime(2020, 1, 6).add(Duration(days: weekday - 1));
    return DateFormat.EEEE(AppLocalizations.of(context)!.localeName).format(date);
  }

  String _getFieldLabel(String fieldId) {
    if (_fieldLabels != null && _fieldLabels!.containsKey(fieldId)) {
      return _fieldLabels![fieldId]!;
    }
    
    if (_fieldLabels != null) {
      for (var entry in _fieldLabels!.entries) {
        if (entry.key.toString() == fieldId.toString()) {
          return entry.value;
        }
      }
    }
    
    if (RegExp(r'^\d+$').hasMatch(fieldId)) {
      return AppLocalizations.of(context)!.formQuestionNumber(fieldId);
    }
    
    return fieldId
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shift Information Section (Autofilled Data)
          if (widget.shiftId != 'N/A' && widget.shiftId.isNotEmpty) ...[
            if (_isLoadingShift)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.loadingShiftInformation,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_shift != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.shiftInformationAutofilled,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_shift!.studentNames.isNotEmpty)
                      _buildShiftInfoRow(
                        'Students',
                        _shift!.studentNames.join(', '),
                      ),
                    if (_shift!.subjectDisplayName != null && _shift!.subjectDisplayName!.isNotEmpty)
                      _buildShiftInfoRow(
                        'Subject',
                        _shift!.subjectDisplayName!,
                      ),
                    _buildShiftInfoRow(
                      'Schedule',
                      '${_getDayOfWeekString(_shift!.shiftStart.weekday)} • ${DateFormat('MMM d, yyyy').format(_shift!.shiftStart)} • ${DateFormat('HH:mm').format(_shift!.shiftStart)} - ${DateFormat('HH:mm').format(_shift!.shiftEnd)}',
                    ),
                    Builder(
                      builder: (context) {
                        final duration = _shift!.shiftEnd.difference(_shift!.shiftStart);
                        final hours = duration.inHours;
                        final minutes = duration.inMinutes % 60;
                        return _buildShiftInfoRow(
                          'Duration',
                          hours > 0 
                            ? '$hours ${hours == 1 ? 'hour' : 'hours'}${minutes > 0 ? ' $minutes min' : ''}'
                            : '$minutes min',
                        );
                      },
                    ),
                    _buildShiftInfoRow(
                      'Teacher',
                      _shift!.teacherName,
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          // Form Responses Section
          Text(
            AppLocalizations.of(context)!.formResponses2,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingLabels)
            Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (!_isLoadingLabels && widget.responses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                AppLocalizations.of(context)!.noResponses,
                style: GoogleFonts.inter(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                ),
              ),
            ),
          if (!_isLoadingLabels && widget.responses.isNotEmpty)
            ...widget.responses.entries.map((entry) {
              final label = _getFieldLabel(entry.key);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Colors.grey.shade900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _formatResponseValue(entry.value),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildShiftInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatResponseValue(dynamic value) {
    if (value == null) {
      return Text(
        AppLocalizations.of(context)!.text5,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey.shade400,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (value is String) {
      if (value.isEmpty) {
        return Text(
          AppLocalizations.of(context)!.text5,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        );
      }
      return Text(
        value,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey.shade800,
          height: 1.4,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (value is bool) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value ? 'Yes' : 'No',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: value ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      );
    }
    if (value is num) {
      return Text(
        value.toString(),
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey.shade800,
        ),
      );
    }
    return Text(
      value.toString(),
      style: GoogleFonts.inter(
        fontSize: 12,
        color: Colors.grey.shade800,
      ),
    );
  }
}
