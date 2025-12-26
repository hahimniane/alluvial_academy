import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/enums/shift_enums.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/zoom_service.dart';

/// Admin-specific Zoom screen that shows ALL Zoom meetings across all shifts.
/// Groups shifts by Hub Meeting and shows breakout room assignments.
/// Allows admins to monitor and join any meeting regardless of time window.
class AdminZoomScreen extends StatefulWidget {
  const AdminZoomScreen({super.key});

  @override
  State<AdminZoomScreen> createState() => _AdminZoomScreenState();
}

class _AdminZoomScreenState extends State<AdminZoomScreen> {
  static const Duration _historyLookback = Duration(hours: 24);
  static const Duration _futureLookahead = Duration(days: 7);

  @override
  Widget build(BuildContext context) {
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
      body: StreamBuilder<List<TeachingShift>>(
        stream: ShiftService.getAllShifts(),
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

          // Filter to include shifts with Zoom meetings OR scheduled shifts pending Zoom creation
          final relevantShifts = allShifts
              .where(
                  (s) => s.hasZoomMeeting || s.status == ShiftStatus.scheduled)
              .where((s) => s.shiftEnd.toUtc().isAfter(fromUtc))
              .where((s) => s.shiftStart.toUtc().isBefore(toUtc))
              .toList();

          if (relevantShifts.isEmpty) {
            return const _NoZoomMeetingsState();
          }

          // Group shifts by Hub Meeting ID
          final hubGroups = <String, List<TeachingShift>>{};
          final standaloneShifts = <TeachingShift>[];
          final pendingShifts = <TeachingShift>[];

          for (final shift in relevantShifts) {
            if (shift.hubMeetingId != null && shift.hubMeetingId!.isNotEmpty) {
              hubGroups.putIfAbsent(shift.hubMeetingId!, () => []).add(shift);
            } else if (shift.hasZoomMeeting) {
              // Standalone meeting (has zoomMeetingId but no hubMeetingId)
              standaloneShifts.add(shift);
            } else {
              // Scheduled but no Zoom meeting assigned
              pendingShifts.add(shift);
            }
          }

          // Categorize hub meetings by status
          final activeHubs = <String, List<TeachingShift>>{};
          final upcomingHubs = <String, List<TeachingShift>>{};
          final completedHubs = <String, List<TeachingShift>>{};

          for (final entry in hubGroups.entries) {
            final shifts = entry.value;
            shifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

            final earliestStart = shifts.first.shiftStart.toUtc();
            final latestEnd = shifts
                .map((s) => s.shiftEnd.toUtc())
                .reduce((a, b) => a.isAfter(b) ? a : b);

            final activeWindowStart =
                earliestStart.subtract(const Duration(minutes: 10));
            final activeWindowEnd = latestEnd.add(const Duration(minutes: 10));

            if (nowUtc.isAfter(activeWindowStart) &&
                nowUtc.isBefore(activeWindowEnd)) {
              activeHubs[entry.key] = shifts;
            } else if (nowUtc.isBefore(earliestStart)) {
              upcomingHubs[entry.key] = shifts;
            } else {
              completedHubs[entry.key] = shifts;
            }
          }

          // Categorize standalone shifts by status
          final activeStandalone = <TeachingShift>[];
          final upcomingStandalone = <TeachingShift>[];
          final completedStandalone = <TeachingShift>[];

          for (final shift in standaloneShifts) {
            final shiftStartUtc = shift.shiftStart.toUtc();
            final shiftEndUtc = shift.shiftEnd.toUtc();

            final activeWindowStart =
                shiftStartUtc.subtract(const Duration(minutes: 10));
            final activeWindowEnd =
                shiftEndUtc.add(const Duration(minutes: 10));

            if (nowUtc.isAfter(activeWindowStart) &&
                nowUtc.isBefore(activeWindowEnd)) {
              activeStandalone.add(shift);
            } else if (nowUtc.isBefore(shiftStartUtc)) {
              upcomingStandalone.add(shift);
            } else {
              completedStandalone.add(shift);
            }
          }

          // Pending shifts are always upcoming or late, so just sort them
          pendingShifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

          // Sort standalone shifts
          activeStandalone.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
          upcomingStandalone
              .sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
          completedStandalone.sort((a, b) => b.shiftEnd.compareTo(a.shiftEnd));

          // Count totals
          int activeCount = activeHubs.length + activeStandalone.length;
          int upcomingCount = upcomingHubs.length +
              upcomingStandalone.length +
              pendingShifts.length;
          int totalMeetings = relevantShifts.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(
                activeCount: activeCount,
                upcomingCount: upcomingCount,
                totalMeetings: totalMeetings,
                hubCount: hubGroups.length,
              ),
              const SizedBox(height: 20),

              // Pending / Issues Section
              if (pendingShifts.isNotEmpty) ...[
                _buildSectionHeader(
                  'Action Required',
                  Icons.warning_amber_rounded,
                  const Color(0xFFF59E0B),
                  pendingShifts.length,
                ),
                const SizedBox(height: 12),
                ...pendingShifts.map((shift) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StandaloneMeetingCard(
                        shift: shift,
                        status: _MeetingStatus.pending,
                      ),
                    )),
                const SizedBox(height: 24),
              ],

              // Pending / Issues Section
              if (pendingShifts.isNotEmpty) ...[
                _buildSectionHeader(
                  'Action Required',
                  Icons.warning_amber_rounded,
                  const Color(0xFFF59E0B),
                  pendingShifts.length,
                ),
                const SizedBox(height: 12),
                ...pendingShifts.map((shift) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StandaloneMeetingCard(
                        shift: shift,
                        status: _MeetingStatus.pending,
                      ),
                    )),
                const SizedBox(height: 24),
              ],

