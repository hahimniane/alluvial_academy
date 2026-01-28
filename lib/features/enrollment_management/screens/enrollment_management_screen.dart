import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // Pipeline Counts
  int _inboxCount = 0;
  int _contactedCount = 0;
  int _broadcastCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
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
                    onRefreshCounts: _updateCounts),
                _EnrollmentList(
                    status: 'contacted',
                    nextActionLabel: 'Broadcast',
                    onRefreshCounts: _updateCounts),
                _EnrollmentList(
                    status: 'broadcasted',
                    nextActionLabel: 'View Matches',
                    isLive: true,
                    onRefreshCounts: _updateCounts),
                const FilledOpportunitiesScreen(),
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
    
    // Only update if count changed
    if (currentCount != count) {
      // Use microtask to avoid setState during build
      Future.microtask(() {
        if (mounted) {
          setState(() {
            if (status == 'pending') _inboxCount = count;
            if (status == 'contacted') _contactedCount = count;
            if (status == 'broadcasted') _broadcastCount = count;
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
                AppLocalizations.of(context)!.count,
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

// FIX: Converted to StatefulWidget to cache the Stream and prevent infinite rebuild loops
class _EnrollmentList extends StatefulWidget {
  final String status;
  final String nextActionLabel;
  final bool isLive;
  final Function(String, int) onRefreshCounts;

  const _EnrollmentList({
    required this.status,
    required this.nextActionLabel,
    this.isLive = false,
    required this.onRefreshCounts,
  });

  @override
  State<_EnrollmentList> createState() => _EnrollmentListState();
}

class _EnrollmentListState extends State<_EnrollmentList> with AutomaticKeepAliveClientMixin {
  late Stream<QuerySnapshot> _enrollmentStream;

  @override
  void initState() {
    super.initState();
    // Initialize stream ONCE to prevent recreating it on every parent rebuild
    _enrollmentStream = FirebaseFirestore.instance
          .collection('enrollments')
          .where('metadata.status', isEqualTo: widget.status)
          .snapshots();
  }

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
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
                  isLive ? const Color(0xffECFDF5) : const Color(0xffF8FAFC),
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
                    _buildQuickContactButton(context),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDetailsGrid(),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 3. Action Bar (The sequential logic)
                Row(
                  children: [
                    if (isLive) ...[
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
                        onPressed: () =>
                            _handleStatusChange(context, 'rejected'),
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
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorE)));
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
      BuildContext context, String newStatus) async {
    if (enrollment.id == null) return;
    await FirebaseFirestore.instance
        .collection('enrollments')
        .doc(enrollment.id)
        .update({
      'metadata.status': newStatus, // Keep consistent capitalization
      'metadata.lastUpdated': FieldValue.serverTimestamp(),
      'metadata.updatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }
}
