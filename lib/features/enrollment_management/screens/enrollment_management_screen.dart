import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
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
  int _unfinishedCount = 0;
  int _contactedCount = 0;
  int _broadcastCount = 0;
  int _archivedCount = 0;
  int _matchedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
                _EnrollmentDraftList(
                  onRefreshCounts: _updateCounts,
                  tabIndex: 1,
                  currentTabIndex: _currentTabIndex,
                ),
                _EnrollmentList(
                  status: 'contacted',
                  nextActionLabel: 'Broadcast',
                  onRefreshCounts: _updateCounts,
                  tabIndex: 2,
                  currentTabIndex: _currentTabIndex,
                ),
                _EnrollmentList(
                  status: 'broadcasted',
                  nextActionLabel: 'View Matches',
                  isLive: true,
                  onRefreshCounts: _updateCounts,
                  tabIndex: 3,
                  currentTabIndex: _currentTabIndex,
                ),
                _EnrollmentList(
                  status: 'archived',
                  nextActionLabel: 'Unarchive',
                  onRefreshCounts: _updateCounts,
                  tabIndex: 4,
                  currentTabIndex: _currentTabIndex,
                ),
                _MatchedEnrollmentList(
                  onRefreshCounts: _updateCounts,
                  tabIndex: 5,
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
    if (status == 'unfinished') currentCount = _unfinishedCount;
    if (status == 'contacted') currentCount = _contactedCount;
    if (status == 'broadcasted') currentCount = _broadcastCount;
    if (status == 'archived') currentCount = _archivedCount;
    if (status == 'matched') currentCount = _matchedCount;

    if (currentCount != count) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            if (status == 'pending') _inboxCount = count;
            if (status == 'unfinished') _unfinishedCount = count;
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
                AppLocalizations.of(context)!
                    .manageStudentApplicationsAndEnrollment,
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
          _buildTabItem(
              'Unfinished', _unfinishedCount, Icons.hourglass_bottom_rounded),
          _buildTabItem('Ready', _contactedCount, Icons.call_end_rounded),
          _buildTabItem('Live', _broadcastCount, Icons.sensors_rounded),
          _buildTabItem(AppLocalizations.of(context)!.archived, _archivedCount,
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

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return {};
}

String _stringValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  return value.toString().trim();
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _timestampToDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = diff.inDays ~/ 7;
  if (weeks < 5) return '${weeks}w ago';
  final months = diff.inDays ~/ 30;
  if (months < 12) return '${months}mo ago';
  return '${diff.inDays ~/ 365}y ago';
}

