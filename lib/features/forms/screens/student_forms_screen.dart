import 'package:flutter/material.dart';

import 'teacher_forms_screen.dart';

/// The forms the school shares with students, which a student fills in and
/// sends from here.
class StudentFormsScreen extends StatelessWidget {
  const StudentFormsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeacherFormsScreen(studentOnly: true);
  }
}
