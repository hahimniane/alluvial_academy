import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alluwalacademyadmin/core/models/enrollment_request.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

Future<void> showEnrollmentApplicantDetailsDialog(
  BuildContext context,
  String enrollmentId,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Applicant Details'),
      content: SizedBox(
        width: MediaQuery.of(ctx).size.width > 900 ? 780 : 520,
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('enrollments')
              .doc(enrollmentId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              return const Text('Could not load applicant details.');
            }

            final data = snapshot.data!.data() ?? {};
            final contact = data['contact'] as Map<String, dynamic>? ?? {};
            final student = data['student'] as Map<String, dynamic>? ?? {};
            final preferences =
                data['preferences'] as Map<String, dynamic>? ?? {};
            final program = data['program'] as Map<String, dynamic>? ?? {};
            final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
            final country = contact['country'] as Map<String, dynamic>? ?? {};

            final prettyJson = const JsonEncoder.withIndent('  ')
                .convert(_normalizeEnrollmentForJson(data));

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  enrollmentDetailsSection('Student', [
                    enrollmentDetailRow(
                        'Name', student['name'] ?? data['studentName']),
                    enrollmentDetailRow('Age', student['age'] ?? data['studentAge']),
                    enrollmentDetailRow(
                        'Gender', student['gender'] ?? data['gender']),
                    enrollmentDetailRow('Grade Level', data['gradeLevel']),
                    enrollmentDetailRow('Adult Student', metadata['isAdult']),
                    enrollmentDetailRow(
                        'Knows Zoom', student['knowsZoom'] ?? data['knowsZoom']),
                  ]),
                  enrollmentDetailsSection('Contact', [
                    enrollmentDetailRow('Email', contact['email'] ?? data['email']),
                    enrollmentDetailRow(
                        'Phone', contact['phone'] ?? data['phoneNumber']),
                    enrollmentDetailRow('WhatsApp',
                        contact['whatsApp'] ?? data['whatsAppNumber']),
                    enrollmentDetailRow(
                        'Parent Name', contact['parentName'] ?? data['parentName']),
                    enrollmentDetailRow(
                        'Guardian ID', contact['guardianId'] ?? data['guardianId']),
                    enrollmentDetailRow('City', contact['city'] ?? data['city']),
                    enrollmentDetailRow(
                        'Country', country['name'] ?? data['countryName']),
                    enrollmentDetailRow(
                        'Country Code', country['code'] ?? data['countryCode']),
                  ]),
                  enrollmentDetailsSection('Program', [
                    enrollmentDetailRow(
                        'Program', data['programTitle'] ?? data['subject']),
                    if (data['programTitle'] != null)
                      enrollmentDetailRow('Subject (internal)', data['subject']),
                    enrollmentDetailRow(
                        'Specific Language', data['specificLanguage']),
                    enrollmentDetailRow('Role', program['role'] ?? data['role']),
                    enrollmentDetailRow(
                        'Class Type', program['classType'] ?? data['classType']),
                    enrollmentDetailRow('Session Duration',
                        program['sessionDuration'] ?? data['sessionDuration']),
                  ]),
                  enrollmentDetailsSection('Preferences', [
                    enrollmentDetailRow('Preferred Language',
                        preferences['preferredLanguage'] ??
                            data['preferredLanguage']),
                    enrollmentDetailRow(
                        'Time Zone', preferences['timeZone'] ?? data['timeZone']),
                    enrollmentDetailRow('Days', preferences['days']),
                    enrollmentDetailRow('Time Slots', preferences['timeSlots']),
                    enrollmentDetailRow('Time of Day',
                        preferences['timeOfDayPreference'] ??
                            data['timeOfDayPreference']),
                  ]),
                  enrollmentDetailsSection(
                      'Pricing', enrollmentPricingDetailRows(metadata)),
                  enrollmentDetailsSection('Metadata', [
                    enrollmentDetailRow('Status', metadata['status']),
                    enrollmentDetailRow('Submitted At', metadata['submittedAt']),
                    enrollmentDetailRow('Reviewed By', metadata['reviewedBy']),
                    enrollmentDetailRow('Reviewed At', metadata['reviewedAt']),
                    enrollmentDetailRow('Source', metadata['source']),
                  ]),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Raw Application Data',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff334155),
                        ),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xff0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            prettyJson,
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: const Color(0xffE2E8F0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(AppLocalizations.of(context)!.commonClose),
        ),
      ],
    ),
  );
}