String? _encodeQueryParameters(Map<String, String> params) {
  if (params.isEmpty) return null;
  return params.entries
      .map((entry) =>
          '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
      .join('&');
}

Future<void> _launch(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _EnrollmentDraft {
  final String id;
  final DateTime? updatedAt;
  final int step;
  final String stepTitle;
  final String role;
  final List<String> studentNames;
  final List<String> subjects;
  final String email;
  final String phone;
  final String whatsApp;
  final String parentName;
  final String city;
  final String timeZone;

  const _EnrollmentDraft({
    required this.id,
    required this.updatedAt,
    required this.step,
    required this.stepTitle,
    required this.role,
    required this.studentNames,
    required this.subjects,
    required this.email,
    required this.phone,
    required this.whatsApp,
    required this.parentName,
    required this.city,
    required this.timeZone,
  });

  factory _EnrollmentDraft.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final contact = _mapValue(data['contact']);
    final students = (data['students'] as List? ?? const [])
        .map(_mapValue)
        .where((student) => student.isNotEmpty)
        .toList();

    return _EnrollmentDraft(
      id: doc.id,
      updatedAt: _timestampToDate(data['updatedAt']),
      step: _intValue(data['step']),
      stepTitle: _stringValue(data['stepTitle']),
      role: _stringValue(data['role']),
      studentNames: students
          .map((student) => _stringValue(student['name']))
          .where((name) => name.isNotEmpty)
          .toList(),
      subjects: students
          .map((student) => _stringValue(student['subject']))
          .where((subject) => subject.isNotEmpty)
          .toSet()
          .toList(),
      email: _stringValue(contact['email']),
      phone: _stringValue(contact['phoneNumber']),
      whatsApp: _stringValue(contact['whatsAppNumber']),
      parentName: _stringValue(contact['parentName']),
      city: _stringValue(contact['city']),
      timeZone: _stringValue(data['timeZone']),
    );
  }

  String get primaryName {
    if (studentNames.isNotEmpty) return studentNames.join(', ');
    if (parentName.isNotEmpty) return parentName;
    if (email.isNotEmpty) return email;
    if (whatsApp.isNotEmpty) return whatsApp;
    if (phone.isNotEmpty) return phone;
    return 'Unknown applicant';
  }

  String get programSummary {
    if (subjects.isNotEmpty) return subjects.join(', ');
    if (role.isNotEmpty) return role;
    return 'No program selected yet';
  }

  String get bestPhone => phone.isNotEmpty ? phone : whatsApp;

  int get progressStep => (step + 1).clamp(1, 5).toInt();
}

class _EnrollmentDraftList extends StatefulWidget {
  final Function(String, int) onRefreshCounts;
  final int tabIndex;
  final int currentTabIndex;

  const _EnrollmentDraftList({
    required this.onRefreshCounts,
    required this.tabIndex,
    required this.currentTabIndex,
  });

  @override
  State<_EnrollmentDraftList> createState() => _EnrollmentDraftListState();
}

class _EnrollmentDraftListState extends State<_EnrollmentDraftList>
    with AutomaticKeepAliveClientMixin {
  Stream<QuerySnapshot>? _stream;

  bool get _isActive => widget.currentTabIndex == widget.tabIndex;

  Stream<QuerySnapshot> _createStream() {
    return FirebaseFirestore.instance
        .collection('enrollment_drafts')
        .where('status', isEqualTo: 'in_progress')
        .limit(80)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    if (_isActive) _stream = _createStream();
  }

  @override
  void didUpdateWidget(covariant _EnrollmentDraftList oldWidget) {
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
    if (_stream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(AppLocalizations.of(context)!
                .commonErrorWithDetails(snapshot.error ?? 'Unknown error')),
          );
        }

        final drafts = (snapshot.data?.docs ?? [])
            .map(_EnrollmentDraft.fromFirestore)
            .toList()
          ..sort((a, b) {
            if (a.updatedAt == null && b.updatedAt == null) return 0;
            if (a.updatedAt == null) return 1;
            if (b.updatedAt == null) return -1;
            return b.updatedAt!.compareTo(a.updatedAt!);
          });

        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onRefreshCounts('unfinished', drafts.length);
          });
        }

        if (drafts.isEmpty) {
          return _DraftEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drafts.length,
          itemBuilder: (context, index) {
            return _EnrollmentDraftCard(
              draft: drafts[index],
              onDismissed: () => widget.onRefreshCounts(
                  'unfinished', (snapshot.data?.docs.length ?? 1) - 1),
            );
          },
        );
      },
    );
  }
}

class _EnrollmentDraftCard extends StatefulWidget {
  final _EnrollmentDraft draft;
  final VoidCallback onDismissed;

  const _EnrollmentDraftCard({
    required this.draft,
    required this.onDismissed,
  });

  @override
  State<_EnrollmentDraftCard> createState() => _EnrollmentDraftCardState();
}

