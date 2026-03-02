import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/services/class_recording_service.dart';
import 'package:alluwalacademyadmin/features/surah_podcast/widgets/video_player_widget.dart';

/// A group of recordings that share the same shift.
class _ShiftGroup {
  final String shiftId;
  final String shiftName;
  final String teacherName;
  final String subjectName;
  final DateTime? date;
  final List<ClassRecordingItem> segments;

  _ShiftGroup({
    required this.shiftId,
    required this.shiftName,
    required this.teacherName,
    required this.subjectName,
    required this.date,
    required this.segments,
  });

  int get readyCount => segments.where((s) => s.canPlay).length;
  int get processingCount =>
      segments.where((s) => !s.canPlay && s.status != 'failed').length;
}

class ClassRecordingsScreen extends StatefulWidget {
  final String? title;

  const ClassRecordingsScreen({super.key, this.title});

  @override
  State<ClassRecordingsScreen> createState() => _ClassRecordingsScreenState();
}

class _ClassRecordingsScreenState extends State<ClassRecordingsScreen> {
  final List<ClassRecordingItem> _recordings = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  /// When set, the detail view for this shift group is shown inline.
  String? _selectedShiftId;

  /// Tracks which recording segment is expanded with its video player.
  String? _expandedRecordingId;

  /// Tracks which recording is currently fetching its playback URL.
  String? _loadingRecordingId;

  /// Cached signed playback URLs.
  final Map<String, String> _playbackUrls = {};

  /// Currently playing video (for mutual exclusion).
  String? _currentlyPlayingId;

  /// Cached student names per shift ID.
  final Map<String, List<String>> _studentNamesCache = {};

  /// Whether student names are being loaded for the selected shift.
  bool _loadingStudents = false;

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

