import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/features/forms/services/form_labels_cache_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// In-memory shift cache so repeat opens (modal / review) avoid extra reads.
/// Entries expire after 5 minutes. Max 100 entries.
final Map<String, TeachingShift> _formSubmissionShiftCache = {};
final Map<String, DateTime> _formSubmissionShiftCacheTime = {};
const Duration _shiftCacheTtl = Duration(minutes: 5);
const int _shiftCacheMaxEntries = 100;

bool _isShiftCacheValid(String key) {
  final time = _formSubmissionShiftCacheTime[key];
  if (time == null) return false;
  return DateTime.now().difference(time) < _shiftCacheTtl;
}

void _putShiftCache(String key, TeachingShift shift) {
  if (_formSubmissionShiftCache.length >= _shiftCacheMaxEntries &&
      !_formSubmissionShiftCache.containsKey(key)) {
    final oldest = _formSubmissionShiftCacheTime.entries.reduce(
      (a, b) => a.value.isBefore(b.value) ? a : b,
    );
    _formSubmissionShiftCache.remove(oldest.key);
    _formSubmissionShiftCacheTime.remove(oldest.key);
  }
  _formSubmissionShiftCache[key] = shift;
  _formSubmissionShiftCacheTime[key] = DateTime.now();
}

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
      barrierColor: Colors.black.withValues(alpha: 0.5),
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
                child: FormSubmissionDetailsView(
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

/// Shared submission details view that can be used inside a dialog
/// (via [FormDetailsModal]) or embedded inline in a master–detail layout.
class FormSubmissionDetailsView extends StatefulWidget {
  final String formId;
  final String shiftId;
  final Map<String, dynamic> responses;
  /// When provided (e.g. batched prefetch in admin review), skips shift read.
  final TeachingShift? initialShift;

  /// Optional scroll controller (e.g. [DraggableScrollableSheet] in review mode).
  final ScrollController? scrollController;

  const FormSubmissionDetailsView({
    super.key,
    required this.formId,
    required this.shiftId,
    required this.responses,
    this.initialShift,
    this.scrollController,
  });

  @override
  State<FormSubmissionDetailsView> createState() => _FormSubmissionDetailsViewState();
}

class _FormSubmissionDetailsViewState extends State<FormSubmissionDetailsView> {
  Map<String, String>? _fieldLabels;
  bool _isLoadingLabels = true;
  TeachingShift? _shift;
  bool _isLoadingShift = true;

  bool _shouldFetchShiftFromNetwork() {
    if (widget.shiftId == 'N/A' || widget.shiftId.isEmpty) {
      _shift = null;
      _isLoadingShift = false;
      return false;
    }
    if (widget.initialShift != null) {
      _shift = widget.initialShift;
      _isLoadingShift = false;
      _putShiftCache(widget.shiftId, widget.initialShift!);
      return false;
    }
    if (_isShiftCacheValid(widget.shiftId)) {
      _shift = _formSubmissionShiftCache[widget.shiftId];
      _isLoadingShift = false;
      return false;
    }
    _shift = null;
    _isLoadingShift = true;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _shouldFetchShiftFromNetwork();
    if (_isLoadingShift) {
      _loadShiftData();
    }
    _loadFieldLabels();
  }

  @override
  void didUpdateWidget(covariant FormSubmissionDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shiftId != widget.shiftId ||
        oldWidget.formId != widget.formId) {
      setState(() {
        _fieldLabels = null;
        _isLoadingLabels = true;
        _shouldFetchShiftFromNetwork();
      });
      if (_isLoadingShift) {
        _loadShiftData();
      }
      _loadFieldLabels();
    } else if (widget.initialShift != null &&
        !identical(oldWidget.initialShift, widget.initialShift)) {
      setState(() {
        _shift = widget.initialShift;
        _isLoadingShift = false;
        _putShiftCache(widget.shiftId, widget.initialShift!);
      });
    }
  }

  Future<void> _loadShiftData() async {
    if (widget.shiftId == 'N/A' || widget.shiftId.isEmpty) {
      return;
    }

    try {
      final shiftDoc = await FirebaseFirestore.instance
          .collection('teaching_shifts')
          .doc(widget.shiftId)
          .get();

      if (shiftDoc.exists) {
        final shift = TeachingShift.fromFirestore(shiftDoc);
        _putShiftCache(widget.shiftId, shift);
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
      final labels = await FormLabelsCacheService()
          .getLabelsForFormResponse(widget.formId);
      if (mounted) {
        setState(() {
          _fieldLabels = labels.isNotEmpty ? labels : null;
          _isLoadingLabels = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading field labels: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingLabels = false;
        });
      }
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
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      controller: widget.scrollController,
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
                      l10n.loadingShiftInformation,
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
                      l10n.shiftInformationAutofilled,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.formResponsesTitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              if (_isLoadingLabels && widget.responses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.formResponsesUpdatingLabels,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_isLoadingLabels && widget.responses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.noResponses,
                style: GoogleFonts.inter(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                ),
              ),
            ),
          if (widget.responses.isNotEmpty)
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
        AppLocalizations.of(context)!.notProvidedLabel,
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
          AppLocalizations.of(context)!.notProvidedLabel,
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
