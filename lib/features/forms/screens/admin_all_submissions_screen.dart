import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import '../../../core/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../widgets/form_details_modal.dart';

/// Admin screen – Gmail-density redesign.
class AdminAllSubmissionsScreen extends StatefulWidget {
  const AdminAllSubmissionsScreen({super.key});

  @override
  State<AdminAllSubmissionsScreen> createState() =>
      _AdminAllSubmissionsScreenState();
}

class _AdminAllSubmissionsScreenState extends State<AdminAllSubmissionsScreen> {
  // ── state ──
  bool _isLoading = true;
  bool _isLoadingPreferences = true;

  List<QueryDocumentSnapshot> _allSubmissions = [];
  Map<String, List<QueryDocumentSnapshot>> _groupedByTeacher = {};
  Map<String, List<QueryDocumentSnapshot>> _groupedByForm = {};

  Map<String, Map<String, dynamic>> _teachersData = {};
  List<String> _allTeacherIds = [];
  Map<String, String> _formTitles = {};

  Set<String> _selectedTeacherIds = {};
  String? _selectedYearMonth;
  List<String> _availableMonths = [];
  bool _showAllMonths = false;
  String? _selectedStatus;
  /// Form filter: null = all forms, otherwise same keys as _filteredByForm (e.g. _kDailyClassReportKey).
  String? _selectedFormKey;

  String _viewMode = 'by_teacher';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _teacherPickerSearchQuery = '';

  List<String> _favoriteTeacherIds = [];
  String _defaultViewMode = 'by_teacher';
  bool _defaultShowAllMonths = false;

  String _filterCacheKey = '';
  List<QueryDocumentSnapshot>? _filteredCache;
  Map<String, dynamic>? _statsCache;
  Map<String, List<QueryDocumentSnapshot>>? _byTeacherCache;
  Map<String, List<QueryDocumentSnapshot>>? _byFormCache;

  void _invalidateFilterCache() {
    _filteredCache = null;
    _statsCache = null;
    _byTeacherCache = null;
    _byFormCache = null;
    _filterCacheKey = '';
  }

