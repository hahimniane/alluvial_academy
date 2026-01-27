import 'package:flutter/material.dart';
import '../../../core/models/landing_page_content.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CoursesSectionEditor extends StatelessWidget {
  final List<CourseContent> courses;
  final Function(List<CourseContent>) onChanged;

  const CoursesSectionEditor({
    super.key,
    required this.courses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text(AppLocalizations.of(context)!.coursesEditor));
  }
} 