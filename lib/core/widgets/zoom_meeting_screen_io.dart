import 'package:flutter/material.dart';
import 'package:flutter_zoom_meeting_wrapper/flutter_zoom_meeting_wrapper.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Native (Android/iOS) Zoom Meeting SDK classroom.
///
/// Initializes the SDK with the Meeting SDK signature (which embeds the SDK
/// key) produced by the `getZoomJoinInfo` backend, then joins the meeting.
/// The native SDK renders its own full-screen meeting UI once joined; this
/// screen only shows connecting/error state around that.
class ZoomMeetingScreen extends StatefulWidget {
  final String sdkKey;
  final String signature;
  final String meetingNumber;
  final String password;
  final String displayName;
  final String shiftName;
  final String customerKey;
  final String? joinUrl;
  final String? breakoutRoomName;
  final String? breakoutRoomKey;
  final bool autoJoinBreakoutRoom;

  const ZoomMeetingScreen({
    super.key,
    required this.sdkKey,
    required this.signature,
    required this.meetingNumber,
    required this.password,
    required this.displayName,
    required this.shiftName,
    required this.customerKey,
    this.joinUrl,
    this.breakoutRoomName,
    this.breakoutRoomKey,
    this.autoJoinBreakoutRoom = false,
  });

  @override
  State<ZoomMeetingScreen> createState() => _ZoomMeetingScreenState();
}

class _ZoomMeetingScreenState extends State<ZoomMeetingScreen> {
  bool _joining = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  Future<void> _join() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final initialized = await ZoomMeetingWrapper.initZoom(widget.signature);
      if (!mounted) return;
      if (!initialized) {
        setState(() {
          _joining = false;
          _error = l10n.zoomUnableToInitialize;
        });
        return;
      }

      final joined = await ZoomMeetingWrapper.joinMeeting(
        meetingId: widget.meetingNumber,
        meetingPassword: widget.password,
        displayName: widget.displayName,
      );
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = joined ? null : l10n.zoomUnableToJoinMeeting;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = l10n.zoomUnableToJoinMeeting;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.shiftName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _joining
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    l10n.connectingToClass,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              )
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}