  static const int _priorityFormsLimit = 500;
  static const int _otherFormsPageSize = 500;
  static const int _loadMorePageSize = 500;
  static const String _kFormTypeDaily = 'daily';
  static const String _kFormTypeWeekly = 'weekly';
  static const String _kFormTypeMonthly = 'monthly';
  DocumentSnapshot? _lastSubmissionDoc;
  bool _hasMoreSubmissions = false;
  bool _isLoadingMore = false;
  bool _loadedOtherForms = false;
  bool _isLoadingOtherForms = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    _loadAdminPreferences();
    _loadAllTeachers();
    try {
      await _loadCurrentMonthSubmissions();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAdminPreferences() async {
    setState(() => _isLoadingPreferences = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('admin_preferences')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _favoriteTeacherIds =
              List<String>.from(data['favoriteTeacherIds'] ?? []);
          _defaultViewMode = data['defaultViewMode'] ?? 'by_teacher';
          _defaultShowAllMonths = data['defaultShowAllMonths'] ?? false;
          _viewMode = 'by_teacher';
          _showAllMonths = _defaultShowAllMonths;
          // Favorites only affect sort order (show on top), not which teachers are visible
        });
      }
      if (mounted) setState(() => _isLoadingPreferences = false);
    } catch (e) {
      AppLogger.error('Error loading admin preferences: $e');
      if (mounted) setState(() => _isLoadingPreferences = false);
    }
  }

  Future<void> _saveAdminPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('admin_preferences')
          .doc(user.uid)
          .set({
        'favoriteTeacherIds': _favoriteTeacherIds,
        'defaultViewMode': _defaultViewMode,
        'defaultShowAllMonths': _defaultShowAllMonths,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminPreferencesSaved),
            backgroundColor: const Color(0xff16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error saving admin preferences: $e');
    }
  }

  Future<void> _loadAllTeachers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();
      final teachersData = <String, Map<String, dynamic>>{};
      final teacherIds = <String>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final first =
            (data['first_name'] ?? data['firstName'] ?? '').toString();
        final last = (data['last_name'] ?? data['lastName'] ?? '').toString();
        final display = (data['displayName'] ?? '').toString();
        String name =
            display.isNotEmpty ? display : '$first $last'.trim();
        if (name.isEmpty) {
          final email = (data['email'] ?? data['e-mail'] ?? '').toString();
          name = email.isNotEmpty ? email.split('@').first : 'Unknown';
        }
        teachersData[doc.id] = {
          'uid': doc.id,
          'name': name,
          'email': (data['email'] ?? data['e-mail'] ?? '').toString(),
          'photoURL': data['photoURL'],
        };
        teacherIds.add(doc.id);
      }
      if (mounted) {
        setState(() {
          _teachersData = teachersData;
          _allTeacherIds = teacherIds;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading teachers: $e');
    }
  }

  Future<void> _loadAllSubmissions({bool clearLoadingWhenDone = false}) async {
    setState(() => _isLoading = true);
    _lastSubmissionDoc = null;
    _hasMoreSubmissions = false;
    try {
      if (!_showAllMonths && _selectedYearMonth != null) {
        await _loadSpecificMonthSubmissions(_selectedYearMonth!);
        if (clearLoadingWhenDone && mounted) setState(() => _isLoading = false);
        return;
      }
      // Cache-first: show UI as soon as we have any cached data
      final cacheResults = await Future.wait([
        _queryByFormTypeCacheOnly(_kFormTypeDaily, _priorityFormsLimit),
        _queryByFormTypeCacheOnly(_kFormTypeWeekly, _priorityFormsLimit),
        _queryByFormTypeCacheOnly(_kFormTypeMonthly, _priorityFormsLimit),
      ]);
      final cacheDaily = cacheResults[0];
      final cacheWeekly = cacheResults[1];
      final cacheMonthly = cacheResults[2];
      final mergedCache = <QueryDocumentSnapshot>[]
        ..addAll(cacheDaily)
        ..addAll(cacheWeekly)
        ..addAll(cacheMonthly);
      if (mergedCache.isNotEmpty && mounted) {
        _applyMergedDocsToState(
          dailyDocs: cacheDaily,
          weeklyDocs: cacheWeekly,
          monthlyDocs: cacheMonthly,
          clearLoadingWhenDone: clearLoadingWhenDone,
        );
      }
      // Then fetch from server and update
      final results = await Future.wait([
        _queryByFormTypeServerOnly(_kFormTypeDaily, _priorityFormsLimit),
        _queryByFormTypeServerOnly(_kFormTypeWeekly, _priorityFormsLimit),
        _queryByFormTypeServerOnly(_kFormTypeMonthly, _priorityFormsLimit),
      ]);
      final dailyDocs = results[0];
      final weeklyDocs = results[1];
      final monthlyDocs = results[2];
      if (!mounted) return;
      final byTeacher = <String, List<QueryDocumentSnapshot>>{};
      final formIdsToFetch = <String>{};
      final idToTryForForm = <String, String>{};
      void collectEnrich(List<QueryDocumentSnapshot> docs, {String? formKeyOverride}) {
        for (var doc in docs) {
          final data = (doc.data() as Map<String, dynamic>?) ?? {};
          final userId = data['userId'] as String?;
          final formId = data['formId'] as String?;
          if (userId == null || formId == null) continue;
          byTeacher.putIfAbsent(userId, () => []).add(doc);
          if (!_formTitles.containsKey(formId)) {
            final stored = data['formTitle'] ?? data['form_title'] ?? data['title'];
            if (stored != null &&
                stored.toString().isNotEmpty &&
                stored.toString() != 'Untitled Form') {
              // will be merged in _applyMergedDocsToState via processDocs
            } else {
              formIdsToFetch.add(formId);
              final tid = (data['templateId'] as String?)?.trim();
              idToTryForForm[formId] = (tid != null && tid.isNotEmpty) ? tid : formId;
            }
          }
        }
      }
      collectEnrich(dailyDocs, formKeyOverride: _kDailyClassReportKey);
      collectEnrich(weeklyDocs, formKeyOverride: _kWeeklyReportKey);
      collectEnrich(monthlyDocs, formKeyOverride: _kMonthlyReportKey);
      _applyMergedDocsToState(
        dailyDocs: dailyDocs,
        weeklyDocs: weeklyDocs,
        monthlyDocs: monthlyDocs,
        clearLoadingWhenDone: clearLoadingWhenDone,
      );
      if (!_showAllMonths &&
          _selectedYearMonth == null &&
          _availableMonths.isNotEmpty) {
        _selectedYearMonth = _availableMonths.first;
      }
      _lastSubmissionDoc = _allSubmissions.isNotEmpty ? _allSubmissions.last : null;
      _hasMoreSubmissions =
          dailyDocs.length >= _priorityFormsLimit ||
          weeklyDocs.length >= _priorityFormsLimit ||
          monthlyDocs.length >= _priorityFormsLimit;
      if (mounted) setState(() => _invalidateFilterCache());
      final missingUserIds = byTeacher.keys
          .where((uid) => !_teachersData.containsKey(uid))
          .toSet()
          .toList();
      if (formIdsToFetch.isNotEmpty || missingUserIds.isNotEmpty) {
        Future.microtask(() => _enrichFormTitlesAndUsers(
              formIdsToFetch.toList(),
              idToTryForForm,
              missingUserIds,
            ));
      }
      if (_showAllMonths && _hasMoreSubmissions && mounted) {
        _scheduleLoadRemainingInBackground();
      }
    } catch (e) {
      AppLogger.error('Error loading all submissions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLoadingData}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _yearMonthFromDoc(Map<String, dynamic> data) {
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    if (submittedAt == null) return null;
    return '${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}';
  }

  void _applyMergedDocsToState({
    required List<QueryDocumentSnapshot> dailyDocs,
    required List<QueryDocumentSnapshot> weeklyDocs,
    required List<QueryDocumentSnapshot> monthlyDocs,
    bool clearLoadingWhenDone = false,
  }) {
    if (!mounted) return;
    final monthsSet = <String>{};
    final byTeacher = <String, List<QueryDocumentSnapshot>>{};
    final byForm = <String, List<QueryDocumentSnapshot>>{};
    final formTitles = <String, String>{};
    void processDocs(List<QueryDocumentSnapshot> docs, {String? formKeyOverride}) {
      for (var doc in docs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final userId = data['userId'] as String?;
        final formId = data['formId'] as String?;
        if (userId == null || formId == null) continue;
        String? yearMonth = data['yearMonth'] as String? ?? _yearMonthFromDoc(data);
        if (yearMonth != null) monthsSet.add(yearMonth);
        byTeacher.putIfAbsent(userId, () => []).add(doc);
        final formKey = formKeyOverride ?? formId;
        byForm.putIfAbsent(formKey, () => []).add(doc);
        final stored = data['formTitle'] ?? data['form_title'] ?? data['title'];
        if (stored != null &&
            stored.toString().isNotEmpty &&
            stored.toString() != 'Untitled Form') {
          formTitles[formId!] = stored.toString();
        }
      }
    }
    processDocs(dailyDocs, formKeyOverride: _kDailyClassReportKey);
    processDocs(weeklyDocs, formKeyOverride: _kWeeklyReportKey);
    processDocs(monthlyDocs, formKeyOverride: _kMonthlyReportKey);
    final mergedDocs = <QueryDocumentSnapshot>[]
      ..addAll(dailyDocs)
      ..addAll(weeklyDocs)
      ..addAll(monthlyDocs);
    mergedDocs.sort((a, b) {
      final da = (a.data() as Map<String, dynamic>?);
      final db = (b.data() as Map<String, dynamic>?);
      final ta = (da?['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final tb = (db?['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    final sortedMonths = monthsSet.toList()..sort((a, b) => b.compareTo(a));
    setState(() {
      _allSubmissions = mergedDocs;
      _groupedByTeacher = byTeacher;
      _groupedByForm = byForm;
      _formTitles = Map<String, String>.from(_formTitles)..addAll(formTitles);
      _availableMonths = sortedMonths;
      if (clearLoadingWhenDone) _isLoading = false;
      _invalidateFilterCache();
    });
  }

  Future<List<QueryDocumentSnapshot>> _queryByFormType(String formType, int limit) async {
    final query = FirebaseFirestore.instance
        .collection('form_responses')
        .where('formType', isEqualTo: formType)
        .orderBy('submittedAt', descending: true)
        .limit(limit);
    try {
      final cached = await query.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty && mounted) {
        _applyQueryResults(formType, cached.docs);
      }
    } catch (_) {}
    try {
      final snapshot = await query.get(const GetOptions(source: Source.server));
      return snapshot.docs;
    } catch (e) {
      AppLogger.error('Query formType=$formType failed: $e');
      return [];
    }
  }

  /// Cache-only read for one form type (used for cache-first display).
  Future<List<QueryDocumentSnapshot>> _queryByFormTypeCacheOnly(String formType, int limit) async {
    final query = FirebaseFirestore.instance
        .collection('form_responses')
        .where('formType', isEqualTo: formType)
        .orderBy('submittedAt', descending: true)
        .limit(limit);
    try {
      final cached = await query.get(const GetOptions(source: Source.cache));
      return cached.docs;
    } catch (_) {
      return [];
    }
  }

  /// Server-only read for one form type (used after showing cache).
  Future<List<QueryDocumentSnapshot>> _queryByFormTypeServerOnly(String formType, int limit) async {
    final query = FirebaseFirestore.instance
        .collection('form_responses')
        .where('formType', isEqualTo: formType)
        .orderBy('submittedAt', descending: true)
        .limit(limit);
    try {
      final snapshot = await query.get(const GetOptions(source: Source.server));
      return snapshot.docs;
    } catch (e) {
      AppLogger.error('Query formType=$formType failed: $e');
      return [];
    }
  }

  Future<List<QueryDocumentSnapshot>> _queryAllFormsByMonth(String yearMonth, int limit) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('yearMonth', isEqualTo: yearMonth)
          .orderBy('submittedAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.server));
      return snapshot.docs;
    } catch (e) {
      AppLogger.error('Query all forms month=$yearMonth failed: $e');
      return [];
    }
  }

  /// Cache-only read for month query (used for cache-first display).
  Future<List<QueryDocumentSnapshot>> _queryAllFormsByMonthCacheOnly(String yearMonth, int limit) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('yearMonth', isEqualTo: yearMonth)
          .orderBy('submittedAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.cache));
      return snapshot.docs;
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadMonthSubmissions(String yearMonth, {bool setSelectedIfUnset = false}) async {
    final allDocs = await _queryAllFormsByMonth(yearMonth, _priorityFormsLimit);
    if (!mounted) return;
    final monthsSet = <String>{yearMonth};
      final byTeacher = <String, List<QueryDocumentSnapshot>>{};
      final byForm = <String, List<QueryDocumentSnapshot>>{};
      final formTitles = <String, String>{};
      final formIdsToFetch = <String>{};
    final idToTryForForm = <String, String>{};
    void processDocs(List<QueryDocumentSnapshot> docs, {String? formKeyOverride}) {
      for (var doc in docs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final userId = data['userId'] as String?;
        final formId = data['formId'] as String?;
        if (userId == null || formId == null) continue;
        String? ym = data['yearMonth'] as String?;
        if (ym == null) {
          final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
          if (submittedAt != null) {
            ym = '${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}';
          }
        }
        if (ym != null) monthsSet.add(ym);
        byTeacher.putIfAbsent(userId, () => []).add(doc);
        final formKey = formKeyOverride ?? formId;
        byForm.putIfAbsent(formKey, () => []).add(doc);
        if (!formTitles.containsKey(formId)) {
          final stored = data['formTitle'] ?? data['form_title'] ?? data['title'];
          if (stored != null &&
              stored.toString().isNotEmpty &&
              stored.toString() != 'Untitled Form') {
            formTitles[formId] = stored.toString();
          } else {
            formIdsToFetch.add(formId);
            final tid = (data['templateId'] as String?)?.trim();
            idToTryForForm[formId] = (tid != null && tid.isNotEmpty) ? tid : formId;
          }
        }
      }
    }
    final dailyDocs = <QueryDocumentSnapshot>[];
    final weeklyDocs = <QueryDocumentSnapshot>[];
    final monthlyDocs = <QueryDocumentSnapshot>[];
    final otherDocs = <QueryDocumentSnapshot>[];
    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      final formType = (data?['formType'] ?? '').toString().toLowerCase();
      if (formType == _kFormTypeDaily) {
        dailyDocs.add(doc);
      } else if (formType == _kFormTypeWeekly) {
        weeklyDocs.add(doc);
      } else if (formType == _kFormTypeMonthly) {
        monthlyDocs.add(doc);
      } else {
        otherDocs.add(doc);
      }
    }
    processDocs(dailyDocs, formKeyOverride: _kDailyClassReportKey);
    processDocs(weeklyDocs, formKeyOverride: _kWeeklyReportKey);
    processDocs(monthlyDocs, formKeyOverride: _kMonthlyReportKey);
    processDocs(otherDocs);
    final mergedDocs = List<QueryDocumentSnapshot>.from(allDocs);
    mergedDocs.sort((a, b) {
      final da = (a.data() as Map<String, dynamic>?);
      final db = (b.data() as Map<String, dynamic>?);
      final ta = (da?['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final tb = (db?['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    final sortedMonths = monthsSet.toList()..sort((a, b) => b.compareTo(a));
    _lastSubmissionDoc = mergedDocs.isNotEmpty ? mergedDocs.last : null;
    _hasMoreSubmissions = allDocs.length >= _priorityFormsLimit;
    final missingUserIds = byTeacher.keys
        .where((uid) => !_teachersData.containsKey(uid))
        .toSet()
        .toList();
    if (formIdsToFetch.isNotEmpty || missingUserIds.isNotEmpty) {
      await _enrichFormTitlesAndUsers(
        formIdsToFetch.toList(),
        idToTryForForm,
        missingUserIds,
      );
    }
    if (!mounted) return;
    setState(() {
      _allSubmissions = mergedDocs;
      _groupedByTeacher = byTeacher;
      _groupedByForm = byForm;
      _formTitles = Map<String, String>.from(_formTitles)..addAll(formTitles);
      _availableMonths = sortedMonths;
      _isLoading = false;
      if (setSelectedIfUnset) {
        _showAllMonths = false;
        _selectedYearMonth = yearMonth;
      }
      _invalidateFilterCache();
    });
  }

  Future<void> _loadCurrentMonthSubmissions() async {
    setState(() => _isLoading = true);
    _lastSubmissionDoc = null;
    _hasMoreSubmissions = false;
    try {
      final now = DateTime.now();
      final currentYearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await _loadMonthSubmissions(currentYearMonth, setSelectedIfUnset: true);
    } catch (e) {
      AppLogger.error('Error loading current month submissions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLoadingData}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSpecificMonthSubmissions(String yearMonth) async {
    try {
      await _loadMonthSubmissions(yearMonth, setSelectedIfUnset: false);
    } catch (e) {
      AppLogger.error('Error loading specific month $yearMonth: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyQueryResults(String formType, List<QueryDocumentSnapshot> docs) {
    if (!mounted) return;
    final formKey = formType == _kFormTypeDaily
        ? _kDailyClassReportKey
        : formType == _kFormTypeWeekly
            ? _kWeeklyReportKey
            : _kMonthlyReportKey;
    final byTeacher = Map<String, List<QueryDocumentSnapshot>>.from(_groupedByTeacher);
    final byForm = Map<String, List<QueryDocumentSnapshot>>.from(_groupedByForm);
    final monthsSet = <String>{..._availableMonths};
    for (final doc in docs) {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final userId = data['userId'] as String?;
      if (userId == null) continue;
      byTeacher.putIfAbsent(userId, () => []).add(doc);
      byForm.putIfAbsent(formKey, () => []).add(doc);
      String? yearMonth = data['yearMonth'] as String?;
      if (yearMonth == null) {
        final ts = (data['submittedAt'] as Timestamp?)?.toDate();
        if (ts != null) yearMonth = '${ts.year}-${ts.month.toString().padLeft(2, '0')}';
      }
      if (yearMonth != null) monthsSet.add(yearMonth);
    }
    final sortedMonths = monthsSet.toList()..sort((a, b) => b.compareTo(a));
    setState(() {
      _groupedByTeacher = byTeacher;
      _groupedByForm = byForm;
      _availableMonths = sortedMonths;
      _invalidateFilterCache();
    });
  }

  Future<void> _loadOtherForms() async {
    if (_isLoadingOtherForms) return;
    setState(() => _isLoadingOtherForms = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('form_responses')
          .where('formType', whereNotIn: [_kFormTypeDaily, _kFormTypeWeekly, _kFormTypeMonthly])
          .orderBy('formType')
          .orderBy('submittedAt', descending: true)
          .limit(_otherFormsPageSize)
          .get();
      if (!mounted) return;
      final otherDocs = snapshot.docs;
      if (otherDocs.isEmpty) {
        setState(() {
          _loadedOtherForms = true;
          _isLoadingOtherForms = false;
        });
        return;
      }
      final byTeacher2 = <String, List<QueryDocumentSnapshot>>{};
      final byForm2 = <String, List<QueryDocumentSnapshot>>{};
      final formTitles = Map<String, String>.from(_formTitles);
      final formIdsToFetch = <String>{};
      final idToTryForForm = <String, String>{};
      final monthsSet = <String>{..._availableMonths};
      for (var doc in otherDocs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final userId = data['userId'] as String?;
        final formId = data['formId'] as String?;
        if (userId == null || formId == null) continue;
        String? yearMonth = data['yearMonth'] as String?;
        if (yearMonth == null) {
          final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
          if (submittedAt != null) {
            yearMonth =
                '${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}';
          }
        }
        if (yearMonth != null) monthsSet.add(yearMonth);
        byTeacher2.putIfAbsent(userId, () => []).add(doc);
        byForm2.putIfAbsent(formId, () => []).add(doc);
        if (!formTitles.containsKey(formId)) {
          final stored =
              data['formTitle'] ?? data['form_title'] ?? data['title'];
          if (stored != null &&
              stored.toString().isNotEmpty &&
              stored.toString() != 'Untitled Form') {
            formTitles[formId] = stored.toString();
          } else {
            formIdsToFetch.add(formId);
            final tid = (data['templateId'] as String?)?.trim();
            idToTryForForm[formId] =
                (tid != null && tid.isNotEmpty) ? tid : formId;
          }
        }
      }
      final mergedDocs = List<QueryDocumentSnapshot>.from(_allSubmissions)
        ..addAll(otherDocs);
      mergedDocs.sort((a, b) {
        final da = (a.data() as Map<String, dynamic>?);
        final db = (b.data() as Map<String, dynamic>?);
        final ta = (da?['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (db?['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
      final mergedByTeacher = Map<String, List<QueryDocumentSnapshot>>.from(_groupedByTeacher);
      for (final e in byTeacher2.entries) {
        mergedByTeacher[e.key] = [...?mergedByTeacher[e.key], ...e.value];
      }
      final mergedByForm = Map<String, List<QueryDocumentSnapshot>>.from(_groupedByForm);
      for (final e in byForm2.entries) {
        mergedByForm[e.key] = [...?mergedByForm[e.key], ...e.value];
      }
      final sortedMonths = monthsSet.toList()..sort((a, b) => b.compareTo(a));
      if (mounted) {
        setState(() {
          _allSubmissions = mergedDocs;
          _groupedByTeacher = mergedByTeacher;
          _groupedByForm = mergedByForm;
          _formTitles = formTitles;
          _availableMonths = sortedMonths;
          _loadedOtherForms = true;
          _isLoadingOtherForms = false;
          _invalidateFilterCache();
        });
      }
      final missingUserIds = byTeacher2.keys
          .where((uid) => !_teachersData.containsKey(uid))
          .toSet()
          .toList();
      if (formIdsToFetch.isNotEmpty || missingUserIds.isNotEmpty) {
        Future.microtask(() => _enrichFormTitlesAndUsers(
              formIdsToFetch.toList(),
              idToTryForForm,
              missingUserIds,
            ));
      }
    } catch (e) {
      AppLogger.error('Error loading other forms: $e');
      if (mounted) setState(() => _isLoadingOtherForms = false);
    }
  }

  Future<void> _enrichFormTitlesAndUsers(
    List<String> formIdsToFetch,
    Map<String, String> idToTryForForm,
    List<String> missingUserIds,
  ) async {
    if (!mounted) return;
    final formTitles = Map<String, String>.from(_formTitles);
    Future<void> fetchFormTitles() async {
      if (formIdsToFetch.isEmpty) return;
      final chunks = <List<String>>[];
      for (var i = 0; i < formIdsToFetch.length; i += 10) {
        chunks.add(formIdsToFetch.skip(i).take(10).toList());
      }
      await Future.wait(chunks.map((chunk) async {
        if (!mounted) return;
        final templateFutures = chunk.map((formId) => FirebaseFirestore.instance
              .collection('form_templates')
              .doc(idToTryForForm[formId] ?? formId)
              .get());
        final formFutures = chunk.map((formId) =>
            FirebaseFirestore.instance.collection('form').doc(formId).get());
        final allResults = await Future.wait([
          Future.wait(templateFutures),
          Future.wait(formFutures),
        ]);
        final templateDocs = allResults[0];
        final formDocs = allResults[1];
          for (var j = 0; j < chunk.length; j++) {
          final formId = chunk[j];
          if (formTitles.containsKey(formId) && formTitles[formId] != 'Form') continue;
          String? resolvedTitle;
          final tDoc = templateDocs[j];
          if (tDoc.exists) {
            final d = tDoc.data();
            final n = d?['name'] ?? d?['title'];
            if (n != null && n.toString().isNotEmpty) resolvedTitle = n.toString();
          }
          if (resolvedTitle == null) {
            final fDoc = formDocs[j];
            if (fDoc.exists) {
              final d = fDoc.data();
              final t = d?['title'] ?? d?['formTitle'] ?? d?['name'];
              if (t != null && t.toString().isNotEmpty) resolvedTitle = t.toString();
            }
          }
          if (resolvedTitle != null) formTitles[formId] = resolvedTitle;
        }
      }));
    }
    Future<void> fetchUsers() async {
      if (missingUserIds.isEmpty) return;
      final teachersData = Map<String, Map<String, dynamic>>.from(_teachersData);
      final chunks = <List<String>>[];
      for (var i = 0; i < missingUserIds.length; i += 10) {
        chunks.add(missingUserIds.skip(i).take(10).toList());
      }
      await Future.wait(chunks.map((chunk) async {
        if (!mounted) return;
          final futures = chunk.map((id) =>
            FirebaseFirestore.instance.collection('users').doc(id).get());
          final results = await Future.wait(futures);
          for (var j = 0; j < chunk.length; j++) {
          final userDoc = results[j];
          if (userDoc.exists) {
            final d = userDoc.data()!;
            final first = (d['first_name'] ?? d['firstName'] ?? '').toString();
            final last = (d['last_name'] ?? d['lastName'] ?? '').toString();
            final display = (d['displayName'] ?? '').toString();
            String name = display.isNotEmpty ? display : '$first $last'.trim();
            if (name.isEmpty) {
              final email = (d['email'] ?? d['e-mail'] ?? '').toString();
              name = email.isNotEmpty ? email.split('@').first : 'Unknown';
            }
            teachersData[chunk[j]] = {
              'uid': chunk[j],
              'name': name,
              'email': (d['email'] ?? d['e-mail'] ?? '').toString(),
              'photoURL': d['photoURL'],
            };
          }
        }
      }));
      if (mounted) {
        setState(() {
          _teachersData = teachersData;
          _invalidateFilterCache();
        });
      }
    }
    await Future.wait([fetchFormTitles(), fetchUsers()]);
    if (mounted) {
      setState(() {
        for (final e in formTitles.entries) _formTitles[e.key] = e.value;
        _invalidateFilterCache();
      });
    }
  }

  Future<Map<String, TeachingShift>> _getShiftSummariesForIds(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final result = <String, TeachingShift>{};
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 10) {
      final chunk = list.skip(i).take(10).toList();
          final futures = chunk.map((id) => FirebaseFirestore.instance
              .collection('teaching_shifts')
              .doc(id)
              .get());
          final results = await Future.wait(futures);
          for (var j = 0; j < chunk.length; j++) {
            final doc = results[j];
            if (doc.exists) {
              try {
            result[chunk[j]] = TeachingShift.fromFirestore(doc);
              } catch (_) {}
            }
          }
        }
    return result;
  }

  Future<void> _loadMoreSubmissions() async {
    if (_lastSubmissionDoc == null || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('form_responses')
          .orderBy('submittedAt', descending: true)
          .startAfterDocument(_lastSubmissionDoc!)
          .limit(_loadMorePageSize)
          .get();
      if (!mounted) return;
      if (snapshot.docs.isEmpty) {
      setState(() {
          _hasMoreSubmissions = false;
          _isLoadingMore = false;
        });
        return;
      }
      final formIdsToFetch = <String>{};
      final idToTryForForm = <String, String>{};
      final newByTeacher = <String, List<QueryDocumentSnapshot>>{};
      final newByForm = <String, List<QueryDocumentSnapshot>>{};
      for (var doc in snapshot.docs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final userId = data['userId'] as String?;
        final formId = data['formId'] as String?;
        if (userId == null || formId == null) continue;
        newByTeacher.putIfAbsent(userId, () => []).add(doc);
        newByForm.putIfAbsent(formId, () => []).add(doc);
        if (!_formTitles.containsKey(formId)) {
          final stored =
              data['formTitle'] ?? data['form_title'] ?? data['title'];
          if (stored != null &&
              stored.toString().isNotEmpty &&
              stored.toString() != 'Untitled Form') {
            _formTitles[formId] = stored.toString();
          } else {
            formIdsToFetch.add(formId);
            final tid = (data['templateId'] as String?)?.trim();
            idToTryForForm[formId] =
                (tid != null && tid.isNotEmpty) ? tid : formId;
          }
        }
      }
      if (formIdsToFetch.isNotEmpty && mounted) {
        final ids = formIdsToFetch.toList();
        for (var i = 0; i < ids.length; i += 10) {
          final chunk = ids.skip(i).take(10).toList();
          final futures = chunk.map((formId) => FirebaseFirestore.instance
            .collection('form_templates')
              .doc(idToTryForForm[formId] ?? formId)
              .get());
          final results = await Future.wait(futures);
          for (var j = 0; j < chunk.length; j++) {
            final doc = results[j];
            if (doc.exists) {
              final d = doc.data();
          final name = d?['name'] ?? d?['title'];
          if (name != null && name.toString().isNotEmpty) {
                _formTitles[chunk[j]] = name.toString();
              }
            }
          }
        }
      }
      final missingUserIds = newByTeacher.keys
          .where((uid) => !_teachersData.containsKey(uid))
          .toSet()
          .toList();
      if (missingUserIds.isNotEmpty && mounted) {
        for (var i = 0; i < missingUserIds.length; i += 10) {
          final chunk = missingUserIds.skip(i).take(10).toList();
          final futures = chunk.map((id) =>
              FirebaseFirestore.instance.collection('users').doc(id).get());
          final results = await Future.wait(futures);
          for (var j = 0; j < chunk.length; j++) {
            final userDoc = results[j];
            if (userDoc.exists) {
              final d = userDoc.data()!;
              final first =
                  (d['first_name'] ?? d['firstName'] ?? '').toString();
              final last =
                  (d['last_name'] ?? d['lastName'] ?? '').toString();
              final display = (d['displayName'] ?? '').toString();
              String name =
                  display.isNotEmpty ? display : '$first $last'.trim();
              if (name.isEmpty) {
                final email = (d['email'] ?? d['e-mail'] ?? '').toString();
                name = email.isNotEmpty ? email.split('@').first : 'Unknown';
              }
              _teachersData[chunk[j]] = {
                'uid': chunk[j],
                'name': name,
                'email': (d['email'] ?? d['e-mail'] ?? '').toString(),
                'photoURL': d['photoURL'],
              };
            }
          }
        }
      }
      if (!mounted) return;
      final mergedDocs = List<QueryDocumentSnapshot>.from(_allSubmissions)
        ..addAll(snapshot.docs);
      final mergedByTeacher =
          Map<String, List<QueryDocumentSnapshot>>.from(_groupedByTeacher);
      for (final e in newByTeacher.entries) {
        mergedByTeacher[e.key] = [...?mergedByTeacher[e.key], ...e.value];
      }
      final mergedByForm =
          Map<String, List<QueryDocumentSnapshot>>.from(_groupedByForm);
      for (final e in newByForm.entries) {
        mergedByForm[e.key] = [...?mergedByForm[e.key], ...e.value];
      }
      final monthsSet = <String>{..._availableMonths};
      for (var doc in snapshot.docs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        String? yearMonth = data['yearMonth'] as String?;
        if (yearMonth == null) {
          final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
          if (submittedAt != null) {
            yearMonth =
                '${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}';
          }
        }
        if (yearMonth != null) monthsSet.add(yearMonth);
      }
      final sortedMonths = monthsSet.toList()..sort((a, b) => b.compareTo(a));
      _lastSubmissionDoc = snapshot.docs.last;
      _hasMoreSubmissions = snapshot.docs.length >= _loadMorePageSize;
      setState(() {
        _allSubmissions = mergedDocs;
        _groupedByTeacher = mergedByTeacher;
        _groupedByForm = mergedByForm;
        _availableMonths = sortedMonths;
        _isLoadingMore = false;
        _invalidateFilterCache();
      });
    } catch (e) {
      AppLogger.error('Error loading more submissions: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _scheduleLoadRemainingInBackground() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadRemainingInBackground();
    });
  }

  Future<void> _loadRemainingInBackground() async {
    while (mounted && _hasMoreSubmissions && !_isLoadingMore) {
      await _loadMoreSubmissions();
    }
  }

  static const String _kDailyClassReportKey = '__daily_class_report__';
  static const String _kWeeklyReportKey = '__weekly_report__';
  static const String _kMonthlyReportKey = '__monthly_report__';

  /// Form key for a submission doc (same logic as _filteredByForm).
  String? _formKeyForDoc(Map<String, dynamic> data) {
    final formId = data['formId'] as String?;
    if (formId == null) return null;
    final formType = (data['formType'] ?? '').toString().toLowerCase();
    if (formType == _kFormTypeDaily) return _kDailyClassReportKey;
    if (formType == _kFormTypeWeekly) return _kWeeklyReportKey;
    if (formType == _kFormTypeMonthly) return _kMonthlyReportKey;
    return formId;
  }

  List<QueryDocumentSnapshot> get _filteredSubmissions {
    final cacheKey =
        '${_allSubmissions.length}_${_selectedTeacherIds.join(',')}:${_selectedYearMonth}_${_showAllMonths}_${_selectedStatus}_${_selectedFormKey}_${_searchQuery}_${_formTitles.length}_${_teachersData.length}';
    if (_filteredCache != null && cacheKey == _filterCacheKey) {
      return _filteredCache!;
    }
    final filterTeacher = _selectedTeacherIds.isNotEmpty;
    final filterMonth = !_showAllMonths && _selectedYearMonth != null;
    final filterStatus = _selectedStatus != null;
    final filterForm = _selectedFormKey != null;
    final filterSearch = _searchQuery.isNotEmpty;
    final q = filterSearch ? _searchQuery.toLowerCase() : '';
    final targetMonth = filterMonth ? _selectedYearMonth! : '';
    final targetStatus = filterStatus ? _selectedStatus!.toLowerCase() : '';
    final targetFormKey = filterForm ? _selectedFormKey! : '';
    final result = <QueryDocumentSnapshot>[];
    for (final doc in _allSubmissions) {
      final data = doc.data() as Map<String, dynamic>;
      if (filterTeacher) {
        final userId = data['userId'] as String?;
        if (userId == null || !_selectedTeacherIds.contains(userId)) continue;
      }
      if (filterMonth) {
        String? ym = data['yearMonth'] as String?;
        if (ym == null) {
          final ts = (data['submittedAt'] as Timestamp?)?.toDate();
          if (ts != null) ym = '${ts.year}-${ts.month.toString().padLeft(2, '0')}';
        }
        if (ym != targetMonth) continue;
      }
      if (filterStatus) {
        final status = (data['status'] ?? 'completed').toString().toLowerCase();
        if (status != targetStatus) continue;
      }
      if (filterForm) {
        final key = _formKeyForDoc(data);
        if (key != targetFormKey) continue;
      }
      if (filterSearch) {
        final userId = data['userId'] as String?;
        final formId = data['formId'] as String?;
        final teacherName =
            (userId != null ? (_teachersData[userId]?['name'] ?? '') : '')
            .toString()
            .toLowerCase();
        final formTitle =
            (formId != null ? (_formTitles[formId] ?? '') : '').toLowerCase();
        if (!teacherName.contains(q) && !formTitle.contains(q)) continue;
      }
      result.add(doc);
    }
    _filterCacheKey = cacheKey;
    _filteredCache = result;
    _statsCache = null;
    _byTeacherCache = null;
    _byFormCache = null;
    return result;
  }

  /// Form keys that have at least one submission in current filter (excluding form filter). Used for form picker options.
  List<String> get _availableFormKeysForPicker {
    final filterTeacher = _selectedTeacherIds.isNotEmpty;
    final filterMonth = !_showAllMonths && _selectedYearMonth != null;
    final filterStatus = _selectedStatus != null;
    final filterSearch = _searchQuery.isNotEmpty;
    final q = filterSearch ? _searchQuery.toLowerCase() : '';
    final targetMonth = filterMonth ? _selectedYearMonth! : '';
    final targetStatus = filterStatus ? _selectedStatus!.toLowerCase() : '';
    final keys = <String>{};
    for (final doc in _allSubmissions) {
        final data = doc.data() as Map<String, dynamic>;
      if (filterTeacher) {
        final userId = data['userId'] as String?;
        if (userId == null || !_selectedTeacherIds.contains(userId)) continue;
      }
      if (filterMonth) {
        String? ym = data['yearMonth'] as String?;
        if (ym == null) {
          final ts = (data['submittedAt'] as Timestamp?)?.toDate();
          if (ts != null) ym = '${ts.year}-${ts.month.toString().padLeft(2, '0')}';
        }
        if (ym != targetMonth) continue;
      }
      if (filterStatus) {
        final status = (data['status'] ?? 'completed').toString().toLowerCase();
        if (status != targetStatus) continue;
      }
      if (filterSearch) {
        final userId = data['userId'] as String?;
        final formId = data['formId'] as String?;
        final teacherName =
            (userId != null ? (_teachersData[userId]?['name'] ?? '') : '')
                .toString()
                .toLowerCase();
        final formTitle =
            (formId != null ? (_formTitles[formId] ?? '') : '').toLowerCase();
        if (!teacherName.contains(q) && !formTitle.contains(q)) continue;
      }
      final key = _formKeyForDoc(data);
      if (key != null) keys.add(key);
    }
    final list = keys.toList();
    list.sort((a, b) {
      final orderA = _formKeySortOrder(a);
      final orderB = _formKeySortOrder(b);
      if (orderA != orderB) return orderA.compareTo(orderB);
      return _formKeyToDisplayTitle(a)
          .toLowerCase()
          .compareTo(_formKeyToDisplayTitle(b).toLowerCase());
    });
    return list;
  }

  Map<String, List<QueryDocumentSnapshot>> get _filteredByTeacher {
    if (_byTeacherCache != null) return _byTeacherCache!;
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in _filteredSubmissions) {
      final userId =
          (doc.data() as Map<String, dynamic>)['userId'] as String?;
      if (userId != null) {
        grouped.putIfAbsent(userId, () => []).add(doc);
      }
    }
    return _byTeacherCache = grouped;
  }

  Map<String, List<QueryDocumentSnapshot>> get _filteredByForm {
    if (_byFormCache != null) return _byFormCache!;
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in _filteredSubmissions) {
      final data = doc.data() as Map<String, dynamic>;
      final formId = data['formId'] as String?;
      if (formId == null) continue;
      final formType = (data['formType'] ?? '').toString().toLowerCase();
      String key;
      if (formType == _kFormTypeDaily) {
        key = _kDailyClassReportKey;
      } else if (formType == _kFormTypeWeekly) {
        key = _kWeeklyReportKey;
      } else if (formType == _kFormTypeMonthly) {
        key = _kMonthlyReportKey;
      } else {
        key = formId;
      }
      grouped.putIfAbsent(key, () => []).add(doc);
    }
    return _byFormCache = grouped;
  }

  static const _cPrimary = Color(0xff0386FF);
  static const _cText = Color(0xff1E293B);
  static const _cSub = Color(0xff64748B);
  static const _cMuted = Color(0xff94A3B8);
  static const _cBorder = Color(0xffE2E8F0);
  static const _cBg = Color(0xffF8FAFC);
  static const _cGreen = Color(0xff16A34A);
  static const _cAmber = Color(0xffF59E0B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: (_isLoading || _isLoadingPreferences)
          ? _SubmissionsLoadingPlaceholder(
              title: AppLocalizations.of(context)!.adminAllSubmissionsTitle,
            )
          : Column(children: [
              _buildToolbar(),
              const Divider(height: 1, color: _cBorder),
              if (!_showAllMonths && _selectedYearMonth != null) _buildMonthBanner(),
              ..._topActionsWidgets(),
                Expanded(child: _buildContent()),
            ]),
    );
  }

  List<Widget> _topActionsWidgets() {
    final showLoadOther = _showAllMonths && !_loadedOtherForms;
    final showLoadMore = _hasMoreSubmissions || _isLoadingMore;
    if (!showLoadOther && !showLoadMore) return const [];
    final l10n = AppLocalizations.of(context)!;
    return [
      Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _cBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          if (showLoadOther)
            InkWell(
              onTap: _isLoadingOtherForms ? null : _loadOtherForms,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cBg,
                  border: Border.all(color: _cBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoadingOtherForms
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        l10n.adminSubmissionsLoadOtherForms,
        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _cPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          if (showLoadOther && showLoadMore) const SizedBox(width: 8),
          if (showLoadMore)
            InkWell(
              onTap: _isLoadingMore ? null : _loadMoreSubmissions,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cBg,
                  border: Border.all(color: _cBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoadingMore
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : Text(
                        l10n.adminSubmissionsLoadMore,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _cPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
        ],
      ),
    ),
    ];
  }

  Widget _buildMonthBanner() {
    final l10n = AppLocalizations.of(context)!;
    final ym = _selectedYearMonth!;
    final count = _filteredSubmissions.length;
    return Container(
      width: double.infinity,
      color: const Color(0xffEFF6FF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _cPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_month, size: 20, color: Color(0xff0386FF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getMonthDisplayName(ym),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _cText),
                ),
                Text(
                  '$count ${count == 1 ? 'submission' : 'submissions'}',
                  style: GoogleFonts.inter(fontSize: 12, color: _cMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _showAllMonths = true;
                _selectedYearMonth = null;
              });
              _loadAllSubmissions(clearLoadingWhenDone: true);
            },
            child: Text(
              l10n.formViewAll,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _cPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final l10n = AppLocalizations.of(context)!;
    final stats = _quickStats;
    final hasActiveFilters =
        _selectedTeacherIds.isNotEmpty || !_showAllMonths || _selectedStatus != null || _selectedFormKey != null;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
            Text(
                l10n.adminAllSubmissionsTitle,
              style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _cText),
              ),
              const SizedBox(width: 8),
            Text(
                '${stats['total']} total · ${stats['teachers']} teachers · ${stats['completed']} done · ${stats['pending']} pending',
                style: GoogleFonts.inter(fontSize: 11, color: _cMuted),
              ),
              const Spacer(),
              _iconBtn(
                icon: Icons.settings_outlined,
                tooltip: l10n.adminPreferencesTitle,
                onTap: _showSettingsDialog,
            ),
          ],
        ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: Row(
        children: [
                SizedBox(
                  width: 200,
                  child: TextField(
            controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.inter(fontSize: 12),
            decoration: InputDecoration(
              hintText: l10n.adminSubmissionsSearchPlaceholder,
                      hintStyle:
                          GoogleFonts.inter(fontSize: 12, color: _cMuted),
                      prefixIcon:
                          const Icon(Icons.search, size: 16, color: _cSub),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 32, minHeight: 0),
              suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                              child: const Icon(Icons.close,
                                  size: 14, color: _cSub),
                    )
                  : null,
                      suffixIconConstraints:
                          const BoxConstraints(minWidth: 28, minHeight: 0),
              filled: true,
                      fillColor: _cBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      isDense: true,
              border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _cBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: _cPrimary, width: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                        _chip(
                          label: _selectedTeacherIds.isEmpty
                              ? l10n.adminSubmissionsTeachersAll
                              : '${l10n.adminSubmissionsFilterTeachers} (${_selectedTeacherIds.length})',
                          active: _selectedTeacherIds.isNotEmpty,
                  onTap: _showTeacherPicker,
                ),
                        const SizedBox(width: 4),
                        _chip(
                  label: _showAllMonths
                      ? l10n.adminSubmissionsAllTime
                              : _getMonthDisplayName(
                                  _selectedYearMonth ?? ''),
                          active: !_showAllMonths,
                  onTap: _showMonthPicker,
                ),
                        const SizedBox(width: 4),
                        _chip(
                  label: _selectedStatus == null
                      ? l10n.adminSubmissionsAllStatus
                      : _selectedStatusLabel,
                          active: _selectedStatus != null,
                  onTap: _showStatusPicker,
                ),
                        const SizedBox(width: 4),
                        _chip(
                          label: _selectedFormKey == null
                              ? (AppLocalizations.of(context)!.adminSubmissionsAllForms)
                              : _formKeyToDisplayTitle(_selectedFormKey!),
                          active: _selectedFormKey != null,
                          onTap: _showFormPicker,
                        ),
                        if (hasActiveFilters) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() {
                        _selectedTeacherIds.clear();
                        _showAllMonths = true;
                        _selectedYearMonth = null;
                        _selectedStatus = null;
                              _selectedFormKey = null;
                            }),
                            child: Container(
                              height: 26,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xffFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.commonClear,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xffEF4444)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _iconBtn(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
      onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: _cSub),
        ),
      ),
    );
  }

  Widget _chip(
      {required String label, bool active = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _cPrimary.withValues(alpha: 0.08) : _cBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? _cPrimary.withValues(alpha: 0.3) : _cBorder,
          ),
        ),
        child: Text(
              label,
              style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? _cPrimary : _cSub,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> get _quickStats {
    if (_statsCache != null) return _statsCache!;
    final filtered = _filteredSubmissions;
    final uniqueTeachers = <String>{};
    var completedCount = 0;
    var pendingCount = 0;
    for (var doc in filtered) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String?;
      if (userId != null) uniqueTeachers.add(userId);
      final status = (data['status'] ?? 'completed').toString().toLowerCase();
      if (status == 'completed') {
        completedCount++;
      } else if (status == 'pending') {
        pendingCount++;
      }
    }
    return _statsCache = {
      'total': filtered.length,
      'teachers': uniqueTeachers.length,
      'completed': completedCount,
      'pending': pendingCount,
    };
  }

  Widget _buildContent() {
    if (_filteredSubmissions.isEmpty && !_hasMoreSubmissions && (_loadedOtherForms || !_showAllMonths)) {
      return _buildEmpty();
    }
    return _buildTeacherView();
  }

  Widget _buildEmpty() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 36, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(l10n.adminSubmissionsNoSubmissions,
              style: GoogleFonts.inter(fontSize: 13, color: _cSub)),
          const SizedBox(height: 4),
          Text(l10n.adminSubmissionsTryAdjustingFilters,
              style: GoogleFonts.inter(fontSize: 11, color: _cMuted)),
        ],
      ),
    );
  }

  String _formKeyToDisplayTitle(String key) {
    if (key == _kDailyClassReportKey) return 'Daily Class Report';
    if (key == _kWeeklyReportKey) return 'Weekly Report';
    if (key == _kMonthlyReportKey) return 'Monthly Report';
    return _formTitles[key] ?? 'Form';
  }

  int _formKeySortOrder(String key) {
    if (key == _kDailyClassReportKey) return 0;
    if (key == _kWeeklyReportKey) return 1;
    if (key == _kMonthlyReportKey) return 2;
    return 3;
  }

  Widget _buildTeacherView() {
    final grouped = _filteredByTeacher;
    // Show all teachers that have submissions (favorites only affect order, not visibility)
    List<String> baseIds = grouped.isEmpty
        ? List<String>.from(_allTeacherIds)
        : List<String>.from(grouped.keys);
    baseIds.sort((a, b) {
      final favA = _favoriteTeacherIds.contains(a);
      final favB = _favoriteTeacherIds.contains(b);
      if (favA && !favB) return -1;
      if (!favA && favB) return 1;
      final na = (_teachersData[a]?['name'] ?? '').toString();
      final nb = (_teachersData[b]?['name'] ?? '').toString();
      return na.compareTo(nb);
    });
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: baseIds.length,
      itemBuilder: (context, index) {
        final tid = baseIds[index];
        final subs = grouped[tid] ?? [];
        final info = _teachersData[tid];
        final name = info?['name'] ?? 'Unknown';
        final isFav = _favoriteTeacherIds.contains(tid);
        return _TeacherRow(
          name: name,
          count: subs.length,
          isFavorite: isFav,
          onTap: () {
            if (MediaQuery.of(context).size.width > 600) {
              _showMinimalistPopup(
                title: name,
                content: _MinimalistSubmissionList(
                  submissions: subs,
                  isDailyClassReport: false,
                  teachersData: _teachersData,
                  formTitle: name,
                  parentContext: context,
                  groupByFormType: true,
                ),
              );
            } else {
              _showTeacherSubmissionsSheet(tid, name, subs);
            }
          },
          onFavToggle: () {
            setState(() {
              if (isFav) {
                _favoriteTeacherIds.remove(tid);
              } else {
                _favoriteTeacherIds.add(tid);
              }
            });
            _saveAdminPreferences();
          },
        );
      },
    );
  }

  void _showAdminFormSubmissionsSheet(
    String formId,
    String formTitle,
    List<QueryDocumentSnapshot> submissions,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminFormSheet(
        formTitle: formTitle,
        submissions: submissions,
        teachersData: _teachersData,
        favoriteTeacherIds: Set<String>.from(_favoriteTeacherIds),
        getShiftSummaries: _getShiftSummariesForIds,
        parentContext: ctx,
      ),
    );
  }

  void _showTeacherSubmissionsSheet(
    String teacherId,
    String teacherName,
    List<QueryDocumentSnapshot> submissions,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeacherSubmissionsSheet(
        teacherName: teacherName,
        submissions: submissions,
        getFormTitles: () => _formTitles,
        parentContext: ctx,
      ),
    );
  }

  /// Popup style Gmail/Google (top-right, compact) for desktop/tablet.
  void _showMinimalistPopup({
    required String title,
    required Widget content,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)?.commonClose ?? 'Dismiss',
      barrierColor: Colors.black12,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.only(top: 60, right: 16, bottom: 16),
              child: Container(
                width: 360,
                constraints: const BoxConstraints(maxHeight: 600),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
        children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                            child: Text(
                              title,
                        style: GoogleFonts.inter(
                                fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff1E293B),
                        ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 18, color: Color(0xff64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
                    const Divider(height: 1, color: Color(0xffF1F5F9)),
                    Flexible(child: content),
              ],
            ),
          ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          alignment: Alignment.topRight,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  String get _selectedStatusLabel {
    final l10n = AppLocalizations.of(context)!;
    switch (_selectedStatus) {
      case 'completed':
        return l10n.adminSubmissionsCompleted;
      case 'pending':
        return l10n.adminSubmissionsPending;
      case 'draft':
        return l10n.formDraft;
      default:
        return l10n.adminSubmissionsAllStatus;
    }
  }

  void _showTeacherPicker() {
    setState(() => _teacherPickerSearchQuery = '');
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          final q = _teacherPickerSearchQuery.trim().toLowerCase();
          var filteredIds = q.isEmpty
              ? List<String>.from(_allTeacherIds)
              : _allTeacherIds.where((id) {
                  final info = _teachersData[id];
                  final name = (info?['name'] ?? '').toString().toLowerCase();
                  final email = (info?['email'] ?? '').toString().toLowerCase();
                  return name.contains(q) || email.contains(q);
                }).toList();
          filteredIds = filteredIds
            ..sort((a, b) {
              final favA = _favoriteTeacherIds.contains(a);
              final favB = _favoriteTeacherIds.contains(b);
              if (favA && !favB) return -1;
              if (!favA && favB) return 1;
              final na = (_teachersData[a]?['name'] ?? '').toString();
              final nb = (_teachersData[b]?['name'] ?? '').toString();
              return na.compareTo(nb);
            });
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
                        Text(l10n.adminSubmissionsSelectTeachers,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (_selectedTeacherIds.length == filteredIds.length) {
                                _selectedTeacherIds.clear();
                              } else {
                                _selectedTeacherIds.clear();
                                _selectedTeacherIds.addAll(filteredIds);
                              }
                            });
                          },
                          child: Text(
                            _selectedTeacherIds.length == filteredIds.length
                                ? l10n.adminSubmissionsClearAll
                                : l10n.adminSubmissionsSelectAll,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {});
                            Navigator.pop(context);
                          },
                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 18)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        onChanged: (v) {
                          setState(() => _teacherPickerSearchQuery = v);
                          setModalState(() {});
                        },
                        style: GoogleFonts.inter(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: l10n.adminSubmissionsSearchPlaceholder,
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: _cMuted),
                          prefixIcon: const Icon(Icons.search, size: 16, color: _cSub),
                          prefixIconConstraints: const BoxConstraints(minWidth: 32),
                          filled: true,
                          fillColor: _cBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filteredIds.length,
                      itemExtent: 40,
                      itemBuilder: (context, index) {
                        final teacherId = filteredIds[index];
                        final info = _teachersData[teacherId];
                        final isSelected = _selectedTeacherIds.contains(teacherId);
                        final isFav = _favoriteTeacherIds.contains(teacherId);
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              if (isSelected) {
                                _selectedTeacherIds.remove(teacherId);
                              } else {
                                _selectedTeacherIds.add(teacherId);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                                Icon(
                                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                  size: 16,
                                  color: isSelected ? _cPrimary : _cMuted,
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: _cPrimary.withValues(alpha: 0.1),
                                  child: Text(
                                    ((info?['name'] ?? 'U') as String).isNotEmpty
                                        ? ((info?['name'] ?? 'U') as String)[0].toUpperCase()
                                        : 'U',
                                    style: GoogleFonts.inter(fontSize: 10, color: _cPrimary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    info?['name'] ?? l10n.commonUnknownUser,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isFav) const Icon(Icons.star, size: 14, color: _cAmber),
                            ],
                          ),
                        ),
                        );
                      },
                    ),
                  ),
                          Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _cBorder)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cPrimary,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          '${l10n.adminSubmissionsApply} (${_selectedTeacherIds.length} ${l10n.selected})',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showMonthPicker() {
    final l10n = AppLocalizations.of(context)!;
    final monthList = _monthsForPicker;
    final now = DateTime.now();
    final currentYearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
                ),
                child: Row(
                  children: [
                                Text(
                      l10n.formSelectMonth,
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                ),
                              ],
                            ),
                          ),
              ListTile(
                leading: Icon(Icons.all_inclusive, color: _showAllMonths ? _cPrimary : _cSub, size: 22),
                title: Text(
                  l10n.timesheetAllTime,
                  style: GoogleFonts.inter(
                    fontWeight: _showAllMonths ? FontWeight.w600 : FontWeight.w400,
                    color: _showAllMonths ? _cPrimary : _cText,
                  ),
                ),
                trailing: _showAllMonths ? const Icon(Icons.check, color: Color(0xff0386FF)) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showAllMonths = true;
                    _selectedYearMonth = null;
                  });
                  _loadAllSubmissions(clearLoadingWhenDone: true);
                },
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  itemCount: monthList.length,
                  itemBuilder: (context, index) {
                    final month = monthList[index];
                    final isSelected = !_showAllMonths && _selectedYearMonth == month;
                    final isCurrent = month == currentYearMonth;
                    return ListTile(
                      leading: Icon(Icons.calendar_today, color: isSelected ? _cPrimary : _cSub, size: 22),
                      title: Row(
                        children: [
                      Text(
                            _getMonthDisplayName(month),
                        style: GoogleFonts.inter(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? _cPrimary : _cText,
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
                                l10n.formCurrentMonth,
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
                      trailing: isSelected ? const Icon(Icons.check, color: Color(0xff0386FF)) : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _showAllMonths = false;
                          _selectedYearMonth = month;
                        });
                        _loadAllSubmissions(clearLoadingWhenDone: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusPicker() {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      _StatusOption(l10n.adminSubmissionsAllStatus, null),
      _StatusOption(l10n.adminSubmissionsCompleted, 'completed'),
      _StatusOption(l10n.adminSubmissionsPending, 'pending'),
      _StatusOption(l10n.formDraft, 'draft'),
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.adminSubmissionsFilterByStatus,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((o) {
              final isSelected = o.value == null
                  ? _selectedStatus == null
                  : _selectedStatus == o.value;
              return InkWell(
                onTap: () {
                  setState(() => _selectedStatus = o.value);
                  Navigator.pop(context);
                },
                  child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                          children: [
                            Text(
                        o.label,
                              style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? _cPrimary : _cText,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xff0386FF)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
                        onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
    );
  }

  void _showFormPicker() {
    final l10n = AppLocalizations.of(context)!;
    final availableKeys = _availableFormKeysForPicker;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.adminSubmissionsFilterByForm,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                          onTap: () {
                  setState(() => _selectedFormKey = null);
                            Navigator.pop(context);
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                      Text(
                        l10n.adminSubmissionsAllForms,
                                    style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: _selectedFormKey == null ? FontWeight.w600 : FontWeight.w400,
                          color: _selectedFormKey == null ? _cPrimary : _cText,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedFormKey == null) const Icon(Icons.check, size: 16, color: Color(0xff0386FF)),
                    ],
                  ),
                ),
              ),
              ...availableKeys.map((key) {
                final isSelected = _selectedFormKey == key;
                final label = _formKeyToDisplayTitle(key);
                if (label.isEmpty) return const SizedBox.shrink();
                return InkWell(
                  onTap: () {
                    setState(() => _selectedFormKey = key);
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? _cPrimary : _cText,
                                        ),
                            overflow: TextOverflow.ellipsis,
                                      ),
                        ),
                        if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xff0386FF)),
                                    ],
                                  ),
                                ),
                );
              }),
                              ],
                            ),
                          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        actionsPadding: const EdgeInsets.all(8),
        title: Text(
          l10n.adminPreferencesTitle,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.adminPreferencesShowAllMonthsDefault,
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  value: _defaultShowAllMonths,
                  onChanged: (v) => setDialogState(() => _defaultShowAllMonths = v),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.adminPreferencesFavoriteTeachers,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _cSub),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.adminPreferencesFavoriteCount(_favoriteTeacherIds.length),
                  style: GoogleFonts.inter(fontSize: 11, color: _cMuted),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel, style: const TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _viewMode = 'by_teacher';
                _showAllMonths = _defaultShowAllMonths;
              });
              _saveAdminPreferences();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _cPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(l10n.commonSave, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _getMonthDisplayName(String yearMonth) {
    try {
      final parts = yearMonth.split('-');
      if (parts.length != 2) return yearMonth;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = DateTime(year, month, 1);
      return DateFormat('MMM yyyy').format(date);
    } catch (e) {
      return yearMonth;
    }
  }
  List<String> get _monthsForPicker {
    final now = DateTime.now();
    final set = <String>{..._availableMonths};
    for (var i = 0; i < 24; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      set.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    return set.toList()..sort((a, b) => b.compareTo(a));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOADING PLACEHOLDER (step messages like Audit screen)
// ═══════════════════════════════════════════════════════════════════════════

class _SubmissionsLoadingPlaceholder extends StatefulWidget {
  final String title;

  const _SubmissionsLoadingPlaceholder({required this.title});

  @override
  State<_SubmissionsLoadingPlaceholder> createState() =>
      _SubmissionsLoadingPlaceholderState();
}

class _SubmissionsLoadingPlaceholderState
    extends State<_SubmissionsLoadingPlaceholder> {
  int _stepIndex = 0;

  static const _loadingSteps = [
    'Loading Daily Report forms…',
    'Loading Weekly Report forms…',
    'Loading Monthly Report forms…',
    'Loading teacher submissions…',
    'Almost there…',
  ];

  @override
  void initState() {
    super.initState();
    _cycleStep();
  }

  Future<void> _cycleStep() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      setState(() => _stepIndex = (_stepIndex + 1) % _loadingSteps.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
          children: [
            Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
                children: [
                  Text(
                widget.title,
                    style: GoogleFonts.inter(
                  fontSize: 14,
                      fontWeight: FontWeight.w600,
                  color: const Color(0xff1E293B),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xff0386FF).withOpacity(0.8),
                  ),
                    ),
                  ),
                ],
              ),
            ),
        const Divider(height: 1, color: Color(0xffE2E8F0)),
            Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  backgroundColor: const Color(0xffE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(Icons.sync, color: const Color(0xff0386FF), size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _loadingSteps[_stepIndex],
                          style: GoogleFonts.inter(
                          fontSize: 15,
                          color: const Color(0xff475569),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                  ),
                ],
              ),
            ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMPACT ROW WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _FormRow extends StatefulWidget {
  final String formTitle;
  final int count;
  final int completedCount;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _FormRow({
    required this.formTitle,
    required this.count,
    required this.completedCount,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_FormRow> createState() => _FormRowState();
}

class _FormRowState extends State<_FormRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? const Color(0xffF1F5F9)
        : widget.isHighlighted
            ? const Color(0xffEFF6FF)
            : Colors.white;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
            color: bg,
            border: const Border(
                bottom: BorderSide(color: Color(0xffF1F5F9), width: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                widget.isHighlighted
                    ? Icons.description
                    : Icons.description_outlined,
                size: 16,
                color: widget.isHighlighted
                    ? const Color(0xff0386FF)
                    : const Color(0xff94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.formTitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: widget.isHighlighted
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: const Color(0xff1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xffF1F5F9),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${widget.count}',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff64748B)),
                ),
              ),
              if (widget.completedCount > 0) ...[
                  const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xffDCFCE7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${widget.completedCount}',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                      fontWeight: FontWeight.w600,
                        color: const Color(0xff16A34A)),
                    ),
                  ),
                ],
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: _hovered
                    ? const Color(0xff64748B)
                    : const Color(0xffCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherRow extends StatefulWidget {
  final String name;
  final int count;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavToggle;

  const _TeacherRow({
    required this.name,
    required this.count,
    required this.isFavorite,
    required this.onTap,
    required this.onFavToggle,
  });

  @override
  State<_TeacherRow> createState() => _TeacherRowState();
}

class _TeacherRowState extends State<_TeacherRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xffF1F5F9) : Colors.white,
            border: const Border(
                bottom: BorderSide(color: Color(0xffF1F5F9), width: 0.5)),
          ),
          child: Row(
        children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xff0386FF).withValues(alpha: 0.1),
                child: Text(
                  widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
            style: GoogleFonts.inter(
                      fontSize: 10, color: const Color(0xff0386FF)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.name,
            style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xffF1F5F9),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${widget.count}',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff64748B)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onFavToggle,
                child: Icon(
                  widget.isFavorite ? Icons.star : Icons.star_border,
                  size: 16,
                  color: widget.isFavorite
                      ? const Color(0xffF59E0B)
                      : (_hovered
                          ? const Color(0xff94A3B8)
                          : const Color(0xffCBD5E1)),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 16,
                  color: _hovered
                      ? const Color(0xff64748B)
                      : const Color(0xffCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  POPUP MINIMALISTE STYLE GMAIL (haut-droite, compact)
// ═══════════════════════════════════════════════════════════════════════════

class _MinimalistSubmissionList extends StatefulWidget {
  final List<QueryDocumentSnapshot> submissions;
  final bool isDailyClassReport;
  final Map<String, Map<String, dynamic>> teachersData;
  final String formTitle;
  final BuildContext parentContext;
  final bool groupByFormType;
  /// When true (e.g. view-by-form): first group by teacher, then by student.
  final bool groupByTeacherFirst;

  const _MinimalistSubmissionList({
    required this.submissions,
    required this.isDailyClassReport,
    required this.teachersData,
    required this.formTitle,
    required this.parentContext,
    this.groupByFormType = false,
    this.groupByTeacherFirst = false,
  });

  @override
  State<_MinimalistSubmissionList> createState() => _MinimalistSubmissionListState();
}

class _MinimalistSubmissionListState extends State<_MinimalistSubmissionList> {
  bool _isLoadingShifts = true;
  final Map<String, TeachingShift> _shiftCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.isDailyClassReport || widget.groupByFormType) {
      _loadShiftData();
    } else {
      _isLoadingShifts = false;
    }
  }

  Future<void> _loadShiftData() async {
    final shiftIds = <String>{};
    for (var doc in widget.submissions) {
    final data = doc.data() as Map<String, dynamic>;
      final sid = (data['shiftId'] ?? data['shift_id'])?.toString();
      if (sid != null && sid.isNotEmpty && sid != 'N/A') shiftIds.add(sid);
    }
    if (shiftIds.isEmpty) {
      if (mounted) setState(() => _isLoadingShifts = false);
      return;
    }
    final list = shiftIds.toList();
    final cache = <String, TeachingShift>{};
    for (var i = 0; i < list.length; i += 10) {
      final chunk = list.skip(i).take(10).toList();
      try {
        await Future.wait(chunk.map((id) async {
          final snap = await FirebaseFirestore.instance
              .collection('teaching_shifts')
              .doc(id)
              .get();
          if (snap.exists) {
            cache[id] = TeachingShift.fromFirestore(snap);
          }
        }));
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _shiftCache.addAll(cache);
        _isLoadingShifts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingShifts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final l10n = AppLocalizations.of(context)!;
    if (widget.groupByTeacherFirst && widget.isDailyClassReport) {
      return _buildGroupedByTeacherThenStudentList(l10n);
    }
    if (widget.groupByTeacherFirst) {
      return _buildGroupedByTeacherThenFlatList(l10n);
    }
    if (widget.isDailyClassReport) {
      return _buildGroupedByStudentList(l10n);
    }
    if (widget.groupByFormType) {
      return _buildGroupedByFormTypeList(l10n);
    }
    return _buildFlatList(context, widget.submissions);
  }

  Widget _buildGroupedByStudentList(AppLocalizations l10n) {
    const generalUnknownKey = 'General / Unknown';
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in widget.submissions) {
      final data = doc.data() as Map<String, dynamic>;
      final shiftId = (data['shiftId'] ?? data['shift_id'])?.toString();
      String studentName = generalUnknownKey;
      if (shiftId != null && _shiftCache.containsKey(shiftId)) {
        final names = _shiftCache[shiftId]!.studentNames;
        if (names.isNotEmpty) studentName = names.first;
      }
      grouped.putIfAbsent(studentName, () => []).add(doc);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == generalUnknownKey) return 1;
        if (b == generalUnknownKey) return -1;
        return a.compareTo(b);
      });
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final student = sortedKeys[index];
        final docs = grouped[student]!;
        final displayName = student == generalUnknownKey ? l10n.adminSubmissionsGeneralUnknown : student;
              return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xffF8FAFC),
              width: double.infinity,
                    child: Row(
                      children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xffCBD5E1),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                          child: Text(
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${docs.length}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff94A3B8)),
                        ),
                      ],
                    ),
                  ),
            ...docs.map((doc) => _buildCompactRow(context, doc, showTeacher: false)),
          ],
        );
      },
    );
  }

  /// View-by-form: first group by teacher, then by student under each teacher.
  Widget _buildGroupedByTeacherThenStudentList(AppLocalizations l10n) {
    final byTeacherId = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in widget.submissions) {
      final data = doc.data() as Map<String, dynamic>;
      final uid = (data['userId'] as String?) ?? '';
      final key = uid.isEmpty ? 'unknown' : uid;
      byTeacherId.putIfAbsent(key, () => []).add(doc);
    }
    final teacherIds = byTeacherId.keys.toList()
      ..sort((a, b) {
        final nameA = a == 'unknown' ? l10n.commonUnknown : (widget.teachersData[a]?['name'] ?? l10n.commonUnknown).toString();
        final nameB = b == 'unknown' ? l10n.commonUnknown : (widget.teachersData[b]?['name'] ?? l10n.commonUnknown).toString();
        if (nameA == l10n.commonUnknown) return 1;
        if (nameB == l10n.commonUnknown) return -1;
        return nameA.compareTo(nameB);
      });
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: teacherIds.length,
      itemBuilder: (context, index) {
        final tid = teacherIds[index];
        final docs = byTeacherId[tid]!;
        final teacherName = tid == 'unknown' ? l10n.commonUnknown : (widget.teachersData[tid]?['name'] ?? l10n.commonUnknown).toString();
        final studentSections = _buildStudentGroupSection(l10n, docs);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xffEEF2FF),
              width: double.infinity,
                    child: Row(
                      children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xff6366F1),
                    child: Text(
                      teacherName.isNotEmpty ? teacherName[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                    child: Text(
                      teacherName,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff4338CA),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${docs.length}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff6366F1)),
                        ),
                      ],
                    ),
                  ),
            ...studentSections,
          ],
        );
      },
    );
  }

  /// View-by-form (non-daily): group by teacher, then flat list of submissions.
  Widget _buildGroupedByTeacherThenFlatList(AppLocalizations l10n) {
    final byTeacherId = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in widget.submissions) {
      final data = doc.data() as Map<String, dynamic>;
      final uid = (data['userId'] as String?) ?? '';
      final key = uid.isEmpty ? 'unknown' : uid;
      byTeacherId.putIfAbsent(key, () => []).add(doc);
    }
    final teacherIds = byTeacherId.keys.toList()
      ..sort((a, b) {
        final nameA = a == 'unknown' ? l10n.commonUnknown : (widget.teachersData[a]?['name'] ?? l10n.commonUnknown).toString();
        final nameB = b == 'unknown' ? l10n.commonUnknown : (widget.teachersData[b]?['name'] ?? l10n.commonUnknown).toString();
        if (nameA == l10n.commonUnknown) return 1;
        if (nameB == l10n.commonUnknown) return -1;
        return nameA.compareTo(nameB);
      });
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: teacherIds.length,
      itemBuilder: (context, index) {
        final tid = teacherIds[index];
        final docs = byTeacherId[tid]!;
        final teacherName = tid == 'unknown' ? l10n.commonUnknown : (widget.teachersData[tid]?['name'] ?? l10n.commonUnknown).toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
                            children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xffEEF2FF),
              width: double.infinity,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xff6366F1),
                    child: Text(
                      teacherName.isNotEmpty ? teacherName[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                      teacherName,
                                  style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff4338CA),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${docs.length}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff6366F1)),
                                ),
                            ],
                          ),
            ),
            ...docs.map((doc) => _buildCompactRow(context, doc, showTeacher: false)),
          ],
        );
      },
    );
  }

  Widget _buildGroupedByFormTypeList(AppLocalizations l10n) {
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in widget.submissions) {
      final d = doc.data() as Map<String, dynamic>;
      final title = (d['formTitle'] ?? d['form_title'] ?? l10n.formDefaultTitle).toString();
      if (title.isEmpty) continue;
      grouped.putIfAbsent(title, () => []).add(doc);
    }
    final keys = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final docs = grouped[key]!;
        final isDailyReport = key.toLowerCase().contains('daily') ||
            (docs.isNotEmpty &&
                ((docs.first.data() as Map<String, dynamic>)['formType'] ?? '')
                    .toString()
                    .toLowerCase() == 'daily');
        return ExpansionTile(
          title: Text(
            key,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          initiallyExpanded: true,
          shape: const Border(),
          children: isDailyReport && _shiftCache.isNotEmpty
              ? _buildStudentGroupSection(l10n, docs)
              : docs.map((d) => _buildCompactRow(context, d, showTeacher: false)).toList(),
        );
      },
    );
  }

  /// Daily Class Report inside teacher popup: group by student.
  List<Widget> _buildStudentGroupSection(AppLocalizations l10n, List<QueryDocumentSnapshot> docs) {
    const generalUnknownKey = 'General / Unknown';
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final shiftId = (data['shiftId'] ?? data['shift_id'])?.toString();
      String studentName = generalUnknownKey;
      if (shiftId != null && _shiftCache.containsKey(shiftId)) {
        final names = _shiftCache[shiftId]!.studentNames;
        if (names.isNotEmpty) studentName = names.first;
      }
      grouped.putIfAbsent(studentName, () => []).add(doc);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == generalUnknownKey) return 1;
        if (b == generalUnknownKey) return -1;
        return a.compareTo(b);
      });
    final list = <Widget>[];
    for (final student in sortedKeys) {
      final studentDocs = grouped[student]!;
      final displayName = student == generalUnknownKey ? l10n.adminSubmissionsGeneralUnknown : student;
      list.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xffF8FAFC),
          width: double.infinity,
          child: Row(
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: const Color(0xffCBD5E1),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff475569),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${studentDocs.length}',
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff94A3B8)),
              ),
            ],
          ),
        ),
      );
      for (final d in studentDocs) {
        list.add(_buildCompactRow(context, d, showTeacher: false));
      }
    }
    return list;
  }

  Widget _buildFlatList(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: docs.length,
      itemBuilder: (context, index) => _buildCompactRow(context, docs[index], showTeacher: true),
    );
  }

  Widget _buildCompactRow(BuildContext context, QueryDocumentSnapshot doc, {bool showTeacher = false}) {
    final l10n = AppLocalizations.of(context)!;
    final data = doc.data() as Map<String, dynamic>;
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final dateStr = submittedAt != null
        ? DateFormat('MMM d, h:mm a').format(submittedAt)
        : '—';
    final status = (data['status'] ?? 'completed').toString().toLowerCase();
    final isDone = status == 'completed';
    String subtitle = dateStr;
    if (showTeacher) {
      final uid = data['userId'] as String?;
      final name = widget.teachersData[uid]?['name'] ?? l10n.commonUnknown;
      subtitle = '$name · $dateStr';
    }
    return InkWell(
      onTap: () {
        FormDetailsModal.show(
          widget.parentContext,
          formId: doc.id,
          shiftId: (data['shiftId'] ?? data['shift_id'] ?? '').toString(),
          responses: (data['responses'] as Map<String, dynamic>?) ?? {},
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff334155)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xffDCFCE7) : const Color(0xffFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                  isDone ? l10n.commonDone : l10n.adminSubmissionsPending,
                          style: GoogleFonts.inter(
                    fontSize: 10,
                            fontWeight: FontWeight.w600,
                    color: isDone ? const Color(0xff16A34A) : const Color(0xffD97706),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              child: Icon(
                Icons.visibility_outlined,
                size: 16,
                color: const Color(0xff0386FF),
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHEET: form → grouped by teacher → teacher detail
// ═══════════════════════════════════════════════════════════════════════════

class _AdminFormSheet extends StatefulWidget {
  final String formTitle;
  final List<QueryDocumentSnapshot> submissions;
  final Map<String, Map<String, dynamic>> teachersData;
  final Set<String> favoriteTeacherIds;
  final Future<Map<String, TeachingShift>> Function(Set<String> shiftIds) getShiftSummaries;
  final BuildContext parentContext;

  const _AdminFormSheet({
    required this.formTitle,
    required this.submissions,
    required this.teachersData,
    required this.favoriteTeacherIds,
    required this.getShiftSummaries,
    required this.parentContext,
  });

  @override
  State<_AdminFormSheet> createState() => _AdminFormSheetState();
}

class _AdminFormSheetState extends State<_AdminFormSheet> {
  String _selectedTeacherId = '';
  Map<String, TeachingShift>? _teacherShiftSummaries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
        child: Column(
          children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xffCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                    children: [
                      if (_selectedTeacherId.isNotEmpty)
                        InkWell(
                          onTap: () => setState(() {
                            _selectedTeacherId = '';
                            _teacherShiftSummaries = null;
                          }),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.arrow_back,
                                size: 18, color: Color(0xff64748B)),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                              _selectedTeacherId.isEmpty
                                  ? widget.formTitle
                                  : (widget.teachersData[_selectedTeacherId]
                                          ?['name'] ??
                                      l10n.commonUnknownUser),
                    style: GoogleFonts.inter(
                                  fontSize: 13,
                      fontWeight: FontWeight.w600,
                                  color: const Color(0xff1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _selectedTeacherId.isEmpty
                                  ? '${widget.submissions.length} submissions'
                                  : '${widget.submissions.where((d) => (d.data() as Map<String, dynamic>)['userId'] == _selectedTeacherId).length} submissions',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xff94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 18),
                        ),
                  ),
                ],
              ),
            ),
                const Divider(height: 1, color: Color(0xffE2E8F0)),
                Expanded(
                  child: _selectedTeacherId.isEmpty
                      ? _buildTeacherList(scrollController)
                      : _buildTeacherDetail(scrollController),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeacherList(ScrollController controller) {
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in widget.submissions) {
      final uid =
          (doc.data() as Map<String, dynamic>)['userId'] as String? ??
              'unknown';
      grouped.putIfAbsent(uid, () => []).add(doc);
    }
    final teacherIds = grouped.keys.toList()
      ..sort((a, b) {
        final favA = widget.favoriteTeacherIds.contains(a);
        final favB = widget.favoriteTeacherIds.contains(b);
        if (favA && !favB) return -1;
        if (!favA && favB) return 1;
        final na = (widget.teachersData[a]?['name'] ?? '').toString();
        final nb = (widget.teachersData[b]?['name'] ?? '').toString();
        return na.compareTo(nb);
      });
    final bottomPad = 24.0 + (MediaQuery.of(context).padding.bottom);
    return ListView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.only(bottom: bottomPad),
      itemCount: teacherIds.length,
      itemExtent: 40,
      itemBuilder: (context, index) {
        final uid = teacherIds[index];
        final subs = grouped[uid]!;
        final name =
            widget.teachersData[uid]?['name'] ?? 'Unknown';
        return InkWell(
              onTap: () {
            final teacherSubs = widget.submissions
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['userId'] == uid)
                .toList();
            final shiftIds = <String>{};
            for (var d in teacherSubs) {
              final data = d.data() as Map<String, dynamic>;
              final id = (data['shiftId'] ?? data['shift_id'])?.toString();
              if (id != null && id.isNotEmpty && id != 'N/A') shiftIds.add(id);
            }
                setState(() {
              _selectedTeacherId = uid;
              _teacherShiftSummaries = null;
            });
            widget.getShiftSummaries(shiftIds).then((map) {
              if (mounted) setState(() => _teacherShiftSummaries = map);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: Color(0xffF1F5F9), width: 0.5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      const Color(0xff0386FF).withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xff0386FF)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xffF1F5F9),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${subs.length}',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff64748B)),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    size: 16, color: Color(0xffCBD5E1)),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildTeacherDetail(ScrollController controller) {
    if (_teacherShiftSummaries == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final shiftSummaries = _teacherShiftSummaries!;
    final teacherSubs = widget.submissions
        .where((d) =>
            (d.data() as Map<String, dynamic>)['userId'] ==
            _selectedTeacherId)
        .toList();
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in teacherSubs) {
      final data = doc.data() as Map<String, dynamic>;
      final shiftId = (data['shiftId'] ?? data['shift_id'])?.toString();
      String key = 'General';
      if (shiftId != null && shiftSummaries.containsKey(shiftId)) {
        final names = shiftSummaries[shiftId]!.studentNames;
        if (names.isNotEmpty) key = names.first;
      }
      grouped.putIfAbsent(key, () => []).add(doc);
    }
    final keys = grouped.keys.toList()..sort();
    final bottomPad = 24.0 + (MediaQuery.of(context).padding.bottom);
    return ListView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.only(top: 4, bottom: bottomPad),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final student = keys[index];
        final docs = grouped[student]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              color: const Color(0xffF8FAFC),
              child: Text(
                '$student (${docs.length})',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff475569)),
              ),
            ),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final submittedAt =
                  (data['submittedAt'] as Timestamp?)?.toDate();
              final dateStr = submittedAt != null
                  ? DateFormat('MMM d, h:mm a').format(submittedAt)
                  : '—';
              final shiftId =
                  (data['shiftId'] ?? data['shift_id'])?.toString() ?? '';
              final responses =
                  (data['responses'] as Map<String, dynamic>?) ?? {};
              return InkWell(
                onTap: () => FormDetailsModal.show(
                  widget.parentContext,
                  formId: doc.id,
                  shiftId: shiftId,
                  responses: responses,
                ),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                        bottom: BorderSide(
                            color: Color(0xffF1F5F9), width: 0.5)),
              ),
              child: Row(
                children: [
                  Text(
                        dateStr,
                    style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xff475569)),
                  ),
                  const Spacer(),
                      const SizedBox(
                        width: 24,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Icon(Icons.visibility_outlined,
                              size: 14, color: Color(0xff0386FF)),
                        ),
                  ),
                ],
              ),
            ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Body of teacher sheet: form groups (Daily, Weekly, Monthly, etc.)
