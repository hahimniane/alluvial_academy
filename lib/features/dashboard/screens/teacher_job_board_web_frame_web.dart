// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Embeds the Next.js job board (`/teacher/job-board/?embed=1`) inside the
/// Flutter web app's content area, so teachers keep their own Flutter sidebar
/// and top bar while replying with ranked slots. Same origin, so the signed-in
/// Firebase session carries over.
class TeacherJobBoardWebFrame extends StatefulWidget {
  const TeacherJobBoardWebFrame({super.key});

  @override
  State<TeacherJobBoardWebFrame> createState() =>
      _TeacherJobBoardWebFrameState();
}

class _TeacherJobBoardWebFrameState extends State<TeacherJobBoardWebFrame> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'teacher-job-board-frame-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return html.IFrameElement()
        ..src = '/teacher/job-board/?embed=1'
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