              // Active Now Section (Hubs + Standalone)
              if (activeHubs.isNotEmpty || activeStandalone.isNotEmpty) ...[
                _buildSectionHeader(
                  'Active Now',
                  Icons.play_circle_fill,
                  const Color(0xFF10B981),
                  activeHubs.length + activeStandalone.length,
                ),
                const SizedBox(height: 12),
                // Active Hub Meetings
                ...activeHubs.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _HubMeetingCard(
                        hubMeetingId: entry.key,
                        shifts: entry.value,
                        status: _MeetingStatus.active,
                      ),
                    )),
                // Active Standalone Meetings
                ...activeStandalone.map((shift) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StandaloneMeetingCard(
                        shift: shift,
                        status: _MeetingStatus.active,
                      ),
                    )),
                const SizedBox(height: 8),
              ],

              // Upcoming Section (Hubs + Standalone)
              if (upcomingHubs.isNotEmpty || upcomingStandalone.isNotEmpty) ...[
                _buildSectionHeader(
                  'Upcoming',
                  Icons.schedule,
                  const Color(0xFF0E72ED),
                  upcomingHubs.length + upcomingStandalone.length,
                ),
                const SizedBox(height: 12),
                // Upcoming Hub Meetings
                ...upcomingHubs.entries.take(5).map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _HubMeetingCard(
                        hubMeetingId: entry.key,
                        shifts: entry.value,
                        status: _MeetingStatus.upcoming,
                      ),
                    )),
                // Upcoming Standalone Meetings
                ...upcomingStandalone.take(10).map((shift) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StandaloneMeetingCard(
                        shift: shift,
                        status: _MeetingStatus.upcoming,
                      ),
                    )),
                if (upcomingHubs.length > 5 || upcomingStandalone.length > 10)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '+${(upcomingHubs.length > 5 ? upcomingHubs.length - 5 : 0) + (upcomingStandalone.length > 10 ? upcomingStandalone.length - 10 : 0)} more upcoming',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 8),
              ],

              // Completed Section (Hubs + Standalone)
              if (completedHubs.isNotEmpty ||
                  completedStandalone.isNotEmpty) ...[
                _buildSectionHeader(
                  'Recently Completed',
                  Icons.check_circle,
                  const Color(0xFF6B7280),
                  completedHubs.length + completedStandalone.length,
                ),
                const SizedBox(height: 12),
                // Completed Hub Meetings
                ...completedHubs.entries.take(3).map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _HubMeetingCard(
                        hubMeetingId: entry.key,
                        shifts: entry.value,
                        status: _MeetingStatus.completed,
                      ),
                    )),
                // Completed Standalone Meetings
                ...completedStandalone.take(5).map((shift) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StandaloneMeetingCard(
                        shift: shift,
                        status: _MeetingStatus.completed,
                      ),
                    )),
              ],

              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard({
    required int activeCount,
    required int upcomingCount,
    required int totalMeetings,
    required int hubCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E72ED), Color(0xFF2D8CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E72ED).withAlpha(51),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.videocam,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zoom Meetings',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalMeetings classes${hubCount > 0 ? ' • $hubCount hub${hubCount != 1 ? 's' : ''}' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatBadge('Active', activeCount, const Color(0xFF10B981)),
              const SizedBox(height: 6),
              _buildStatBadge(
                  'Upcoming', upcomingCount, Colors.white.withAlpha(77)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha(230),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    int count,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count Hub${count != 1 ? 's' : ''}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

enum _MeetingStatus {
  active,
  upcoming,
  completed,
  pending,
}

/// A card representing a Hub Meeting with all its breakout rooms
class _HubMeetingCard extends StatefulWidget {
  final String hubMeetingId;
  final List<TeachingShift> shifts;
  final _MeetingStatus status;

  const _HubMeetingCard({
    required this.hubMeetingId,
    required this.shifts,
    required this.status,
  });

  @override
  State<_HubMeetingCard> createState() => _HubMeetingCardState();
}

class _HubMeetingCardState extends State<_HubMeetingCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (widget.status) {
      _MeetingStatus.active => const Color(0xFF10B981),
      _MeetingStatus.upcoming => const Color(0xFF0E72ED),
      _MeetingStatus.completed => const Color(0xFF6B7280),
      _MeetingStatus.pending => const Color(0xFFF59E0B),
    };

    final statusLabel = switch (widget.status) {
      _MeetingStatus.active => 'LIVE',
      _MeetingStatus.upcoming => 'UPCOMING',
      _MeetingStatus.completed => 'ENDED',
      _MeetingStatus.pending => 'PENDING',
    };

    // Get time range from shifts
    final earliestStart = widget.shifts.first.shiftStart;
    final latestEnd = widget.shifts
        .map((s) => s.shiftEnd)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final timeText = _formatTimeRange(context, earliestStart, latestEnd);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: widget.status == _MeetingStatus.active
              ? statusColor.withAlpha(77)
              : const Color(0xFFE2E8F0),
          width: widget.status == _MeetingStatus.active ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hub Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Status badge & expand icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.status == _MeetingStatus.active)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              statusLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeText,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFF64748B),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Hub Meeting info
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E72ED).withAlpha(26),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.meeting_room,
                          color: Color(0xFF0E72ED),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hub Meeting',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.shifts.length} Breakout Room${widget.shifts.length != 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Join Hub Button
                      if (widget.status != _MeetingStatus.completed)
                        SizedBox(
                          height: 34,
                          child: ElevatedButton.icon(
                            onPressed: () => ZoomService.joinClassAdmin(
                                context, widget.shifts.first),
                            icon: const Icon(Icons.videocam, size: 16),
                            label: Text(
                              widget.status == _MeetingStatus.active
                                  ? 'Join Hub'
                                  : 'Join',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  widget.status == _MeetingStatus.active
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF0E72ED),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Breakout Rooms List (expandable)
          if (_isExpanded) ...[
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: const Color(0xFFF8FAFC),
                    child: Row(
                      children: [
                        const Icon(Icons.grid_view,
                            size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'Breakout Rooms',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Breakout room list
                  ...widget.shifts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final shift = entry.value;
                    final isLast = index == widget.shifts.length - 1;
                    return _BreakoutRoomRow(
                      shift: shift,
                      isLast: isLast,
                      hubStatus: widget.status,
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimeRange(BuildContext context, DateTime start, DateTime end) {
    final now = DateTime.now();
    final startTime = TimeOfDay.fromDateTime(start).format(context);
    final endTime = TimeOfDay.fromDateTime(end).format(context);

    final isToday = start.day == now.day &&
        start.month == now.month &&
        start.year == now.year;

    final isTomorrow = start.day == now.day + 1 &&
        start.month == now.month &&
        start.year == now.year;

    if (isToday) {
      return 'Today $startTime - $endTime';
    } else if (isTomorrow) {
      return 'Tomorrow $startTime - $endTime';
    } else {
      final localizations = MaterialLocalizations.of(context);
      final dateStr = localizations.formatShortDate(start);
      return '$dateStr $startTime - $endTime';
    }
  }
}

/// A single breakout room row within a Hub Meeting card
class _BreakoutRoomRow extends StatelessWidget {
  final TeachingShift shift;
  final bool isLast;
  final _MeetingStatus hubStatus;

  const _BreakoutRoomRow({
    required this.shift,
    required this.isLast,
    required this.hubStatus,
  });

  @override
  Widget build(BuildContext context) {
    final studentCount = shift.studentNames.length;
    final startTime = TimeOfDay.fromDateTime(shift.shiftStart).format(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // Room icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withAlpha(26),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.videocam_outlined,
              color: Color(0xFF8B5CF6),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),

          // Room info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.teacherName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$studentCount ${studentCount == 1 ? 'student' : 'students'} • ${shift.effectiveSubjectDisplayName}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              startTime,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Join this room button (smaller)
          if (hubStatus != _MeetingStatus.completed)
            SizedBox(
              height: 28,
              child: TextButton(
                onPressed: () => ZoomService.joinClassAdmin(context, shift),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: const Color(0xFF0E72ED),
                ),
                child: Text(
                  'Join',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A card for a standalone meeting (not part of a hub)
class _StandaloneMeetingCard extends StatelessWidget {
  final TeachingShift shift;
  final _MeetingStatus status;

  const _StandaloneMeetingCard({
    required this.shift,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      _MeetingStatus.active => const Color(0xFF10B981),
      _MeetingStatus.upcoming => const Color(0xFF0E72ED),
      _MeetingStatus.completed => const Color(0xFF6B7280),
      _MeetingStatus.pending => const Color(0xFFF59E0B),
    };

    final statusLabel = switch (status) {
      _MeetingStatus.active => 'ACTIVE',
      _MeetingStatus.upcoming => 'SCHEDULED',
      _MeetingStatus.completed => 'COMPLETED',
      _MeetingStatus.pending => 'PENDING CREATION',
    };

    final timeText = _formatTimeText(context);
    final studentCount = shift.studentNames.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: status == _MeetingStatus.active
              ? statusColor.withAlpha(77)
              : const Color(0xFFE2E8F0),
          width: status == _MeetingStatus.active ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == _MeetingStatus.active)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                timeText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Teacher Name
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E72ED).withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF0E72ED),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.teacherName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shift.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bottom Row: Students & Join Button
          Row(
            children: [
              // Student count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.groups,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$studentCount ${studentCount == 1 ? 'Student' : 'Students'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // Subject badge
              if (shift.effectiveSubjectDisplayName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    shift.effectiveSubjectDisplayName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const Spacer(),

              // Join Button
              if (status == _MeetingStatus.pending)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Zoom creation awaiting scheduler. Check back later.',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Pending',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => ZoomService.joinClassAdmin(context, shift),
                    icon: const Icon(Icons.videocam, size: 16),
                    label: Text(
                      status == _MeetingStatus.active ? 'Join Now' : 'Join',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == _MeetingStatus.active
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0E72ED),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeText(BuildContext context) {
    final now = DateTime.now();
    final shiftStart = shift.shiftStart;
    final shiftEnd = shift.shiftEnd;

    final localizations = MaterialLocalizations.of(context);
    final startTime = TimeOfDay.fromDateTime(shiftStart).format(context);
    final endTime = TimeOfDay.fromDateTime(shiftEnd).format(context);

    final isToday = shiftStart.day == now.day &&
        shiftStart.month == now.month &&
        shiftStart.year == now.year;

    final isTomorrow = shiftStart.day == now.day + 1 &&
        shiftStart.month == now.month &&
        shiftStart.year == now.year;

    if (isToday) {
      return 'Today $startTime - $endTime';
    } else if (isTomorrow) {
      return 'Tomorrow $startTime - $endTime';
    } else {
      final dateStr = localizations.formatShortDate(shiftStart);
      return '$dateStr $startTime - $endTime';
    }
  }
}

class _NoZoomMeetingsState extends StatelessWidget {
  const _NoZoomMeetingsState();

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
              'No Zoom meetings scheduled',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'When shifts have Zoom meetings scheduled, they will appear here.',
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
