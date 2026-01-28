import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/join_link_service.dart';
import '../../../core/services/livekit_service.dart';
import '../../../screens/landing_page.dart';
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
    final shiftId = _shiftId;
    if (shiftId == null || shiftId.isEmpty) {
      setState(() {
        _joining = false;
        _error = 'Invalid or expired class link.';
      });
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

    final joinResult = await LiveKitService.getGuestJoinToken(shiftId);
    if (!mounted) return;

    if (!joinResult.success ||
        joinResult.token == null ||
        joinResult.livekitUrl == null ||
        joinResult.roomName == null) {
      setState(() {
        _joining = false;
        _error = joinResult.error ?? 'Unable to join this class right now.';
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LiveKitCallScreen(
          livekitUrl: joinResult.livekitUrl!,
          token: joinResult.token!,
          roomName: joinResult.roomName!,
          displayName: joinResult.displayName ?? 'Guest',
          isTeacher: false,
          shiftId: shiftId,
          shiftName: joinResult.shiftName ?? 'Class',
          initialRoomLocked: joinResult.roomLocked,
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
                  Text(AppLocalizations.of(context)!.joiningClass, style: titleStyle),
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
                  Text(AppLocalizations.of(context)!.unableToJoin, style: titleStyle),
                  const SizedBox(height: 8),
                  Text(
                    _error ?? 'Something went wrong.',
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
