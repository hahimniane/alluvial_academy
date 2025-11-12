import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Screen for teachers to view their own form submissions (read-only)
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

  @override
  void initState() {
    super.initState();
    _loadMySubmissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      // Group submissions by formId
      final grouped = <String, List<QueryDocumentSnapshot>>{};
      final titles = <String, String>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final formId = data['formId'] as String?;
        
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

      setState(() {
        _mySubmissions = snapshot.docs;
        _groupedSubmissions = grouped;
        _formTitles = titles;
        _isLoading = false;
      });

      AppLogger.debug('MySubmissions: Loaded ${_mySubmissions.length} submissions, grouped into ${grouped.length} forms');
    } catch (e) {
      AppLogger.error('Error loading my submissions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading submissions: $e'),
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

  Future<String> _getFormTitle(Map<String, dynamic> data, String? formId) async {
    // Try to get title from the stored data first
    final storedTitle = data['formTitle'] ?? 
                       data['form_title'] ?? 
                       data['title'];
    
    if (storedTitle != null && storedTitle.toString().isNotEmpty && 
        storedTitle.toString() != 'Untitled Form') {
      return storedTitle.toString();
    }

    // If no title or it's "Untitled Form", fetch from form template
    if (formId != null && formId.isNotEmpty) {
      try {
        final formDoc = await FirebaseFirestore.instance
            .collection('form')
            .doc(formId)
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
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Form Submissions',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
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
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by form name or status',
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
                                  '$completedCount completed',
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
                        'Tap to view',
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
      final formId = widget.data['formId'] as String?;
      AppLogger.debug('Loading form template for formId: $formId');
      
      if (formId == null) {
        setState(() => _isLoadingLabels = false);
        return;
      }

      final formDoc = await FirebaseFirestore.instance
          .collection('form')
          .doc(formId)
          .get();

      if (!formDoc.exists) {
        AppLogger.warning('Form document not found for formId: $formId');
        setState(() => _isLoadingLabels = false);
        return;
      }

      final formData = formDoc.data();
      AppLogger.debug('Form data structure: ${formData?.keys.toList()}');
      
      final fieldsData = formData?['fields'];
      AppLogger.debug('Fields data type: ${fieldsData.runtimeType}');

      final labels = <String, String>{};
      
      // Handle both Map and List structures
      if (fieldsData is Map<String, dynamic>) {
        // Fields stored as a map where key is field ID
        AppLogger.debug('Found ${fieldsData.length} fields in form (Map structure)');
        
        for (var entry in fieldsData.entries) {
          final fieldId = entry.key;
          final field = entry.value as Map<String, dynamic>?;
          
          if (field != null) {
            AppLogger.debug('Field $fieldId structure: ${field.keys.toList()}');
            final label = field['label'] as String?;
            final question = field['question'] as String?;
            final placeholderLabel = field['placeholderLabel'] as String?;
            
            AppLogger.debug('Field: id=$fieldId, label=$label, question=$question, placeholderLabel=$placeholderLabel');
            
            // Try label first, then question, then placeholderLabel, then fall back to id
            labels[fieldId] = label ?? question ?? placeholderLabel ?? fieldId;
          }
        }
      } else if (fieldsData is List<dynamic>) {
        // Fields stored as a list (legacy structure)
        AppLogger.debug('Found ${fieldsData.length} fields in form (List structure)');
        
        for (var field in fieldsData) {
          if (field is Map<String, dynamic>) {
            AppLogger.debug('Field structure: ${field.keys.toList()}');
            final id = field['id'] as String?;
            final label = field['label'] as String?;
            final question = field['question'] as String?;
            final placeholderLabel = field['placeholderLabel'] as String?;
            
            AppLogger.debug('Field: id=$id, label=$label, question=$question, placeholderLabel=$placeholderLabel');
            
            if (id != null) {
              labels[id] = label ?? question ?? placeholderLabel ?? id;
            }
          }
        }
      }

      AppLogger.debug('Loaded ${labels.length} field labels: $labels');
      
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
                                      'Read Only',
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
                    ? const Center(
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
                                  'No responses recorded',
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

/// Bottom sheet to show all submissions for a specific form
class _FormSubmissionsSheet extends StatelessWidget {
  final String formTitle;
  final List<QueryDocumentSnapshot> submissions;
  final Function(String, String, Map<String, dynamic>) onViewDetails;

  const _FormSubmissionsSheet({
    required this.formTitle,
    required this.submissions,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
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
                          Text(
                            formTitle,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${submissions.length} ${submissions.length == 1 ? 'submission' : 'submissions'}',
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

              // Submissions list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: submissions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = submissions[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildSubmissionItem(context, doc.id, data);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmissionItem(BuildContext context, String submissionId, Map<String, dynamic> data) {
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final status = (data['status'] ?? 'completed').toString();
    final responses = data['responses'] as Map<String, dynamic>?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xffE2E8F0)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onViewDetails(submissionId, formTitle, data);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
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
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            submittedAt != null
                                ? DateFormat('MMM d, yyyy • h:mm a').format(submittedAt)
                                : 'Unknown date',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff1E293B),
                            ),
                          ),
                        ),
                        _statusBadge(status),
                      ],
                    ),
                    if (responses != null && responses.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.question_answer,
                            size: 14,
                            color: Color(0xff64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${responses.length} ${responses.length == 1 ? 'response' : 'responses'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xff64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Arrow
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xff94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isCompleted = status.toLowerCase() == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            size: 12,
            color: isCompleted
                ? const Color(0xff16A34A)
                : const Color(0xffF59E0B),
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 11,
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
}

