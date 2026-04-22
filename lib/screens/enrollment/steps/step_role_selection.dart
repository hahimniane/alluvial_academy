import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

import '../widgets/role_card.dart';

/// Step 0: role cards and optional sibling count for parent/guardian.
class EnrollmentStepRoleView extends StatelessWidget {
  const EnrollmentStepRoleView({
    super.key,
    required this.selectedRole,
    required this.onSelectRole,
    required this.extraStudentCount,
    required this.onAddStudent,
    this.onRemoveLastStudent,
  });

  final String? selectedRole;
  final ValueChanged<String> onSelectRole;
  final int extraStudentCount;
  final VoidCallback onAddStudent;
  final VoidCallback? onRemoveLastStudent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final showCount = selectedRole == 'Parent' || selectedRole == 'Guardian';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EnrollmentRoleCard(
          title: l.enrollmentRoleStudentTitle,
          subtitle: l.enrollmentRoleStudentSubtitle,
          icon: Icons.school_outlined,
          selected: selectedRole == 'Student',
          onTap: () => onSelectRole('Student'),
        ),
        EnrollmentRoleCard(
          title: l.enrollmentRoleParentTitle,
          subtitle: l.enrollmentRoleParentSubtitle,
          icon: Icons.family_restroom_outlined,
          selected: selectedRole == 'Parent',
          onTap: () => onSelectRole('Parent'),
        ),
        EnrollmentRoleCard(
          title: l.enrollmentRoleGuardianTitle,
          subtitle: l.enrollmentRoleGuardianSubtitle,
          icon: Icons.supervisor_account_outlined,
          selected: selectedRole == 'Guardian',
          onTap: () => onSelectRole('Guardian'),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: showCount
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xffF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.enrollmentStepChildren,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xff0F172A),
                                ),
                              ),
                              Text(
                                l.youCanAddMultipleStudentsIn,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: const Color(0xff64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          visualDensity: VisualDensity.compact,
                          onPressed: (extraStudentCount <= 0 ||
                                  onRemoveLastStudent == null)
                              ? null
                              : onRemoveLastStudent,
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              size: 22),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '${1 + extraStudentCount}',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xff0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          visualDensity: VisualDensity.compact,
                          onPressed: onAddStudent,
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              size: 22),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
