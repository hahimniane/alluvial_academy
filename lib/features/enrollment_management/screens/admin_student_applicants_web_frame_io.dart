import 'package:flutter/material.dart';

/// Native builds never reach this widget — the dashboard shows the Flutter
/// [EnrollmentManagementScreen] off the web. It exists only to satisfy the
/// conditional import.
class AdminStudentApplicantsWebFrame extends StatelessWidget {
  const AdminStudentApplicantsWebFrame({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
