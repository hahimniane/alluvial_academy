import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/constants/shift_colors.dart';

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

  const ShiftBlock({
    super.key,
    required this.shift,
    required this.onTap,
    this.onViewDetails,
    this.onEdit,
    this.onAddShift,
    this.teacherEmail,
    this.compact = false,
  });

  @override
  State<ShiftBlock> createState() => _ShiftBlockState();
}

class _ShiftBlockState extends State<ShiftBlock> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final blockColor = _getShiftColor();
    
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
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                margin: const EdgeInsets.all(1),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: blockColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: blockColor.withOpacity(0.3), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time - always show
                    Text(
                      '${_formatTimeShort(widget.shift.shiftStart)} - ${_formatTimeShort(widget.shift.shiftEnd)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: blockColor,
                        fontSize: widget.compact ? 9 : 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Subject - show if space
                    Text(
                      _getDisplayName(),
                      style: GoogleFonts.inter(
                        fontSize: widget.compact ? 8 : 9,
                        color: const Color(0xff374151),
                        fontWeight: FontWeight.w500,
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
            ),
            // Hover actions overlay
            if (_isHovered)
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
                      // Edit icon (pencil)
                      if (widget.onEdit != null)
                        Tooltip(
                          message: 'Edit shift',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onEdit,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                bottomLeft: Radius.circular(6),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF3F4F6),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Color(0xff374151),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Divider
                      if (widget.onEdit != null && widget.onViewDetails != null)
                        Container(
                          width: 1,
                          height: 24,
                          color: const Color(0xffE2E8F0),
                        ),
                      // 3 dots menu (view details)
                      if (widget.onViewDetails != null)
                        Tooltip(
                          message: 'View details',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onViewDetails,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xffF3F4F6),
                                ),
                                child: const Icon(
                                  Icons.more_vert,
                                  size: 16,
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
                          height: 24,
                          color: const Color(0xffE2E8F0),
                        ),
                      // Plus icon (add another shift for same teacher)
                      if (widget.onAddShift != null)
                        Tooltip(
                          message: 'Add another shift',
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
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.add,
                                  size: 16,
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
