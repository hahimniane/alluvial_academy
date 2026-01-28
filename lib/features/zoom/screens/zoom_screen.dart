import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/employee_model.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/services/video_call_service.dart';
import '../../../core/services/livekit_service.dart';
import '../../../core/services/user_role_service.dart';
import '../../shift_management/widgets/create_shift_dialog.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

enum _ClassesTimeFilter {
  all,
  joinable,
  activeNow,
  upcoming,
  past,
}

extension on _ClassesTimeFilter {
  String get label {
    switch (this) {
      case _ClassesTimeFilter.all:
        return 'All';
      case _ClassesTimeFilter.joinable:
        return 'Joinable';
      case _ClassesTimeFilter.activeNow:
        return 'Active';
      case _ClassesTimeFilter.upcoming:
        return 'Upcoming';
      case _ClassesTimeFilter.past:
        return 'Past';
    }
  }
}

class ZoomScreen extends StatefulWidget {
  const ZoomScreen({super.key});

  @override
  State<ZoomScreen> createState() => _ZoomScreenState();
}

class _ZoomScreenState extends State<ZoomScreen> with WidgetsBindingObserver {
  // Teachers/admins need visibility into upcoming schedules well in advance.
  // Keep a generous window to avoid "missing" classes due to client-side filtering.
  static const Duration _historyLookback = Duration(days: 30);
  static const Duration _futureLookahead = Duration(days: 365);
  static const Duration _uiTickInterval = Duration(seconds: 10);
  static const _ClassesTimeFilter _defaultTimeFilter = _ClassesTimeFilter.activeNow;

  String? _userRole;
  bool _isLoadingRole = true;
  final Map<String, Future<LiveKitRoomPresenceResult>> _liveKitPresenceFutures = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _suppressSearchListener = false;

  _ClassesTimeFilter _timeFilter = _defaultTimeFilter;
  DateTimeRange? _dateRangeFilter;
  Employee? _teacherFilter;
  String? _subjectFilter;

