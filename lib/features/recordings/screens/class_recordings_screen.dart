import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/services/class_recording_service.dart';
import 'package:alluwalacademyadmin/features/surah_podcast/widgets/video_player_widget.dart';

const String _unknownStudentKey = '__unknown_student__';
const String _unknownDateKey = '__unknown_date__';

class _TeacherBucket {
  final String key;
  final String name;
  final List<ClassRecordingItem> recordings;

  _TeacherBucket({
    required this.key,
    required this.name,
    required this.recordings,
  });

  DateTime? get latestDate {
    DateTime? latest;
    for (final item in recordings) {
      final date = item.displayDate;
      if (date == null) continue;
      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }
    return latest;
  }

  int get studentCount {
    final ids = <String>{};
    for (final r in recordings) {
      ids.addAll(r.studentIds.where((id) => id.trim().isNotEmpty));
    }
    return ids.length;
  }
}

class _StudentBucket {
  final String id;
  final String name;
  final List<ClassRecordingItem> recordings;

  _StudentBucket({
    required this.id,
    required this.name,
    required this.recordings,
  });

  DateTime? get latestDate {
    DateTime? latest;
    for (final item in recordings) {
      final date = item.displayDate;
      if (date == null) continue;
      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }
    return latest;
  }
}

class _DateBucket {
  final String key;
  final DateTime? date;
  final List<ClassRecordingItem> recordings;

  _DateBucket({
    required this.key,
    required this.date,
    required this.recordings,
  });
}

class _ShiftBucket {
  final String key;
  final String shiftId;
  final String shiftName;
  final String subjectName;
  final String teacherName;
  final DateTime? date;
  final List<ClassRecordingItem> fragments;

  _ShiftBucket({
    required this.key,
    required this.shiftId,
    required this.shiftName,
    required this.subjectName,
    required this.teacherName,
    required this.date,
    required this.fragments,
  });

  int get readyCount => fragments.where((f) => f.canPlay).length;
}

class ClassRecordingsScreen extends StatefulWidget {
  final String? title;

  const ClassRecordingsScreen({super.key, this.title});

  @override
  State<ClassRecordingsScreen> createState() => _ClassRecordingsScreenState();
}

class _ClassRecordingsScreenState extends State<ClassRecordingsScreen> {
  final List<ClassRecordingItem> _recordings = [];
  final Map<String, String> _nameCache = {};

  bool _isLoading = true;
  String? _error;
  String? _accessRole;
  String _searchQuery = '';

  String? _selectedTeacherKey;
  String? _selectedStudentId;
  String? _selectedDateKey;
  String? _selectedShiftKey;

  String? _expandedRecordingId;
  String? _loadingRecordingId;
  final Map<String, String> _playbackUrls = {};
  String? _currentlyPlayingId;

  bool get _isAdminRole =>
      _accessRole == 'admin' || _accessRole == 'super_admin';

  bool get _showTeacherLevel => _isAdminRole;

