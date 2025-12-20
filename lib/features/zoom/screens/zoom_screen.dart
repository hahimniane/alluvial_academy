import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/zoom_service.dart';

class ZoomScreen extends StatefulWidget {
  const ZoomScreen({super.key});

  @override
  State<ZoomScreen> createState() => _ZoomScreenState();
}

class _ZoomScreenState extends State<ZoomScreen> {
  static const Duration _historyLookback = Duration(hours: 24);
  static const Duration _futureLookahead = Duration(days: 30);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          'Zoom Meetings',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff6B7280)),
      ),
      body: user == null
          ? _UnauthenticatedState()
          : StreamBuilder<List<TeachingShift>>(
              stream: ShiftService.getTeacherShifts(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorState(message: '${snapshot.error}');
                }

                final allShifts = snapshot.data ?? const <TeachingShift>[];
                final nowUtc = DateTime.now().toUtc();
                final fromUtc = nowUtc.subtract(_historyLookback);
                final toUtc = nowUtc.add(_futureLookahead);

                final zoomShifts = allShifts
                    .where((s) => s.hasZoomMeeting)
                    .where((s) => s.shiftEnd.toUtc().isAfter(fromUtc))
                    .where((s) => s.shiftStart.toUtc().isBefore(toUtc))
                    .toList()
                  ..sort((a, b) {
                    final aCanJoin = ZoomService.canJoinClass(a);
                    final bCanJoin = ZoomService.canJoinClass(b);

                    // Priority 1: Currently joinable shifts at the top
                    if (aCanJoin && !bCanJoin) return -1;
                    if (!aCanJoin && bCanJoin) return 1;

                    final now = DateTime.now().toUtc();
                    final aHasEnded = a.shiftEnd
                        .toUtc()
                        .add(const Duration(minutes: 10))
                        .isBefore(now);
                    final bHasEnded = b.shiftEnd
                        .toUtc()
                        .add(const Duration(minutes: 10))
                        .isBefore(now);

                    // Priority 2: Not ended vs Ended (Past shifts at the bottom)
                    if (aHasEnded && !bHasEnded) return 1;
                    if (!aHasEnded && bHasEnded) return -1;

                    // Same category sorting:
                    if (aHasEnded) {
                      // Both past: most recent first
                      return b.shiftStart.compareTo(a.shiftStart);
                    }
                    // Both upcoming/active: soonest first
                    return a.shiftStart.compareTo(b.shiftStart);
                  });

                if (zoomShifts.isEmpty) {
                  return const _NoZoomShiftsState();
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeaderCard(),
                    const SizedBox(height: 12),
                    ...zoomShifts.map(
                      (shift) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ZoomShiftCard(shift: shift),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                );
              },
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0E72ED).withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.videocam,
              color: Color(0xFF0E72ED),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your shift meetings',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Join your Zoom meetings directly in the app. Each shift has its own Join button that becomes active 10 minutes before the shift starts.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomShiftCard extends StatelessWidget {
  final TeachingShift shift;

  const _ZoomShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final canJoin = ZoomService.canJoinClass(shift);
    final timeUntil = ZoomService.getTimeUntilCanJoin(shift);

    final localizations = MaterialLocalizations.of(context);
    final startDateText = localizations.formatShortDate(shift.shiftStart);
    final startTimeText =
        TimeOfDay.fromDateTime(shift.shiftStart).format(context);
    final endTimeText = TimeOfDay.fromDateTime(shift.shiftEnd).format(context);

    final buttonLabel = canJoin
        ? 'Join'
        : timeUntil != null
            ? 'Join (${_formatTimeUntil(timeUntil)})'
            : 'Ended';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  (canJoin ? const Color(0xFF10B981) : const Color(0xFF94A3B8))
                      .withAlpha(31),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              canJoin ? Icons.play_arrow_rounded : Icons.schedule,
              color:
                  canJoin ? const Color(0xFF10B981) : const Color(0xFF64748B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$startDateText • $startTimeText – $endTimeText',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed:
                  canJoin ? () => ZoomService.joinClass(context, shift) : null,
              icon: const Icon(Icons.videocam, size: 18),
              label: Text(
                buttonLabel,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canJoin ? const Color(0xFF0E72ED) : const Color(0xFF94A3B8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeUntil(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }
}

class _NoZoomShiftsState extends StatelessWidget {
  const _NoZoomShiftsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF0E72ED).withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off,
                size: 44,
                color: Color(0xFF0E72ED),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Zoom meetings right now',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'When you have a shift with a Zoom meeting scheduled, it will appear here with a Join button (inactive until the meeting window opens).',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnauthenticatedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Please sign in to view your Zoom meetings.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Unable to load Zoom meetings.\n$message',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
