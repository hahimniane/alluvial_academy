import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/services/class_video_service.dart';
import 'package:alluwalacademyadmin/core/services/join_link_service.dart';
import 'package:alluwalacademyadmin/core/widgets/realtimekit_meeting_screen.dart';
import '../../website/screens/landing_page.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class GuestJoinScreen extends StatefulWidget {
  const GuestJoinScreen({super.key});

  @override
  State<GuestJoinScreen> createState() => _GuestJoinScreenState();
}

class _GuestJoinScreenState extends State<GuestJoinScreen> {
  bool _joining = true;
  String? _error;
  String? _shiftId;

  @override
  void initState() {
    super.initState();
    _shiftId = JoinLinkService.consumePendingGuestShiftId();
    _startJoin();
  }

  Future<void> _startJoin() async {
    final l10n = AppLocalizations.of(context)!;
    final shiftId = _shiftId;
    if (shiftId == null || shiftId.isEmpty) {
      setState(() {
        _joining = false;
        _error = l10n.classVideoInvalidGuestLink;
      });
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      setState(() {
        _joining = false;
        _error = l10n.classVideoJoinUnavailable;
      });
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

    final joinResult = await ClassVideoService.getGuestJoinToken(
      shiftId,
      fallbackError: l10n.classVideoConnectFailed,
      unexpectedResponseError: l10n.classVideoJoinUnavailable,
    );
    if (!mounted) return;

    if (!joinResult.success || joinResult.authToken == null) {
      setState(() {
        _joining = false;
        _error = joinResult.error?.trim().isNotEmpty == true
            ? joinResult.error
            : l10n.classVideoJoinUnavailable;
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RealtimeKitMeetingScreen(
          authToken: joinResult.authToken!,
          displayName: joinResult.displayName ?? 'Guest',
          shiftName: joinResult.shiftName ?? 'Class',
          shiftId: shiftId,
          meetingId: joinResult.meetingId,
          participantId: joinResult.participantId,
          userRole: joinResult.userRole,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF0F172A),
    );
    final bodyStyle = GoogleFonts.inter(
      fontSize: 14,
      color: const Color(0xFF475569),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_joining) ...[
                  const CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(AppLocalizations.of(context)!.joiningClass,
                      style: titleStyle),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.pleaseWaitWhileWeConnectYou,
                    style: bodyStyle,
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.unableToJoin,
                      style: titleStyle),
                  const SizedBox(height: 8),
                  Text(
                    _error ??
                        AppLocalizations.of(context)!.errorSomethingWentWrong,
                    style: bodyStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _startJoin,
                        child: Text(AppLocalizations.of(context)!.tryAgain),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LandingPage(),
                            ),
                          );
                        },
                        child: Text(AppLocalizations.of(context)!.goToSite),
                      ),
                    ],
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
