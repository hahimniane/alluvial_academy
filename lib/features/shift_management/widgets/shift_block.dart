import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/constants/shift_colors.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Color-coded shift block component for grid view
/// Shows hover actions: edit (pencil), details (3 dots), and add (plus)
class ShiftBlock extends StatefulWidget {
  final TeachingShift shift;
  final VoidCallback onTap;
  final VoidCallback? onViewDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onAddShift;
  final String? teacherEmail; // For pre-selecting teacher when adding shift
  final bool compact;
  final bool isPastDate; // Whether this shift is in the past
  final bool isSelected; // Whether this shift is selected for batch operations
  final Function(bool)? onSelectionChanged; // Callback for selection changes
  final bool isSelectionMode; // Whether selection mode is active
  final bool showMultipleShiftsIndicator; // Show indicator for multiple shifts
  final int? shiftIndex; // Index of this shift (for multiple shifts)
  final int? totalShifts; // Total number of shifts (for multiple shifts)

  const ShiftBlock({
    super.key,
    required this.shift,
    required this.onTap,
    this.onViewDetails,
    this.onEdit,
    this.onAddShift,
    this.teacherEmail,
    this.compact = false,
    this.isPastDate = false,
    this.isSelected = false,
    this.onSelectionChanged,
    this.isSelectionMode = false,
    this.showMultipleShiftsIndicator = false,
    this.shiftIndex,
    this.totalShifts,
  });

  @override
  State<ShiftBlock> createState() => _ShiftBlockState();
}

