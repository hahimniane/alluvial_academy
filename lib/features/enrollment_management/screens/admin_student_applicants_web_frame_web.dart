// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Embeds the Next.js student applicants screen
/// (`/admin/student-applicants/?embed=1`) inside the Flutter web app's content
/// area, so admins keep their own Flutter sidebar and top bar. Same origin, so
/// the signed-in Firebase session carries over.
class AdminStudentApplicantsWebFrame extends StatefulWidget {
  const AdminStudentApplicantsWebFrame({super.key});

  @override
  State<AdminStudentApplicantsWebFrame> createState() =>
      _AdminStudentApplicantsWebFrameState();
}

class _AdminStudentApplicantsWebFrameState
    extends State<AdminStudentApplicantsWebFrame> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'admin-student-applicants-frame-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return html.IFrameElement()
        ..src = '/admin/student-applicants/?embed=1'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
