// Conditional import - uses dart:html on web, stub on other platforms
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utility_functions/export_helpers.dart';
import '../../../core/services/user_role_service.dart';
import '../widgets/form_submissions_dialog.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class FormResponsesScreen extends StatefulWidget {
  const FormResponsesScreen({super.key});

  @override
  State<FormResponsesScreen> createState() => _FormResponsesScreenState();
}

class _FormResponsesScreenState extends State<FormResponsesScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _selectedTab = 'Active';
  late TabController _tabController;
  bool _isLoading = true;
  String? _userRole;
  String? _userEmail;
  List<QueryDocumentSnapshot> _allResponses = [];
  Map<String, DocumentSnapshot> _formTemplates = {};
  Map<String, int> _formIdToEntries = {};
  List<String> _filteredFormIds = [];
  final Map<String, String> _uidToFullName = {}; // cache

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedTab = _tabController.index == 0 ? 'Active' : 'Archived';
      });
      _filterForms();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUserData();
    });
  }

  @override
  void didUpdateWidget(FormResponsesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.key != oldWidget.key) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final role = await UserRoleService.getCurrentUserRole();

      if (mounted) {
        setState(() {
          _userRole = role;
          _userEmail = user.email;
        });
      }

      await _loadFormResponses();
    } catch (e) {
      AppLogger.error('Error loading user data: $e');
      await _loadFormResponses();
    }
  }

  // After loading data, compute counts and filter
  Future<void> _loadFormResponses() async {
      setState(() => _isLoading = true);
    try {
      final formTemplatesSnapshot = await FirebaseFirestore.instance
          .collection('form')
          .get();

      _formTemplates = {
        for (var doc in formTemplatesSnapshot.docs) doc.id: doc,
      };
      // DEBUG: Template count
      // ignore: avoid_print
      AppLogger.info('[FormResponses] Loaded ${_formTemplates.length} form templates');

      // Always aggregate counts across all responses to ensure "Entries" is accurate
      Query query = FirebaseFirestore.instance
          .collection('form_responses')
            .orderBy('submittedAt', descending: true);
      final responsesSnapshot = await query.get();

          _allResponses = responsesSnapshot.docs;
      // DEBUG: Responses count
      // ignore: avoid_print
      AppLogger.info('[FormResponses] Loaded ${_allResponses.length} form_responses documents');

      // Aggregate entries per form (count every document with a valid formId)
      _formIdToEntries = {};
      final Set<String> uidsToFetch = {};
      int missingFormId = 0;
      for (final doc in _allResponses) {
          final data = doc.data() as Map<String, dynamic>;
        final formId = (data['formId'] ?? '').toString();
        if (formId.isEmpty) {
          missingFormId++;
          continue;
        }
        _formIdToEntries.update(formId, (v) => v + 1, ifAbsent: () => 1);
      }
      // DEBUG: Aggregation summary
      // ignore: avoid_print
      AppLogger.debug('[FormResponses] Aggregated entries for ${_formIdToEntries.length} forms (missing formId: $missingFormId)');
      int shown = 0;
      _formIdToEntries.forEach((id, count) {
        if (shown < 5) {
          final title = (_formTemplates[id]?.data() as Map<String, dynamic>?)?['title'] ?? 'Unknown';
          AppLogger.debug('  - $id → $count entries | $title');
          shown++;
        }
      });

      // Collect creator and assigned user ids from forms
      for (final form in _formTemplates.values) {
        final d = form.data() as Map<String, dynamic>;
        final createdBy = (d['createdBy'] ?? '').toString();
        if (createdBy.isNotEmpty) uidsToFetch.add(createdBy);
        final permissions = d['permissions'] as Map<String, dynamic>?;
        final users = permissions?['users'] as List<dynamic>?;
        if (users != null) {
          for (final u in users) {
            final id = u.toString();
            if (id.isNotEmpty) uidsToFetch.add(id);
          }
        }
      }

      // Fetch user names in one go (batched by 10)
      final ids = uidsToFetch.toList();
      for (int i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final u in snap.docs) {
          final ud = u.data();
          final first = (ud['first_name'] ?? ud['firstName'] ?? '').toString();
          final last = (ud['last_name'] ?? ud['lastName'] ?? '').toString();
          final display = (ud['displayName'] ?? '').toString();
          String name = [display, '$first $last'.trim()]
              .firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
          if (name.isEmpty) {
            final email = (ud['e-mail'] ?? ud['email'] ?? '').toString();
            name = email.isNotEmpty ? email.split('@').first : 'Unknown User';
          }
          _uidToFullName[u.id] = name;
        }
      }

      _filterForms();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterForms() {
    final search = _searchController.text.toLowerCase();
    final isArchivedTab = _selectedTab == 'Archived';

    final ids = <String>[];
    for (final entry in _formTemplates.entries) {
      final formId = entry.key;
      final data = entry.value.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'active').toString().toLowerCase();
      final isArchived = status == 'archived' || status == 'inactive';
      if (isArchivedTab != isArchived) continue;

      final title = (data['title'] ?? '').toString().toLowerCase();
      final createdByName = (data['createdByName'] ?? '').toString().toLowerCase();
      if (search.isNotEmpty &&
          !(title.contains(search) || createdByName.contains(search))) {
        continue;
      }
      ids.add(formId);
    }
    if (!mounted) return;
    setState(() => _filteredFormIds = ids);
  }

  void _exportResponses() {
    if (_filteredFormIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No form responses to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Prepare headers and rows for export
      final headers = <String>[
        'Form Title',
        'First Name',
        'Last Name',
        'Email',
        'Status',
        'Submitted At',
      ];

      final rows = _allResponses.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final formTemplate = _formTemplates[data['formId']];
        final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
        final submittedAtStr = submittedAt != null
            ? '${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}'
            : '';

        return <String>[
          (formTemplate != null ? (formTemplate['title'] ?? 'Untitled Form') : 'Untitled Form').toString(),
          (data['firstName'] ?? '').toString(),
          (data['lastName'] ?? '').toString(),
          (data['userEmail'] ?? '').toString(),
          (data['status'] ?? 'Completed').toString(),
          submittedAtStr,
        ];
    }).toList();

      ExportHelpers.showExportDialog(context, headers, rows, 'form_responses');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Export failed: $e'),
          backgroundColor: Colors.red,
      ),
    );
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xffE2E8F0)),
              ),
            ),
            child: _buildCleanTabInterface(),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                          color: Color(0xff0386FF),
                    ),
                  )
                : _filteredFormIds.isEmpty
                    ? _buildEmptyState()
                    : _buildResponsesTable(),
          ),
        ],
      ),
    );
  }

  // Header with TabBar (match user management style)
  Widget _buildCleanTabInterface() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
      children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.black54,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                tabs: [
                  Tab(text: 'Active (${_getActiveCount()})'),
                  Tab(text: 'Archived (${_getArchivedCount()})'),
                ],
              ),
              ),
            ),
            const SizedBox(width: 16),
          // Search
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by form or creator',
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xff64748B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => _filterForms(),
            ),
          ),
          const SizedBox(width: 12),
          // Export
            ElevatedButton.icon(
            onPressed: _exportResponses,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildResponsesTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
              color: Colors.white,
        borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
              ),
            ],
          ),
                  child: Column(
                    children: [
          // Header row
                          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xffFAFBFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Color(0xffE2E8F0), width: 1)),
            ),
            child: Row(
              children: [
                _th('FORM NAME', flex: 3),
                _th('STATUS', flex: 2),
                _th('ENTRIES', flex: 1),
                _th('ASSIGNED TO', flex: 2),
                _th('CREATED BY', flex: 2),
                _th('DATE CREATED', flex: 2),
              ],
            ),
          ),
          // Rows
                          Expanded(
            child: ListView.builder(
              itemCount: _filteredFormIds.length,
              itemBuilder: (context, index) {
                final formId = _filteredFormIds[index];
                final formDoc = _formTemplates[formId]!;
                final formData = formDoc.data() as Map<String, dynamic>;
                final title = (formData['title'] ?? 'Untitled Form').toString();
                final status = (formData['status'] ?? 'active').toString();
                final createdByName = _resolveCreatorName(formData);
                final createdAt = (formData['createdAt'] as Timestamp?)?.toDate();
                final entries = _resolveEntriesCount(formId, formData);
                final assignedTo = _resolveAssignedTo(formData);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openFormResponses(formId),
                    hoverColor: const Color(0xffF8FAFC),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: index == _filteredFormIds.length - 1 
                              ? Colors.transparent 
                              : const Color(0xffF1F5F9),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _td(
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff0386FF).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.description_outlined,
                                    size: 18,
                                    color: Color(0xff0386FF),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xff1E293B),
                                          height: 1.3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Form ID: ${formId.substring(0, formId.length > 8 ? 8 : formId.length)}...',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xff94A3B8),
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            flex: 3,
                          ),
                          _td(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _statusPill(status),
                            ),
                            flex: 2,
                          ),
                          _td(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: entries > 0 ? const Color(0xffEFF6FF) : const Color(0xffF9FAFB),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                entries.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: entries > 0 ? const Color(0xff0386FF) : const Color(0xff6B7280),
                                ),
                              ),
                            ),
                            flex: 1,
                          ),
                          _td(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assignedTo,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xff475569),
                                    height: 1.4,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            flex: 2,
                          ),
                          _td(
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff8B5CF6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      createdByName.isNotEmpty ? createdByName[0].toUpperCase() : '?',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xff8B5CF6),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    createdByName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xff475569),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            flex: 2,
                          ),
                          _td(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  createdAt != null
                                      ? '${_getMonthName(createdAt.month)} ${createdAt.day}, ${createdAt.year}'
                                      : '-',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xff475569),
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xff94A3B8),
                                    ),
                                  ),
                              ],
                            ),
                            flex: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
                                ),
                              ],
      ),
    );
  }

  // Helpers for table cells
  Widget _th(String text, {required int flex}) => Expanded(
        flex: flex,
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xff64748B),
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _td(Widget child, {required int flex}) => Expanded(flex: flex, child: child);

  Widget _statusPill(String statusRaw) {
    final s = statusRaw.toLowerCase();
    final isActive = s == 'active';
    final bg = isActive ? const Color(0xffDCFCE7) : const Color(0xffFEF2F2);
    final fg = isActive ? const Color(0xff16A34A) : const Color(0xffDC2626);
    final label = isActive ? 'Active' : 'Inactive';
    final icon = isActive ? Icons.check_circle : Icons.cancel;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _resolveCreatorName(Map<String, dynamic> formData) {
    final byName = (formData['createdByName'] ?? '').toString().trim();
    if (byName.isNotEmpty) return byName;
    final by = (formData['createdBy'] ?? '').toString();
    if (by.isEmpty) return 'Unknown User';
    return _uidToFullName[by] ?? 'Unknown User';
  }

  int _resolveEntriesCount(String formId, Map<String, dynamic> formData) {
    // Prefer live aggregated count first
    final agg = _formIdToEntries[formId] ?? 0;
    if (agg > 0) {
      // ignore: avoid_print
      AppLogger.debug('[FormResponses] entries(agg) formId=$formId -> $agg');
      return agg;
    }
    final rc = formData['responseCount'];
    if (rc is int && rc > 0) {
      // ignore: avoid_print
      AppLogger.debug('[FormResponses] entries(responseCount) formId=$formId -> $rc');
      return rc;
    }
    // If a responses map exists on the form doc
    final responsesObj = formData['responses'];
    if (responsesObj is Map) {
      final len = responsesObj.length;
      // ignore: avoid_print
      AppLogger.debug('[FormResponses] entries(responsesMap) formId=$formId -> $len');
      return len;
    }
    // Fallback to aggregated count from loaded responses
    // ignore: avoid_print
    AppLogger.debug('[FormResponses] entries(fallback) formId=$formId -> 0');
    return 0;
  }

  String _resolveAssignedTo(Map<String, dynamic> formData) {
    final permissions = formData['permissions'] as Map<String, dynamic>?;
    if (permissions == null || permissions['type'] != 'restricted') {
      return 'All users group';
    }
    final users = (permissions['users'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final role = (permissions['role'] ?? '').toString();
    if (users.isEmpty && role.isNotEmpty) {
      switch (role) {
        case 'students':
          return 'Students';
        case 'parents':
          return 'Parents';
        case 'teachers':
          return 'Teachers';
        case 'admins':
          return 'Admins';
        default:
          return role;
      }
    }
    if (users.isNotEmpty) {
      final first = _uidToFullName[users.first] ?? 'User';
      final extra = users.length - 1;
      return extra > 0 ? '$first +$extra others' : first;
    }
    return 'All users group';
  }

  int _getActiveCount() {
    int count = 0;
    for (final doc in _formTemplates.values) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'active').toString().toLowerCase();
      final isArchived = status == 'archived' || status == 'inactive';
      if (!isArchived) count++;
    }
    return count;
  }

  int _getArchivedCount() {
    int count = 0;
    for (final doc in _formTemplates.values) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'active').toString().toLowerCase();
      final isArchived = status == 'archived' || status == 'inactive';
      if (isArchived) count++;
    }
    return count;
  }

  void _openFormResponses(String formId) {
    final formData = _formTemplates[formId]?.data() as Map<String, dynamic>?;
    final title = (formData?['title'] ?? 'Form').toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(
        maxWidth: double.infinity,
        minWidth: double.infinity,
      ),
      builder: (_) => FormSubmissionsDialog(formId: formId, formTitle: title),
    );
  }

  Widget _buildEmptyState() {
    return Center(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
              color: const Color(0xffF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Color(0xff64748B),
            ),
          ),
          const SizedBox(height: 24),
                          Text(
            'No form responses found',
                            style: GoogleFonts.inter(
              fontSize: 20,
                              fontWeight: FontWeight.w600,
              color: const Color(0xff1E293B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
            _searchController.text.isNotEmpty
                ? 'Try adjusting your search criteria'
                : 'Form responses will appear here once submitted',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
              color: const Color(0xff64748B),
                                                ),
                                              ),
                                            ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}