import 'package:flutter/material.dart';
import 'package:realtimekit_ui/realtimekit_ui.dart';

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
  late final RealtimeKitUI _meetingUi;

  @override
  void initState() {
    super.initState();
    final meetingInfo = RtkMeetingInfo(authToken: widget.authToken);
    final uiKitInfo = RealtimeKitUIInfo(meetingInfo);
    _meetingUi = RealtimeKitUIBuilder.build(
      uiKitInfo: uiKitInfo,
    );
  }

  @override
  void dispose() {
    RealtimeKitUIBuilder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _meetingUi;
  }
}
