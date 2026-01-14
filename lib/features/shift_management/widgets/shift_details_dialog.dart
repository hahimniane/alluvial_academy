import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/models/form_template.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/services/shift_form_service.dart';
import '../../../core/services/form_template_service.dart';
import '../../../form_screen.dart';
import '../../forms/widgets/form_details_modal.dart';
import 'quick_edit_shift_popup.dart';

class ShiftDetailsDialog extends StatefulWidget {
  final TeachingShift shift;
  final VoidCallback? onPublishShift;
  final VoidCallback? onUnpublishShift;
  final VoidCallback? onClaimShift;
  final VoidCallback? onRefresh;
  final Function(ShiftStatus)? onCorrectStatus;
  final VoidCallback? onFillForm;
  final VoidCallback? onEditShift;

  const ShiftDetailsDialog({
    super.key,
    required this.shift,
    this.onPublishShift,
    this.onUnpublishShift,
    this.onClaimShift,
    this.onRefresh,
    this.onCorrectStatus,
    this.onFillForm,
    this.onEditShift,
  });

  @override
  State<ShiftDetailsDialog> createState() => _ShiftDetailsDialogState();
}

class _ShiftDetailsDialogState extends State<ShiftDetailsDialog> {
  String? _formResponseId;
  bool _isCheckingForm = true;

  @override
  void initState() {
    super.initState();
    _checkFormStatus();
  }

  Future<void> _checkFormStatus() async {
    if (widget.shift.status == ShiftStatus.completed || 
        widget.shift.status == ShiftStatus.fullyCompleted ||
        widget.shift.status == ShiftStatus.partiallyCompleted ||
        widget.shift.status == ShiftStatus.missed) {
      final formId = await ShiftFormService.getFormResponseForShift(widget.shift.id);
      if (mounted) {
        setState(() {
          _formResponseId = formId;
          _isCheckingForm = false;
        });
      }
    } else {
      setState(() {
        _isCheckingForm = false;
      });
    }
  }