    final result = await ClassRecordingService.listRecordings(limit: 100);
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _error = result.error ?? 'Failed to load recordings';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _recordings
        ..clear()
        ..addAll(result.recordings);
    });
  }

  Future<void> _fetchStudentNames(String shiftId) async {
    if (_studentNamesCache.containsKey(shiftId)) return;
    if (mounted) setState(() => _loadingStudents = true);
    final names =
        await ClassRecordingService.getStudentNamesForShift(shiftId);
    if (!mounted) return;
    setState(() {
      _studentNamesCache[shiftId] = names;
      _loadingStudents = false;
    });
  }

  // ───────────────────── GROUPING ─────────────────────

  List<_ShiftGroup> get _shiftGroups {
    final map = <String, List<ClassRecordingItem>>{};
    for (final r in _recordings) {
      final key = (r.shiftId != null && r.shiftId!.isNotEmpty)
          ? r.shiftId!
          : r.recordingId;
      map.putIfAbsent(key, () => []).add(r);
    }

    final groups = <_ShiftGroup>[];
    for (final entry in map.entries) {
      final segs = entry.value;
      segs.sort((a, b) {
        final da = a.displayDate;
        final db = b.displayDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
      final first = segs.first;
      groups.add(_ShiftGroup(
        shiftId: entry.key,
        shiftName: first.shiftName,
        teacherName: first.teacherName,
        subjectName: first.subjectName,
        date: first.displayDate,
        segments: segs,
      ));
    }

    groups.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

    return groups;
  }

  List<_ShiftGroup> get _filteredGroups {
    final groups = _shiftGroups;
    if (_searchQuery.isEmpty) return groups;

    final q = _searchQuery.toLowerCase();
    return groups.where((g) {
      if (g.shiftName.toLowerCase().contains(q)) return true;
      if (g.teacherName.toLowerCase().contains(q)) return true;
      if (g.subjectName.toLowerCase().contains(q)) return true;
      if (g.date != null) {
        final dateStr =
            DateFormat('EEE, MMM d, yyyy').format(g.date!.toLocal());
        if (dateStr.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  // ───────────────────── IN-APP PLAYBACK ─────────────────────

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

  // ───────────────────── HELPERS ─────────────────────

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

  String _statusLabel(String status) {
    final n = status.toLowerCase();
    if (n == 'active' || n == 'complete' || n == 'ended') return 'Ready';
    if (n == 'starting') return 'Processing';
    if (n == 'failed') return 'Failed';
    return n.isEmpty ? 'Unknown' : n;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown date';
    return DateFormat('EEE, MMM d · h:mm a').format(dt.toLocal());
  }

  String _formatShortDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('MMM d, yyyy').format(dt.toLocal());
  }

  bool _isWide(BuildContext context) =>
      MediaQuery.of(context).size.width > 600;

  // ───────────────────── BUILD ─────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
              child: CircularProgressIndicator(color: Color(0xFF0E72ED))),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(child: Center(child: _buildErrorCard())),
      );
    }

    if (_selectedShiftId != null) {
      final group = _shiftGroups
          .cast<_ShiftGroup?>()
          .firstWhere((g) => g!.shiftId == _selectedShiftId,
              orElse: () => null);
      if (group != null) {
        return Material(
          color: const Color(0xFFF8FAFC),
          child: SafeArea(child: _buildShiftDetail(group)),
        );
      }
    }

    return _buildFolderGrid();
  }

  // ───────────────────── FOLDER GRID VIEW ─────────────────────

  Widget _buildFolderGrid() {
    final groups = _filteredGroups;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecordings,
          color: const Color(0xFF0E72ED),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildPageHeader(
                  'Class Recordings',
                  subtitle:
                      '${_recordings.length} recording${_recordings.length == 1 ? '' : 's'} across ${_shiftGroups.length} session${_shiftGroups.length == 1 ? '' : 's'}',
                  icon: Icons.video_library_rounded,
                ),
              ),
              if (_recordings.isNotEmpty)
                SliverToBoxAdapter(child: _buildSearchBar()),
              if (_recordings.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(
                    Icons.video_library_outlined,
                    'No recordings yet',
                    'Class recordings will appear here after sessions are recorded.',
                  ),
                )
              else if (groups.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(
                    Icons.search_off_rounded,
                    'No results found',
                    'Try a different search term.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: _isWide(context) ? 300 : 220,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: _isWide(context) ? 1.15 : 0.95,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildShiftFolder(groups[i]),
                      childCount: groups.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── SHIFT FOLDER CARD ─────────────────────

  Widget _buildShiftFolder(_ShiftGroup group) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedShiftId = group.shiftId);
        _fetchStudentNames(group.shiftId);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2E5A8F)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.videocam_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                group.shiftName,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (group.teacherName.trim().isNotEmpty)
                Text(
                  group.teacherName,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF6B7280)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (group.date != null)
                Text(
                  _formatShortDate(group.date),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _contentBadge(
                    Icons.videocam_rounded,
                    '${group.segments.length}',
                    const Color(0xFF0E72ED),
                  ),
                  if (group.readyCount > 0)
                    _contentBadge(
                      Icons.check_circle_rounded,
                      '${group.readyCount} ready',
                      const Color(0xFF10B981),
                    ),
                  if (group.processingCount > 0)
                    _contentBadge(
                      Icons.hourglass_top_rounded,
                      '${group.processingCount}',
                      const Color(0xFFF59E0B),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── SHIFT DETAIL (INLINE) ─────────────────────

  Widget _buildShiftDetail(_ShiftGroup group) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF1E293B)),
                onPressed: () => setState(() {
                  _selectedShiftId = null;
                  _expandedRecordingId = null;
                  _currentlyPlayingId = null;
                }),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.shiftName,
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B)),
                    ),
                    Row(
                      children: [
                        if (group.teacherName.trim().isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              group.teacherName,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(' · ',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                        ],
                        Flexible(
                          child: Text(
                            _formatDate(group.date),
                            style: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
                onPressed: _loadRecordings,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        _buildStudentInfoBar(group.shiftId),
        Expanded(
          child: group.segments.isEmpty
              ? _buildEmptyState(
                  Icons.videocam_off_rounded,
                  'No segments',
                  'No recording segments found for this session.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: group.segments.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSegmentSectionHeader(group);
                    }
                    return _buildSegmentCard(
                        group.segments[index - 1], index,
                        group.segments.length);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStudentInfoBar(String shiftId) {
    final names = _studentNamesCache[shiftId];
    if (_loadingStudents && names == null) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Loading students…',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF94A3B8))),
          ],
        ),
      );
    }
    if (names == null || names.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Students (${names.length})',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: names.map((n) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(n,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF334155))),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentSectionHeader(_ShiftGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0E72ED).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.videocam_rounded,
                size: 16, color: Color(0xFF0E72ED)),
          ),
          const SizedBox(width: 10),
          Text(
            'Segments',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0E72ED).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${group.segments.length}',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0E72ED)),
            ),
          ),
          const Spacer(),
          if (group.subjectName.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                group.subjectName,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7C3AED)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(
      ClassRecordingItem recording, int segmentNumber, int totalSegments) {
    final statusColor = _statusColor(recording.status);
    final isLoading = _loadingRecordingId == recording.recordingId;
    final isExpanded = _expandedRecordingId == recording.recordingId;
    final url = _playbackUrls[recording.recordingId];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                      '$segmentNumber',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0E72ED)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalSegments > 1
                            ? 'Segment $segmentNumber'
                            : 'Full Recording',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827)),
                      ),
                      Text(
                        _formatDate(recording.displayDate),
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF64748B)),
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
                        color: statusColor),
                  ),
                ),
              ],
            ),
            if ((recording.error ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                recording.error!,
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFFDC2626)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            if (isExpanded && url != null) ...[
              VideoPlayerWidget(
                videoUrl: url,
                title: totalSegments > 1
                    ? 'Segment $segmentNumber'
                    : 'Full Recording',
                videoId: recording.recordingId,
                onPlayStarted: (id) =>
                    setState(() => _currentlyPlayingId = id),
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
                  label: Text('Close Player',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
                        borderRadius: BorderRadius.circular(10)),
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

  // ───────────────────── SHARED WIDGETS ─────────────────────

  Widget _contentBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildPageHeader(String title, {String? subtitle, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0E72ED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0E72ED), size: 24),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B))),
                if (subtitle != null)
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
            onPressed: _loadRecordings,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search by class name, teacher, or date...',
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
            borderSide:
                const BorderSide(color: Color(0xFF0E72ED), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: GoogleFonts.inter(fontSize: 14),
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
                child: Icon(icon,
                    size: 32,
                    color: const Color(0xFF0E72ED).withOpacity(0.5)),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: const Color(0xFF6B7280)),
                  textAlign: TextAlign.center),
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
            child: const Icon(Icons.error_outline,
                size: 28, color: Color(0xFFEF4444)),
          ),
          const SizedBox(height: 16),
          Text(_error!,
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadRecordings,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('Try Again', style: GoogleFonts.inter()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E72ED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
