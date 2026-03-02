import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../../core/models/enrollment_request.dart';
import '../../../core/services/job_board_service.dart';
import 'filled_opportunities_screen.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class EnrollmentManagementScreen extends StatefulWidget {
  const EnrollmentManagementScreen({super.key});

  @override
  State<EnrollmentManagementScreen> createState() =>
      _EnrollmentManagementScreenState();
}

class _EnrollmentManagementScreenState extends State<EnrollmentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  // Pipeline Counts
  int _inboxCount = 0;
  int _contactedCount = 0;
  int _broadcastCount = 0;
  int _archivedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted && _currentTabIndex != _tabController.index) {
      setState(() => _currentTabIndex = _tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF3F4F6),
      body: Column(
        children: [
          _buildHeader(),
          _buildPipelineTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _EnrollmentList(
                  status: 'pending',
                  nextActionLabel: 'Mark Contacted',
                  onRefreshCounts: _updateCounts,
                  tabIndex: 0,
                  currentTabIndex: _currentTabIndex,
                ),
                _EnrollmentList(
                  status: 'contacted',
                  nextActionLabel: 'Broadcast',
                  onRefreshCounts: _updateCounts,
                  tabIndex: 1,
                  currentTabIndex: _currentTabIndex,
                ),
                _EnrollmentList(
                  status: 'broadcasted',
                  nextActionLabel: 'View Matches',
                  isLive: true,
                  onRefreshCounts: _updateCounts,
                  tabIndex: 2,
                  currentTabIndex: _currentTabIndex,
                ),
                _EnrollmentList(
                  status: 'archived',
                  nextActionLabel: 'Unarchive',
                  onRefreshCounts: _updateCounts,
                  tabIndex: 3,
                  currentTabIndex: _currentTabIndex,
                ),
                _currentTabIndex == 4
                    ? const FilledOpportunitiesScreen()
                    : const _TabPlaceholder(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateCounts(String status, int count) {
    // Only update state if count actually changed to prevent refresh loops
    if (!mounted) return;
    
    int currentCount = 0;
    if (status == 'pending') currentCount = _inboxCount;
    if (status == 'contacted') currentCount = _contactedCount;
    if (status == 'broadcasted') currentCount = _broadcastCount;
    if (status == 'archived') currentCount = _archivedCount;
    
    // Only update if count changed
    if (currentCount != count) {
      // Use microtask to avoid setState during build
      Future.microtask(() {
        if (mounted) {
          setState(() {
            if (status == 'pending') _inboxCount = count;
            if (status == 'contacted') _contactedCount = count;
            if (status == 'broadcasted') _broadcastCount = count;
            if (status == 'archived') _archivedCount = count;
          });
        }
      });
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xffEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.dashboard_rounded,
                color: Color(0xff3B82F6), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.studentApplicants,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              Text(
                AppLocalizations.of(context)!.manageStudentApplicationsAndEnrollment,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xff3B82F6),
        unselectedLabelColor: const Color(0xff6B7280),
        indicatorColor: const Color(0xff3B82F6),
        indicatorWeight: 3,
        labelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: [
          _buildTabItem('Inbox', _inboxCount, Icons.inbox_rounded),
          _buildTabItem('Ready', _contactedCount, Icons.call_end_rounded),
          _buildTabItem('Live', _broadcastCount, Icons.sensors_rounded),
          _buildTabItem(
              AppLocalizations.of(context)!.archived,
              _archivedCount,
              Icons.archive_outlined),
          Tab(text: AppLocalizations.of(context)!.enrolledFilled),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int count, IconData icon) {
    return Tab(
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xffEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder when a tab is not active (avoids running its stream until selected)
class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: SizedBox.shrink());
  }
}

// FIX: Converted to StatefulWidget to cache the Stream and prevent infinite rebuild loops
class _EnrollmentList extends StatefulWidget {
  final String status;
  final String nextActionLabel;
  final bool isLive;
  final Function(String, int) onRefreshCounts;
  final int tabIndex;
  final int currentTabIndex;

  const _EnrollmentList({
    required this.status,
    required this.nextActionLabel,
    this.isLive = false,
    required this.onRefreshCounts,
    required this.tabIndex,
    required this.currentTabIndex,
  });

  @override
  State<_EnrollmentList> createState() => _EnrollmentListState();
}

class _EnrollmentListState extends State<_EnrollmentList> with AutomaticKeepAliveClientMixin {
  Stream<QuerySnapshot>? _enrollmentStream;

  bool get _isActive => widget.currentTabIndex == widget.tabIndex;

  Stream<QuerySnapshot> _createStream() {
    return FirebaseFirestore.instance
        .collection('enrollments')
        .where('metadata.status', isEqualTo: widget.status)
        .limit(80)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    if (_isActive) _enrollmentStream = _createStream();
  }

  @override
  void didUpdateWidget(covariant _EnrollmentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive && _enrollmentStream == null) {
      setState(() => _enrollmentStream = _createStream());
    }
  }

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Only run Firestore stream when this tab is active (speeds up Ready/Live/Enrolled)
    if (!_isActive) {
      return const Center(child: SizedBox.shrink());
    }
    if (_enrollmentStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _enrollmentStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(AppLocalizations.of(context)!.commonErrorWithDetails(snapshot.error ?? 'Unknown error')),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Sort client-side by submittedAt (most recent first)
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aSubmitted = aData['metadata']?['submittedAt'] as Timestamp?;
          final bSubmitted = bData['metadata']?['submittedAt'] as Timestamp?;
          
          if (aSubmitted == null && bSubmitted == null) return 0;
          if (aSubmitted == null) return 1;
          if (bSubmitted == null) return -1;
          
          return bSubmitted.compareTo(aSubmitted);
        });

        // Update counts securely
        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onRefreshCounts(widget.status, docs.length);
          });
        }

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            try {
              final enrollment = EnrollmentRequest.fromFirestore(docs[index]);
              return _EnrollmentCard(
                enrollment: enrollment,
                nextActionLabel: widget.nextActionLabel,
                isLive: widget.isLive,
              );
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No enrollments in "${widget.status}"',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  final EnrollmentRequest enrollment;
  final String nextActionLabel;
  final bool isLive;

  const _EnrollmentCard({
    required this.enrollment,
    required this.nextActionLabel,
    required this.isLive,
  });

  bool get _isAdult =>
      enrollment.isAdult ||
      (int.tryParse(enrollment.studentAge ?? '0') ?? 0) >= 18;
  bool get _isArchived => enrollment.status.toLowerCase() == 'archived';

  @override
  Widget build(BuildContext context) {
    // FIX: Reduced margins to save space
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border:
            isLive ? Border.all(color: const Color(0xff10B981), width: 1.5) : null,
      ),
      child: Column(
        children: [
          // 1. Header with visual cues - FIX: Reduced Padding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isLive
                      ? const Color(0xffECFDF5)
                      : _isArchived
                          ? const Color(0xffF1F5F9)
                          : const Color(0xffF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                if (isLive) ...[
                  const Icon(Icons.sensors,
                      size: 14, color: Color(0xff059669)),
                  SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.liveOnJobBoard,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff059669),
                      letterSpacing: 0.5,
                    ),
                  ),
                ] else if (_isArchived) ...[
                  const Icon(Icons.archive_outlined,
                      size: 14, color: Color(0xff64748B)),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.archived,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff64748B),
                      letterSpacing: 0.3,
                    ),
                  ),
                ] else ...[
                  Icon(Icons.access_time_filled,
                      size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, h:mm a')
                        .format(enrollment.submittedAt),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
                const Spacer(),
                if (_isAdult)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(AppLocalizations.of(context)!.adultStudent,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          // 2. Main Content - FIX: Reduced Padding
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enrollment.subject ??
                                AppLocalizations.of(context)!.commonUnknownSubject,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${enrollment.studentName ?? AppLocalizations.of(context)!.commonUnknown} • ${enrollment.gradeLevel}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xff64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildApplicantDetailsButton(context),
                        const SizedBox(width: 8),
                        _buildQuickContactButton(context),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDetailsGrid(),
                const SizedBox(height: 12),
                // Show action history / tracking info
                _buildActionHistory(),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 3. Action Bar (The sequential logic)
                Row(
                  children: [
                    if (_isArchived) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmUnarchive(context),
                          icon: const Icon(Icons.unarchive_outlined, size: 16),
                          label: const Text('Unarchive'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff2563EB),
                            side: const BorderSide(color: Color(0xff93C5FD)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ] else if (isLive) ...[
                      // Stop Broadcast Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _handleStatusChange(context, 'contacted'),
                          icon: const Icon(Icons.visibility_off_outlined,
                              size: 16),
                          label: Text(AppLocalizations.of(context)!.unBroadcast),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xffEF4444),
                            side: const BorderSide(color: Color(0xffEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Reject / Hold Button
                      IconButton(
                        onPressed: () => _confirmArchive(context),
                        icon: const Icon(Icons.archive_outlined,
                            color: Colors.grey, size: 20),
                        tooltip: AppLocalizations.of(context)!.archive,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(12),
                      ),
                      const SizedBox(width: 8),
                      // Primary Action Button (Moves to next stage)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _advanceWorkflow(context),
                          icon: Icon(
                              enrollment.status.toLowerCase() == 'pending'
                                  ? Icons.check
                                  : Icons.sensors,
                              size: 16),
                          label: Text(nextActionLabel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildInfoChip(
            Icons.calendar_today, enrollment.preferredDays.join(', ')),
        _buildInfoChip(
            Icons.schedule, enrollment.preferredTimeSlots.join(', ')),
        _buildInfoChip(Icons.public, enrollment.timeZone),
        if (!_isAdult && enrollment.parentName != null)
          _buildInfoChip(
              Icons.family_restroom, 'Parent: ${enrollment.parentName}'),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xff94A3B8)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label.length > 25 ? '${label.substring(0, 25)}...' : label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff475569),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionHistory() {
    // Get enrollment document to read action history
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: enrollment.id != null 
          ? FirebaseFirestore.instance
              .collection('enrollments')
              .doc(enrollment.id)
              .get()
          : Future.value(null),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        
        final data = snapshot.data!.data() ?? <String, dynamic>{};
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        
        // Collect all action info
        final List<Map<String, dynamic>> actions = [];
        
        // Check for contacted info
        if (metadata['contactedAt'] != null) {
          actions.add({
            'action': 'Marked as Contacted',
            'by': metadata['contactedByName'] ?? metadata['contactedBy'] ?? 'Admin',
            'at': metadata['contactedAt'],
            'icon': Icons.phone,
            'color': const Color(0xff3B82F6),
          });
        }
        
        // Check for broadcasted info
        if (metadata['broadcastedAt'] != null) {
          actions.add({
            'action': 'Broadcasted to Teachers',
            'by': metadata['broadcastedByName'] ?? metadata['broadcastedBy'] ?? 'Admin',
            'at': metadata['broadcastedAt'],
            'icon': Icons.sensors,
            'color': const Color(0xff10B981),
          });
        }
        
        // Check for matched info (teacher accepted)
        if (metadata['matchedAt'] != null) {
          actions.add({
            'action': 'Matched with Teacher',
            'by': metadata['matchedTeacherName'] ?? metadata['matchedTeacherId'] ?? 'Teacher',
            'at': metadata['matchedAt'],
            'icon': Icons.handshake,
            'color': const Color(0xff8B5CF6),
          });
        }
        
        // Check action history array
        final actionHistory = metadata['actionHistory'] as List<dynamic>?;
        if (actionHistory != null && actionHistory.isNotEmpty) {
          // Add any additional actions from history
          for (final entry in actionHistory) {
            if (entry is Map<String, dynamic>) {
              final actionType = entry['action'] as String? ?? '';
              if (actionType == 'marked_contacted' && 
                  !actions.any((a) => a['action'] == 'Marked as Contacted')) {
                actions.add({
                  'action': 'Marked as Contacted',
                  'by': entry['adminName'] ?? entry['adminId'] ?? 'Admin',
                  'at': entry['timestamp'],
                  'icon': Icons.phone,
                  'color': const Color(0xff3B82F6),
                });
              } else if (actionType == 'broadcasted' && 
                         !actions.any((a) => a['action'] == 'Broadcasted to Teachers')) {
                actions.add({
                  'action': 'Broadcasted to Teachers',
                  'by': entry['adminName'] ?? entry['adminId'] ?? 'Admin',
                  'at': entry['timestamp'],
                  'icon': Icons.sensors,
                  'color': const Color(0xff10B981),
                });
              } else if (actionType == 'teacher_accepted') {
                actions.add({
                  'action': 'Matched with Teacher',
                  'by': entry['teacherName'] ?? entry['teacherId'] ?? 'Teacher',
                  'at': entry['timestamp'],
                  'icon': Icons.handshake,
                  'color': const Color(0xff8B5CF6),
                });
              } else if (actionType == 'admin_revoked') {
                actions.add({
                  'action': 'Admin Revoked (Re-broadcast)',
                  'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
                  'at': entry['timestamp'],
                  'icon': Icons.undo,
                  'color': Colors.red,
                });
              } else if (actionType == 'teacher_withdrawn') {
                actions.add({
                  'action': 'Teacher Withdrew',
                  'by': entry['teacherName'] ?? entry['teacherId'] ?? 'Teacher',
                  'at': entry['timestamp'],
                  'icon': Icons.exit_to_app,
                  'color': Colors.orange,
                });
              } else if (actionType == 'archived') {
                actions.add({
                  'action': 'Archived Application',
                  'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
                  'at': entry['timestamp'],
                  'icon': Icons.archive_outlined,
                  'color': const Color(0xff475569),
                });
              } else if (actionType == 'unarchived') {
                actions.add({
                  'action': 'Unarchived Application',
                  'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
                  'at': entry['timestamp'],
                  'icon': Icons.unarchive_outlined,
                  'color': const Color(0xff2563EB),
                });
              } else if (actionType == 'admin_closed') {
                actions.add({
                  'action': 'Closed by admin (no re-broadcast)',
                  'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
                  'at': entry['timestamp'],
                  'icon': Icons.archive_outlined,
                  'color': const Color(0xff4B5563),
                });
              }
            }
          }
        }
        
        if (actions.isEmpty) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Color(0xff64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'Activity History',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff475569),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...actions.map((action) {
                final timestamp = action['at'] as Timestamp?;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (action['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          size: 14,
                          color: action['color'] as Color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action['action'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff1E293B),
                              ),
                            ),
                            Text(
                              'by ${action['by']}${timestamp != null ? ' • ${DateFormat('MMM d, h:mm a').format(timestamp.toDate())}' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xff64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickContactButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        // Simple bottom sheet for contact
        showModalBottomSheet(
          context: context,
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Contact ${_isAdult ? "Student" : "Parent"}',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.email),
                  title: Text(enrollment.email),
                  onTap: () =>
                      launchUrl(Uri.parse('mailto:${enrollment.email}')),
                ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(enrollment.phoneNumber),
                  onTap: () =>
                      launchUrl(Uri.parse('tel:${enrollment.phoneNumber}')),
                ),
                if (enrollment.whatsAppNumber != null &&
                    enrollment.whatsAppNumber!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.chat),
                    title: Text(AppLocalizations.of(context)!.whatsapp),
                    onTap: () => launchUrl(
                        Uri.parse('https://wa.me/${enrollment.whatsAppNumber}')),
                  ),
              ],
            ),
          ),
        );
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xffEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.phone_outlined, size: 18, color: Color(0xff3B82F6)),
      ),
    );
  }

  Widget _buildApplicantDetailsButton(BuildContext context) {
    return Tooltip(
      message: 'View full applicant details',
      child: IconButton(
        onPressed: () => _showApplicantDetailsDialog(context),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xffEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.info_outline, size: 18, color: Color(0xff4F46E5)),
        ),
      ),
    );
  }

  Future<void> _showApplicantDetailsDialog(BuildContext context) async {
    if (enrollment.id == null) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Applicant Details'),
        content: SizedBox(
          width: MediaQuery.of(ctx).size.width > 900 ? 780 : 520,
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('enrollments')
                .doc(enrollment.id)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return const Text('Could not load applicant details.');
              }

              final data = snapshot.data!.data() ?? {};
              final contact = data['contact'] as Map<String, dynamic>? ?? {};
              final student = data['student'] as Map<String, dynamic>? ?? {};
              final preferences = data['preferences'] as Map<String, dynamic>? ?? {};
              final program = data['program'] as Map<String, dynamic>? ?? {};
              final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
              final country = contact['country'] as Map<String, dynamic>? ?? {};

              final prettyJson = const JsonEncoder.withIndent('  ')
                  .convert(_normalizeForJson(data));

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailsSection('Student', [
                      _detailRow('Name', student['name'] ?? data['studentName']),
                      _detailRow('Age', student['age'] ?? data['studentAge']),
                      _detailRow('Gender', student['gender'] ?? data['gender']),
                      _detailRow('Grade Level', data['gradeLevel']),
                      _detailRow('Adult Student', metadata['isAdult']),
                      _detailRow('Knows Zoom', student['knowsZoom'] ?? data['knowsZoom']),
                    ]),
                    _buildDetailsSection('Contact', [
                      _detailRow('Email', contact['email'] ?? data['email']),
                      _detailRow('Phone', contact['phone'] ?? data['phoneNumber']),
                      _detailRow('WhatsApp', contact['whatsApp'] ?? data['whatsAppNumber']),
                      _detailRow('Parent Name', contact['parentName'] ?? data['parentName']),
                      _detailRow('Guardian ID', contact['guardianId'] ?? data['guardianId']),
                      _detailRow('City', contact['city'] ?? data['city']),
                      _detailRow('Country', country['name'] ?? data['countryName']),
                      _detailRow('Country Code', country['code'] ?? data['countryCode']),
                    ]),
                    _buildDetailsSection('Program', [
                      _detailRow('Subject', data['subject']),
                      _detailRow('Specific Language', data['specificLanguage']),
                      _detailRow('Role', program['role'] ?? data['role']),
                      _detailRow('Class Type', program['classType'] ?? data['classType']),
                      _detailRow(
                          'Session Duration', program['sessionDuration'] ?? data['sessionDuration']),
                    ]),
                    _buildDetailsSection('Preferences', [
                      _detailRow('Preferred Language',
                          preferences['preferredLanguage'] ?? data['preferredLanguage']),
                      _detailRow('Time Zone', preferences['timeZone'] ?? data['timeZone']),
                      _detailRow('Days', preferences['days']),
                      _detailRow('Time Slots', preferences['timeSlots']),
                      _detailRow('Time of Day',
                          preferences['timeOfDayPreference'] ?? data['timeOfDayPreference']),
                    ]),
                    _buildDetailsSection('Metadata', [
                      _detailRow('Status', metadata['status']),
                      _detailRow('Submitted At', metadata['submittedAt']),
                      _detailRow('Reviewed By', metadata['reviewedBy']),
                      _detailRow('Reviewed At', metadata['reviewedAt']),
                      _detailRow('Source', metadata['source']),
                    ]),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'Raw Application Data',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff334155),
                          ),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              prettyJson,
                              style: GoogleFonts.robotoMono(
                                fontSize: 11,
                                color: const Color(0xffE2E8F0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context)!.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(String title, List<Widget> rows) {
    final visibleRows = rows.where((row) => row is! SizedBox).toList();
    if (visibleRows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xff1E293B),
            ),
          ),
          const SizedBox(height: 8),
          ...visibleRows,
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    final formattedValue = _formatDetailValue(value);
    if (formattedValue == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xff64748B),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              formattedValue,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _formatDetailValue(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    if (value is Timestamp) {
      return DateFormat('MMM d, yyyy h:mm a').format(value.toDate());
    }

    if (value is List) {
      final parts = value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isEmpty) return null;
      return parts.join(', ');
    }

    return value.toString();
  }

  dynamic _normalizeForJson(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), _normalizeForJson(val)));
    }

    if (value is List) {
      return value.map(_normalizeForJson).toList();
    }

    return value;
  }

  Future<void> _confirmArchive(BuildContext context) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Archive applicant?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will archive the application and remove it from active lists. '
          'It will not be permanently deleted.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff475569)),
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldArchive != true || !context.mounted) return;
    await _handleStatusChange(
      context,
      'archived',
      forcedAction: 'archived',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Application archived. It was not deleted.'),
      ),
    );
  }

  Future<void> _confirmUnarchive(BuildContext context) async {
    final shouldUnarchive = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Unarchive applicant?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will move the application back to the active pipeline.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    );

    if (shouldUnarchive != true || !context.mounted || enrollment.id == null) return;

    String restoreStatus = 'pending';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(enrollment.id)
          .get();
      final metadata = snapshot.data()?['metadata'] as Map<String, dynamic>? ?? {};
      final previousStatus =
          (metadata['archivedPreviousStatus'] as String?)?.toLowerCase().trim();
      if (previousStatus == 'contacted') {
        restoreStatus = 'contacted';
      }
    } catch (_) {
      // Keep fallback to pending if metadata lookup fails.
    }

    if (!context.mounted) return;
    await _handleStatusChange(
      context,
      restoreStatus,
      forcedAction: 'unarchived',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restoreStatus == 'contacted'
              ? 'Application moved to Ready.'
              : 'Application moved to Inbox.',
        ),
      ),
    );
  }

  Future<void> _advanceWorkflow(BuildContext context) async {
    final status = enrollment.status.toLowerCase();
    // 1. Pending -> Contacted
    if (status == 'pending') {
      await _handleStatusChange(context, 'contacted');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.markedAsContactedMovedToReady)));
      }
    }
    // 2. Contacted -> Broadcasted
    else if (status == 'contacted') {
      _showBroadcastDialog(context);
    }
  }

  void _showBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.broadcastToTeachers),
        content: Text(
            AppLocalizations.of(context)!.thisWillMakeTheOpportunityVisible),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.commonCancel)),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // Call your existing service
                await JobBoardService().broadcastEnrollment(enrollment);
                // Status automatically updates to 'Broadcasted' by the service/function,
                // but we can force UI update if needed via the stream
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            AppLocalizations.of(context)!.broadcastLiveTeachersCanNowSee)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg.length > 120 ? '${msg.substring(0, 120)}…' : msg),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(AppLocalizations.of(context)!.broadcastNow),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStatusChange(
      BuildContext context, String newStatus, {String? forcedAction}) async {
    if (enrollment.id == null) return;

    final targetStatus = newStatus == 'rejected' ? 'archived' : newStatus;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // When un-broadcasting (moving from live to contacted), close job_board entries
    // so teachers no longer see the opportunity.
    if (targetStatus == 'contacted') {
      try {
        await JobBoardService().unbroadcastEnrollment(enrollment.id!);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Un-broadcast failed to update job board: $e')),
          );
        }
        return;
      }
    }
    
    // Get admin name for tracking
    String? adminName;
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (adminDoc.exists) {
        final data = adminDoc.data() as Map<String, dynamic>;
        adminName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
        if (adminName.isEmpty) adminName = data['e-mail'] as String?;
      }
    } catch (e) {
      // If we can't get name, use email
      adminName = currentUser.email;
    }
    
    // Build action history entry (use Timestamp - serverTimestamp() is not allowed inside arrayUnion)
    final actionEntry = {
      'action': forcedAction ??
          (targetStatus == 'contacted'
              ? 'marked_contacted'
              : targetStatus == 'broadcasted'
                  ? 'broadcasted'
                  : targetStatus == 'archived'
                      ? 'archived'
                      : 'status_changed'),
      'status': targetStatus,
      'adminId': currentUser.uid,
      'adminName': adminName ?? 'Unknown',
      'adminEmail': currentUser.email ?? '',
      'timestamp': Timestamp.fromDate(DateTime.now()),
    };
    
    await FirebaseFirestore.instance
        .collection('enrollments')
        .doc(enrollment.id)
        .update({
      'metadata.status': targetStatus,
      'metadata.lastUpdated': FieldValue.serverTimestamp(),
      'metadata.updatedBy': currentUser.uid,
      'metadata.updatedByName': adminName,
      // Track specific action timestamps
      if (targetStatus == 'contacted') 'metadata.contactedAt': FieldValue.serverTimestamp(),
      if (targetStatus == 'contacted') 'metadata.contactedBy': currentUser.uid,
      if (targetStatus == 'contacted') 'metadata.contactedByName': adminName,
      if (targetStatus == 'broadcasted') 'metadata.broadcastedBy': currentUser.uid,
      if (targetStatus == 'broadcasted') 'metadata.broadcastedByName': adminName,
      if (targetStatus == 'archived') 'metadata.archivedAt': FieldValue.serverTimestamp(),
      if (targetStatus == 'archived') 'metadata.archivedBy': currentUser.uid,
      if (targetStatus == 'archived') 'metadata.archivedByName': adminName,
      if (targetStatus == 'archived' &&
          enrollment.status.toLowerCase() != 'archived')
        'metadata.archivedPreviousStatus': enrollment.status.toLowerCase(),
      if (forcedAction == 'unarchived')
        'metadata.unarchivedAt': FieldValue.serverTimestamp(),
      if (forcedAction == 'unarchived')
        'metadata.unarchivedBy': currentUser.uid,
      if (forcedAction == 'unarchived')
        'metadata.unarchivedByName': adminName,
      // Add to action history array (entry must contain only serializable values, not FieldValue)
      'metadata.actionHistory': FieldValue.arrayUnion([actionEntry]),
    });
  }
}
