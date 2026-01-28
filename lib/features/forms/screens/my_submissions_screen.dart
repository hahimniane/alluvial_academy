import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/form_labels_cache_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../widgets/form_details_modal.dart';

/// Screen for teachers to view their own form submissions (read-only)
/// Now supports month filtering for better organization
class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _mySubmissions = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, List<QueryDocumentSnapshot>> _groupedSubmissions = {};
  Map<String, String> _formTitles = {};
  
  // Month filtering - default to current month
  late String _selectedYearMonth;
  List<String> _availableMonths = [];
  bool _showAllMonths = false;

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _selectedYearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _loadMySubmissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  /// Get display name for yearMonth (e.g., "January 2026")
  String _getMonthDisplayName(String yearMonth) {
    try {
      final parts = yearMonth.split('-');
      if (parts.length != 2) return yearMonth;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = DateTime(year, month, 1);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return yearMonth;
    }
  }

  Future<void> _loadMySubmissions() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Query all form submissions by current user
      final snapshot = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('userId', isEqualTo: user.uid)
          .orderBy('submittedAt', descending: true)
          .get();

      if (!mounted) return;

      // Collect available months and group submissions
      final monthsSet = <String>{};
      final grouped = <String, List<QueryDocumentSnapshot>>{};
      final titles = <String, String>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final formId = data['formId'] as String?;
        
        // Extract yearMonth from doc (or derive from submittedAt)
        String? yearMonth = data['yearMonth'] as String?;
        if (yearMonth == null) {
          // Derive from submittedAt for backward compatibility
          final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
          if (submittedAt != null) {
            yearMonth = '${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}';
          }
        }
        
        if (yearMonth != null) {
          monthsSet.add(yearMonth);
        }
        
        // Filter by selected month (unless showing all)
        if (!_showAllMonths && yearMonth != _selectedYearMonth) {
          continue;
        }
        
        if (formId != null) {
          if (!grouped.containsKey(formId)) {
            grouped[formId] = [];
            // Fetch form title
            final title = await _getFormTitle(data, formId);
            titles[formId] = title;
          }
          grouped[formId]!.add(doc);
        }
      }
      
      // Sort months in descending order (most recent first)
      final sortedMonths = monthsSet.toList()..sort((a, b) => b.compareTo(a));

      setState(() {
        _mySubmissions = snapshot.docs;
        _groupedSubmissions = grouped;
        _formTitles = titles;
        _availableMonths = sortedMonths;
        _isLoading = false;
      });

      AppLogger.debug('MySubmissions: Loaded ${_mySubmissions.length} total submissions');
      AppLogger.debug('MySubmissions: Showing ${grouped.values.fold(0, (sum, list) => sum + list.length)} for $_selectedYearMonth');
      AppLogger.debug('MySubmissions: Available months: $sortedMonths');
    } catch (e) {
      AppLogger.error('Error loading my submissions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorLoadingSubmissionsE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, List<QueryDocumentSnapshot>> get _filteredGroupedSubmissions {
    if (_searchQuery.isEmpty) return _groupedSubmissions;

    final filtered = <String, List<QueryDocumentSnapshot>>{};
    
    _groupedSubmissions.forEach((formId, submissions) {
      final formTitle = (_formTitles[formId] ?? '').toLowerCase();
      
      // Check if form title matches search
      if (formTitle.contains(_searchQuery.toLowerCase())) {
        filtered[formId] = submissions;
      } else {
        // Check if any submission status matches
        final matchingSubmissions = submissions.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          return status.contains(_searchQuery.toLowerCase());
        }).toList();
        
        if (matchingSubmissions.isNotEmpty) {
          filtered[formId] = matchingSubmissions;
        }
      }
    });
    
    return filtered;
  }
  
  /// Show month picker dialog
  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
              ),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.formSelectMonth,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // "All Time" option
            ListTile(
              leading: Icon(
                Icons.all_inclusive,
                color: _showAllMonths ? const Color(0xff0386FF) : const Color(0xff64748B),
              ),
              title: Text(
                AppLocalizations.of(context)!.timesheetAllTime,
                style: GoogleFonts.inter(
                  fontWeight: _showAllMonths ? FontWeight.w600 : FontWeight.w400,
                  color: _showAllMonths ? const Color(0xff0386FF) : const Color(0xff1E293B),
                ),
              ),
              trailing: _showAllMonths 
                  ? const Icon(Icons.check, color: Color(0xff0386FF))
                  : null,
              onTap: () {
                Navigator.pop(context);
                setState(() => _showAllMonths = true);
                _loadMySubmissions();
              },
            ),
            
            const Divider(height: 1),
            
            // Month options
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableMonths.length,
                itemBuilder: (context, index) {
                  final month = _availableMonths[index];
                  final isSelected = !_showAllMonths && month == _selectedYearMonth;
                  
                  // Check if this is current month
                  final now = DateTime.now();
                  final currentYearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                  final isCurrent = month == currentYearMonth;
                  
                  return ListTile(
                    leading: Icon(
                      Icons.calendar_today,
                      color: isSelected ? const Color(0xff0386FF) : const Color(0xff64748B),
                    ),
                    title: Row(
                      children: [
                        Text(
                          _getMonthDisplayName(month),
                          style: GoogleFonts.inter(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? const Color(0xff0386FF) : const Color(0xff1E293B),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xff10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.formCurrentMonth,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff10B981),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: isSelected 
                        ? const Icon(Icons.check, color: Color(0xff0386FF))
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedYearMonth = month;
                        _showAllMonths = false;
                      });
                      _loadMySubmissions();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getFormTitle(Map<String, dynamic> data, String? formId) async {
    // Try to get title from the stored data first
    final storedTitle = data['formTitle'] ??
        data['form_title'] ??
        data['title'];

    if (storedTitle != null &&
        storedTitle.toString().isNotEmpty &&
        storedTitle.toString() != 'Untitled Form') {
      return storedTitle.toString();
    }

    final templateId = (data['templateId'] as String?)?.trim();
    final idToTry = templateId ?? formId;

    if (idToTry != null && idToTry.isNotEmpty) {
      try {
        // Prefer form_templates (new system) for known template ids
        final templateDoc = await FirebaseFirestore.instance
            .collection('form_templates')
            .doc(idToTry)
            .get();
        if (templateDoc.exists) {
          final d = templateDoc.data();
          final name = d?['name'] ?? d?['title'];
          if (name != null && name.toString().isNotEmpty) {
            return name.toString();
          }
        }

        // Fallback to form collection
        final formDoc = await FirebaseFirestore.instance
            .collection('form')
            .doc(idToTry)
            .get();
        if (formDoc.exists) {
          final formData = formDoc.data();
          final title = formData?['title'] ?? formData?['formTitle'];
          if (title != null && title.toString().isNotEmpty) {
            return title.toString();
          }
        }
      } catch (e) {
        AppLogger.debug('Error fetching form title: $e');
      }
    }

    return 'Form Submission';
  }

  @override
  Widget build(BuildContext context) {
    // Count submissions for current month display
    final currentMonthCount = _groupedSubmissions.values.fold(0, (sum, list) => sum + list.length);
    
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.formMySubmissions,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
        actions: [
          // Month filter toggle
          if (!_isLoading)
            TextButton.icon(
              onPressed: () => _showMonthPicker(),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(
                _showAllMonths ? 'All Time' : _getMonthDisplayName(_selectedYearMonth),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xffE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          // Month summary banner
          if (!_isLoading && !_showAllMonths)
            Container(
              color: const Color(0xffEFF6FF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      size: 20,
                      color: Color(0xff0386FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getMonthDisplayName(_selectedYearMonth),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff1E293B),
                          ),
                        ),
                        Text(
                          '$currentMonthCount ${currentMonthCount == 1 ? 'submission' : 'submissions'} this month',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _showAllMonths = true);
                      _loadMySubmissions();
                    },
                    child: Text(
                      AppLocalizations.of(context)!.formViewAll,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff0386FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.formSearchByName,
                hintStyle: GoogleFonts.inter(color: const Color(0xff94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xff64748B)),
                filled: true,
                fillColor: const Color(0xffF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xff0386FF),
                    ),
                  )
                : _filteredGroupedSubmissions.isEmpty
                    ? _buildEmptyState()
                    : _buildSubmissionsList(),
          ),
        ],
      ),
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
            _searchQuery.isEmpty
                ? 'No form submissions yet'
                : 'No results found',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xff1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Your submitted forms will appear here'
                : 'Try adjusting your search',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xff64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsList() {
    final groupedSubmissions = _filteredGroupedSubmissions;
    final formIds = groupedSubmissions.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: formIds.length,
      itemBuilder: (context, index) {
        final formId = formIds[index];
        final submissions = groupedSubmissions[formId]!;
        final formTitle = _formTitles[formId] ?? 'Form';
        return _buildFormGroupCard(formId, formTitle, submissions);
      },
    );
  }

  Widget _buildFormGroupCard(String formId, String formTitle, List<QueryDocumentSnapshot> submissions) {
    // Get most recent submission date
    final latestSubmission = submissions.first;
    final latestData = latestSubmission.data() as Map<String, dynamic>;
    final latestDate = (latestData['submittedAt'] as Timestamp?)?.toDate();

    // Count completed submissions
    final completedCount = submissions.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['status'] ?? '').toString().toLowerCase() == 'completed';
    }).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xffE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _showFormSubmissions(formId, formTitle, submissions),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xff0386FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_outlined,
                  size: 24,
                  color: Color(0xff0386FF),
                ),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formTitle,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.assignment_outlined,
                                size: 14,
                                color: Color(0xff64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${submissions.length} ${submissions.length == 1 ? 'submission' : 'submissions'}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xff64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (completedCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Color(0xff16A34A),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppLocalizations.of(context)!.completedcountCompleted,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xff16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (latestDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Last submitted ${DateFormat('MMM d, yyyy').format(latestDate)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Arrow
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xff94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFormSubmissions(String formId, String formTitle, List<QueryDocumentSnapshot> submissions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormSubmissionsSheet(
        formTitle: formTitle,
        submissions: submissions,
        onViewDetails: _viewSubmissionDetails,
      ),
    );
  }

  Widget _buildSubmissionCard(String submissionId, Map<String, dynamic> data) {
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final status = (data['status'] ?? 'completed').toString();
    final responses = data['responses'] as Map<String, dynamic>?;
    final formId = data['formId'] as String?;

    return FutureBuilder<String>(
      future: _getFormTitle(data, formId),
      builder: (context, snapshot) {
        final formTitle = snapshot.data ?? 'Loading...';
        
        return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xffE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _viewSubmissionDetails(submissionId, formTitle, data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xff0386FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description,
                      size: 20,
                      color: Color(0xff0386FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formTitle,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          submittedAt != null
                              ? 'Submitted ${DateFormat('MMM d, yyyy • h:mm a').format(submittedAt)}'
                              : 'Date unknown',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xff64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              if (responses != null && responses.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.question_answer,
                        size: 16,
                        color: Color(0xff64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${responses.length} responses',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff475569),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        AppLocalizations.of(context)!.formTapToView,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff0386FF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Color(0xff0386FF),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    final isCompleted = status.toLowerCase() == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xffDCFCE7)
            : const Color(0xffFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.pending,
            size: 14,
            color: isCompleted
                ? const Color(0xff16A34A)
                : const Color(0xffF59E0B),
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isCompleted
                  ? const Color(0xff16A34A)
                  : const Color(0xffF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  void _viewSubmissionDetails(
      String submissionId, String formTitle, Map<String, dynamic> data) {
    final shiftId = (data['shiftId'] ?? data['shift_id'])?.toString() ?? '';
    final hasShift = shiftId.isNotEmpty && shiftId != 'N/A';
    final responses = data['responses'] as Map<String, dynamic>? ?? {};

    if (hasShift) {
      FormDetailsModal.show(
        context,
        formId: submissionId,
        shiftId: shiftId,
        responses: responses,
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _SubmissionDetailView(
          submissionId: submissionId,
          formTitle: formTitle,
          data: data,
        ),
      );
    }
  }
}

/// Bottom sheet to view submission details (read-only)
class _SubmissionDetailView extends StatefulWidget {
  final String submissionId;
  final String formTitle;
  final Map<String, dynamic> data;

  const _SubmissionDetailView({
    required this.submissionId,
    required this.formTitle,
    required this.data,
  });

  @override
  State<_SubmissionDetailView> createState() => _SubmissionDetailViewState();
}

class _SubmissionDetailViewState extends State<_SubmissionDetailView> {
  Map<String, String> _fieldLabels = {};
  bool _isLoadingLabels = true;

  @override
  void initState() {
    super.initState();
    _loadFormTemplate();
  }

  Future<void> _loadFormTemplate() async {
    try {
      // Use FormLabelsCacheService which handles both old form system and new template system
      // It will automatically fetch the form response document and extract templateId/formId
      AppLogger.debug('Loading form labels for submission: ${widget.submissionId}');
      
      final labels = await FormLabelsCacheService().getLabelsForFormResponse(widget.submissionId);
      
      AppLogger.debug('Loaded ${labels.length} field labels for submission ${widget.submissionId}');
      
      if (mounted) {
        setState(() {
          _fieldLabels = labels;
          _isLoadingLabels = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error loading form template: $e', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isLoadingLabels = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responses = widget.data['responses'] as Map<String, dynamic>? ?? {};
    final submittedAt = (widget.data['submittedAt'] as Timestamp?)?.toDate();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xffE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xffE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.formTitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xff1E293B),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.visibility_outlined,
                                      size: 14,
                                      color: Color(0xff0386FF),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppLocalizations.of(context)!.formReadOnly,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xff0386FF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            submittedAt != null
                                ? 'Submitted on ${DateFormat('MMMM d, yyyy at h:mm a').format(submittedAt)}'
                                : 'Submission date unknown',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xff64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: const Color(0xff64748B),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoadingLabels
                    ? Center(
                        child: CircularProgressIndicator(),
                      )
                    : responses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.inbox_outlined,
                                  size: 64,
                                  color: Color(0xff94A3B8),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppLocalizations.of(context)!.noResponsesRecorded,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xff64748B),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(20),
                            itemCount: responses.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final entry = responses.entries.elementAt(index);
                              final fieldId = entry.key;
                              final fieldLabel = _fieldLabels[fieldId] ?? fieldId;
                              return _buildResponseField(
                                  fieldLabel, entry.value, index + 1);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResponseField(String fieldLabel, dynamic value, int questionNumber) {
    // Handle different response types
    String displayValue = '';
    if (value is List) {
      displayValue = value.join(', ');
    } else if (value is Map) {
      displayValue = value.toString();
    } else {
      displayValue = value?.toString() ?? '(No answer)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xff0386FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    questionNumber.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fieldLabel,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffE2E8F0)),
                      ),
                      child: Text(
                        displayValue,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff1E293B),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Summary for list display (student names, day/date)
class _ShiftSummary {
  final String dayDate; // e.g. "Wed, Jan 28, 2026"
  final List<String> studentNames;
  _ShiftSummary({required this.dayDate, required this.studentNames});
}

/// Modernized Bottom Sheet for viewing submissions
class _FormSubmissionsSheet extends StatefulWidget {
  final String formTitle;
  final List<QueryDocumentSnapshot> submissions;
  final Function(String, String, Map<String, dynamic>) onViewDetails;

  const _FormSubmissionsSheet({
    required this.formTitle,
    required this.submissions,
    required this.onViewDetails,
  });

  @override
  State<_FormSubmissionsSheet> createState() => _FormSubmissionsSheetState();
}

class _FormSubmissionsSheetState extends State<_FormSubmissionsSheet> {
  String _dateRange = 'all';
  Map<String, _ShiftSummary> _shiftSummaries = {};
  bool _loadingShifts = true;

  bool get _isDailyClassReport {
    final title = widget.formTitle.toLowerCase();
    if (title.contains('daily') || title.contains('class report')) return true;
    if (widget.submissions.isEmpty) return false;
    final first = widget.submissions.first.data() as Map<String, dynamic>?;
    final tid = (first?['templateId'] ?? first?['template_id'])?.toString().toLowerCase();
    return tid == 'daily_class_report';
  }

  @override
  void initState() {
    super.initState();
    _loadShiftSummaries();
  }

  Future<void> _loadShiftSummaries() async {
    final ids = <String>{};
    for (final doc in widget.submissions) {
      final d = doc.data() as Map<String, dynamic>;
      final id = (d['shiftId'] ?? d['shift_id'])?.toString();
      if (id != null && id.isNotEmpty && id != 'N/A') ids.add(id);
    }
    if (ids.isEmpty) {
      if (mounted) setState(() => _loadingShifts = false);
      return;
    }
    final map = <String, _ShiftSummary>{};
    try {
      for (final shiftId in ids) {
        final snap = await FirebaseFirestore.instance
            .collection('teaching_shifts')
            .doc(shiftId)
            .get();
        if (snap.exists) {
          final shift = TeachingShift.fromFirestore(snap);
          final dayDate = DateFormat('EEE, MMM d').format(shift.shiftStart);
          map[shiftId] = _ShiftSummary(
            dayDate: dayDate,
            studentNames: List.from(shift.studentNames),
          );
        }
      }
    } catch (e) {
      AppLogger.debug('MySubmissions: could not load some shifts: $e');
    }
    if (mounted) {
      setState(() {
        _shiftSummaries = map;
        _loadingShifts = false;
      });
    }
  }

  List<QueryDocumentSnapshot> get _filteredSubmissions {
    if (_dateRange == 'all') return widget.submissions;
    final now = DateTime.now();
    DateTime start;
    switch (_dateRange) {
      case '7':
        start = now.subtract(const Duration(days: 7));
        break;
      case '30':
        start = now.subtract(const Duration(days: 30));
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        break;
      default:
        return widget.submissions;
    }
    return widget.submissions.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final t = data['submittedAt'] as Timestamp?;
      if (t == null) return false;
      return t.toDate().isAfter(start.subtract(const Duration(seconds: 1)));
    }).toList();
  }

  Map<String, List<QueryDocumentSnapshot>> get _groupedByStudent {
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in _filteredSubmissions) {
      final data = doc.data() as Map<String, dynamic>;
      final shiftId = (data['shiftId'] ?? data['shift_id'])?.toString();
      String studentName = 'General / Other';
      if (shiftId != null && _shiftSummaries.containsKey(shiftId)) {
        final names = _shiftSummaries[shiftId]!.studentNames;
        if (names.isNotEmpty) studentName = names.first;
      }
      grouped.putIfAbsent(studentName, () => []).add(doc);
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) {
          if (a.key.contains('Other')) return 1;
          if (b.key.contains('Other')) return -1;
          return a.key.compareTo(b.key);
        }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xffF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.formTitle,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff1E293B),
                            ),
                          ),
                          Text(
                            _isDailyClassReport
                                ? 'Organized by student'
                                : '${widget.submissions.length} total submissions',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xff64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffF1F5F9),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        color: const Color(0xff64748B),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xffE2E8F0)),
              Expanded(
                child: _isDailyClassReport
                    ? _buildDailyReportView(scrollController)
                    : _buildLegacyListView(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyReportView(ScrollController scrollController) {
    if (_loadingShifts) {
      return const Center(child: CircularProgressIndicator(color: Color(0xff0386FF)));
    }
    final grouped = _groupedByStudent;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('Last 7 Days', '7'),
                const SizedBox(width: 8),
                _buildFilterChip('Last 30 Days', '30'),
                const SizedBox(width: 8),
                _buildFilterChip('This Month', 'month'),
                const SizedBox(width: 8),
                _buildFilterChip('All Time', 'all'),
              ],
            ),
          ),
        ),
        Expanded(
          child: grouped.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final studentName = grouped.keys.elementAt(index);
                    final studentSubmissions = grouped[studentName]!;
                    return _buildStudentGroupCard(studentName, studentSubmissions);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStudentGroupCard(String studentName, List<QueryDocumentSnapshot> docs) {
    final completed = docs.where((d) => (d.data() as Map)['status'] == 'completed').length;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff64748B).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xffEFF6FF),
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      color: const Color(0xff0386FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xffF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${docs.length} Entries',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (completed == docs.length)
                            Text(
                              '100% Completed',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xff16A34A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffF1F5F9)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (context, i) => const Divider(
              height: 1,
              indent: 56,
              color: Color(0xffF8FAFC),
            ),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildTimelineItem(doc);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final shiftId = (data['shiftId'] ?? data['shift_id'])?.toString();
    final summary = shiftId != null ? _shiftSummaries[shiftId] : null;
    final dateStr = summary?.dayDate ??
        (submittedAt != null ? DateFormat('MMM d').format(submittedAt) : 'Unknown');
    final timeStr = submittedAt != null ? DateFormat('h:mm a').format(submittedAt) : '';
    final dayPart = dateStr.contains(',') ? dateStr.split(',')[0].trim() : dateStr;
    return InkWell(
      onTap: () => widget.onViewDetails(doc.id, widget.formTitle, data),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayPart,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff94A3B8),
                    ),
                  ),
                  Text(
                    submittedAt != null ? submittedAt.day.toString() : '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff475569),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 2,
              height: 30,
              color: const Color(0xffE2E8F0),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary?.dayDate ?? 'Submission',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff334155),
                    ),
                  ),
                  Text(
                    'Submitted at $timeStr',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xffF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffBAE6FD).withOpacity(0.5)),
              ),
              child: const Icon(
                Icons.visibility_outlined,
                size: 18,
                color: Color(0xff0284C7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _dateRange == value;
    return GestureDetector(
      onTap: () => setState(() => _dateRange = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff0386FF) : const Color(0xffF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xff0386FF) : const Color(0xffE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xff64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLegacyListView(ScrollController scrollController) {
    final list = _filteredSubmissions;
    if (list.isEmpty) return _buildEmptyState();
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = list[index];
        final data = doc.data() as Map<String, dynamic>;
        final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
        final status = (data['status'] ?? 'completed').toString();
        final shiftId = (data['shiftId'] ?? data['shift_id'])?.toString();
        final summary = shiftId != null && shiftId.isNotEmpty ? _shiftSummaries[shiftId] : null;
        // Prefer class date (shift date) when available; always show submission time
        final String dateTitle = summary != null
            ? 'Class: ${summary.dayDate}'
            : (submittedAt != null ? DateFormat('EEE, MMM d, yyyy').format(submittedAt) : 'Date unknown');
        final String subtitleText = submittedAt != null
            ? 'Submitted ${DateFormat('MMM d').format(submittedAt)} at ${DateFormat('h:mm a').format(submittedAt)}'
            : '';
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: ListTile(
            onTap: () => widget.onViewDetails(doc.id, widget.formTitle, data),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xffF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_today, size: 20, color: Color(0xff64748B)),
            ),
            title: Text(
              dateTitle,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xff1E293B),
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              subtitleText,
              style: GoogleFonts.inter(
                color: const Color(0xff94A3B8),
                fontSize: 13,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status.toLowerCase() == 'completed')
                  const Icon(Icons.check_circle, size: 16, color: Color(0xff16A34A)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xffCBD5E1)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No submissions found',
            style: GoogleFonts.inter(
              color: const Color(0xff94A3B8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
