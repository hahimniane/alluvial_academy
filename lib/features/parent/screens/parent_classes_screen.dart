import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/features/shift_management/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/features/parent/services/parent_service.dart';
import 'package:alluwalacademyadmin/features/shift_management/services/shift_service.dart';
import 'package:alluwalacademyadmin/features/livekit/services/video_call_service.dart';
import 'package:alluwalacademyadmin/features/livekit/services/livekit_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ParentClassesScreen extends StatefulWidget {
  const ParentClassesScreen({super.key});

  @override
  State<ParentClassesScreen> createState() => _ParentClassesScreenState();
}

class _ParentClassesScreenState extends State<ParentClassesScreen> {
  List<Map<String, dynamic>> _children = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final children = await ParentService.getParentChildren(uid);
      if (mounted) setState(() { _children = children; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Classes',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: _loadChildren,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadChildren,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _children.map((child) => _ChildClassesSection(
                      studentId: child['id'] as String,
                      studentName: child['name'] as String,
                    )).toList(),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_outlined, size: 56, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(
            'No children linked to your account',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-child section — mirrors AdminClassesScreen exactly
// ─────────────────────────────────────────────────────────────────────────────

class _ChildClassesSection extends StatefulWidget {
  final String studentId;
  final String studentName;

  const _ChildClassesSection({
    required this.studentId,
    required this.studentName,
  });

  @override
  State<_ChildClassesSection> createState() => _ChildClassesSectionState();
}

class _ChildClassesSectionState extends State<_ChildClassesSection> {
  bool _showUpcoming = true;
  final Map<String, LiveKitRoomPresenceResult> _presenceCache = {};
  // Track which shiftIds have a pending fetch so we don't flood the server
  final Set<String> _pendingFetches = {};
  Timer? _presenceTimer;
  Timer? _refreshTimer;

  List<TeachingShift> _shifts = [];
  bool _loadingShifts = true;
  StreamSubscription<List<TeachingShift>>? _shiftsSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToShifts();
    // Refresh UI every 30s (countdown timers, duration since joined)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    // Refresh LiveKit presence every 15s for active classes
    _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshActivePresence();
    });
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _refreshTimer?.cancel();
    _shiftsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToShifts() {
    _shiftsSubscription?.cancel();
    _shiftsSubscription = ShiftService.getStudentShifts(widget.studentId).listen(
      (shifts) {
        if (!mounted) return;
        setState(() {
          _shifts = shifts;
          _loadingShifts = false;
        });
        // Kick off presence fetch for any newly active classes
        for (final s in shifts) {
          final isActive = s.status == ShiftStatus.active || s.isClockedIn;
          if (isActive && !_presenceCache.containsKey(s.id)) {
            _fetchPresence(s.id);
          }
        }
      },
      onError: (_) {
        if (mounted) setState(() => _loadingShifts = false);
      },
    );
  }

  Future<void> _fetchPresence(String shiftId) async {
    if (_pendingFetches.contains(shiftId)) return;
    _pendingFetches.add(shiftId);
    try {
      final result = await LiveKitService.getRoomPresence(shiftId);
      if (mounted) setState(() => _presenceCache[shiftId] = result);
    } catch (e) {
      AppLogger.error('ParentClasses: presence fetch error for $shiftId: $e');
    } finally {
      _pendingFetches.remove(shiftId);
    }
  }

  void _refreshActivePresence() {
    for (final shift in _shifts) {
      final isActive = shift.status == ShiftStatus.active || shift.isClockedIn;
      if (isActive) _fetchPresence(shift.id);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<TeachingShift> upcoming = _shifts
        .where((s) => s.shiftEnd.isAfter(now))
        .toList()
      ..sort((a, b) {
        final aActive = a.status == ShiftStatus.active || a.isClockedIn;
        final bActive = b.status == ShiftStatus.active || b.isClockedIn;
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;
        final aCanJoin = VideoCallService.canJoinClass(a);
        final bCanJoin = VideoCallService.canJoinClass(b);
        if (aCanJoin && !bCanJoin) return -1;
        if (!aCanJoin && bCanJoin) return 1;
        return a.shiftStart.compareTo(b.shiftStart);
      });

    final List<TeachingShift> history = _shifts
        .where((s) => !s.shiftEnd.isAfter(now))
        .toList()
      ..sort((a, b) => b.shiftStart.compareTo(a.shiftStart));

    final displayList = _showUpcoming ? upcoming : history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Child header ──────────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, size: 18, color: Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.studentName,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            _buildToggle(),
          ],
        ),
        const SizedBox(height: 12),