  Timer? _uiTickTimer;
  Set<String> _autoRefreshPresenceShiftIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
    _startUiTicker();
    _loadUserRole();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startUiTicker();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopUiTicker();
        break;
      case AppLifecycleState.hidden:
        _stopUiTicker();
        break;
    }
  }

  @override
  void dispose() {
    _stopUiTicker();
    WidgetsBinding.instance.removeObserver(this);
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _startUiTicker() {
    _uiTickTimer?.cancel();
    _uiTickTimer = Timer.periodic(_uiTickInterval, (_) {
      if (!mounted) return;
      final isAdmin = _userRole == 'admin' || _userRole == 'super_admin';
      if (isAdmin && _autoRefreshPresenceShiftIds.isNotEmpty) {
        setState(() {
          for (final id in _autoRefreshPresenceShiftIds) {
            _liveKitPresenceFutures.remove(id);
          }
        });
        return;
      }
      setState(() {});
    });
  }

  void _stopUiTicker() {
    _uiTickTimer?.cancel();
    _uiTickTimer = null;
  }

  Future<void> _loadUserRole() async {
    final role = await UserRoleService.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _userRole = role?.toLowerCase();
        _isLoadingRole = false;
      });
    }
  }

  void _onSearchChanged() {
    if (_suppressSearchListener) return;
    final value = _searchController.text;
    if (value == _searchQuery) return;
    setState(() {
      _searchQuery = value;
    });
  }

  /// Get the appropriate shifts stream based on user role
  Stream<List<TeachingShift>> _getShiftsStream(String uid) {
    if (_userRole == 'student') {
      return ShiftService.getStudentShifts(uid);
    } else if (_userRole == 'admin' || _userRole == 'super_admin') {
      return ShiftService.getAllShifts();
    } else {
      // Teachers and others get teacher shifts
      return ShiftService.getTeacherShifts(uid);
    }
  }

  Future<LiveKitRoomPresenceResult> _getLiveKitPresence(String shiftId) {
    return _liveKitPresenceFutures.putIfAbsent(
      shiftId,
      () => LiveKitService.getRoomPresence(shiftId),
    );
  }

  void _refreshLiveKitPresence(String shiftId) {
    setState(() {
      _liveKitPresenceFutures.remove(shiftId);
    });
  }

  int _activeFilterCount() {
    int count = 0;
    if (_timeFilter != _defaultTimeFilter) count++;
    if (_dateRangeFilter != null) count++;
    if (_teacherFilter != null) count++;
    if ((_subjectFilter ?? '').trim().isNotEmpty) count++;
    return count;
  }

  void _clearFilters() {
    _suppressSearchListener = true;
    _searchController.clear();
    _suppressSearchListener = false;
    setState(() {
      _searchQuery = '';
      _timeFilter = _defaultTimeFilter;
      _dateRangeFilter = null;
      _teacherFilter = null;
      _subjectFilter = null;
    });
  }

  String _normalizeSearch(String text) {
    return text.toLowerCase().trim();
  }

  bool _matchesSearch(TeachingShift shift, String rawQuery) {
    final query = _normalizeSearch(rawQuery);
    if (query.isEmpty) return true;

    final haystacks = <String>[
      shift.displayName,
      shift.teacherName,
      shift.studentNames.join(', '),
      shift.subjectDisplayName ?? '',
      shift.effectiveSubjectDisplayName,
      shift.id,
    ].map(_normalizeSearch);

    for (final hay in haystacks) {
      if (hay.contains(query)) return true;
    }
    return false;
  }

  bool _matchesTeacherFilter(TeachingShift shift) {
    final teacher = _teacherFilter;
    if (teacher == null) return true;

    final teacherId = _normalizeSearch(teacher.documentId);
    final teacherEmail = _normalizeSearch(teacher.email);
    final shiftTeacherId = _normalizeSearch(shift.teacherId);

    if (shiftTeacherId == teacherId || shiftTeacherId == teacherEmail) return true;

    final teacherName = _normalizeSearch('${teacher.firstName} ${teacher.lastName}');
    return _normalizeSearch(shift.teacherName).contains(teacherName);
  }

  bool _matchesSubjectFilter(TeachingShift shift) {
    final filter = (_subjectFilter ?? '').trim();
    if (filter.isEmpty) return true;
    final subject = shift.subjectDisplayName?.trim().isNotEmpty == true
        ? shift.subjectDisplayName!
        : shift.effectiveSubjectDisplayName;
    return _normalizeSearch(subject).contains(_normalizeSearch(filter));
  }

  bool _matchesDateRangeFilter(TeachingShift shift) {
    final range = _dateRangeFilter;
    if (range == null) return true;

    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final endExclusive =
        DateTime(range.end.year, range.end.month, range.end.day).add(const Duration(days: 1));

    return !shift.shiftStart.isBefore(start) && shift.shiftStart.isBefore(endExclusive);
  }

  bool _matchesTimeFilter(TeachingShift shift, DateTime nowUtc) {
    switch (_timeFilter) {
      case _ClassesTimeFilter.all:
        return true;
      case _ClassesTimeFilter.joinable:
        return VideoCallService.canJoinClass(shift);
      case _ClassesTimeFilter.activeNow:
        return shift.shiftStart.toUtc().isBefore(nowUtc) &&
            shift.shiftEnd.toUtc().isAfter(nowUtc);
      case _ClassesTimeFilter.upcoming:
        return shift.shiftStart.toUtc().isAfter(nowUtc);
      case _ClassesTimeFilter.past:
        return shift.shiftEnd.toUtc().isBefore(nowUtc);
    }
  }

  List<TeachingShift> _applySearchAndFilters(
    List<TeachingShift> shifts,
    DateTime nowUtc,
    bool enabled,
  ) {
    if (!enabled) return shifts;
    return shifts
        .where((s) => _matchesSearch(s, _searchQuery))
        .where(_matchesTeacherFilter)
        .where(_matchesSubjectFilter)
        .where(_matchesDateRangeFilter)
        .where((s) => _matchesTimeFilter(s, nowUtc))
        .toList();
  }

  String _formatDateRange(DateTimeRange range, MaterialLocalizations localizations) {
    final start = localizations.formatShortDate(range.start);
    final end = localizations.formatShortDate(range.end);
    return '$start → $end';
  }

  Future<void> _openFiltersSheet(BuildContext context, {required bool isAdmin}) async {
    final localizations = MaterialLocalizations.of(context);

    var timeFilter = _timeFilter;
    DateTimeRange? dateRange = _dateRangeFilter;
    Employee? teacherFilter = _teacherFilter;
    var subjectFilterText = _subjectFilter ?? '';
    final subjectController = TextEditingController(text: subjectFilterText);
    var isLoadingTeachers = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDateRange() async {
              final picked = await showDateRangePicker(
                context: dialogContext,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                initialDateRange: dateRange,
                builder: (context, child) {
                  if (child == null) return const SizedBox.shrink();
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: child,
                    ),
                  );
                },
              );
              if (picked == null) return;
              setDialogState(() {
                dateRange = picked;
              });
            }

            Future<void> pickTeacher() async {
              if (!isAdmin || isLoadingTeachers) return;
              setDialogState(() => isLoadingTeachers = true);
              final teachers = await ShiftService.getAvailableTeachers();
              if (!mounted) return;
              setDialogState(() => isLoadingTeachers = false);

              if (teachers.isEmpty) return;

              final selected = await showDialog<List<Employee>>(
                context: dialogContext,
                builder: (context) => EmployeeSelectionDialog(
                  employees: teachers,
                  selectedIds: teacherFilter == null
                      ? <String>{}
                      : <String>{teacherFilter!.documentId},
                  title: AppLocalizations.of(context)!.selectTeacher,
                  idSelector: (t) => t.documentId,
                ),
              );
              if (selected == null || selected.isEmpty) return;
              setDialogState(() => teacherFilter = selected.first);
            }

            final teacherLabel = teacherFilter == null
                ? 'Any'
                : '${teacherFilter!.firstName} ${teacherFilter!.lastName}';

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      child: Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.filters,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                timeFilter = _defaultTimeFilter;
                                dateRange = null;
                                teacherFilter = null;
                                subjectController.clear();
                              });
                            },
                            child: Text(
                              AppLocalizations.of(context)!.commonClear,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: AppLocalizations.of(context)!.commonClose,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.shiftTime,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _ClassesTimeFilter.values
                                  .map(
                                    (f) => ChoiceChip(
                                      label: Text(
                                        f.label,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      selected: timeFilter == f,
                                      onSelected: (_) =>
                                          setDialogState(() => timeFilter = f),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.dateRange2,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dateRange == null
                                        ? 'Any'
                                        : _formatDateRange(dateRange!, localizations),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: pickDateRange,
                                  child: Text(
                                    AppLocalizations.of(context)!.select,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (isAdmin) ...[
                              Text(
                                AppLocalizations.of(context)!.roleTeacher,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: isLoadingTeachers ? null : pickTeacher,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    prefixIcon: isLoadingTeachers
                                        ? Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        : const Icon(Icons.person_outline),
                                    suffixIcon: teacherFilter == null
                                        ? const Icon(Icons.arrow_drop_down)
                                        : IconButton(
                                            onPressed: () => setDialogState(
                                              () => teacherFilter = null,
                                            ),
                                            icon: const Icon(Icons.close),
                                            tooltip: AppLocalizations.of(context)!.clearTeacherFilter,
                                          ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    isDense: true,
                                  ),
                                  child: Text(
                                    teacherLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              AppLocalizations.of(context)!.shiftSubject,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: subjectController,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!.filterBySubject,
                                prefixIcon: const Icon(Icons.menu_book_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.commonCancel,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                subjectFilterText = subjectController.text;
                                setState(() {
                                  _timeFilter = timeFilter;
                                  _dateRangeFilter = dateRange;
                                  _teacherFilter = teacherFilter;
                                  _subjectFilter = subjectFilterText.trim().isEmpty
                                      ? null
                                      : subjectFilterText.trim();
                                });
                                Navigator.of(dialogContext).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: const Color(0xFF0E72ED),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.commonApply,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
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
          },
        );
      },
    );
    subjectController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    final title = _userRole == 'student' ? 'My Classes' : 'Classes';
    final isAdmin = _userRole == 'admin' || _userRole == 'super_admin';
    
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xff111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xff6B7280)),
      ),
      body: user == null
          ? _UnauthenticatedState()
          : _isLoadingRole
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<TeachingShift>>(
              stream: _getShiftsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorState(message: '${snapshot.error}');
                }

                final allShifts = snapshot.data ?? const <TeachingShift>[];
                final nowUtc = DateTime.now().toUtc();
                final fromUtc = nowUtc.subtract(_historyLookback);
                final toUtc = nowUtc.add(_futureLookahead);

                // Only filter by time window. We still show Zoom shifts even if a meeting
                // hasn't been created yet, so teachers can see their schedule.
                final windowShifts = allShifts
                    .where((s) => s.shiftEnd.toUtc().isAfter(fromUtc))
                    .where((s) => s.shiftStart.toUtc().isBefore(toUtc))
                    .toList();

                final zoomShifts = _applySearchAndFilters(windowShifts, nowUtc, isAdmin)
                  ..sort((a, b) {
                    final aCanJoin = VideoCallService.canJoinClass(a);
                    final bCanJoin = VideoCallService.canJoinClass(b);

                    // Priority 1: Currently joinable shifts at the top
                    if (aCanJoin && !bCanJoin) return -1;
                    if (!aCanJoin && bCanJoin) return 1;

                    final now = DateTime.now().toUtc();
                    final aHasEnded = a.shiftEnd
                        .toUtc()
                        .add(const Duration(minutes: 10))
                        .isBefore(now);
                    final bHasEnded = b.shiftEnd
                        .toUtc()
                        .add(const Duration(minutes: 10))
                        .isBefore(now);

                    // Priority 2: Not ended vs Ended (Past shifts at the bottom)
                    if (aHasEnded && !bHasEnded) return 1;
                    if (!aHasEnded && bHasEnded) return -1;

                    // Same category sorting:
                    if (aHasEnded) {
                      // Both past: most recent first
                      return b.shiftStart.compareTo(a.shiftStart);
                    }
                    // Both upcoming/active: soonest first
                    return a.shiftStart.compareTo(b.shiftStart);
                  });

                if (isAdmin) {
                  _autoRefreshPresenceShiftIds = zoomShifts
                      .where((s) => s.usesLiveKit && VideoCallService.canJoinClass(s))
                      .take(25)
                      .map((s) => s.id)
                      .toSet();
                } else {
                  _autoRefreshPresenceShiftIds = <String>{};
                }

	                if (zoomShifts.isEmpty) {
	                  if (!isAdmin) return const _NoZoomShiftsState();

	                  final filterCount = _activeFilterCount();
	                  final hasActiveSearchOrFilters =
	                      filterCount > 0 || _searchQuery.trim().isNotEmpty;

	                  return ListView(
	                    padding: const EdgeInsets.all(16),
	                    children: [
	                      Row(
	                        children: [
	                          Expanded(
	                            child: TextField(
	                              controller: _searchController,
	                              decoration: InputDecoration(
	                                hintText: AppLocalizations.of(context)!.searchClassesTeacherStudentSubject,
	                                prefixIcon: const Icon(Icons.search),
	                                suffixIcon: _searchQuery.trim().isEmpty
	                                    ? null
	                                    : IconButton(
	                                        onPressed: () {
	                                          _searchController.clear();
	                                        },
	                                        icon: const Icon(Icons.close),
	                                        tooltip: AppLocalizations.of(context)!.clearSearch,
	                                      ),
	                                border: OutlineInputBorder(
	                                  borderRadius: BorderRadius.circular(14),
	                                ),
	                                isDense: true,
	                              ),
	                            ),
	                          ),
	                          const SizedBox(width: 12),
	                          SizedBox(
	                            height: 44,
	                            child: OutlinedButton.icon(
	                              onPressed: () =>
	                                  _openFiltersSheet(context, isAdmin: isAdmin),
	                              icon: const Icon(Icons.tune, size: 18),
	                              label: Text(
	                                filterCount == 0
	                                    ? 'Filters'
	                                    : 'Filters ($filterCount)',
	                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
	                              ),
	                              style: OutlinedButton.styleFrom(
	                                shape: RoundedRectangleBorder(
	                                  borderRadius: BorderRadius.circular(14),
	                                ),
	                              ),
	                            ),
	                          ),
	                          if (hasActiveSearchOrFilters) ...[
	                            const SizedBox(width: 8),
	                            SizedBox(
	                              height: 44,
	                              child: TextButton(
	                                onPressed: _clearFilters,
	                                child: Text(
	                                  AppLocalizations.of(context)!.commonClear,
	                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
	                                ),
	                              ),
	                            ),
	                          ],
	                        ],
	                      ),
	                      const SizedBox(height: 12),
	                      Align(
	                        alignment: Alignment.centerLeft,
	                        child: Text(
	                          AppLocalizations.of(context)!.zeroResults,
	                          style: GoogleFonts.inter(
	                            fontSize: 12,
	                            fontWeight: FontWeight.w600,
	                            color: const Color(0xFF64748B),
	                          ),
	                        ),
	                      ),
	                      const SizedBox(height: 12),
	                      const _HeaderCard(),
	                      const SizedBox(height: 12),
	                      _NoClassResultsCard(
	                        hasAnyClassesInWindow: windowShifts.isNotEmpty,
	                        showClearButton: hasActiveSearchOrFilters,
	                        title: hasActiveSearchOrFilters
	                            ? null
	                            : 'No active classes right now',
	                        subtitle: hasActiveSearchOrFilters
	                            ? null
	                            : 'Switch the Time filter to Upcoming or All to browse other classes.',
	                        onClear: _clearFilters,
	                      ),
	                      SizedBox(height: MediaQuery.of(context).padding.bottom),
	                    ],
	                  );
	                }

	                final isStudent = _userRole == 'student';
	                final filterCount = _activeFilterCount();
	                final hasActiveSearchOrFilters =
                    filterCount > 0 || _searchQuery.trim().isNotEmpty;
                
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (isAdmin) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!.searchClassesTeacherStudentSubject,
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.trim().isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                        icon: const Icon(Icons.close),
                                        tooltip: AppLocalizations.of(context)!.clearSearch,
                                      ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () => _openFiltersSheet(context, isAdmin: isAdmin),
                              icon: const Icon(Icons.tune, size: 18),
                              label: Text(
                                filterCount == 0 ? 'Filters' : 'Filters ($filterCount)',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          if (hasActiveSearchOrFilters) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 44,
                              child: TextButton(
                                onPressed: _clearFilters,
                                child: Text(
                                  AppLocalizations.of(context)!.commonClear,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${zoomShifts.length} result${zoomShifts.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const _HeaderCard(),
                    const SizedBox(height: 12),
                    ...zoomShifts.map(
                      (shift) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ZoomShiftCard(
                          shift: shift, 
                          isTeacher: !isStudent,
                          liveKitPresenceFuture: isAdmin &&
                                  shift.usesLiveKit &&
                                  VideoCallService.canJoinClass(shift)
                              ? _getLiveKitPresence(shift.id)
                              : null,
                          onRefreshLiveKitPresence: isAdmin
                              ? () => _refreshLiveKitPresence(shift.id)
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                );
              },
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();
  
  @override
  Widget build(BuildContext context) {
    final title = 'Your classes';
    final subtitle =
        'Join your classes directly in the app. The Join button becomes active 10 minutes before the class starts.';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0E72ED).withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.videocam,
              color: Color(0xFF0E72ED),
              size: 24,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomShiftCard extends StatelessWidget {
  final TeachingShift shift;
  final bool isTeacher;
  final Future<LiveKitRoomPresenceResult>? liveKitPresenceFuture;
  final VoidCallback? onRefreshLiveKitPresence;

  const _ZoomShiftCard({
    required this.shift,
    this.isTeacher = true,
    this.liveKitPresenceFuture,
    this.onRefreshLiveKitPresence,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideoCall = VideoCallService.hasVideoCall(shift);

    final nowUtc = DateTime.now().toUtc();
    final joinWindowStart =
        shift.shiftStart.toUtc().subtract(const Duration(minutes: 10));
    final joinWindowEnd =
        shift.shiftEnd.toUtc().add(const Duration(minutes: 10));

    final withinJoinWindow =
        !nowUtc.isBefore(joinWindowStart) && !nowUtc.isAfter(joinWindowEnd);
    final hasEnded = nowUtc.isAfter(joinWindowEnd);
    final timeUntilJoinWindow =
        nowUtc.isBefore(joinWindowStart) ? joinWindowStart.difference(nowUtc) : null;

    final canJoin = hasVideoCall && withinJoinWindow;

    final localizations = MaterialLocalizations.of(context);
    final startDateText = localizations.formatShortDate(shift.shiftStart);
    final startTimeText =
        TimeOfDay.fromDateTime(shift.shiftStart).format(context);
    final endTimeText = TimeOfDay.fromDateTime(shift.shiftEnd).format(context);

    final buttonLabel = canJoin
        ? 'Join'
        : (!hasVideoCall && withinJoinWindow && !hasEnded)
            ? 'Meeting not ready'
            : timeUntilJoinWindow != null
                ? 'Join (${_formatTimeUntil(timeUntilJoinWindow)})'
                : 'Ended';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (canJoin
                      ? const Color(0xFF10B981)
                      : (!hasVideoCall && !hasEnded)
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF94A3B8))
                  .withAlpha(31),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              canJoin
                  ? Icons.play_arrow_rounded
                  : (!hasVideoCall && !hasEnded)
                      ? Icons.error_outline
                      : Icons.schedule,
              color: canJoin
                  ? const Color(0xFF10B981)
                  : (!hasVideoCall && !hasEnded)
                      ? const Color(0xFFB45309)
                      : const Color(0xFF64748B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shift.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Show LiveKit badge if using beta provider
                    if (shift.usesLiveKit) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withAlpha(26),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withAlpha(51),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.beta,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.startdatetextStarttimetextEndtimetext,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                if (!hasVideoCall && !hasEnded) ...[
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.meetingIsNotReadyYetContact,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
                if (liveKitPresenceFuture != null) ...[
                  const SizedBox(height: 8),
                  FutureBuilder<LiveKitRoomPresenceResult>(
                    future: liveKitPresenceFuture,
                    builder: (context, snapshot) {
                      String formatPresenceError(Object? error) {
                        final text = (error ?? '').toString();
                        final lower = text.toLowerCase();

                        if (lower.contains('not-found')) {
                          return 'Presence function not deployed yet';
                        }
                        if (lower.contains('permission-denied')) {
                          return 'Permission denied';
                        }
                        if (lower.contains('unauthenticated')) {
                          return 'Please sign in again';
                        }
                        if (lower.contains('unavailable')) {
                          return 'Service unavailable';
                        }
                        return text.isEmpty
                            ? AppLocalizations.of(context)!.commonUnknownError
                            : text;
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _LiveKitPresenceRow(
                          label: AppLocalizations.of(context)!.zoomCheckingwhosintheroom,
                          trailing: IconButton(
                            onPressed: onRefreshLiveKitPresence,
                            icon: const Icon(Icons.refresh, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: const Color(0xFF64748B),
                            tooltip: AppLocalizations.of(context)!.commonRefresh,
                          ),
                        );
                      }

                      final presence = snapshot.data;
                      if (snapshot.hasError ||
                          presence == null ||
                          !presence.success ||
                          presence.error != null) {
                        final subtitle = presence?.error ?? formatPresenceError(snapshot.error);
                        return _LiveKitPresenceRow(
                          label: AppLocalizations.of(context)!.zoomUnabletoloadparticipants,
                          subtitle: subtitle,
                          trailing: IconButton(
                            onPressed: onRefreshLiveKitPresence,
                            icon: const Icon(Icons.refresh, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: const Color(0xFF64748B),
                            tooltip: AppLocalizations.of(context)!.commonRefresh,
                          ),
                        );
                      }

                      final count = presence.participantCount;
                      final names = presence.participants
                          .map((p) => p.name)
                          .where((n) => n.trim().isNotEmpty)
                          .toList();

                      String subtitle;
                      if (presence.inJoinWindow == false) {
                        subtitle = 'Available when the class is joinable';
                      } else
                      if (count == 0) {
                        subtitle = 'No one has joined yet';
                      } else {
                        const previewLimit = 3;
                        final preview = names.take(previewLimit).toList();
                        final remaining = count - preview.length;
                        subtitle = preview.join(', ');
                        if (remaining > 0) subtitle = '$subtitle +$remaining';
                      }

                      return _LiveKitPresenceRow(
                        label: AppLocalizations.of(context)!.zoomInclassnowcount,
                        subtitle: subtitle,
                        onTap: count > 0
                            ? () => _showLiveKitParticipantsDialog(context, presence)
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              TextButton(
                                onPressed: () => _showLiveKitParticipantsDialog(context, presence),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.commonView,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0E72ED),
                                  ),
                                ),
                              ),
                            IconButton(
                              onPressed: onRefreshLiveKitPresence,
                              icon: const Icon(Icons.refresh, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: const Color(0xFF64748B),
                              tooltip: AppLocalizations.of(context)!.commonRefresh,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context)!.copyClassLink,
                onPressed: () => VideoCallService.copyJoinLink(context, shift),
                icon: const Icon(Icons.link),
                color: const Color(0xFF0E72ED),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: canJoin
                      ? () => VideoCallService.joinClass(
                            context,
                            shift,
                            isTeacher: isTeacher,
                          )
                      : (!hasVideoCall && withinJoinWindow && !hasEnded)
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(context)!.thisClassDoesNotHaveA,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                  icon: Icon(
                    VideoCallService.getProviderIcon(shift.videoProvider),
                    size: 18,
                  ),
                  label: Text(
                    buttonLabel,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canJoin
                        ? const Color(0xFF0E72ED)
                        : const Color(0xFF94A3B8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeUntil(Duration duration) {
    final minutes = duration.inMinutes;
    final days = duration.inDays;
    if (days >= 1) {
      final hours = duration.inHours % 24;
      final dayLabel = days == 1 ? '1 day' : '$days days';
      if (hours == 0) return dayLabel;
      return '$dayLabel ${hours}h';
    }
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }
}

class _LiveKitPresenceRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _LiveKitPresenceRow({
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.people_outline, color: Color(0xFF64748B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}

void _showLiveKitParticipantsDialog(
  BuildContext context,
  LiveKitRoomPresenceResult presence,
) {
  final participants = presence.participants;

  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          'Participants (${presence.participantCount})',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 320,
            minWidth: 280,
            maxWidth: 520,
          ),
          child: participants.isEmpty
              ? Text(
                  AppLocalizations.of(context)!.noOneIsInTheRoom,
                  style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    final role = participant.role?.toLowerCase();

                    IconData icon = Icons.person_outline;
                    Color iconColor = const Color(0xFF64748B);
                    String? roleLabel;

                    if (role == 'teacher') {
                      icon = Icons.school;
                      iconColor = const Color(0xFF0E72ED);
                      roleLabel = 'Teacher';
                    } else if (role == 'student') {
                      icon = Icons.person;
                      iconColor = const Color(0xFF10B981);
                      roleLabel = 'Student';
                    } else if (role != null && role.isNotEmpty) {
                      icon = Icons.admin_panel_settings_outlined;
                      iconColor = const Color(0xFF8B5CF6);
                      roleLabel = role;
                    }

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon, color: iconColor),
                      title: Text(
                        participant.name.isNotEmpty
                            ? participant.name
                            : participant.identity,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: roleLabel == null
                          ? null
                          : Text(
                              roleLabel,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.commonClose,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    },
  );
}

class _NoZoomShiftsState extends StatelessWidget {
  const _NoZoomShiftsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF0E72ED).withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off,
                size: 44,
                color: Color(0xFF0E72ED),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.noClassesRightNow,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.yourScheduledClassesWillAppearHere,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoClassResultsCard extends StatelessWidget {
  final bool hasAnyClassesInWindow;
  final bool showClearButton;
  final String? title;
  final String? subtitle;
  final VoidCallback onClear;

  const _NoClassResultsCard({
    required this.hasAnyClassesInWindow,
    required this.showClearButton,
    this.title,
    this.subtitle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTitle =
        title ?? (hasAnyClassesInWindow ? 'No classes match your filters' : 'No classes found');
    final resolvedSubtitle = subtitle ??
        (hasAnyClassesInWindow
        ? 'Try adjusting your filters or clearing them.'
        : 'Try clearing filters or coming back later.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF0E72ED).withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off,
              size: 34,
              color: Color(0xFF0E72ED),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            resolvedTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            resolvedSubtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          if (showClearButton) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear),
                label: Text(
                  AppLocalizations.of(context)!.clearFilters,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnauthenticatedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context)!.pleaseSignInToViewYour,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context)!.unableToLoadClassesNMessage,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
