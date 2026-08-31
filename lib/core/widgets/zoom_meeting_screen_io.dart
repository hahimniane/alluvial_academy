import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_zoom_meeting_wrapper/flutter_zoom_meeting_wrapper.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alluwalacademyadmin/core/services/class_video_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Native (Android/iOS) Zoom Meeting SDK classroom.
///
/// Initializes the SDK with the Meeting SDK signature (which embeds the SDK
/// key) produced by the `getZoomJoinInfo` backend, then joins the meeting.
/// The native SDK renders its own full-screen meeting UI once joined; this
/// screen only shows connecting/error state around that.
class ZoomMeetingScreen extends StatefulWidget {
  final String shiftId;
  final String sdkKey;
  final String signature;
  final String meetingNumber;
  final String password;
  final String displayName;
  final String? nativeDisplayName;
  final String? routingDisplayName;
  final String shiftName;
  final String customerKey;
  final String? joinUrl;
  final String? breakoutRoomName;
  final String? breakoutRoomKey;
  final bool autoJoinBreakoutRoom;
  final DateTime? classEndsAt;
  final bool preferDesktopZoomApp;

  const ZoomMeetingScreen({
    super.key,
    this.shiftId = '',
    required this.sdkKey,
    required this.signature,
    required this.meetingNumber,
    required this.password,
    required this.displayName,
    this.nativeDisplayName,
    this.routingDisplayName,
    required this.shiftName,
    required this.customerKey,
    this.joinUrl,
    this.breakoutRoomName,
    this.breakoutRoomKey,
    this.autoJoinBreakoutRoom = false,
    this.classEndsAt,
    this.preferDesktopZoomApp = false,
  });

  @override
  State<ZoomMeetingScreen> createState() => _ZoomMeetingScreenState();
}

class _ZoomMeetingScreenState extends State<ZoomMeetingScreen> {
  bool _joining = true;
  String? _error;

  // Attendance: the join is recorded server-side by getZoomJoinInfo; these
  // heartbeats extend the presence window while the student is in the meeting,
  // and the leave (on meeting end / screen close) closes it at the exact time.
  static const Duration _heartbeatInterval = Duration(seconds: 45);
  Timer? _heartbeatTimer;
  bool _leaveRecorded = false;

  bool get _usesNativeMeetingSdk =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_usesNativeMeetingSdk) {
      // When the native meeting ends (user taps Leave), return to the app instead
      // of leaving the user on this now-empty meeting screen.
      ZoomMeetingWrapper.onMeetingEnded = _handleMeetingEnded;
      WidgetsBinding.instance.addPostFrameCallback((_) => _joinNativeMeeting());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDesktopZoom());
  }

  void _startPresenceHeartbeat() {
    if (widget.shiftId.trim().isEmpty || _heartbeatTimer != null) return;
    ClassVideoService.recordClassPresence(widget.shiftId, 'heartbeat');
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => ClassVideoService.recordClassPresence(widget.shiftId, 'heartbeat'),
    );
  }

  void _recordLeave() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_leaveRecorded || widget.shiftId.trim().isEmpty) return;
    _leaveRecorded = true;
    ClassVideoService.recordClassPresence(widget.shiftId, 'leave');
  }

  void _handleMeetingEnded() {
    _recordLeave();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void dispose() {
    _recordLeave();
    if (_usesNativeMeetingSdk &&
        ZoomMeetingWrapper.onMeetingEnded == _handleMeetingEnded) {
      ZoomMeetingWrapper.onMeetingEnded = null;
    }
    super.dispose();
  }

  String get _desktopZoomDisplayName {
    final routingName = (widget.routingDisplayName ?? '').trim();
    if (routingName.isNotEmpty) return routingName;
    final nativeName = (widget.nativeDisplayName ?? '').trim();
    if (nativeName.isNotEmpty) return nativeName;
    return widget.displayName.trim().isNotEmpty
        ? widget.displayName.trim()
        : 'Participant';
  }

  Uri? _desktopZoomUri() {
    final meetingNumber = widget.meetingNumber.replaceAll(RegExp(r'\D'), '');
    if (meetingNumber.isEmpty) return null;
    return Uri(
      scheme: 'zoommtg',
      host: 'zoom.us',
      path: '/join',
      queryParameters: {
        'action': 'join',
        'confno': meetingNumber,
        if (widget.password.trim().isNotEmpty) 'pwd': widget.password.trim(),
        'uname': _desktopZoomDisplayName,
      },
    );
  }

  Future<bool> _launchExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openDesktopZoom() async {
    final l10n = AppLocalizations.of(context)!;
    if (mounted) {
      setState(() {
        _joining = true;
        _error = null;
      });
    }

    var launched = false;
    final desktopUri = _desktopZoomUri();
    if (desktopUri != null) {
      launched = await _launchExternal(desktopUri);
    }
    if (!launched) {
      final rawJoinUrl = widget.joinUrl?.trim();
      final joinUri = rawJoinUrl == null || rawJoinUrl.isEmpty
          ? null
          : Uri.tryParse(rawJoinUrl);
      if (joinUri != null) launched = await _launchExternal(joinUri);
    }

    if (!mounted) return;
    setState(() {
      _joining = false;
      _error = launched ? null : l10n.zoomUnableToJoinMeeting;
    });
  }

  Future<void> _joinNativeMeeting() async {
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

      final nativeJoinName = (widget.nativeDisplayName ?? '').trim().isNotEmpty
          ? widget.nativeDisplayName!.trim()
          : widget.displayName;
      final joined = await ZoomMeetingWrapper.joinMeeting(
        meetingId: widget.meetingNumber,
        meetingPassword: widget.password,
        displayName: nativeJoinName,
        routingDisplayName: nativeJoinName,
        customerKey: widget.customerKey,
        breakoutRoomName: widget.breakoutRoomName,
        breakoutRoomKey: widget.breakoutRoomKey,
        autoJoinBreakoutRoom: widget.autoJoinBreakoutRoom,
        classEndsAtIso: widget.classEndsAt?.toUtc().toIso8601String(),
      );
      if (joined) _startPresenceHeartbeat();
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
    final canOpenDesktopZoom = !_usesNativeMeetingSdk;
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
                        if (canOpenDesktopZoom) ...[
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _openDesktopZoom,
                            icon: const Icon(Icons.open_in_new),
                            label: Text(l10n.zoomOpenInZoomApp),
                          ),
                        ],
                      ],
                    ),
                  )
                : canOpenDesktopZoom
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.open_in_new,
                                color: Colors.white, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              widget.shiftName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _openDesktopZoom,
                              icon: const Icon(Icons.open_in_new),
                              label: Text(l10n.zoomOpenInZoomApp),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _handleMeetingEnded,
                              child: Text(l10n.leaveClass),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
      ),
    );
  }
}