        // ── List ─────────────────────────────────────────────────────────
        if (_loadingShifts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (displayList.isEmpty)
          _buildEmpty(_showUpcoming ? 'No upcoming classes' : 'No class history')
        else
          ...displayList.map((shift) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildClassCard(shift),
          )),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn('Upcoming', true),
          _toggleBtn('History', false),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool isUpcoming) {
    final isSelected = _showUpcoming == isUpcoming;
    return GestureDetector(
      onTap: () => setState(() => _showUpcoming = isUpcoming),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  // ── Class card — identical layout to AdminClassesScreen ─────────────────

  Widget _buildClassCard(TeachingShift shift) {
    final now = DateTime.now();
    final isActive = shift.status == ShiftStatus.active || shift.isClockedIn;
    final canJoin = isActive || VideoCallService.canJoinClass(shift);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (shift.status) {
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
        if (shift.isClockedIn) {
          statusColor = const Color(0xFF10B981);
          statusText = 'In Progress';
          statusIcon = Icons.play_circle;
        } else if (shift.shiftStart.isBefore(now)) {
          statusColor = const Color(0xFFF59E0B);
          statusText = 'Missed';
          statusIcon = Icons.warning;
        } else {
          statusColor = const Color(0xFF3B82F6);
          statusText = 'Scheduled';
          statusIcon = Icons.schedule;
        }
    }

    final presence = isActive ? _presenceCache[shift.id] : null;
    final participantCount = presence?.participantCount ?? 0;

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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canJoin ? () => _joinClass(shift) : null,
        onLongPress: () => _showClassDetails(shift),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status + participant count + time ───────────────────────
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
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
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
                    DateFormat('h:mm a').format(shift.shiftStart),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Class name ──────────────────────────────────────────────
              Text(
                shift.subjectDisplayName ?? shift.subject.toString(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),

              // ── Teacher ─────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Teacher: ${shift.teacherName.isNotEmpty ? shift.teacherName : 'Unknown'}',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Date ────────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(shift.shiftStart),
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                ],
              ),

              // ── Live participants panel ──────────────────────────────────
              if (isActive) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981), shape: BoxShape.circle,
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
                          if (presence != null)
                            Text(
                              '${presence.participantCount} in class',
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
                      if (presence != null && presence.participants.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...presence.participants.map((p) {
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
                      ] else if (presence != null && presence.participants.isEmpty) ...[
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

              // ── Join button ─────────────────────────────────────────────
              if (canJoin) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _joinClass(shift),
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _joinClass(TeachingShift shift) async {
    try {
      await VideoCallService.joinClass(context, shift, isTeacher: false);
    } catch (e) {
      AppLogger.error('ParentClasses: join error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showClassDetails(TeachingShift shift) async {
    final presence = await _fetchPresenceAndReturn(shift.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassDetailsSheet(
        shift: shift,
        presence: presence,
        onJoin: () {
          Navigator.pop(context);
          _joinClass(shift);
        },
      ),
    );
  }

  Future<LiveKitRoomPresenceResult?> _fetchPresenceAndReturn(String shiftId) async {
    try {
      final result = await LiveKitService.getRoomPresence(shiftId);
      if (mounted) setState(() => _presenceCache[shiftId] = result);
      return result;
    } catch (e) {
      AppLogger.error('ParentClasses: presence fetch error: $e');
      return null;
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'Just joined';
  }

  Widget _buildEmpty(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 10),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet — identical to AdminClassesScreen._ClassDetailsSheet
// ─────────────────────────────────────────────────────────────────────────────

class _ClassDetailsSheet extends StatelessWidget {
  final TeachingShift shift;
  final LiveKitRoomPresenceResult? presence;
  final VoidCallback onJoin;

  const _ClassDetailsSheet({
    required this.shift,
    required this.presence,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = shift.status == ShiftStatus.active || shift.isClockedIn;
    final canJoin = isActive || VideoCallService.canJoinClass(shift);

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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                  color: Color(0xFF10B981), shape: BoxShape.circle,
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
                    DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(shift.shiftStart),
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
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
                  // Teacher section
                  _buildSection('Teacher', Icons.person, [
                    _buildInfoRow('Name',
                        shift.teacherName.isNotEmpty ? shift.teacherName : 'Unknown'),
                    if (shift.clockInTime != null)
                      _buildInfoRow(
                        'Clocked in',
                        DateFormat('h:mm a').format(shift.clockInTime!),
                      ),
                    if (shift.clockInTime != null && isActive)
                      _buildInfoRow(
                        'Time in class',
                        _formatDuration(DateTime.now().difference(shift.clockInTime!)),
                      ),
                  ]),

                  const SizedBox(height: 20),

                  // Students section
                  _buildSection(
                    'Assigned Students (${shift.studentIds.length})',
                    Icons.people,
                    shift.studentNames.isEmpty
                        ? [_buildInfoRow('Students', '${shift.studentIds.length} assigned')]
                        : shift.studentNames.map((n) => _buildInfoRow('', n)).toList(),
                  ),

                  // Currently in class (LiveKit)
                  if (presence != null && presence!.participants.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      'Currently in Class (${presence!.participantCount})',
                      Icons.videocam,
                      presence!.participants.map((p) {
                        final duration = p.joinedAt != null
                            ? _formatDuration(DateTime.now().difference(p.joinedAt!))
                            : AppLocalizations.of(context)!.commonUnknown;
                        return _buildParticipantRow(
                          p.name.isNotEmpty ? p.name : p.identity,
                          p.role ?? 'Participant',
                          p.joinedAt != null
                              ? 'Joined ${DateFormat('h:mm a').format(p.joinedAt!)} · $duration'
                              : duration,
                          p.isPublisher,
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Class info
                  _buildSection('Class Information', Icons.info_outline, [
                    _buildInfoRow('Duration',
                        '${shift.shiftDurationHours.toStringAsFixed(1)} hours'),
                    _buildInfoRow('Subject', shift.effectiveSubjectDisplayName),
                    _buildInfoRow('Status', shift.status.name.toUpperCase()),
                    if (shift.notes != null && shift.notes!.isNotEmpty)
                      _buildInfoRow('Notes', shift.notes!),
                  ]),

                  const SizedBox(height: 30),

                  if (canJoin)
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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
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

  Widget _buildInfoRow(String label, String value) {
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
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
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

  Widget _buildParticipantRow(
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
              color: isPublisher ? const Color(0xFF10B981) : const Color(0xFF64748B),
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
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'Just joined';
  }
}