List<Widget> enrollmentPricingDetailRows(Map<String, dynamic> metadata) {
  final snap = metadata['pricingSnapshot'];
  final rows = <Widget>[
    enrollmentDetailRow('Track ID', metadata['trackId']),
    enrollmentDetailRow('Plan ID', metadata['pricingPlanId']),
    enrollmentDetailRow('Plan label', metadata['pricingPlanLabel']),
  ];
  if (snap is Map) {
    final s = snap.map((k, v) => MapEntry(k.toString(), v));
    if (s['version'] == 2) {
      rows.addAll([
        enrollmentDetailRow('Snapshot version', s['version']),
        enrollmentDetailRow('Track ID', s['trackId']),
        enrollmentDetailRow('Hours per week', s['hoursPerWeek']),
        enrollmentDetailRow('Hourly rate (USD)', s['hourlyRateUsd']),
        enrollmentDetailRow('Discount applied', s['discountApplied']),
        enrollmentDetailRow('Est. monthly (USD)', s['monthlyEstimateUsd']),
      ]);
      return rows;
    }
    final unit = s['unitUsd'];
    final label = s['unitLabel']?.toString();
    String? rateLine;
    if (unit != null || (label != null && label.isNotEmpty)) {
      final uStr = unit?.toString() ?? '';
      rateLine = uStr.isEmpty
          ? label
          : '\$$uStr${label != null && label.isNotEmpty ? ' — $label' : ''}';
    }
    rows.addAll([
      enrollmentDetailRow('Sessions per week', s['sessionsPerWeek']),
      enrollmentDetailRow(
        'Session length',
        s['sessionMinutes'] != null ? '${s['sessionMinutes']} min' : null,
      ),
      enrollmentDetailRow('Weekly hours', s['weeklyHours']),
      enrollmentDetailRow('Rate', rateLine),
      enrollmentDetailRow('Est. weekly (USD)', s['weeklyUsd']),
      enrollmentDetailRow('Est. monthly (USD, ~4.33 wk)', s['monthlyEstimateUsd']),
      enrollmentDetailRow('Summary', s['summary']),
    ]);
  }
  return rows;
}

Widget enrollmentDetailsSection(String title, List<Widget> rows) {
  final visibleRows = rows.where((row) => row is! SizedBox).toList();
  if (visibleRows.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xff1E293B),
          ),
        ),
        const SizedBox(height: 8),
        ...visibleRows,
      ],
    ),
  );
}

Widget enrollmentDetailRow(String label, dynamic value) {
  final formattedValue = _formatEnrollmentDetailValue(value);
  if (formattedValue == null) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            '$label:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xff64748B),
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            formattedValue,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff0F172A),
            ),
          ),
        ),
      ],
    ),
  );
}

String? _formatEnrollmentDetailValue(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is Timestamp) {
    return DateFormat('MMM d, yyyy h:mm a').format(value.toDate());
  }
  if (value is List) {
    final parts = value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
  return value.toString();
}

dynamic _normalizeEnrollmentForJson(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) {
    return value.map(
        (key, val) => MapEntry(key.toString(), _normalizeEnrollmentForJson(val)));
  }
  if (value is List) return value.map(_normalizeEnrollmentForJson).toList();
  return value;
}

bool _enrollmentContactIsAdult(EnrollmentRequest enrollment) {
  return enrollment.isAdult ||
      (int.tryParse(enrollment.studentAge ?? '0') ?? 0) >= 18;
}

class EnrollmentApplicantActionButtons extends StatelessWidget {
  final EnrollmentRequest enrollment;

  const EnrollmentApplicantActionButtons({super.key, required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final isAdult = _enrollmentContactIsAdult(enrollment);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'View full applicant details',
          child: IconButton(
            onPressed: enrollment.id == null
                ? null
                : () => showEnrollmentApplicantDetailsDialog(
                      context,
                      enrollment.id!,
                    ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xffEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline,
                  size: 18, color: Color(0xff4F46E5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              builder: (ctx) => Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Contact ${isAdult ? "Student" : "Parent"}',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(enrollment.email),
                      onTap: () =>
                          launchUrl(Uri.parse('mailto:${enrollment.email}')),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: Text(enrollment.phoneNumber),
                      onTap: () =>
                          launchUrl(Uri.parse('tel:${enrollment.phoneNumber}')),
                    ),
                    if (enrollment.whatsAppNumber != null &&
                        enrollment.whatsAppNumber!.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.chat),
                        title: Text(AppLocalizations.of(context)!.whatsapp),
                        onTap: () => launchUrl(Uri.parse(
                            'https://wa.me/${enrollment.whatsAppNumber}')),
                      ),
                  ],
                ),
              ),
            );
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xffEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_outlined,
                size: 18, color: Color(0xff3B82F6)),
          ),
        ),
      ],
    );
  }
}
