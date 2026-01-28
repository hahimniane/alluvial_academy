import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/video_call_service.dart';
import '../../../core/services/livekit_service.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Admin Classes Screen - Shows all classes and allows admins to join any class
class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen>
    with SingleTickerProviderStateMixin {
  List<TeachingShift> _todayClasses = [];
  List<TeachingShift> _upcomingClasses = [];
  List<TeachingShift> _pastClasses = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  Timer? _presenceTimer;
  StreamSubscription<List<TeachingShift>>? _shiftsSubscription;
  late TabController _tabController;
  
  // Cache for room presence data (shiftId -> presence result)
  final Map<String, LiveKitRoomPresenceResult> _presenceCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClasses();
    // Refresh every 30 seconds to update countdown timers
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    // Refresh presence data every 15 seconds for active classes
    _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshActiveClassPresence();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _presenceTimer?.cancel();
    _shiftsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }
  
  /// Refresh presence for all active classes
  Future<void> _refreshActiveClassPresence() async {
    final activeClasses = _todayClasses.where((s) => s.status == ShiftStatus.active).toList();
    for (final shift in activeClasses) {
      await _fetchPresence(shift.id);
    }
  }
  
  /// Fetch presence for a specific shift
  Future<LiveKitRoomPresenceResult?> _fetchPresence(String shiftId) async {
    try {
      final result = await LiveKitService.getRoomPresence(shiftId);
      if (mounted) {
        setState(() {
          _presenceCache[shiftId] = result;
        });
      }
      return result;
    } catch (e) {
      AppLogger.error('Error fetching presence for $shiftId: $e');
      return null;
    }
  }

  void _loadClasses() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _shiftsSubscription?.cancel();
    _shiftsSubscription = ShiftService.getAllShifts().listen(
      (shifts) {
        if (!mounted) return;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));

        // Categorize shifts
        final todayClasses = <TeachingShift>[];
        final upcomingClasses = <TeachingShift>[];
        final pastClasses = <TeachingShift>[];

        for (final shift in shifts) {
          final shiftDate = DateTime(
            shift.shiftStart.year,
            shift.shiftStart.month,
            shift.shiftStart.day,
          );

          if (shiftDate.isBefore(today)) {
            pastClasses.add(shift);
          } else if (shiftDate.isAtSameMomentAs(today) ||
              (shiftDate.isAfter(today) && shiftDate.isBefore(tomorrow))) {
            todayClasses.add(shift);
          } else {
            upcomingClasses.add(shift);
          }
        }

        // Sort: joinable/active classes first, then by start time
        todayClasses.sort((a, b) {
          // Joinable classes come first
          final aCanJoin = VideoCallService.canJoinClass(a);
          final bCanJoin = VideoCallService.canJoinClass(b);
          if (aCanJoin && !bCanJoin) return -1;
          if (!aCanJoin && bCanJoin) return 1;
          // Then active classes
          final aIsActive = a.status == ShiftStatus.active;
          final bIsActive = b.status == ShiftStatus.active;
          if (aIsActive && !bIsActive) return -1;
          if (!aIsActive && bIsActive) return 1;
          // Then sort by start time
          return a.shiftStart.compareTo(b.shiftStart);
        });
        upcomingClasses.sort((a, b) {
          // Joinable classes come first
          final aCanJoin = VideoCallService.canJoinClass(a);
          final bCanJoin = VideoCallService.canJoinClass(b);
          if (aCanJoin && !bCanJoin) return -1;
          if (!aCanJoin && bCanJoin) return 1;
          // Then active classes
          final aIsActive = a.status == ShiftStatus.active;
          final bIsActive = b.status == ShiftStatus.active;
          if (aIsActive && !bIsActive) return -1;
          if (!aIsActive && bIsActive) return 1;
          // Then sort by start time
          return a.shiftStart.compareTo(b.shiftStart);
        });
        pastClasses.sort((a, b) => b.shiftStart.compareTo(a.shiftStart)); // Newest first

        setState(() {
          _todayClasses = todayClasses;
          _upcomingClasses = upcomingClasses;
          _pastClasses = pastClasses;
          _isLoading = false;
        });
      },
      onError: (error) {
        AppLogger.error('Error loading classes: $error');
        if (mounted) {
          setState(() {
            _error = 'Failed to load classes';
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          AppLocalizations.of(context)!.allClasses,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0E72ED),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0E72ED),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: 'Today (${_todayClasses.length})'),
            Tab(text: 'Upcoming (${_upcomingClasses.length})'),
            Tab(text: 'Past (${_pastClasses.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: _loadClasses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildClassList(_todayClasses, 'No classes scheduled for today'),
                    _buildClassList(_upcomingClasses, 'No upcoming classes'),
                    _buildClassList(_pastClasses, 'No past classes'),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(_error!, style: GoogleFonts.inter(fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadClasses,
            child: Text(AppLocalizations.of(context)!.commonRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildClassList(List<TeachingShift> classes, String emptyMessage) {
    if (classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadClasses(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: classes.length,
        itemBuilder: (context, index) => _buildClassCard(classes[index]),
      ),
    );
  }

  Widget _buildClassCard(TeachingShift shift) {
    final now = DateTime.now();
    final isActive = shift.status == ShiftStatus.active || shift.isClockedIn;
    final isUpcoming = shift.shiftStart.isAfter(now);
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

    // Get cached presence data for active classes
    final presence = isActive ? _presenceCache[shift.id] : null;
    final participantCount = presence?.participantCount ?? 0;
    
    // Fetch presence if not cached and class is active
    if (isActive && presence == null) {
      _fetchPresence(shift.id);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
              // Header with status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
                  // Live participant indicator for active classes
                  if (isActive && participantCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)!.participantcountInClass,
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
                    _formatTime(shift.shiftStart),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Class name
              Text(
                shift.displayName.isNotEmpty
                    ? shift.displayName
                    : 'Class #${shift.id.substring(0, 6)}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),

              // Teacher info
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Teacher: ${shift.teacherName.isNotEmpty ? shift.teacherName : AppLocalizations.of(context)!.commonUnknown}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Students info
              Row(
                children: [
                  const Icon(Icons.people, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    '${shift.studentIds.length} student${shift.studentIds.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Date
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(shift.shiftStart),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              
              // Show participants for active classes - always visible section
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
                            width: 8,
                            height: 8,
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
                              width: 12,
                              height: 12,
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
                              ? _formatParticipantDuration(DateTime.now().difference(p.joinedAt!))
                              : '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
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
                                      horizontal: 8,
                                      vertical: 3,
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
                // Tap for more details hint
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context)!.tapAndHoldForMoreDetails,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],

              // Join button for active/upcoming classes
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
  
  /// Show detailed class information in a bottom sheet
  void _showClassDetails(TeachingShift shift) async {
    // Fetch fresh presence data
    final presence = await _fetchPresence(shift.id);
    
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

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }
  
  String _formatParticipantDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'Just joined';
    }
  }

  Future<void> _joinClass(TeachingShift shift) async {
    try {
      await VideoCallService.joinClass(
        context,
        shift,
        isTeacher: false, // Admins join as observers
      );
    } catch (e) {
      AppLogger.error('Error joining class: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .classJoinFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Bottom sheet showing detailed class information
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
    final now = DateTime.now();
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
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
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
                          shift.displayName.isNotEmpty
                              ? shift.displayName
                              : 'Class Details',
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
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
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
                    DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(shift.shiftStart),
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
                  // Teacher section
                  _buildSection(
                    'Teacher',
                    Icons.person,
                    [
                      _buildInfoRow('Name', shift.teacherName.isNotEmpty ? shift.teacherName : AppLocalizations.of(context)!.commonUnknown),
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
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Students section
                  _buildSection(
                    'Assigned Students (${shift.studentIds.length})',
                    Icons.people,
                    shift.studentNames.isEmpty
                        ? [_buildInfoRow('Students', '${shift.studentIds.length} assigned')]
                        : shift.studentNames
                            .map((name) => _buildInfoRow('', name))
                            .toList(),
                  ),
                  
                  // Current participants section (for active classes)
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
                          duration,
                          p.isPublisher,
                        );
                      }).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Class info section
                  _buildSection(
                    'Class Information',
                    Icons.info_outline,
                    [
                      _buildInfoRow('Duration', '${shift.shiftDurationHours.toStringAsFixed(1)} hours'),
                      _buildInfoRow('Subject', shift.effectiveSubjectDisplayName),
                      _buildInfoRow('Status', shift.status.name.toUpperCase()),
                      if (shift.notes != null && shift.notes!.isNotEmpty)
                        _buildInfoRow('Notes', shift.notes!),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Join button
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
          child: Column(
            children: children,
          ),
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
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
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

  Widget _buildParticipantRow(String name, String role, String duration, bool isPublisher) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
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
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
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

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'Just joined';
    }
  }
}
