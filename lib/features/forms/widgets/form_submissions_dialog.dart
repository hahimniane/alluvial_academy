import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/core/utils/app_search.dart';
import 'package:alluwalacademyadmin/core/utils/export_helpers.dart';
import '../../../core/utils/performance_logger.dart';
import '../utils/form_date_range_utils.dart';
import '../utils/form_review_status.dart';
import 'form_review_status_badge.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class FormSubmissionsDialog extends StatefulWidget {
  final String formId;
  final String formTitle;
  final List<String> formIds;
  final List<String> definitionIds;

  const FormSubmissionsDialog(
      {super.key,
      required this.formId,
      required this.formTitle,
      this.formIds = const [],
      this.definitionIds = const []});

  @override
  State<FormSubmissionsDialog> createState() => _FormSubmissionsDialogState();
}

class _FormSubmissionsDialogState extends State<FormSubmissionsDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _template = {};
  List<QueryDocumentSnapshot> _submissions = [];
  DateTimeRange? _dateRange;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  final Map<String, TextEditingController> _notesControllers = {};
  final Map<String, bool> _editingNotes = {};
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  int _rowsPerPage = 10;
  int _currentPage = 0;
  final Set<String> _notifyingSubmissionIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    // Initialize date range to last 30 days
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    final opId =
        PerformanceLogger.newOperationId('FormSubmissionsDialog._load');
    PerformanceLogger.startTimer(opId, metadata: {
      'form_id': widget.formId,
    });

    setState(() => _isLoading = true);
    try {
      final responsesStopwatch = Stopwatch()..start();
      final docs = await _loadSubmissionDocs();
      responsesStopwatch.stop();

      final templateStopwatch = Stopwatch()..start();
      final fieldsMap = await _loadFieldsMapForForm(docs);
      templateStopwatch.stop();

      PerformanceLogger.checkpoint(opId, 'template_loaded', metadata: {
        'query_time_ms': templateStopwatch.elapsedMilliseconds,
        'field_count': fieldsMap.length,
      });

      PerformanceLogger.checkpoint(opId, 'responses_loaded', metadata: {
        'query_time_ms': responsesStopwatch.elapsedMilliseconds,
        'submission_count': docs.length,
      });

      if (!mounted) return;
      setState(() {
        _template = {'fields': fieldsMap};
        _submissions = docs;
        _notesControllers.clear();
        _editingNotes.clear();
        // Initialize notes controllers for each submission
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final note = (data['adminNote'] ?? '').toString();
          _notesControllers[doc.id] = TextEditingController(text: note);
          _editingNotes[doc.id] = false;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
      PerformanceLogger.endTimer(opId, metadata: {
        'submission_count': _submissions.length,
      });
    }
  }

  Future<Map<String, dynamic>> _loadFieldsMapForForm(
      List<QueryDocumentSnapshot> submissions) async {
    final mergedFields = <String, dynamic>{};
    final candidateIds = <String>{
      widget.formId,
      ...widget.formIds.where((value) => value.trim().isNotEmpty),
      ...widget.definitionIds.where((value) => value.trim().isNotEmpty),
      for (final doc in submissions)
        ...[
          (doc.data() as Map<String, dynamic>)['templateId']?.toString(),
          (doc.data() as Map<String, dynamic>)['formId']?.toString(),
        ].whereType<String>().where((value) => value.trim().isNotEmpty),
    };

    for (final candidateId in candidateIds) {
      final legacyDoc = await FirebaseFirestore.instance
          .collection('form')
          .doc(candidateId)
          .get();
      _mergeFields(mergedFields, _extractFieldsMap(legacyDoc.data()));

      final templateDoc = await FirebaseFirestore.instance
          .collection('form_templates')
          .doc(candidateId)
          .get();
      _mergeFields(mergedFields, _extractFieldsMap(templateDoc.data()));
    }

    return mergedFields;
  }

  Future<List<QueryDocumentSnapshot>> _loadSubmissionDocs() async {
    final formIds = <String>{
      widget.formId,
      ...widget.formIds.where((value) => value.trim().isNotEmpty),
    }.toList();

    final futures = <Future<QuerySnapshot>>[];
    for (int i = 0; i < formIds.length; i += 10) {
      final chunk =
          formIds.sublist(i, i + 10 > formIds.length ? formIds.length : i + 10);
      Query q = FirebaseFirestore.instance
          .collection('form_responses')
          .where('formId', whereIn: chunk)
          .orderBy('submittedAt', descending: false);

      if (_dateRange != null) {
        final startTs = rangeStartTimestamp(_dateRange)!;
        final endTs = rangeEndTimestamp(_dateRange)!;
        q = q
            .where('submittedAt', isGreaterThanOrEqualTo: startTs)
            .where('submittedAt', isLessThanOrEqualTo: endTs);
      }

      futures.add(q.get());
    }

    final snapshots = await Future.wait(futures);
    final docsById = <String, QueryDocumentSnapshot>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        docsById[doc.id] = doc;
      }
    }

    final docs = docsById.values.toList()
      ..sort((a, b) {
        final aTs =
            (a.data() as Map<String, dynamic>)['submittedAt'] as Timestamp?;
        final bTs =
            (b.data() as Map<String, dynamic>)['submittedAt'] as Timestamp?;
        return (aTs?.millisecondsSinceEpoch ?? 0)
            .compareTo(bTs?.millisecondsSinceEpoch ?? 0);
      });
    return docs;
  }

  void _mergeFields(
      Map<String, dynamic> target, Map<String, dynamic> incoming) {
    for (final entry in incoming.entries) {
      target.putIfAbsent(entry.key, () => entry.value);
    }
  }

  Map<String, dynamic> _extractFieldsMap(Map<String, dynamic>? data) {
    final rawFields = data?['fields'];
    if (rawFields is Map) {
      return rawFields.cast<String, dynamic>();
    }
    if (rawFields is List) {
      final fields = <String, dynamic>{};
      for (final field in rawFields) {
        if (field is! Map) continue;
        final fieldData = Map<String, dynamic>.from(field);
        final fieldId = (fieldData['id'] as String?)?.trim();
        if (fieldId == null || fieldId.isEmpty) continue;
        fields[fieldId] = fieldData;
      }
      return fields;
    }
    return {};
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange,
      currentDate: now,
      helpText: AppLocalizations.of(context)!.selectDateRangeForFormSubmissions,
      cancelText: 'Cancel',
      confirmText: 'Apply Filter',
      saveText: 'Apply',
      builder: (context, child) {
        return Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 450,
                maxHeight: 600,
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  datePickerTheme: DatePickerThemeData(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.white,
                    headerBackgroundColor: const Color(0xff0386FF),
                    headerForegroundColor: Colors.white,
                    headerHeadlineStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    headerHelpStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                    dayStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    rangeSelectionBackgroundColor:
                        const Color(0xff0386FF).withValues(alpha: 0.1),
                    rangeSelectionOverlayColor: WidgetStateProperty.all(
                      const Color(0xff0386FF).withValues(alpha: 0.1),
                    ),
                    dayBackgroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xff0386FF);
                      }
                      return null;
                    }),
                    dayForegroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return null;
                    }),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xff0386FF),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                child: child!,
              ),
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
      _load(); // Reload data with new date range
    }
  }

  Future<void> _saveNote(String docId, String note) async {
    try {
      await FirebaseFirestore.instance
          .collection('form_responses')
          .doc(docId)
          .update({'adminNote': note});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.noteSavedSuccessfully),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSaveNoteE),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _saveStatus(String docId, String status) async {
    try {
      final reviewerId = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance
          .collection('form_responses')
          .doc(docId)
          .update({
        'reviewStatus': status.isEmpty ? FieldValue.delete() : status,
        'reviewedAt':
            status.isEmpty ? FieldValue.delete() : FieldValue.serverTimestamp(),
        'reviewedBy': status.isEmpty || reviewerId == null
            ? FieldValue.delete()
            : reviewerId,
        'reviewNotifiedAt': FieldValue.delete(),
        'reviewNotifiedBy': FieldValue.delete(),
        'reviewNotifiedStatus': FieldValue.delete(),
      });

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.statusUpdatedToStatus(_statusLabel(status))),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSaveStatusE),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _notifyTeacher(
    String docId,
    Map<String, dynamic> submission,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final status = FormReviewStatus.normalize(submission['reviewStatus']);
    if (status != FormReviewStatus.accepted &&
        status != FormReviewStatus.rejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.formDecisionRequiresAcceptedRejected)),
      );
      return;
    }

    final teacherId = (submission['userId'] ??
            submission['submittedBy'] ??
            submission['teacherId'] ??
            submission['teacher_id'])
        ?.toString()
        .trim();
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (teacherId == null || teacherId.isEmpty || adminId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.formDecisionTeacherMissing)),
      );
      return;
    }

    setState(() => _notifyingSubmissionIds.add(docId));
    try {
      final statusLabel = FormReviewStatusBadge.labelFor(context, status);
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendAdminNotification');
      final result = await callable.call<Map<String, dynamic>>({
        'recipientType': 'selected',
        'recipientIds': [teacherId],
        'notificationTitle': l10n.formDecisionNotificationTitle(statusLabel),
        'notificationBody': l10n.formDecisionNotificationBody(
          widget.formTitle,
          statusLabel,
        ),
        'notificationData': {
          'type': 'form_decision',
          'formResponseId': docId,
          'formId': (submission['formId'] ?? widget.formId).toString(),
          'reviewStatus': status,
          'yearMonth': (submission['yearMonth'] ?? '').toString(),
        },
        'sendEmail': false,
        'adminId': adminId,
      });

      final resultData = result.data;
      final deliveryResults = resultData['results'] as Map?;
      final pushDelivered = (deliveryResults?['fcmSuccess'] as num? ?? 0) > 0;

      await FirebaseFirestore.instance
          .collection('form_responses')
          .doc(docId)
          .update({
        'reviewNotificationAttemptedAt': FieldValue.serverTimestamp(),
        'reviewNotifiedStatus': status,
        if (pushDelivered) ...{
          'reviewNotifiedAt': FieldValue.serverTimestamp(),
          'reviewNotifiedBy': adminId,
        },
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pushDelivered
              ? l10n.formDecisionNotificationSent
              : l10n.formDecisionVisibleNoPush),
          backgroundColor:
              pushDelivered ? const Color(0xFF059669) : Colors.orange,
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.formDecisionNotificationFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _notifyingSubmissionIds.remove(docId));
      }
    }
  }

  List<String> get _fieldOrder {
    final fields = (_template['fields'] as Map<String, dynamic>?) ?? {};
    final entries = fields.entries.toList();
    entries.sort((a, b) => ((a.value['order'] ?? 0) as int)
        .compareTo((b.value['order'] ?? 0) as int));
    return entries.map((e) => e.key).toList();
  }

  String _labelFor(String fieldId) {
    final fields = (_template['fields'] as Map<String, dynamic>?) ?? {};
    return (fields[fieldId]?['label'] ?? fieldId).toString();
  }

  List<QueryDocumentSnapshot> get _filteredSubmissions {
    if (_searchQuery.isEmpty) return _submissions;

    return _submissions.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final responses =
          (data['responses'] as Map?)?.cast<String, dynamic>() ?? {};

      return AppSearch.matchesMap(
        query: _searchQuery,
        data: data,
        documentId: doc.id,
        additionalValues: [
          ...responses.values.map((value) => value.toString()),
          widget.formId,
        ],
      );
    }).toList();
  }

  List<QueryDocumentSnapshot> get _paginatedSubmissions {
    final filtered = _filteredSubmissions;
    final start = _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start.clamp(0, filtered.length), end);
  }

  String get _dateRangeText {
    if (_dateRange == null) return AppLocalizations.of(context)!.selectDates;
    final start = _dateRange!.start;
    final end = _dateRange!.end;
    return '${start.month.toString().padLeft(2, '0')}/${start.day.toString().padLeft(2, '0')} - ${end.month.toString().padLeft(2, '0')}/${end.day.toString().padLeft(2, '0')}';
  }

  void _exportSubmissions() {
    if (_filteredSubmissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noSubmissionsToExport),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Build headers: basic user info + all form fields + status + admin notes
      final fieldIds = _fieldOrder;
      final headers = <String>[
        'Submission #',
        'User Name',
        'Email',
        'Submitted At',
      ];

      // Add dynamic form field headers
      for (final fieldId in fieldIds) {
        headers.add(_labelFor(fieldId));
      }

      // Add status and admin notes columns
      headers.add('Status');
      headers.add('Admin Notes');

      // Build data rows
      final rows = _filteredSubmissions.asMap().entries.map((entry) {
        final index = entry.key;
        final doc = entry.value;
        final data = doc.data() as Map<String, dynamic>;
        final responses =
            (data['responses'] as Map?)?.cast<String, dynamic>() ?? {};

        // Build row data
        final row = <String>[
          '${index + 1}', // Submission number
          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          (data['userEmail'] ?? '').toString(),
          _formatSubmissionDate(data['submittedAt']),
        ];

        // Add dynamic form field values
        for (final fieldId in fieldIds) {
          String value = (responses[fieldId] ?? '').toString();

          // Format dates if it's a timestamp
          if (responses[fieldId] is Timestamp) {
            final date = (responses[fieldId] as Timestamp).toDate();
            value =
                '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
          }

          row.add(value);
        }

        // Add status and admin notes
        row.add(FormReviewStatusBadge.labelFor(
          context,
          FormReviewStatus.normalize(data['reviewStatus']),
        ));
        row.add((data['adminNote'] ?? '').toString());

        return row;
      }).toList();

      // Use ExportHelpers to show export dialog
      ExportHelpers.showExportDialog(
        context,
        headers,
        rows,
        '${widget.formTitle.replaceAll(RegExp(r'[^\w\s-]'), '_')}_submissions',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.exportFailedE),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatSubmissionDate(dynamic submittedAt) {
    if (submittedAt is Timestamp) {
      final date = submittedAt.toDate();
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  Widget _buildStatusDropdown(String docId, String currentStatus) {
    final normalizedCurrentStatus = FormReviewStatus.normalize(currentStatus);

    return Container(
      width: 130,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: FormReviewStatusBadge.colorFor(normalizedCurrentStatus)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: FormReviewStatusBadge.colorFor(normalizedCurrentStatus)
                .withValues(alpha: 0.3)),
      ),
      child: DropdownButton<String>(
        value: normalizedCurrentStatus,
        isExpanded: true,
        underline: const SizedBox(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: FormReviewStatusBadge.colorFor(normalizedCurrentStatus),
        ),
        dropdownColor: Colors.white,
        items: FormReviewStatus.options.map((String status) {
          return DropdownMenuItem<String>(
            value: status,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: FormReviewStatusBadge.colorFor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  FormReviewStatusBadge.labelFor(context, status),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: FormReviewStatusBadge.colorFor(status),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (String? newStatus) async {
          if (newStatus != null && newStatus != normalizedCurrentStatus) {
            final saved = await _saveStatus(docId, newStatus);
            if (saved && mounted) await _load();
          }
        },
      ),
    );
  }

  Widget _buildNotifyTeacherButton(
    String docId,
    Map<String, dynamic> submission,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final status = FormReviewStatus.normalize(submission['reviewStatus']);
    final canNotify = status == FormReviewStatus.accepted ||
        status == FormReviewStatus.rejected;
    final isNotifying = _notifyingSubmissionIds.contains(docId);
    final wasNotified = submission['reviewNotifiedAt'] != null &&
        submission['reviewNotifiedStatus'] == status;

    return Tooltip(
      message:
          wasNotified ? l10n.formNotifyTeacherAgain : l10n.formNotifyTeacher,
      child: IconButton(
        onPressed: canNotify && !isNotifying
            ? () => _notifyTeacher(docId, submission)
            : null,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 32),
        icon: isNotifying
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                wasNotified
                    ? Icons.notifications_active
                    : Icons.notification_add_outlined,
                size: 19,
                color: canNotify
                    ? (wasNotified
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB))
                    : const Color(0xFFD1D5DB),
              ),
      ),
    );
  }

  String _statusLabel(String status) {
    return FormReviewStatusBadge.labelFor(context, status);
  }

  Widget _buildFieldValueWidget(String fieldId, dynamic value, double width) {
    final fields = (_template['fields'] as Map<String, dynamic>?) ?? {};
    final fieldInfo = fields[fieldId] as Map<String, dynamic>?;
    final fieldType = fieldInfo?['type'] as String?;
    final fieldOptions = fieldInfo?['options'];

    // Convert value to string
    String displayValue = value.toString();

    // Format dates if it's a timestamp
    if (value is Timestamp) {
      final date = value.toDate();
      displayValue =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    }

    // If it's a field with options (select, dropdown, multi_select), show as clickable
    if ((fieldType == 'select' ||
            fieldType == 'dropdown' ||
            fieldType == 'multi_select') &&
        fieldOptions != null) {
      List<String> options = [];

      // Parse options from various formats
      if (fieldOptions is List) {
        options = fieldOptions.map((e) => e.toString()).toList();
      } else if (fieldOptions is String) {
        options = fieldOptions.split(',').map((e) => e.trim()).toList();
      }

      if (options.isNotEmpty) {
        return SizedBox(
          width: width,
          child: InkWell(
            onTap: () => _showFieldOptionsDialog(
                fieldId, _labelFor(fieldId), options, displayValue),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayValue.isEmpty ? '-' : displayValue,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF374151),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // Default text display for other field types
    return SizedBox(
      width: width,
      child: Text(
        displayValue.isEmpty ? '-' : displayValue,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF374151),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showFieldOptionsDialog(String fieldId, String fieldLabel,
      List<String> options, String selectedValue) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            fieldLabel,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.availableOptions,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: options.map((option) {
                      final isSelected = option == selectedValue;
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE5E7EB),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isSelected) ...[
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                option,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF374151),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context)!.commonClose,
                style: GoogleFonts.inter(
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.95,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined,
                      color: Color(0xFF6B7280), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.formTitle,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.published,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _exportSubmissions,
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: Text(AppLocalizations.of(context)!.commonExport),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0386FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 2,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF6B7280),
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(text: AppLocalizations.of(context)!.submissions),
                ],
              ),
            ),

            // Toolbar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final dateSelector = InkWell(
                        onTap: _selectDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  color: Color(0xFF6B7280), size: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _dateRangeText,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_drop_down,
                                  color: Color(0xFF6B7280), size: 20),
                            ],
                          ),
                        ),
                      );
                      final submissionCount = Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_filteredSubmissions.length} submissions',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      );
                      final searchField = Container(
                        width: constraints.maxWidth < 700 ? null : 300,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            if (mounted) {
                              setState(() {
                                _searchQuery = value;
                                _currentPage = 0;
                              });
                            }
                          },
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText:
                                AppLocalizations.of(context)!.commonSearch,
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF9CA3AF),
                            ),
                            prefixIcon: const Icon(Icons.search,
                                color: Color(0xFF6B7280), size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      );

                      if (constraints.maxWidth < 700) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Flexible(child: dateSelector),
                                const SizedBox(width: 12),
                                submissionCount,
                              ],
                            ),
                            const SizedBox(height: 12),
                            searchField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          dateSelector,
                          const SizedBox(width: 16),
                          submissionCount,
                          const Spacer(),
                          searchField,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Table
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _buildTable(),
            ),

            // Pagination
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _currentPage > 0
                            ? () {
                                setState(() => _currentPage--);
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        'Page ${_currentPage + 1} of ${(_filteredSubmissions.length / _rowsPerPage).ceil() == 0 ? 1 : (_filteredSubmissions.length / _rowsPerPage).ceil()}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF6B7280)),
                      ),
                      IconButton(
                        onPressed: (_currentPage + 1) * _rowsPerPage <
                                _filteredSubmissions.length
                            ? () {
                                setState(() => _currentPage++);
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.rowsPerPage,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF6B7280)),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _rowsPerPage,
                        items: [10, 25, 50]
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.toString()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _rowsPerPage = value;
                              _currentPage = 0;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    final fieldIds = _fieldOrder;
    final tableWidth = _calculateTableWidth(fieldIds);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Table header
                  Container(
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      border:
                          Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: _buildTableHeader(fieldIds),
                  ),

                  // Table body
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: _paginatedSubmissions
                              .asMap()
                              .entries
                              .map((entry) {
                            final globalIndex =
                                (_currentPage * _rowsPerPage) + entry.key;
                            final doc = entry.value;
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildTableRow(
                                doc.id, data, globalIndex + 1, fieldIds);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateTableWidth(List<String> fieldIds) {
    // Calculate total width: checkbox(48) + #(60) + user(220) + dynamic fields + decision(190) + notes(200) + padding(16)
    double width = 48 + 60 + 220 + 16; // checkbox + number + user + padding

    // Add separators: 5 base separators (after checkbox, #, user, status, notes) + 1 per field
    final separatorCount = 5 + fieldIds.length;
    width += separatorCount * 17; // Each separator is 1px + 16px margin

    // Add dynamic field columns
    for (final fieldId in fieldIds) {
      final label = _labelFor(fieldId);
      // Adjust width based on field type/label
      if (label.toLowerCase().contains('date')) {
        width += 140;
      } else if (label.toLowerCase().contains('email')) {
        width += 200;
      } else {
        width += 180;
      }
    }

    width += 190; // Decision and notification column
    width += 200; // Notes column

    // Ensure minimum width for bottom sheet (account for padding)
    final screenWidth =
        MediaQuery.of(context).size.width - 32; // Account for margins only
    return width < screenWidth ? screenWidth : width;
  }

  Widget _buildColumnSeparator() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildTableHeader(List<String> fieldIds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 48,
            child: Checkbox(
              value: false,
              onChanged: (bool? value) {},
              activeColor: const Color(0xFF2563EB),
            ),
          ),

          _buildColumnSeparator(),

          // # Column
          SizedBox(
            width: 60,
            child: Text(
              AppLocalizations.of(context)!.number,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),

          _buildColumnSeparator(),

          // User Column
          SizedBox(
            width: 220,
            child: Text(
              AppLocalizations.of(context)!.roleUser,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),

          _buildColumnSeparator(),

          // Dynamic field columns
          ...fieldIds.expand((fieldId) {
            final label = _labelFor(fieldId);
            double width = 180;
            if (label.toLowerCase().contains('date')) width = 140;
            if (label.toLowerCase().contains('email')) width = 200;

            return [
              SizedBox(
                width: width,
                child: Tooltip(
                  message: label,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _buildColumnSeparator(),
            ];
          }),

          // Decision Column
          SizedBox(
            width: 190,
            child: Text(
              AppLocalizations.of(context)!.formDecisionColumn,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),

          _buildColumnSeparator(),

          // Notes Column
          SizedBox(
            width: 200,
            child: Text(
              AppLocalizations.of(context)!.shiftNotes,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(String docId, Map<String, dynamic> data, int rowNumber,
      List<String> fieldIds) {
    final responses =
        (data['responses'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    final email = (data['userEmail'] ?? '').toString();
    final displayName = name.isNotEmpty ? name : email;
    final isEditing = _editingNotes[docId] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: rowNumber % 2 == 0 ? Colors.white : const Color(0xFFFAFBFC),
        border: const Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: InkWell(
        onTap: () {},
        hoverColor: const Color(0xFFF3F4F6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 48,
                child: Checkbox(
                  value: false,
                  onChanged: (bool? value) {},
                  activeColor: const Color(0xFF2563EB),
                ),
              ),

              _buildColumnSeparator(),

              // Row number
              SizedBox(
                width: 60,
                child: Text(
                  rowNumber.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),

              _buildColumnSeparator(),

              // User with avatar
              SizedBox(
                width: 220,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getAvatarColor(displayName),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (email.isNotEmpty && email != displayName)
                            Text(
                              email,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF6B7280),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _buildColumnSeparator(),

              // Dynamic field values
              ...fieldIds.expand((fieldId) {
                final label = _labelFor(fieldId);
                double width = 180;
                if (label.toLowerCase().contains('date')) width = 140;
                if (label.toLowerCase().contains('email')) width = 200;

                final value = responses[fieldId] ?? '';

                return [
                  _buildFieldValueWidget(fieldId, value, width),
                  _buildColumnSeparator(),
                ];
              }),

              // Decision and teacher notification
              SizedBox(
                width: 190,
                child: Row(
                  children: [
                    _buildStatusDropdown(
                      docId,
                      (data['reviewStatus'] ?? '').toString(),
                    ),
                    const SizedBox(width: 4),
                    _buildNotifyTeacherButton(docId, data),
                  ],
                ),
              ),

              _buildColumnSeparator(),

              // Notes field
              SizedBox(
                width: 200,
                child: isEditing
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _notesControllers[docId],
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!.addNote,
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF9CA3AF),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD1D5DB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2563EB)),
                                ),
                              ),
                              onSubmitted: (value) async {
                                await _saveNote(docId, value);
                                setState(() {
                                  _editingNotes[docId] = false;
                                });
                              },
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: const Icon(Icons.check,
                                size: 16, color: Color(0xFF059669)),
                            onPressed: () async {
                              await _saveNote(
                                  docId, _notesControllers[docId]!.text);
                              setState(() {
                                _editingNotes[docId] = false;
                              });
                            },
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: const Icon(Icons.close,
                                size: 16, color: Color(0xFFDC2626)),
                            onPressed: () {
                              setState(() {
                                _editingNotes[docId] = false;
                                // Reset to saved value
                                final savedNote =
                                    (data['adminNote'] ?? '').toString();
                                _notesControllers[docId]!.text = savedNote;
                              });
                            },
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: () {
                          setState(() {
                            _editingNotes[docId] = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _notesControllers[docId]!.text.isNotEmpty
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _notesControllers[docId]!.text.isEmpty
                                      ? 'Add note...'
                                      : _notesControllers[docId]!.text,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color:
                                        _notesControllers[docId]!.text.isEmpty
                                            ? const Color(0xFF9CA3AF)
                                            : const Color(0xFF92400E),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: _notesControllers[docId]!.text.isEmpty
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF92400E),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF059669),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFDC2626),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];

    if (name.isEmpty) return colors[0];
    final code = name.codeUnitAt(0);
    return colors[code % colors.length];
  }
}
