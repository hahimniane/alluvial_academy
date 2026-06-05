import 'dart:async';

import 'package:flutter/material.dart';
import 'package:realtimekit_ui/realtimekit_ui.dart';

import 'package:alluwalacademyadmin/core/services/class_video_service.dart';

class RealtimeKitMeetingScreen extends StatefulWidget {
  final String authToken;
  final String displayName;
  final String shiftName;
  final String shiftId;
  final String? meetingId;
  final String? participantId;
  final String? userRole;

  const RealtimeKitMeetingScreen({
    super.key,
    required this.authToken,
    required this.displayName,
    required this.shiftName,
    required this.shiftId,
    this.meetingId,
    this.participantId,
    this.userRole,
  });

  @override
  State<RealtimeKitMeetingScreen> createState() =>
      _RealtimeKitMeetingScreenState();
}

class _RealtimeKitMeetingScreenState extends State<RealtimeKitMeetingScreen> {
  late final RealtimeKitUI _meetingUi;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    final meetingInfo = RtkMeetingInfo(authToken: widget.authToken);
    final uiKitInfo = RealtimeKitUIInfo(meetingInfo);
    _meetingUi = RealtimeKitUIBuilder.build(
      uiKitInfo: uiKitInfo,
    );
    _markPresence('join');
    _presenceTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _markPresence('heartbeat');
    });
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _markPresence('leave');
    RealtimeKitUIBuilder.dispose();
    super.dispose();
  }

  void _markPresence(String event) {
    unawaited(ClassVideoPresenceService.markPresence(
      shiftId: widget.shiftId,
      event: event,
      meetingId: widget.meetingId,
      participantId: widget.participantId,
      displayName: widget.displayName,
      userRole: widget.userRole,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _meetingUi;
  }
}
