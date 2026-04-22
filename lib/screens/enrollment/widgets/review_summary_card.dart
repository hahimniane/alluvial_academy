import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../enrollment_flow_models.dart';

/// Dark-themed sectioned review card for the final enrollment step.
/// Each section has an icon, title, key-value rows, and an Edit button.
class EnrollmentReviewSummaryCard extends StatelessWidget {
  const EnrollmentReviewSummaryCard({
    super.key,
    required this.sections,
    required this.onEditSection,
  });

  final List<EnrollmentReviewSection> sections;
  final void Function(int stepIndex) onEditSection;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      children: sections.map((section) => _buildSection(section)).toList(),
    );
  }

  Widget _buildSection(EnrollmentReviewSection section) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1E293B), Color(0xff0F172A)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xff334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(section.icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  section.sectionTitle.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff94A3B8),
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              Material(
                color: const Color(0xff334155),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => onEditSection(section.editStepIndex),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xffF59E0B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...section.rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.$1,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xff94A3B8),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