class _ShiftBlockState extends State<ShiftBlock> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final blockColor = _getShiftColor();
    final pastDateColor = _getPastDateColor();
    
    // Calculate tighter padding for compact mode
    final verticalPadding = widget.compact ? 1.0 : 2.0; 
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: _buildTooltip(),
        waitDuration: const Duration(milliseconds: 500),
        child: Stack(
          children: [
            // Main shift block
            InkWell(
              onTap: widget.isSelectionMode && widget.onSelectionChanged != null
                  ? () => widget.onSelectionChanged!(!widget.isSelected)
                  : widget.onTap,
              borderRadius: BorderRadius.circular(6), // Rounded rectangles
              child: Container(
                margin: const EdgeInsets.all(1),
                padding: EdgeInsets.only(
                  left: widget.isSelectionMode ? 4 : 4, // Reduced padding
                  right: 4, 
                  top: verticalPadding, // Use tighter padding
                  bottom: verticalPadding,
                ),
                constraints: const BoxConstraints(
                  minHeight: 18, // Minimum height for compact shifts
                  maxHeight: double.infinity,
                ),
                decoration: BoxDecoration(
                  color: widget.isPastDate 
                      ? pastDateColor.withOpacity(0.2)
                      : blockColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6), // Rounded rectangles
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xff0386FF)
                        : widget.isPastDate
                            ? pastDateColor.withOpacity(0.4)
                            : blockColor.withOpacity(0.3),
                    width: widget.isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox for selection mode
                    if (widget.isSelectionMode && widget.onSelectionChanged != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4, top: 1),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: Checkbox(
                            value: widget.isSelected,
                            onChanged: (value) => widget.onSelectionChanged!(value ?? false),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    // Shift content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, // Important!
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ROW 1: Time + Indicator (Save vertical space!)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Time
                              Flexible(
                                child: Text(
                                  '${_formatTimeShort(widget.shift.shiftStart)}-${_formatTimeShort(widget.shift.shiftEnd)}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: widget.isPastDate ? pastDateColor : blockColor,
                                    fontSize: 9, // Slightly larger font
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Indicator (moved here from its own line)
                              if (widget.showMultipleShiftsIndicator && widget.shiftIndex != null && widget.totalShifts != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      '${widget.shiftIndex}/${widget.totalShifts}',
                                      style: GoogleFonts.inter(
                                        fontSize: 7, 
                                        fontWeight: FontWeight.w700, 
                                        color: const Color(0xff6B7280)
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          
                          // ROW 2: Subject (Now has room to breathe)
                          Text(
                            _getDisplayName(),
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: widget.isPastDate 
                                  ? const Color(0xff6B7280)
                                  : const Color(0xff374151),
                              fontWeight: FontWeight.w500,
                              height: 1.2, 
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Students count - only if not compact
                          if (!widget.compact && widget.shift.category == ShiftCategory.teaching && widget.shift.studentNames.isNotEmpty)
                            Text(
                              '${widget.shift.studentNames.length} student${widget.shift.studentNames.length == 1 ? '' : 's'}',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                color: const Color(0xff9CA3AF),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Hover actions overlay (only for future dates and not in selection mode)
            if (_isHovered && !widget.isPastDate && !widget.isSelectionMode)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Edit Icon: Allow editing even if it's part of multiple shifts
                      if (widget.onEdit != null) // REMOVED: && !widget.showMultipleShiftsIndicator
                        Tooltip(
                          message: AppLocalizations.of(context)!.shiftEditShift,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onEdit,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                bottomLeft: Radius.circular(6),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF3F4F6),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Color(0xff374151),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 2. Divider: Fix the condition here too so the line appears
                      if (widget.onEdit != null && widget.onViewDetails != null) // REMOVED: && !widget.showMultipleShiftsIndicator
                        Container(
                          width: 1,
                          height: 20,
                          color: const Color(0xffE2E8F0),
                        ),
                      // 3 dots menu (view details) - always show
                      if (widget.onViewDetails != null)
                        Tooltip(
                          message: widget.showMultipleShiftsIndicator ? 'See all details' : 'View details',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onViewDetails,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF3F4F6),
                                  borderRadius: widget.onEdit == null
                                      ? const BorderRadius.only(
                                          topLeft: Radius.circular(6),
                                          bottomLeft: Radius.circular(6),
                                        )
                                      : BorderRadius.zero,
                                ),
                                child: const Icon(
                                  Icons.more_vert,
                                  size: 14,
                                  color: Color(0xff374151),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Divider
                      if (widget.onViewDetails != null && widget.onAddShift != null)
                        Container(
                          width: 1,
                          height: 20,
                          color: const Color(0xffE2E8F0),
                        ),
                      // Plus icon (add another shift for same teacher)
                      if (widget.onAddShift != null)
                        Tooltip(
                          message: AppLocalizations.of(context)!.addAnotherShift,
                          child: Material(
                            color: const Color(0xff0386FF),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(6),
                              bottomRight: Radius.circular(6),
                            ),
                            child: InkWell(
                              onTap: widget.onAddShift,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(6),
                                bottomRight: Radius.circular(6),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildTooltip() {
    final timeRange = '${_formatTime(widget.shift.shiftStart)} - ${_formatTime(widget.shift.shiftEnd)}';
    final subject = _getDisplayName();
    final students = widget.shift.studentNames.isNotEmpty 
        ? widget.shift.studentNames.join(', ')
        : 'No students';
    final teacher = widget.shift.teacherName;
    return '$timeRange\n$subject\n$teacher\n$students';
  }

  Color _getShiftColor() {
    if (widget.shift.category == ShiftCategory.teaching) {
      return ShiftColors.getSubjectColor(widget.shift.subjectId ?? widget.shift.subject.name);
    } else {
      return ShiftColors.getCategoryColor(widget.shift.category);
    }
  }

  Color _getPastDateColor() {
    switch (widget.shift.status) {
      case ShiftStatus.missed:
        return const Color(0xFFEF4444); // Red
      case ShiftStatus.completed:
      case ShiftStatus.fullyCompleted:
        return const Color(0xFF10B981); // Green
      case ShiftStatus.partiallyCompleted:
        return const Color(0xFFF59E0B); // Yellow/Orange
      case ShiftStatus.scheduled:
      case ShiftStatus.active:
        return const Color(0xFF0386FF); // Blue
      case ShiftStatus.cancelled:
        return const Color(0xFF9CA3AF); // Gray
    }
  }

  String _getDisplayName() {
    if (widget.shift.category == ShiftCategory.teaching) {
      if (widget.shift.subjectDisplayName != null && widget.shift.subjectDisplayName!.isNotEmpty) {
        return widget.shift.subjectDisplayName!;
      }
      return _getSubjectDisplayName(widget.shift.subject);
    } else {
      return _formatLeaderRole(widget.shift.leaderRole ?? 'Leader Duty');
    }
  }

  String _getSubjectDisplayName(IslamicSubject subject) {
    switch (subject) {
      case IslamicSubject.quranStudies:
        return 'Quran Studies';
      case IslamicSubject.hadithStudies:
        return 'Hadith Studies';
      case IslamicSubject.fiqh:
        return 'Fiqh';
      case IslamicSubject.arabicLanguage:
        return 'Arabic';
      case IslamicSubject.islamicHistory:
        return 'History';
      case IslamicSubject.aqeedah:
        return 'Aqeedah';
      case IslamicSubject.tafseer:
        return 'Tafseer';
      case IslamicSubject.seerah:
        return 'Seerah';
      case IslamicSubject.other:
        return 'Other Subject';
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mma').format(dateTime).toLowerCase();
  }

  String _formatTimeShort(DateTime dateTime) {
    return DateFormat('h:mm').format(dateTime);
  }

  String _formatLeaderRole(String role) {
    final roleMap = {
      'admin': 'Administration',
      'coordination': 'Coordination',
      'meeting': 'Meeting',
      'training': 'Staff Training',
      'planning': 'Curriculum Planning',
      'outreach': 'Community Outreach',
    };
    return roleMap[role] ?? role;
  }
}
