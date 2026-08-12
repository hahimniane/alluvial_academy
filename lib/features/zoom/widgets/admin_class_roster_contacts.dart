import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/features/zoom/services/class_roster_contact_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class AdminClassRosterContacts extends StatelessWidget {
  final Future<List<ClassStudentContact>> contacts;

  const AdminClassRosterContacts({
    super.key,
    required this.contacts,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ClassStudentContact>>(
      future: contacts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
          return Text(
            AppLocalizations.of(context)!.classRosterContactsUnavailable,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFFB45309),
            ),
          );
        }

        final students = snapshot.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < students.length; index++) ...[
                if (index > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 5),
                    child: Divider(height: 1),
                  ),
                _buildStudent(context, students[index]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudent(
    BuildContext context,
    ClassStudentContact student,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final studentName = student.name.trim().isNotEmpty
        ? student.name
        : l10n.commonUnknownStudent;
    final studentId = student.studentId.trim().isNotEmpty
        ? student.studentId
        : l10n.commonNotAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          studentName,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.classRosterStudentId(studentId),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF475569),
          ),
        ),
        if (student.parents.isEmpty && student.parentLookupFailed)
          Text(
            l10n.classRosterContactsUnavailable,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: const Color(0xFFB45309),
            ),
          )
        else if (student.parents.isEmpty)
          Text(
            l10n.classRosterNoParentLinked,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: const Color(0xFFB45309),
            ),
          )
        else
          for (final parent in student.parents)
            Wrap(
              spacing: 8,
              runSpacing: 1,
              children: [
                Text(
                  l10n.classRosterParentName(parent.name),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF475569),
                  ),
                ),
                Text(
                  parent.phone == null || parent.phone!.trim().isEmpty
                      ? l10n.classRosterNoPhoneNumber
                      : l10n.classRosterPhone(parent.phone!),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: parent.phone == null || parent.phone!.trim().isEmpty
                        ? const Color(0xFFB45309)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
        if (student.parents.isNotEmpty && student.parentLookupFailed)
          Text(
            l10n.classRosterContactsUnavailable,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: const Color(0xFFB45309),
            ),
          ),
      ],
    );
  }
}
