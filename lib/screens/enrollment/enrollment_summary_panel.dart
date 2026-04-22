import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'enrollment_flow_models.dart';

/// Collapsible summary of per-child program + hours + estimate (mobile-friendly).
class EnrollmentSummaryPanel extends StatelessWidget {
  const EnrollmentSummaryPanel({
    super.key,
    required this.title,
    required this.lines,
    required this.expanded,
    required this.onExpandedChanged,
    required this.showCollapseToggle,
  });

  final String title;
  final List<EnrollmentSummaryLine> lines;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final bool showCollapseToggle;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          Text(
            lines[i].title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xff0F172A),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            lines[i].detail,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xff64748B),
              height: 1.25,
            ),
          ),
        ],
      ],
    );

    return Material(
      elevation: 4,
      shadowColor: const Color(0xff0F172A).withValues(alpha: 0.08),
      color: const Color(0xffF8FAFC),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
        ),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: showCollapseToggle
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => onExpandedChanged(!expanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xff4338CA),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          Icon(
                            expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: const Color(0xff4338CA),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (expanded) content,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff4338CA),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  content,
                ],
              ),
      ),
    );
  }
}
