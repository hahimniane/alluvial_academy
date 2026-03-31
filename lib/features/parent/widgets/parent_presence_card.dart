import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/features/shift_management/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/features/livekit/services/livekit_service.dart';
import 'package:alluwalacademyadmin/features/livekit/services/video_call_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// A presence-aware class card for parents.
/// Shows who is currently in the class and how long they've been there —
/// identical to the admin AdminClassesScreen card.
class ParentPresenceCard extends StatefulWidget {
  final TeachingShift shift;
  final VoidCallback? onJoin;

  const ParentPresenceCard({
    super.key,
    required this.shift,
    this.onJoin,
  });

  @override
  State<ParentPresenceCard> createState() => _ParentPresenceCardState();
}

class _ParentPresenceCardState extends State<ParentPresenceCard> {
  LiveKitRoomPresenceResult? _presence;
  bool _fetchingPresence = false;
  Timer? _presenceTimer;

  bool get _isActive =>
      widget.shift.status == ShiftStatus.active || widget.shift.isClockedIn;

  @override
  void initState() {
    super.initState();
    if (_isActive) {
      _fetchPresence();
      _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted && _isActive) _fetchPresence();
      });
    }
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPresence() async {
    if (_fetchingPresence) return;
    _fetchingPresence = true;
    try {
      final result = await LiveKitService.getRoomPresence(widget.shift.id);
      if (mounted) setState(() => _presence = result);
    } catch (e) {
      AppLogger.error('ParentPresenceCard: presence error for ${widget.shift.id}: $e');
    } finally {
      _fetchingPresence = false;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isActive = _isActive;
    final canJoin = widget.onJoin != null &&
        (isActive || VideoCallService.canJoinClass(widget.shift));

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (widget.shift.status) {
      case ShiftStatus.active:
        statusColor = const Color(0xFF10B981);
        statusText = 'In Progress';
        statusIcon = Icons.play_circle;
      case ShiftStatus.completed:
      case ShiftStatus.partiallyCompleted:
      case ShiftStatus.fullyCompleted:
        statusColor = const Color(0xFF6B7280);
        statusText = 'Completed';
        statusIcon = Icons.check_circle;
      case ShiftStatus.cancelled:
        statusColor = const Color(0xFFEF4444);
        statusText = 'Cancelled';
        statusIcon = Icons.cancel;
      case ShiftStatus.missed:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Missed';
        statusIcon = Icons.warning;
      case ShiftStatus.scheduled:
        if (widget.shift.isClockedIn) {
          statusColor = const Color(0xFF10B981);
          statusText = 'In Progress';
          statusIcon = Icons.play_circle;
        } else if (widget.shift.shiftStart.isBefore(now)) {
          statusColor = const Color(0xFFF59E0B);
          statusText = 'Missed';
          statusIcon = Icons.warning;
        } else {
          statusColor = const Color(0xFF3B82F6);
          statusText = 'Scheduled';
          statusIcon = Icons.schedule;
        }
    }

    final participantCount = _presence?.participantCount ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? statusColor.withOpacity(0.5) : Colors.grey[200]!,
          width: isActive ? 2 : 1,
        ),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canJoin ? widget.onJoin : null,
        onLongPress: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status badge + participant count + start time ──────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive && participantCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$participantCount in class',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    DateFormat('h:mm a').format(widget.shift.shiftStart),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Subject ────────────────────────────────────────────────
              Text(
                widget.shift.subjectDisplayName ?? widget.shift.subject.toString(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),

              // ── Teacher ────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Teacher: ${widget.shift.teacherName.isNotEmpty ? widget.shift.teacherName : 'Unknown'}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Date ───────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(widget.shift.shiftStart),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              // ── Live participants panel (identical to admin) ────────────
              if (isActive) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.liveParticipants,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const Spacer(),
                          if (_presence != null)
                            Text(
                              '${_presence!.participantCount} in class',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981),
                              ),
                            )
                          else
                            const SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF10B981),
                              ),
                            ),
                        ],
                      ),
                      if (_presence != null && _presence!.participants.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ..._presence!.participants.map((p) {
                          final duration = p.joinedAt != null
                              ? _formatDuration(DateTime.now().difference(p.joinedAt!))
                              : '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: p.isPublisher
                                        ? const Color(0xFF10B981).withOpacity(0.2)
                                        : Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    p.isPublisher ? Icons.mic : Icons.mic_off,
                                    size: 14,
                                    color: p.isPublisher
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name.isNotEmpty ? p.name : p.identity,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      if (p.role != null && p.role!.isNotEmpty)
                                        Text(
                                          p.role!,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (duration.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      duration,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ] else if (_presence != null && _presence!.participants.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.noOneHasJoinedYet,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context)!.tapAndHoldForMoreDetails,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],

              // ── Join button ────────────────────────────────────────────
              if (canJoin) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onJoin,
                    icon: const Icon(Icons.video_call, size: 20),
                    label: Text(
                      isActive ? 'Join Now' : 'Join Class',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Detail bottom sheet ───────────────────────────────────────────────────

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PresenceDetailSheet(
        shift: widget.shift,
        presence: _presence,
        onJoin: widget.onJoin != null &&
                (_isActive || VideoCallService.canJoinClass(widget.shift))
            ? () {
                Navigator.pop(context);
                widget.onJoin!();
              }
            : null,
      ),
    );
  }

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'Just joined';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail bottom sheet — identical to AdminClassesScreen._ClassDetailsSheet
// ─────────────────────────────────────────────────────────────────────────────

class _PresenceDetailSheet extends StatelessWidget {
  final TeachingShift shift;
  final LiveKitRoomPresenceResult? presence;
  final VoidCallback? onJoin;

  const _PresenceDetailSheet({
    required this.shift,
    required this.presence,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = shift.status == ShiftStatus.active || shift.isClockedIn;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shift.subjectDisplayName ?? shift.subject.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context)!.live,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy • h:mm a')
                        .format(shift.shiftStart),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Teacher
                  _section('Teacher', Icons.person, [
                    _row('Name',
                        shift.teacherName.isNotEmpty
                            ? shift.teacherName
                            : 'Unknown'),
                    if (shift.clockInTime != null)
                      _row('Clocked in',
                          DateFormat('h:mm a').format(shift.clockInTime!)),
                    if (shift.clockInTime != null && isActive)
                      _row('Time in class',
                          _fmt(DateTime.now().difference(shift.clockInTime!))),
                  ]),

                  const SizedBox(height: 20),

                  // Assigned students
                  _section(
                    'Assigned Students (${shift.studentIds.length})',
                    Icons.people,
                    shift.studentNames.isEmpty
                        ? [_row('Students', '${shift.studentIds.length} assigned')]
                        : shift.studentNames.map((n) => _row('', n)).toList(),
                  ),

                  // Currently in class (LiveKit)
                  if (presence != null && presence!.participants.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _section(
                      'Currently in Class (${presence!.participantCount})',
                      Icons.videocam,
                      presence!.participants.map((p) {
                        final joined = p.joinedAt != null
                            ? 'Joined ${DateFormat('h:mm a').format(p.joinedAt!)} · ${_fmt(DateTime.now().difference(p.joinedAt!))}'
                            : AppLocalizations.of(context)!.commonUnknown;
                        return _participantRow(
                          p.name.isNotEmpty ? p.name : p.identity,
                          p.role ?? 'Participant',
                          joined,
                          p.isPublisher,
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Class info
                  _section('Class Information', Icons.info_outline, [
                    _row('Duration',
                        '${shift.shiftDurationHours.toStringAsFixed(1)} hours'),
                    _row('Subject', shift.effectiveSubjectDisplayName),
                    _row('Status', shift.status.name.toUpperCase()),
                    if (shift.notes != null && shift.notes!.isNotEmpty)
                      _row('Notes', shift.notes!),
                  ]),

                  const SizedBox(height: 30),

                  if (onJoin != null)
                    ElevatedButton.icon(
                      onPressed: onJoin,
                      icon: const Icon(Icons.video_call, size: 22),
                      label: Text(
                        isActive ? 'Join Class Now' : 'Join Class',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0E72ED)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF64748B)),
              ),
            ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _participantRow(
      String name, String role, String duration, bool isPublisher) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isPublisher
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFF64748B).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPublisher ? Icons.mic : Icons.mic_off,
              size: 16,
              color: isPublisher
                  ? const Color(0xFF10B981)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  role,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              duration,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'Just joined';
  }
}
