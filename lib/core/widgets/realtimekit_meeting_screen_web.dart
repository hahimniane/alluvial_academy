// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class RealtimeKitMeetingScreen extends StatefulWidget {
  final String authToken;
  final String displayName;
  final String shiftName;

  const RealtimeKitMeetingScreen({
    super.key,
    required this.authToken,
    required this.displayName,
    required this.shiftName,
  });

  @override
  State<RealtimeKitMeetingScreen> createState() =>
      _RealtimeKitMeetingScreenState();
}

class _RealtimeKitMeetingScreenState extends State<RealtimeKitMeetingScreen> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'realtimekit-meeting-${DateTime.now().microsecondsSinceEpoch}';
    // Load the meeting from a real same-origin page (not srcdoc) so RealtimeKit
    // plugins like the whiteboard, which resolve their iframe URL from
    // window.location, initialize correctly. The token rides in the URL hash so
    // it is never sent to a server.
    final token = Uri.encodeComponent(widget.authToken);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return html.IFrameElement()
        ..src = 'realtimekit_meeting.html#token=$token'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow =
            'camera; microphone; display-capture; fullscreen; autoplay; clipboard-write'
        ..allowFullscreen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.shiftName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: HtmlElementView(viewType: _viewType),
    );
  }
}
