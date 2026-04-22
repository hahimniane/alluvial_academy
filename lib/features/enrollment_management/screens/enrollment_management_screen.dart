import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/enrollment_request.dart';
import '../widgets/enrollment_card.dart';
import '../widgets/matched_enrollment_card.dart';
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

  int _inboxCount = 0;
  int _contactedCount = 0;
  int _broadcastCount = 0;
  int _archivedCount = 0;
  int _matchedCount = 0;

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
                _MatchedEnrollmentList(
                  onRefreshCounts: _updateCounts,
                  tabIndex: 4,
                  currentTabIndex: _currentTabIndex,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateCounts(String status, int count) {
    if (!mounted) return;

    int currentCount = 0;
    if (status == 'pending') currentCount = _inboxCount;
    if (status == 'contacted') currentCount = _contactedCount;
    if (status == 'broadcasted') currentCount = _broadcastCount;
    if (status == 'archived') currentCount = _archivedCount;
    if (status == 'matched') currentCount = _matchedCount;

    if (currentCount != count) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            if (status == 'pending') _inboxCount = count;
            if (status == 'contacted') _contactedCount = count;
            if (status == 'broadcasted') _broadcastCount = count;
            if (status == 'archived') _archivedCount = count;
            if (status == 'matched') _matchedCount = count;
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
          _buildTabItem('Matched', _matchedCount, Icons.handshake_outlined),
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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
              return EnrollmentCard(
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

/// Enrollment list for the "Matched" tab (metadata.status == 'matched').
/// Uses [MatchedEnrollmentCard] instead of [EnrollmentCard].
class _MatchedEnrollmentList extends StatefulWidget {
  final Function(String, int) onRefreshCounts;
  final int tabIndex;
  final int currentTabIndex;

  const _MatchedEnrollmentList({
    required this.onRefreshCounts,
    required this.tabIndex,
    required this.currentTabIndex,
  });

  @override
  State<_MatchedEnrollmentList> createState() => _MatchedEnrollmentListState();
}

class _MatchedEnrollmentListState extends State<_MatchedEnrollmentList>
    with AutomaticKeepAliveClientMixin {
  Stream<QuerySnapshot>? _stream;

  bool get _isActive => widget.currentTabIndex == widget.tabIndex;

  Stream<QuerySnapshot> _createStream() {
    return FirebaseFirestore.instance
        .collection('enrollments')
        .where('metadata.status', isEqualTo: 'matched')
        .limit(80)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    if (_isActive) _stream = _createStream();
  }

  @override
  void didUpdateWidget(covariant _MatchedEnrollmentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive && _stream == null) {
      setState(() => _stream = _createStream());
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_isActive) return const Center(child: SizedBox.shrink());
    if (_stream == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aAt = aData['metadata']?['matchedAt'] as Timestamp?;
          final bAt = bData['metadata']?['matchedAt'] as Timestamp?;
          if (aAt == null && bAt == null) return 0;
          if (aAt == null) return 1;
          if (bAt == null) return -1;
          return bAt.compareTo(aAt);
        });

        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onRefreshCounts('matched', docs.length);
          });
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handshake_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No matched enrollments yet',
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'When a teacher accepts a broadcast, it will appear here',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            try {
              final enrollment = EnrollmentRequest.fromFirestore(docs[index]);
              return MatchedEnrollmentCard(enrollment: enrollment);
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }
}