// ══════════════════════════════════════════════════════════════════════════

const String _teacherSheetDailyKey = '__daily_class_report__';
const String _teacherSheetWeeklyKey = '__weekly_report__';
const String _teacherSheetMonthlyKey = '__monthly_report__';

class _TeacherSheetBody extends StatelessWidget {
  final List<QueryDocumentSnapshot> submissions;
  final Map<String, String> Function() getFormTitles;
  final ScrollController scrollController;
  final BuildContext parentContext;

  const _TeacherSheetBody({
    required this.submissions,
    required this.getFormTitles,
    required this.scrollController,
    required this.parentContext,
  });

  /// Opens a bottom sheet with the list of submissions; row tap opens FormDetailsModal.
  static void showSubmissionsListSheet(
    BuildContext context,
    String formTitle,
    List<QueryDocumentSnapshot> submissions,
    BuildContext parentContext,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomPad = 24.0 + MediaQuery.of(ctx).padding.bottom;
        return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.3,
        maxChildSize: 0.98,
        expand: false,
        builder: (_, sheetScrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formTitle,
                  style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff1E293B),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
          ],
        ),
      ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: sheetScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: bottomPad),
                    itemCount: submissions.length,
                    itemExtent: 56,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemBuilder: (ctx, index) {
                      final l10n = AppLocalizations.of(ctx)!;
                      final doc = submissions[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
                      final dateStr = submittedAt != null
                          ? DateFormat('MMM d, h:mm a').format(submittedAt)
                          : '—';
                      final status = (data['status'] ?? 'completed').toString().toLowerCase();
                      final shiftId = (data['shiftId'] ?? data['shift_id'])?.toString() ?? '';
                      final responses = (data['responses'] as Map<String, dynamic>?) ?? {};
                      return InkWell(
                        onTap: () {
                          FormDetailsModal.show(
                            parentContext,
                            formId: doc.id,
                            shiftId: shiftId,
                            responses: responses,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xffF1F5F9), width: 0.5),
                            ),
                          ),
                          child: Row(
              children: [
                              SizedBox(
                                width: 150,
                                child: Text(
                                  dateStr,
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xff475569)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 80,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'completed'
                                        ? const Color(0xffDCFCE7)
                                        : const Color(0xffFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status == 'completed' ? l10n.commonDone : l10n.adminSubmissionsPending,
                  style: GoogleFonts.inter(
                                      fontSize: 12,
                    fontWeight: FontWeight.w600,
                                      color: status == 'completed'
                                          ? const Color(0xff16A34A)
                                          : const Color(0xffF59E0B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 20,
                                child: Icon(Icons.chevron_right, size: 20, color: Color(0xff94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  List<MapEntry<String, List<QueryDocumentSnapshot>>> _groupByForm() {
    final map = <String, List<QueryDocumentSnapshot>>{};
    for (var doc in submissions) {
      final data = doc.data() as Map<String, dynamic>;
      final formId = data['formId'] as String?;
      final formType = (data['formType'] ?? '').toString().toLowerCase();
      String key;
      if (formType == 'daily') {
        key = _teacherSheetDailyKey;
      } else if (formType == 'weekly') {
        key = _teacherSheetWeeklyKey;
      } else if (formType == 'monthly') {
        key = _teacherSheetMonthlyKey;
      } else {
        key = formId ?? 'other';
      }
      map.putIfAbsent(key, () => []).add(doc);
    }
    for (var list in map.values) {
      list.sort((a, b) {
        final ta = (a.data() as Map<String, dynamic>)['submittedAt'] as Timestamp?;
        final tb = (b.data() as Map<String, dynamic>)['submittedAt'] as Timestamp?;
        return (tb?.millisecondsSinceEpoch ?? 0).compareTo(ta?.millisecondsSinceEpoch ?? 0);
      });
    }
    String titleFor(String k) {
      if (k == _teacherSheetDailyKey) return 'Daily class report';
      if (k == _teacherSheetWeeklyKey) return 'Weekly report';
      if (k == _teacherSheetMonthlyKey) return 'Monthly report';
      return getFormTitles()[k] ?? 'Form';
    }
    final entries = map.entries.toList()
      ..sort((a, b) => titleFor(a.key).compareTo(titleFor(b.key)));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return Center(
        child: Text(
          'No submissions in this period',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff64748B)),
        ),
      );
    }
    final groups = _groupByForm();
    final bottomPad = 24.0 + MediaQuery.of(context).padding.bottom;
    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups[index];
        final formTitle = entry.key == _teacherSheetDailyKey
            ? 'Daily class report'
            : entry.key == _teacherSheetWeeklyKey
                ? 'Weekly report'
                : entry.key == _teacherSheetMonthlyKey
                    ? 'Monthly report'
                    : getFormTitles()[entry.key] ?? 'Form';
        return _buildFormGroupCard(context, formTitle: formTitle, submissions: entry.value);
      },
    );
  }

  Widget _buildFormGroupCard(
    BuildContext context, {
    required String formTitle,
    required List<QueryDocumentSnapshot> submissions,
  }) {
    if (submissions.isEmpty) return const SizedBox.shrink();
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
      child: ListTile(
                  title: Text(
          formTitle,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xff1E293B)),
        ),
        subtitle: Text(
          '${submissions.length} submissions · $completedCount completed',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff64748B)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xff94A3B8)),
        onTap: () {
          _TeacherSheetBody.showSubmissionsListSheet(context, formTitle, submissions, parentContext);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MODIFICATION 3: Améliorer _TeacherSubmissionsSheet
// ══════════════════════════════════════════════════════════════════════════

class _TeacherSubmissionsSheet extends StatelessWidget {
  final String teacherName;
  final List<QueryDocumentSnapshot> submissions;
  final Map<String, String> Function() getFormTitles;
  final BuildContext parentContext;

  const _TeacherSubmissionsSheet({
    required this.teacherName,
    required this.submissions,
    required this.getFormTitles,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      expand: false,
      snap: true,
      snapSizes: const [0.7, 0.9, 0.98],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xffCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                Text(
                              teacherName,
                  style: GoogleFonts.inter(
                                fontSize: 16,
                    fontWeight: FontWeight.w600,
                                color: const Color(0xff1E293B),
                  ),
                ),
                            const SizedBox(height: 2),
                Text(
                              '${submissions.length} submissions',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff94A3B8),
                  ),
                ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 22),
                        tooltip: AppLocalizations.of(context)?.commonClose ?? 'Close',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xffE2E8F0)),
                Expanded(
                  child: _TeacherSheetBody(
                    submissions: submissions,
                    getFormTitles: getFormTitles,
                    scrollController: scrollController,
                    parentContext: parentContext,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MODIFICATION 4: Widget helper pour animer l'ouverture des dropdowns/menus
// ══════════════════════════════════════════════════════════════════════════

/// Wrapper pour les PopupMenuButton avec animation personnalisée
class AnimatedPopupMenuButton<T> extends StatelessWidget {
  final Widget child;
  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final void Function(T)? onSelected;
  final Offset? offset;

  const AnimatedPopupMenuButton({
    super.key,
    required this.child,
    required this.itemBuilder,
    this.onSelected,
    this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      offset: offset ?? const Offset(0, 40),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      // ★ Animation personnalisée
      popUpAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      ),
      itemBuilder: itemBuilder,
      onSelected: onSelected,
      child: child,
    );
  }
}

class _StatusOption {
  final String label;
  final String? value;
  const _StatusOption(this.label, this.value);
}