class _EnrollmentDraftCardState extends State<_EnrollmentDraftCard> {
  bool _isDismissing = false;

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final progress = draft.progressStep / 5;
    final whatsAppDigits = draft.whatsApp.replaceAll(RegExp(r'[^\d]'), '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffFDE68A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xffFFFBEB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_bottom_rounded,
                    size: 14, color: Color(0xffB45309)),
                const SizedBox(width: 8),
                Text(
                  'UNFINISHED APPLICATION',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xffB45309),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  draft.updatedAt == null
                      ? ''
                      : 'Last active ${_relativeTime(draft.updatedAt!)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xffB45309),
                  ),
                ),
              ],
            ),
          ),
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
                            draft.primaryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            draft.programSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xff64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _DraftQuickActions(
                      email: draft.email,
                      phone: draft.phone,
                      whatsAppDigits: whatsAppDigits,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stopped at: ${draft.stepTitle.isNotEmpty ? draft.stepTitle : 'Step ${draft.progressStep}'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff92400E),
                      ),
                    ),
                    Text(
                      '${draft.progressStep} of 5 steps',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress,
                    backgroundColor: const Color(0xffFEF3C7),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xffF59E0B)),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _DraftInfoChip(icon: Icons.mail_outline, text: draft.email),
                    _DraftInfoChip(
                        icon: Icons.phone_outlined, text: draft.bestPhone),
                    _DraftInfoChip(
                        icon: Icons.people_outline,
                        text: draft.parentName.isEmpty
                            ? ''
                            : 'Parent: ${draft.parentName}'),
                    _DraftInfoChip(
                        icon: Icons.school_outlined,
                        text: draft.city.isNotEmpty
                            ? draft.city
                            : draft.timeZone),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Dismiss unfinished application',
                      onPressed: _isDismissing ? null : _dismissDraft,
                      icon: _isDismissing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.archive_outlined),
                      color: const Color(0xff94A3B8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildFollowUpButton(draft, whatsAppDigits)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpButton(_EnrollmentDraft draft, String whatsAppDigits) {
    if (draft.email.isNotEmpty) {
      return _DraftPrimaryAction(
        icon: Icons.mail_outline,
        label: 'Follow Up by Email',
        color: const Color(0xffF59E0B),
        onPressed: () => _launch(Uri(
          scheme: 'mailto',
          path: draft.email,
          query: _encodeQueryParameters({
            'subject': 'Finish your Alluwal Education Hub enrollment',
          }),
        )),
      );
    }

    if (whatsAppDigits.isNotEmpty) {
      return _DraftPrimaryAction(
        icon: Icons.chat_bubble_outline,
        label: 'Follow Up on WhatsApp',
        color: const Color(0xff059669),
        onPressed: () => _launch(Uri.parse('https://wa.me/$whatsAppDigits')),
      );
    }

    if (draft.phone.isNotEmpty) {
      return _DraftPrimaryAction(
        icon: Icons.phone_outlined,
        label: 'Call to Follow Up',
        color: const Color(0xff2563EB),
        onPressed: () => _launch(Uri(scheme: 'tel', path: draft.phone)),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'No contact info yet',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xff94A3B8),
        ),
      ),
    );
  }

  Future<void> _dismissDraft() async {
    setState(() => _isDismissing = true);
    try {
      await FirebaseFirestore.instance
          .collection('enrollment_drafts')
          .doc(widget.draft.id)
          .update({
        'status': 'dismissed',
        'dismissedAt': FieldValue.serverTimestamp(),
      });
      widget.onDismissed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unfinished application dismissed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not dismiss unfinished application: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDismissing = false);
    }
  }
}

class _DraftQuickActions extends StatelessWidget {
  final String email;
  final String phone;
  final String whatsAppDigits;

  const _DraftQuickActions({
    required this.email,
    required this.phone,
    required this.whatsAppDigits,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (email.isNotEmpty)
          _DraftIconButton(
            icon: Icons.mail_outline,
            color: const Color(0xff4F46E5),
            backgroundColor: const Color(0xffEEF2FF),
            tooltip: 'Email $email',
            onPressed: () => _launch(Uri(scheme: 'mailto', path: email)),
          ),
        if (whatsAppDigits.isNotEmpty)
          _DraftIconButton(
            icon: Icons.chat_bubble_outline,
            color: const Color(0xff059669),
            backgroundColor: const Color(0xffECFDF5),
            tooltip: 'WhatsApp',
            onPressed: () =>
                _launch(Uri.parse('https://wa.me/$whatsAppDigits')),
          ),
        if (phone.isNotEmpty)
          _DraftIconButton(
            icon: Icons.phone_outlined,
            color: const Color(0xff2563EB),
            backgroundColor: const Color(0xffEFF6FF),
            tooltip: 'Call $phone',
            onPressed: () => _launch(Uri(scheme: 'tel', path: phone)),
          ),
      ],
    );
  }
}

class _DraftIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String tooltip;
  final VoidCallback onPressed;

  const _DraftIconButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}

class _DraftInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DraftInfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xff94A3B8)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xff475569),
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftPrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _DraftPrimaryAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: color,
          foregroundColor: Colors.white,
          textStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _DraftEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No unfinished applications',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Partially completed enrollment forms will appear here.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
          ),
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

class _EnrollmentListState extends State<_EnrollmentList>
    with AutomaticKeepAliveClientMixin {
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
            child: Text(AppLocalizations.of(context)!
                .commonErrorWithDetails(snapshot.error ?? 'Unknown error')),
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
    if (_stream == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
                Icon(Icons.handshake_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No matched enrollments yet',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'When a teacher accepts a broadcast, it will appear here',
                  style:
                      GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
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
