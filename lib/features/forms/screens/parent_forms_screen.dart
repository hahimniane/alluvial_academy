import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/form_template.dart';
import 'teacher_forms_screen.dart';

class ParentFormsScreen extends StatelessWidget {
  const ParentFormsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();

    return TeacherFormsScreen(
      parentOnly: true,
      parentExcuseTemplate: FormTemplate(
        id: 'parent_student_excuse',
        name: l10n.parentExcuseFormTitle,
        description: l10n.parentExcuseFormDescription,
        frequency: FormFrequency.onDemand,
        category: FormCategory.administrative,
        version: 1,
        allowedRoles: const ['parent'],
        fields: [
          FormFieldDefinition(
            id: 'student_name',
            label: l10n.parentExcuseStudentName,
            type: 'text',
            required: true,
            order: 1,
          ),
          FormFieldDefinition(
            id: 'class_or_teacher',
            label: l10n.parentExcuseClassOrTeacher,
            type: 'text',
            order: 2,
          ),
          FormFieldDefinition(
            id: 'absence_date',
            label: l10n.parentExcuseAbsenceDate,
            type: 'date',
            required: true,
            order: 3,
          ),
          FormFieldDefinition(
            id: 'reason',
            label: l10n.parentExcuseReason,
            type: 'dropdown',
            required: true,
            order: 4,
            options: [
              l10n.parentExcuseReasonIllness,
              l10n.parentExcuseReasonAppointment,
              l10n.parentExcuseReasonFamilyEmergency,
              l10n.parentExcuseReasonTechnicalIssue,
              l10n.other,
            ],
          ),
          FormFieldDefinition(
            id: 'details',
            label: l10n.parentExcuseDetails,
            type: 'long_text',
            required: true,
            order: 5,
          ),
          FormFieldDefinition(
            id: 'preferred_contact',
            label: l10n.parentExcusePreferredContact,
            type: 'dropdown',
            order: 6,
            options: [
              l10n.parentExcuseContactInApp,
              l10n.parentExcuseContactEmail,
              l10n.parentExcuseContactPhone,
            ],
          ),
        ],
        autoFillRules: const [],
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