  Future<void> _showFormDetails() async {
    if (_formResponseId == null) return;
    
    try {
      final formDoc = await FirebaseFirestore.instance
          .collection('form_responses')
          .doc(_formResponseId!)
          .get();
      
      if (formDoc.exists && mounted) {
        final data = formDoc.data() ?? {};
        final responses = data['responses'] as Map<String, dynamic>? ?? {};
        
        FormDetailsModal.show(
          context,
          formId: _formResponseId!,
          shiftId: widget.shift.id,
          responses: responses,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading form details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfo(),
                    const SizedBox(height: 24),
                    _buildScheduleInfo(),
                    const SizedBox(height: 24),
                    _buildParticipantsInfo(),
                    const SizedBox(height: 24),
                    _buildStatusInfo(),
                    if (widget.shift.notes != null) ...[
                      const SizedBox(height: 24),
                      _buildNotesInfo(),
                    ],
                  ],
                ),
              ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.shift.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.shift.status.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return _buildSection(
      'Basic Information',
      Icons.info_outline,
      [
        _buildInfoRow('Subject', widget.shift.effectiveSubjectDisplayName),
        _buildInfoRow('Teacher', widget.shift.teacherName),
        _buildInfoRow(
            'Duration', '${widget.shift.shiftDurationHours.toStringAsFixed(1)} hours'),
        _buildInfoRow(
            'Hourly Rate', '\$${widget.shift.hourlyRate.toStringAsFixed(2)}'),
        _buildInfoRow(
            'Total Payment', '\$${widget.shift.totalPayment.toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildScheduleInfo() {
    return _buildSection(
      'Schedule',
      Icons.schedule,
      [
        _buildInfoRow('Date', _formatDate(widget.shift.shiftStart)),
        _buildInfoRow('Start Time', _formatTime(widget.shift.shiftStart)),
        _buildInfoRow('End Time', _formatTime(widget.shift.shiftEnd)),
        _buildInfoRow('Admin Timezone', widget.shift.adminTimezone),
        _buildInfoRow('Teacher Timezone', widget.shift.teacherTimezone),
        if (widget.shift.recurrence != RecurrencePattern.none) ...[
          _buildInfoRow('Recurrence', _getRecurrenceText()),
          if (widget.shift.recurrenceEndDate != null)
            _buildInfoRow(
                'Recurrence End', _formatDate(widget.shift.recurrenceEndDate!)),
        ],
      ],
    );
  }

  Widget _buildParticipantsInfo() {
    return _buildSection(
      'Participants',
      Icons.people,
      [
        _buildInfoRow('Teacher', widget.shift.teacherName),
        _buildInfoRow(
          'Students (${widget.shift.studentNames.length})',
          widget.shift.studentNames.isNotEmpty
              ? widget.shift.studentNames.join(', ')
              : 'No students assigned',
        ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    return _buildSection(
      'Status & Timing',
      Icons.access_time,
      [
        _buildInfoRow('Current Status', widget.shift.status.name.toUpperCase()),
        _buildInfoRow('Can Clock In', widget.shift.canClockIn ? 'Yes' : 'No'),
        _buildInfoRow(
            'Currently Active', widget.shift.isCurrentlyActive ? 'Yes' : 'No'),
        _buildInfoRow('Has Expired', widget.shift.hasExpired ? 'Yes' : 'No'),
        _buildInfoRow('Created', _formatDateTime(widget.shift.createdAt)),
        if (widget.shift.lastModified != null)
          _buildInfoRow('Last Modified', _formatDateTime(widget.shift.lastModified!)),
      ],
    );
  }

  Widget _buildNotesInfo() {
    return _buildSection(
      'Notes',
      Icons.note,
      [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Text(
            widget.shift.notes!,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff374151),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xffF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xff0386FF)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff374151),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xff6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMyShift = currentUser?.uid == widget.shift.teacherId;
    final canPublish =
        isMyShift && widget.shift.status == ShiftStatus.scheduled && !widget.shift.hasExpired;
    final isPublished = widget.shift.isPublished;

    // Check if shift is marked as missed but hasn't actually started yet
    final now = DateTime.now();
    final isMissedBeforeStart =
        widget.shift.status == ShiftStatus.missed && now.isBefore(widget.shift.shiftStart);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Action buttons on the left
          Row(
            children: [
              // Correct Status button for prematurely missed shifts
              if (isMissedBeforeStart && widget.onCorrectStatus != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCorrectStatus!(ShiftStatus.scheduled);
                    widget.onRefresh?.call();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    'Mark as Scheduled',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              if (isMissedBeforeStart && widget.onCorrectStatus != null)
                const SizedBox(width: 12),
              // Publish/Unpublish button for shift owner
              if (canPublish && widget.onPublishShift != null && !isPublished)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onPublishShift!();
                    widget.onRefresh?.call();
                  },
                  icon: const Icon(Icons.publish, size: 18),
                  label: Text(
                    'Publish Shift',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              if (canPublish && widget.onUnpublishShift != null && isPublished)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onUnpublishShift!();
                    widget.onRefresh?.call();
                  },
                  icon: const Icon(Icons.unpublished, size: 18),
                  label: Text(
                    'Unpublish',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xffF59E0B),
                    side: const BorderSide(color: Color(0xffF59E0B)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

              // Claim button for other teachers viewing published shifts
              if (!isMyShift && isPublished && widget.onClaimShift != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onClaimShift!();
                    widget.onRefresh?.call();
                  },
                  icon: const Icon(Icons.add_task, size: 18),
                  label: Text(
                    'Claim Shift',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              
              // Fill Form or View Form button for shift owner (completed or missed shifts)
              if (isMyShift && 
                  (widget.shift.status == ShiftStatus.completed || 
                   widget.shift.status == ShiftStatus.fullyCompleted ||
                   widget.shift.status == ShiftStatus.partiallyCompleted ||
                   widget.shift.status == ShiftStatus.missed))
                _isCheckingForm 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : _formResponseId != null
                    ? _buildViewFormButton(context)
                    : _buildFillFormButton(context),
              
              // Edit Shift button for shift owner (scheduled shifts only)
              if (isMyShift && widget.shift.status == ShiftStatus.scheduled && !widget.shift.hasExpired)
                _buildEditShiftButton(context),
            ],
          ),

          // Close button on the right
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onRefresh?.call();
            },
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: const Color(0xff6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditShiftButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          // Open quick edit popup
          showDialog(
            context: context,
            builder: (ctx) => QuickEditShiftPopup(
              shift: widget.shift,
              onSaved: () {
                widget.onRefresh?.call();
              },
              onDeleted: () {
                widget.onRefresh?.call();
              },
              onOpenFullEditor: () {
                // For teachers, just close - they can only do quick edit
                widget.onRefresh?.call();
              },
            ),
          );
        },
        icon: const Icon(Icons.edit_calendar, size: 18),
        label: Text(
          'Edit Shift',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xffF59E0B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildViewFormButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: ElevatedButton.icon(
        onPressed: _showFormDetails,
        icon: const Icon(Icons.visibility, size: 18),
        label: Text(
          'View Form',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildFillFormButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            // Get root navigator before closing dialog
            final rootNavigator = Navigator.of(context, rootNavigator: true);
            
            // FIXED: Use same approach as Quick Access - get ALL templates and filter to latest version
            // This ensures we get the latest version even if config points to an old template ID
            final allTemplates = await FormTemplateService.getAllTemplates(forceRefresh: true);
            
            // Filter to keep only the latest version of each template by name (same logic as Quick Access)
            final Map<String, FormTemplate> latestTemplatesByName = {};
            for (var template in allTemplates) {
              if (!template.isActive) continue;
              
              // Normalize template name for comparison
              final normalizedName = template.name
                  .trim()
                  .toLowerCase()
                  .replaceAll(RegExp(r'\s+'), ' ');
              
              if (!latestTemplatesByName.containsKey(normalizedName)) {
                latestTemplatesByName[normalizedName] = template;
              } else {
                final existing = latestTemplatesByName[normalizedName]!;
                // Keep the one with higher version, or if same version, keep the one with later updatedAt
                if (template.version > existing.version) {
                  latestTemplatesByName[normalizedName] = template;
                } else if (template.version == existing.version) {
                  if (template.updatedAt.isAfter(existing.updatedAt)) {
                    latestTemplatesByName[normalizedName] = template;
                  }
                }
              }
            }
            
            // Find the daily class report template (same as Quick Access)
            FormTemplate? template;
            for (var t in latestTemplatesByName.values) {
              if (t.frequency == FormFrequency.perSession &&
                  t.name.toLowerCase().contains('daily') &&
                  (t.name.toLowerCase().contains('class') || t.name.toLowerCase().contains('report'))) {
                template = t;
                break;
              }
            }
            
            // If not found, use first perSession template
            if (template == null) {
              template = latestTemplatesByName.values.firstWhere(
                (t) => t.frequency == FormFrequency.perSession,
                orElse: () => latestTemplatesByName.values.first,
              );
            }
            
            // Close the dialog
            if (context.mounted) {
              Navigator.pop(context);
            }
            
            if (template != null) {
              // Navigate to form screen with template directly (NEW FORMAT)
              // This ensures we use the latest version (same as Quick Access)
              await rootNavigator.push(
                MaterialPageRoute(
                  builder: (context) => FormScreen(
                    shiftId: widget.shift.id,
                    template: template, // Pass template directly - uses latest version
                  ),
                ),
              );
              
              // Call refresh callback if provided
              widget.onRefresh?.call();
              return;
            }
            
            // Fallback: try with autoSelectFormId if template not found
            final readinessFormId = await ShiftFormService.getReadinessFormId();
            
            await rootNavigator.push(
              MaterialPageRoute(
                builder: (context) => FormScreen(
                  shiftId: widget.shift.id,
                  autoSelectFormId: readinessFormId,
                ),
              ),
            );
            
            widget.onRefresh?.call();
          } catch (e) {
            debugPrint('Error loading form: $e');
            // Try to show error using root navigator
            try {
              final rootNavigator = Navigator.of(context, rootNavigator: true);
              if (rootNavigator.context.mounted) {
                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading form: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } catch (_) {
              // If we can't show snackbar, just log
              debugPrint('Could not show error snackbar');
            }
          }
        },
        icon: const Icon(Icons.assignment_outlined, size: 18),
        label: Text(
          'Fill Form',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff8B5CF6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.shift.status) {
      case ShiftStatus.scheduled:
        return const Color(0xff0386FF);
      case ShiftStatus.active:
        return const Color(0xff10B981);
      case ShiftStatus.partiallyCompleted:
        return const Color(0xffF97316);
      case ShiftStatus.fullyCompleted:
        return const Color(0xff6366F1);
      case ShiftStatus.completed:
        return const Color(0xff6B7280);
      case ShiftStatus.missed:
        return const Color(0xffEF4444);
      case ShiftStatus.cancelled:
        return const Color(0xffF59E0B);
    }
  }

  IconData _getStatusIcon() {
    switch (widget.shift.status) {
      case ShiftStatus.scheduled:
        return Icons.schedule;
      case ShiftStatus.active:
        return Icons.play_circle_fill;
      case ShiftStatus.partiallyCompleted:
        return Icons.timelapse;
      case ShiftStatus.fullyCompleted:
        return Icons.check_circle;
      case ShiftStatus.completed:
        return Icons.check_circle;
      case ShiftStatus.missed:
        return Icons.cancel;
      case ShiftStatus.cancelled:
        return Icons.block;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} at ${_formatTime(dateTime)}';
  }

  String _getRecurrenceText() {
    switch (widget.shift.recurrence) {
      case RecurrencePattern.none:
        return 'No Recurrence';
      case RecurrencePattern.daily:
        return 'Daily';
      case RecurrencePattern.weekly:
        return 'Weekly';
      case RecurrencePattern.monthly:
        return 'Monthly';
    }
  }
}