  bool get _canGoBack {
    if (_showTeacherLevel) {
      return _selectedTeacherKey != null ||
          _selectedStudentId != null ||
          _selectedDateKey != null ||
          _selectedShiftKey != null;
    }
    return _selectedStudentId != null ||
        _selectedDateKey != null ||
        _selectedShiftKey != null;
  }

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result = await ClassRecordingService.listRecordings(limit: 200);
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _error = result.error ?? 'Failed to load recordings';
      });
      return;
    }

    final names = await _resolveNames(result.recordings);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _accessRole = result.role;
      _recordings
        ..clear()
        ..addAll(result.recordings);
      _nameCache
        ..clear()
        ..addAll(names);

      _selectedTeacherKey = null;
      _selectedStudentId = null;
      _selectedDateKey = null;
      _selectedShiftKey = null;
      _searchQuery = '';
      _expandedRecordingId = null;
      _loadingRecordingId = null;
      _currentlyPlayingId = null;
      _playbackUrls.clear();
    });
  }

  Future<Map<String, String>> _resolveNames(
    List<ClassRecordingItem> items,
  ) async {
    final ids = <String>{};
    for (final item in items) {
      final teacherId = item.teacherId?.trim() ?? '';
      if (teacherId.isNotEmpty) {
        ids.add(teacherId);
      }
      for (final studentId in item.studentIds) {
        final normalized = studentId.trim();
        if (normalized.isNotEmpty) {
          ids.add(normalized);
        }
      }
    }
    return ClassRecordingService.getUserNamesByIds(ids);
  }

  void _goBackOneLevel() {
    setState(() {
      if (_selectedShiftKey != null) {
        _selectedShiftKey = null;
        _expandedRecordingId = null;
        _currentlyPlayingId = null;
        _searchQuery = '';
        return;
      }
      if (_selectedDateKey != null) {
        _selectedDateKey = null;
        _searchQuery = '';
        return;
      }
      if (_selectedStudentId != null) {
        _selectedStudentId = null;
        _searchQuery = '';
        return;
      }
      if (_selectedTeacherKey != null) {
        _selectedTeacherKey = null;
        _searchQuery = '';
      }
    });
  }

  String _teacherKeyForRecording(ClassRecordingItem recording) {
    final teacherId = recording.teacherId?.trim() ?? '';
    if (teacherId.isNotEmpty) return teacherId;

    final teacherName = recording.teacherName.trim();
    if (teacherName.isNotEmpty) return 'name:$teacherName';

    return 'unknown_teacher';
  }

  String _teacherNameForRecording(ClassRecordingItem recording) {
    final teacherId = recording.teacherId?.trim() ?? '';
    if (teacherId.isNotEmpty) {
      final cached = _nameCache[teacherId];
      if (cached != null && cached.trim().isNotEmpty) {
        return cached;
      }
    }

    final teacherName = recording.teacherName.trim();
    if (teacherName.isNotEmpty) {
      return teacherName;
    }

    return teacherId.isNotEmpty ? teacherId : 'Unknown Teacher';
  }

  String _studentName(String studentId) {
    if (studentId == _unknownStudentKey) return 'Unknown Student';
    final cached = _nameCache[studentId];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }
    return studentId;
  }

  bool _recordingMatchesStudent(
      ClassRecordingItem recording, String studentId) {
    if (studentId == _unknownStudentKey) {
      return recording.studentIds.isEmpty;
    }
    return recording.studentIds.contains(studentId);
  }

  String _dateKey(DateTime? date) {
    if (date == null) return _unknownDateKey;
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _dateFromKey(String key) {
    if (key == _unknownDateKey) return null;
    return DateTime.tryParse('${key}T00:00:00');
  }

  DateTime? _latestDate(List<ClassRecordingItem> recordings) {
    DateTime? latest;
    for (final item in recordings) {
      final date = item.displayDate;
      if (date == null) continue;
      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }
    return latest;
  }

  List<_TeacherBucket> get _teacherBuckets {
    final grouped = <String, List<ClassRecordingItem>>{};
    final teacherNames = <String, String>{};

    for (final recording in _recordings) {
      final key = _teacherKeyForRecording(recording);
      grouped.putIfAbsent(key, () => <ClassRecordingItem>[]).add(recording);
      teacherNames[key] = _teacherNameForRecording(recording);
    }

    var buckets = grouped.entries
        .map(
          (entry) => _TeacherBucket(
            key: entry.key,
            name: teacherNames[entry.key] ?? 'Unknown Teacher',
            recordings: entry.value,
          ),
        )
        .toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      buckets =
          buckets.where((b) => b.name.toLowerCase().contains(query)).toList();
    }

    buckets.sort((a, b) {
      final aDate = a.latestDate;
      final bDate = b.latestDate;
      if (aDate == null && bDate == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return buckets;
  }

  List<ClassRecordingItem> get _recordingsForSelectedTeacher {
    if (!_showTeacherLevel || _selectedTeacherKey == null) {
      return List<ClassRecordingItem>.from(_recordings);
    }
    return _recordings
        .where((r) => _teacherKeyForRecording(r) == _selectedTeacherKey)
        .toList();
  }

  List<_StudentBucket> get _studentBuckets {
    final source = _recordingsForSelectedTeacher;
    final grouped = <String, List<ClassRecordingItem>>{};

    for (final recording in source) {
      final studentIds = recording.studentIds;
      if (studentIds.isEmpty) {
        grouped
            .putIfAbsent(_unknownStudentKey, () => <ClassRecordingItem>[])
            .add(recording);
        continue;
      }
      for (final id in studentIds) {
        final normalized = id.trim();
        if (normalized.isEmpty) continue;
        grouped
            .putIfAbsent(normalized, () => <ClassRecordingItem>[])
            .add(recording);
      }
    }

    var buckets = grouped.entries
        .map(
          (entry) => _StudentBucket(
            id: entry.key,
            name: _studentName(entry.key),
            recordings: entry.value,
          ),
        )
        .toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      buckets =
          buckets.where((b) => b.name.toLowerCase().contains(query)).toList();
    }

    buckets.sort((a, b) {
      final aDate = a.latestDate;
      final bDate = b.latestDate;
      if (aDate == null && bDate == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return buckets;
  }

  List<ClassRecordingItem> get _recordingsForSelectedStudent {
    if (_selectedStudentId == null) return const [];
    return _recordingsForSelectedTeacher
        .where((r) => _recordingMatchesStudent(r, _selectedStudentId!))
        .toList();
  }

  List<_DateBucket> get _dateBuckets {
    final source = _recordingsForSelectedStudent;
    final grouped = <String, List<ClassRecordingItem>>{};

    for (final recording in source) {
      final key = _dateKey(recording.displayDate);
      grouped.putIfAbsent(key, () => <ClassRecordingItem>[]).add(recording);
    }

    var buckets = grouped.entries
        .map(
          (entry) => _DateBucket(
            key: entry.key,
            date: _dateFromKey(entry.key),
            recordings: entry.value,
          ),
        )
        .toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      buckets = buckets.where((bucket) {
        if (bucket.date == null) {
          return 'unknown date'.contains(query);
        }
        final longText = DateFormat('EEEE, MMM d, yyyy')
            .format(bucket.date!.toLocal())
            .toLowerCase();
        final shortText = DateFormat('MMM d, yyyy')
            .format(bucket.date!.toLocal())
            .toLowerCase();
        return longText.contains(query) || shortText.contains(query);
      }).toList();
    }

    buckets.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

    return buckets;
  }

  List<ClassRecordingItem> get _recordingsForSelectedDate {
    if (_selectedDateKey == null) return const [];
    return _recordingsForSelectedStudent
        .where((r) => _dateKey(r.displayDate) == _selectedDateKey)
        .toList();
  }

  List<_ShiftBucket> get _shiftBuckets {
    final source = _recordingsForSelectedDate;
    final grouped = <String, List<ClassRecordingItem>>{};

    for (final recording in source) {
      final shiftId = recording.shiftId?.trim();
      final key = (shiftId != null && shiftId.isNotEmpty)
          ? 'shift:$shiftId'
          : 'recording:${recording.recordingId}';
      grouped.putIfAbsent(key, () => <ClassRecordingItem>[]).add(recording);
    }

    var buckets = grouped.entries.map((entry) {
      final fragments = List<ClassRecordingItem>.from(entry.value);
      fragments.sort((a, b) {
        final aDate = a.displayDate;
        final bDate = b.displayDate;
        if (aDate == null && bDate == null) {
          return a.recordingId.compareTo(b.recordingId);
        }
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        final byDate = aDate.compareTo(bDate);
        if (byDate != 0) return byDate;
        return a.recordingId.compareTo(b.recordingId);
      });

      final first = fragments.first;
      final shiftId = first.shiftId?.trim() ?? '';
      return _ShiftBucket(
        key: entry.key,
        shiftId: shiftId,
        shiftName: first.shiftName.trim().isNotEmpty
            ? first.shiftName.trim()
            : 'Class Recording',
        subjectName: first.subjectName.trim(),
        teacherName: _teacherNameForRecording(first),
        date: _latestDate(fragments),
        fragments: fragments,
      );
    }).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      buckets = buckets.where((bucket) {
        if (bucket.shiftName.toLowerCase().contains(query)) return true;
        if (bucket.subjectName.toLowerCase().contains(query)) return true;
        if (bucket.teacherName.toLowerCase().contains(query)) return true;
        return false;
      }).toList();
    }

    buckets.sort((a, b) {
      if (a.date == null && b.date == null) {
        return a.shiftName.toLowerCase().compareTo(b.shiftName.toLowerCase());
      }
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      final byDate = b.date!.compareTo(a.date!);
      if (byDate != 0) return byDate;
      return a.shiftName.toLowerCase().compareTo(b.shiftName.toLowerCase());
    });

    return buckets;
  }

  _ShiftBucket? get _selectedShiftBucket {
    if (_selectedShiftKey == null) return null;
    for (final shift in _shiftBuckets) {
      if (shift.key == _selectedShiftKey) {
        return shift;
      }
    }
    return null;
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Unknown date';
    return DateFormat('EEE, MMM d · h:mm a').format(date.toLocal());
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return DateFormat('MMM d, yyyy').format(date.toLocal());
  }

  String _formatRetentionCountdown(DateTime? deleteAfter) {
    if (deleteAfter == null) {
      return 'Auto-delete schedule unavailable';
    }

    final now = DateTime.now().toUtc();
    final target = deleteAfter.toUtc();
    if (!target.isAfter(now)) {
      return 'Deleting soon';
    }

    final diff = target.difference(now);
    final totalDays = diff.inDays;

    if (totalDays >= 28) {
      final months = (totalDays / 30).round().clamp(1, 24);
      return 'Auto-deletes in about $months month${months == 1 ? '' : 's'}';
    }

    if (totalDays >= 14) {
      final weeks = (totalDays / 7).floor();
      return 'Auto-deletes in $weeks week${weeks == 1 ? '' : 's'}';
    }

    if (totalDays >= 2) {
      return 'Auto-deletes in $totalDays days';
    }

    final totalHours = diff.inHours;
    if (totalHours >= 2) {
      return 'Auto-deletes in $totalHours hours';
    }

    final totalMinutes = diff.inMinutes;
    if (totalMinutes >= 2) {
      return 'Auto-deletes in $totalMinutes minutes';
    }

    return 'Auto-deletes in less than a minute';
  }

  Color _retentionCountdownColor(DateTime? deleteAfter) {
    if (deleteAfter == null) return const Color(0xFF64748B);

    final now = DateTime.now().toUtc();
    final target = deleteAfter.toUtc();
    final diff = target.difference(now);

    if (!target.isAfter(now) || diff.inDays < 3) {
      return const Color(0xFFDC2626);
    }
    if (diff.inDays < 14) {
      return const Color(0xFFB45309);
    }
    return const Color(0xFF0E7490);
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'complete':
      case 'ended':
        return 'Ready';
      case 'starting':
        return 'Processing';
      case 'failed':
        return 'Failed';
      default:
        final normalized = status.trim();
        return normalized.isEmpty ? 'Unknown' : normalized;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'complete':
      case 'ended':
        return const Color(0xFF10B981);
      case 'starting':
        return const Color(0xFFF59E0B);
      case 'failed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _toggleRecordingPlayer(ClassRecordingItem recording) async {
    if (_expandedRecordingId == recording.recordingId) {
      setState(() {
        _expandedRecordingId = null;
        _currentlyPlayingId = null;
      });
      return;
    }

    if (_playbackUrls.containsKey(recording.recordingId)) {
      setState(() {
        _expandedRecordingId = recording.recordingId;
        _currentlyPlayingId = null;
      });
      return;
    }

    setState(() => _loadingRecordingId = recording.recordingId);
    final result =
        await ClassRecordingService.getPlaybackUrl(recording.recordingId);

    if (!mounted) return;

    if (!result.success || result.url == null) {
      setState(() => _loadingRecordingId = null);
      _showErrorSnackBar(result.error ?? 'Unable to load recording');
      return;
    }

    setState(() {
      _loadingRecordingId = null;
      _playbackUrls[recording.recordingId] = result.url!;
      _expandedRecordingId = recording.recordingId;
      _currentlyPlayingId = null;
    });
  }

  void _showErrorSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });
  }

  bool get _showSearchBar {
    if (_recordings.isEmpty) return false;
    if (_selectedShiftKey != null) return false;
    return true;
  }

  String get _searchHint {
    if (_showTeacherLevel && _selectedTeacherKey == null) {
      return 'Search teacher...';
    }
    if (_selectedStudentId == null) {
      return 'Search student...';
    }
    if (_selectedDateKey == null) {
      return 'Search date...';
    }
    return 'Search class or subject...';
  }

  String get _headerTitle {
    if (_selectedShiftKey != null) {
      final shift = _selectedShiftBucket;
      return shift?.shiftName ?? 'Recording Fragments';
    }
    if (_selectedDateKey != null) return 'Shifts';
    if (_selectedStudentId != null) return 'Dates';
    if (_showTeacherLevel && _selectedTeacherKey != null) return 'Students';
    if (_showTeacherLevel) return 'Teachers';
    return 'Students';
  }

  String get _headerSubtitle {
    if (_selectedShiftKey != null) {
      final shift = _selectedShiftBucket;
      if (shift == null) return '';
      final dateLabel = _formatDateTime(shift.date);
      return '${shift.fragments.length} fragment${shift.fragments.length == 1 ? '' : 's'} · $dateLabel';
    }

    if (_selectedDateKey != null) {
      final count = _shiftBuckets.length;
      return '$count shift${count == 1 ? '' : 's'} on this date';
    }

    if (_selectedStudentId != null) {
      final count = _dateBuckets.length;
      return '$count date${count == 1 ? '' : 's'} with recordings';
    }

    if (_showTeacherLevel && _selectedTeacherKey != null) {
      final count = _studentBuckets.length;
      return '$count student${count == 1 ? '' : 's'}';
    }

    if (_showTeacherLevel) {
      final count = _teacherBuckets.length;
      return '$count teacher${count == 1 ? '' : 's'}';
    }

    final count = _studentBuckets.length;
    return '$count student${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF0E72ED)),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(child: _buildErrorCard()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_showSearchBar) _buildSearchBar(),
            Expanded(child: _buildCurrentLevel()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Row(
        children: [
          if (_canGoBack)
            IconButton(
              onPressed: _goBackOneLevel,
              icon: const Icon(Icons.arrow_back_rounded),
              color: const Color(0xFF1E293B),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _headerTitle,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (_headerSubtitle.isNotEmpty)
                  Text(
                    _headerSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadRecordings,
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: _searchHint,
          hintStyle:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF94A3B8), size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0E72ED), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: GoogleFonts.inter(fontSize: 14),
      ),
    );
  }

  Widget _buildCurrentLevel() {
    if (_recordings.isEmpty) {
      return _buildEmptyState(
        Icons.video_library_outlined,
        'No recordings yet',
        'Class recordings will appear here after sessions are recorded.',
      );
    }

    if (_selectedShiftKey != null) {
      return _buildFragmentsLevel();
    }

    if (_selectedDateKey != null) {
      return _buildShiftsLevel();
    }

    if (_selectedStudentId != null) {
      return _buildDatesLevel();
    }

    if (_showTeacherLevel && _selectedTeacherKey == null) {
      return _buildTeachersLevel();
    }

    return _buildStudentsLevel();
  }

  Widget _buildTeachersLevel() {
    final teachers = _teacherBuckets;
    if (teachers.isEmpty) {
      return _buildEmptyState(
        Icons.search_off_rounded,
        'No teachers found',
        'Try a different search term.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecordings,
      color: const Color(0xFF0E72ED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: teachers.length,
        itemBuilder: (context, index) {
          final teacher = teachers[index];
          return _buildLevelCard(
            title: teacher.name,
            subtitle:
                '${teacher.studentCount} student${teacher.studentCount == 1 ? '' : 's'} · ${teacher.recordings.length} recording${teacher.recordings.length == 1 ? '' : 's'}',
            tertiary: teacher.latestDate == null
                ? null
                : 'Latest: ${_formatShortDate(teacher.latestDate)}',
            icon: Icons.person,
            iconColor: const Color(0xFF0E72ED),
            onTap: () {
              setState(() {
                _selectedTeacherKey = teacher.key;
                _selectedStudentId = null;
                _selectedDateKey = null;
                _selectedShiftKey = null;
                _searchQuery = '';
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildStudentsLevel() {
    final students = _studentBuckets;
    if (students.isEmpty) {
      return _buildEmptyState(
        Icons.search_off_rounded,
        'No students found',
        'Try a different search term.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecordings,
      color: const Color(0xFF0E72ED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return _buildLevelCard(
            title: student.name,
            subtitle:
                '${student.recordings.length} recording${student.recordings.length == 1 ? '' : 's'}',
            tertiary: student.latestDate == null
                ? null
                : 'Latest: ${_formatShortDate(student.latestDate)}',
            icon: Icons.school_rounded,
            iconColor: const Color(0xFF2563EB),
            onTap: () {
              setState(() {
                _selectedStudentId = student.id;
                _selectedDateKey = null;
                _selectedShiftKey = null;
                _searchQuery = '';
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildDatesLevel() {
    final dates = _dateBuckets;
    if (dates.isEmpty) {
      return _buildEmptyState(
        Icons.search_off_rounded,
        'No recording dates found',
        'Try a different search term.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecordings,
      color: const Color(0xFF0E72ED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final bucket = dates[index];
          final dateText = bucket.date == null
              ? 'Unknown date'
              : DateFormat('EEEE, MMM d, yyyy').format(bucket.date!.toLocal());
          return _buildLevelCard(
            title: dateText,
            subtitle:
                '${bucket.recordings.length} recording${bucket.recordings.length == 1 ? '' : 's'}',
            icon: Icons.event_note_rounded,
            iconColor: const Color(0xFF0E7490),
            onTap: () {
              setState(() {
                _selectedDateKey = bucket.key;
                _selectedShiftKey = null;
                _searchQuery = '';
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildShiftsLevel() {
    final shifts = _shiftBuckets;
    if (shifts.isEmpty) {
      return _buildEmptyState(
        Icons.search_off_rounded,
        'No shifts found',
        'Try a different search term.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecordings,
      color: const Color(0xFF0E72ED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: shifts.length,
        itemBuilder: (context, index) {
          final shift = shifts[index];
          final subtitleParts = <String>[
            '${shift.fragments.length} fragment${shift.fragments.length == 1 ? '' : 's'}',
            'Ready: ${shift.readyCount}',
          ];
          if (shift.subjectName.isNotEmpty) {
            subtitleParts.add(shift.subjectName);
          }
          return _buildLevelCard(
            title: shift.shiftName,
            subtitle: subtitleParts.join(' · '),
            tertiary: shift.date == null ? null : _formatDateTime(shift.date),
            icon: Icons.class_rounded,
            iconColor: const Color(0xFF7C3AED),
            onTap: () {
              setState(() {
                _selectedShiftKey = shift.key;
                _searchQuery = '';
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildFragmentsLevel() {
    final shift = _selectedShiftBucket;
    if (shift == null) {
      return _buildEmptyState(
        Icons.videocam_off_rounded,
        'Shift not found',
        'Refresh and try again.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecordings,
      color: const Color(0xFF0E72ED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: shift.fragments.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildShiftSummaryCard(shift);
          }
          final fragmentIndex = index - 1;
          final recording = shift.fragments[fragmentIndex];
          return _buildFragmentCard(
            recording,
            fragmentIndex + 1,
            shift.fragments.length,
          );
        },
      ),
    );
  }

  Widget _buildLevelCard({
    required String title,
    required String subtitle,
    String? tertiary,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tertiary != null && tertiary.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tertiary,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSummaryCard(_ShiftBucket shift) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shift.shiftName,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _summaryBadge(
                Icons.video_collection_rounded,
                '${shift.fragments.length} fragments',
                const Color(0xFF0E72ED),
              ),
              _summaryBadge(
                Icons.check_circle_rounded,
                '${shift.readyCount} ready',
                const Color(0xFF10B981),
              ),
              if (shift.subjectName.isNotEmpty)
                _summaryBadge(
                  Icons.book_rounded,
                  shift.subjectName,
                  const Color(0xFF7C3AED),
                ),
            ],
          ),
          if (shift.date != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatDateTime(shift.date),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFragmentCard(
    ClassRecordingItem recording,
    int fragmentNumber,
    int totalFragments,
  ) {
    final statusColor = _statusColor(recording.status);
    final retentionColor = _retentionCountdownColor(recording.deleteAfter);
    final retentionText = _formatRetentionCountdown(recording.deleteAfter);
    final deleteOnLabel = recording.deleteAfter == null
        ? null
        : DateFormat('MMM d, yyyy').format(recording.deleteAfter!.toLocal());
    final isLoading = _loadingRecordingId == recording.recordingId;
    final isExpanded = _expandedRecordingId == recording.recordingId;
    final playbackUrl = _playbackUrls[recording.recordingId];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E72ED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '$fragmentNumber',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0E72ED),
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
                        totalFragments > 1
                            ? 'Fragment $fragmentNumber'
                            : 'Full Recording',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(recording.displayDate),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(recording.status),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: retentionColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_delete_rounded,
                      size: 14,
                      color: retentionColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      deleteOnLabel == null
                          ? retentionText
                          : '$retentionText · $deleteOnLabel',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: retentionColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if ((recording.error ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                recording.error!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFFDC2626),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            if (isExpanded && playbackUrl != null) ...[
              VideoPlayerWidget(
                videoUrl: playbackUrl,
                title: totalFragments > 1
                    ? 'Fragment $fragmentNumber'
                    : 'Full Recording',
                videoId: recording.recordingId,
                onPlayStarted: (id) => setState(() => _currentlyPlayingId = id),
                shouldPause: _currentlyPlayingId != null &&
                    _currentlyPlayingId != recording.recordingId,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _expandedRecordingId = null;
                    _currentlyPlayingId = null;
                  }),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    'Close Player',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: recording.canPlay && !isLoading
                      ? () => _toggleRecordingPlayer(recording)
                      : null,
                  icon: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    isLoading
                        ? 'Loading...'
                        : recording.canPlay
                            ? 'Play Recording'
                            : 'Not Ready Yet',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E72ED),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E72ED).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: const Color(0xFF0E72ED).withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 28,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadRecordings,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('Try Again', style: GoogleFonts.inter()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E72ED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
