// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alluwalacademyadmin/core/services/join_link_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ZoomMeetingScreen extends StatefulWidget {
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
  bool _launched = false;
  bool _returnScheduled = false;
  String? _meetingPageUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_launched) return;
    _launched = true;
    final l10n = AppLocalizations.of(context)!;
    final params = <String, String>{
      'sdkKey': widget.sdkKey,
      'signature': widget.signature,
      'meetingNumber': widget.meetingNumber,
      'password': widget.password,
      'displayName': widget.displayName,
      'customerKey': widget.customerKey,
      'returnUrl': JoinLinkService.removeJoinParameters(Uri.base).toString(),
      'embedded': '0',
      'connectingText': l10n.connectingToClass,
      'loadErrorText': l10n.zoomUnableToLoadMeeting,
      'joinErrorText': l10n.zoomUnableToJoinMeeting,
      'initErrorText': l10n.zoomUnableToInitialize,
      'leftText': l10n.leaveClass,
      'leaveMeetingText': l10n.leaveMeeting,
      'routingStillConnectingText': l10n.zoomStillConnectingToClass,
      'routingHelpText': l10n.zoomClassRoutingHelp,
      if (widget.classEndsAt != null)
        'classEndsAt': widget.classEndsAt!.toUtc().toIso8601String(),
      // {minutes} placeholder is substituted by the meeting page as it counts down.
      'classEndingSoonText': l10n.zoomClassEndingSoon('{minutes}'),
      'classEndedText': l10n.zoomClassEnded,
      if ((widget.breakoutRoomName ?? '').trim().isNotEmpty)
        'breakoutRoomName': widget.breakoutRoomName!.trim(),
      if ((widget.breakoutRoomKey ?? '').trim().isNotEmpty)
        'breakoutRoomKey': widget.breakoutRoomKey!.trim(),
      if (widget.autoJoinBreakoutRoom) 'autoJoinBreakoutRoom': '1',
    };
    final hash = params.entries
        .map((entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    final cacheBust = DateTime.now().microsecondsSinceEpoch.toString();
    _meetingPageUrl = 'zoom_meeting.html?join=$cacheBust#$hash';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _meetingPageUrl == null) return;
      if (widget.preferDesktopZoomApp) {
        _openDesktopZoomApp();
        return;
      }
      _openZoomClassroom();
    });
  }

  void _leaveClass() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _openNativeZoom() async {
    final raw = widget.joinUrl?.trim();
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
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

  void _openDesktopZoomApp() {
    final uri = _desktopZoomUri();
    if (uri == null) {
      _openZoomClassroom();
      return;
    }
    html.window.location.assign(uri.toString());
    _returnToAppAfterDesktopLaunch();
  }

  void _returnToAppAfterDesktopLaunch() {
    if (_returnScheduled) return;
    _returnScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  void _openZoomClassroom() {
    final url = _meetingPageUrl;
    if (url == null || url.isEmpty) return;
    html.window.location.assign(url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.shiftName),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          if ((widget.joinUrl ?? '').trim().isNotEmpty &&
              !widget.autoJoinBreakoutRoom)
            IconButton(
              onPressed: _openNativeZoom,
              icon: const Icon(Icons.open_in_new),
              tooltip: l10n.zoomOpenInZoomApp,
            ),
          IconButton(
            onPressed: _leaveClass,
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: l10n.navDashboard,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _leaveClass,
              icon: const Icon(Icons.logout, size: 18),
              label: Text(l10n.leaveClass),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  l10n.connectingToClass,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.shiftName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: widget.preferDesktopZoomApp
                      ? _openDesktopZoomApp
                      : _openZoomClassroom,
                  icon: Icon(
                    widget.preferDesktopZoomApp
                        ? Icons.open_in_new
                        : Icons.video_camera_front_outlined,
                  ),
                  label: Text(
                    widget.preferDesktopZoomApp
                        ? l10n.zoomOpenInZoomApp
                        : l10n.joinClass,
                  ),
                ),
                if (widget.preferDesktopZoomApp) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openZoomClassroom,
                    icon: const Icon(Icons.video_camera_front_outlined),
                    label: Text(l10n.joinClass),
                  ),
                ],
                if ((widget.joinUrl ?? '').trim().isNotEmpty &&
                    !widget.autoJoinBreakoutRoom &&
                    !widget.preferDesktopZoomApp) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openNativeZoom,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.zoomOpenInZoomApp),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
