import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/services/surah_podcast_service.dart';
import 'package:alluwalacademyadmin/core/services/user_role_service.dart';

class AssignPodcastDialog extends StatefulWidget {
  final SurahPodcastItem podcast;

  const AssignPodcastDialog({super.key, required this.podcast});

  static Future<bool?> show(BuildContext context, SurahPodcastItem podcast) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.85,
          child: AssignPodcastDialog(podcast: podcast),
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          width: 480,
          height: 560,
          child: AssignPodcastDialog(podcast: podcast),
        ),
      ),
    );
  }

  @override
  State<AssignPodcastDialog> createState() => _AssignPodcastDialogState();
}

class _AssignPodcastDialogState extends State<AssignPodcastDialog> {
  List<Map<String, String>> _students = [];
  final Set<String> _selectedStudentIds = {};
  bool _isLoading = true;
  bool _isAssigning = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _isLoading = false;
          _error = 'Not authenticated';
        });
        return;
      }

      final results = await Future.wait([
        SurahPodcastService.getStudentsForTeacher(uid),
        SurahPodcastService.getAssignedStudentIds(
            widget.podcast.podcastId, uid),
      ]);

      final students = results[0] as List<Map<String, String>>;
      final alreadyAssigned = results[1] as List<String>;

      if (mounted) {
        setState(() {
          _students = students;
          _selectedStudentIds.addAll(alreadyAssigned);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load students';
        });
      }
    }
  }

  List<Map<String, String>> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    final q = _searchQuery.toLowerCase();
    return _students
        .where((s) => (s['name'] ?? '').toLowerCase().contains(q))
        .toList();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedStudentIds.length == _students.length) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds.addAll(_students.map((s) => s['id']!));
      }
    });
  }

  Future<void> _assign() async {
    if (_selectedStudentIds.isEmpty) return;

    setState(() {
      _isAssigning = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final userData = await UserRoleService.getCurrentUserData();
      final firstName =
          userData?['first_name'] ?? userData?['firstName'] ?? '';
      final lastName =
          userData?['last_name'] ?? userData?['lastName'] ?? '';
      final teacherName = '$firstName $lastName'.trim();

      await SurahPodcastService.assignPodcast(
        podcastId: widget.podcast.podcastId,
        surahNumber: widget.podcast.surahNumber,
        surahNameEn: widget.podcast.surahNameEn,
        podcastTitle: widget.podcast.title,
        teacherId: uid,
        teacherName: teacherName.isNotEmpty ? teacherName : 'Teacher',
        studentIds: _selectedStudentIds.toList(),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAssigning = false;
          _error = 'Failed to save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E72ED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.share_rounded,
                    color: Color(0xFF0E72ED), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Share with Students',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B))),
                    Text(widget.podcast.title,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                onPressed:
                    _isAssigning ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search
          TextFormField(
            decoration: InputDecoration(
              hintText: 'Search students...',
              hintStyle:
                  GoogleFonts.inter(color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF94A3B8), size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
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
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 12),

          // Select all toggle
          if (!_isLoading && _students.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedStudentIds.length} of ${_students.length} selected',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF64748B)),
                ),
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(
                    _selectedStudentIds.length == _students.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0E72ED),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),

          // Student list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0E72ED)))
                : _students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E72ED)
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.people_outline_rounded,
                                  size: 28,
                                  color: const Color(0xFF0E72ED)
                                      .withOpacity(0.5)),
                            ),
                            const SizedBox(height: 12),
                            Text('No students found',
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF374151))),
                            const SizedBox(height: 4),
                            Text(
                                'No students in your assigned classes.',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF6B7280))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          final id = student['id']!;
                          final name = student['name'] ?? 'Student';
                          final isSelected =
                              _selectedStudentIds.contains(id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0E72ED)
                                      .withOpacity(0.04)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedStudentIds.add(id);
                                  } else {
                                    _selectedStudentIds.remove(id);
                                  }
                                });
                              },
                              title: Text(name,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: const Color(0xFF111827))),
                              activeColor: const Color(0xFF0E72ED),
                              checkboxShape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(4)),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                            ),
                          );
                        },
                      ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFEF4444))),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    _isAssigning ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF6B7280),
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _selectedStudentIds.isNotEmpty && !_isAssigning
                    ? _assign
                    : null,
                icon: _isAssigning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(
                        Icons.check_rounded,
                        size: 20),
                label: Text(
                  _isAssigning
                      ? 'Saving...'
                      : 'Share (${_selectedStudentIds.length})',
                  style:
                      GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E72ED),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF0E72ED).withOpacity(0.4),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
