import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alluwalacademyadmin/features/tasks/enums/task_enums.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task.dart';
import '../services/task_service.dart';
import '../services/file_attachment_service.dart';
import 'task_comments_section.dart';
import 'add_edit_task_dialog.dart';
import '../../../core/utils/connecteam_style.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/enhanced_recurrence.dart';
import 'package:alluwalacademyadmin/features/shift_management/enums/shift_enums.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TaskDetailsView extends StatefulWidget {
  final Task task;
  final VoidCallback onTaskUpdated;

  /// Resolved display names from the task list screen (`uid` / doc id → name).
  /// When provided, labels show immediately instead of waiting on Firestore.
  final Map<String, String> userDisplayNames;

  const TaskDetailsView({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    this.userDisplayNames = const {},
  });

  @override
  State<TaskDetailsView> createState() => _TaskDetailsViewState();
}

class _TaskDetailsViewState extends State<TaskDetailsView>
    with TickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  final FileAttachmentService _fileService = FileAttachmentService();
  final TextEditingController _notesController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isUpdating = false;
  bool _isUploadingFile = false;
  TaskStatus _currentStatus = TaskStatus.todo;
  late Task _currentTask;
  String? _assignedByName;
  List<String> _assignedToNames = [];
  Timer? _parentCachePollTimer;
  StreamSubscription<DocumentSnapshot>? _taskDocSub;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.task.status;
    _currentTask = widget.task;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _seedFromParentNameCache();

    _animationController.forward();

    // Fill any names still missing (cache hit avoids network for list-known users)
    _resolveUserNames();

    _startParentCachePoll();

    _taskService.recordTaskDetailViewed(widget.task.id);

    if (_isCurrentUserTaskCreator(_currentTask)) {
      _taskDocSub = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.id)
          .snapshots()
          .listen((snap) {
        if (!mounted || !snap.exists) return;
        final fresh = Task.fromFirestore(snap);
        setState(() {
          _currentTask = _currentTask.copyWith(
            firstOpenedAt: fresh.firstOpenedAt,
            firstViewedAt: fresh.firstViewedAt,
            assigneeFirstOpenedAt: fresh.assigneeFirstOpenedAt,
          );
        });
      });
    }
  }

  bool _isCurrentUserTaskCreator(Task task) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;
    final c = task.createdBy.trim();
    if (c.isEmpty) return false;
    if (c == u.uid.trim()) return true;
    final em = u.email?.trim().toLowerCase();
    if (em != null && c.contains('@') && c.trim().toLowerCase() == em) {
      return true;
    }
    return false;
  }

  Timestamp? _firstTimestampForAssigneeSlot(
    Map<String, Timestamp> map,
    String assigneeSlot,
  ) {
    if (map.isEmpty) return null;
    final a = assigneeSlot.trim();
    if (a.isEmpty) return null;
    final direct = map[a];
    if (direct != null) return direct;
    final lower = a.toLowerCase();
    for (final e in map.entries) {
      if (e.key.toLowerCase() == lower) return e.value;
    }
    return null;
  }

  /// Parent screen may still be resolving ids into [userDisplayNames] after open.
  void _startParentCachePoll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mergeParentCacheIntoFields()) {
        setState(() {});
      }
    });
    var ticks = 0;
    _parentCachePollTimer?.cancel();
    _parentCachePollTimer =
        Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      ticks++;
      if (ticks > 16) {
        t.cancel();
        return;
      }
      if (!_mergeParentCacheIntoFields()) {
        if (!_anyDisplayNameMissing()) {
          t.cancel();
        }
        return;
      }
      setState(() {});
    });
  }

  bool _anyDisplayNameMissing() {
    final cb = widget.task.createdBy.trim();
    if (cb.isNotEmpty &&
        (_assignedByName == null || _assignedByName!.trim().isEmpty)) {
      return true;
    }
    final ids = widget.task.assignedTo
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.length != _assignedToNames.length) return true;
    for (var i = 0; i < ids.length; i++) {
      if (_assignedToNames[i].trim().isEmpty) return true;
    }
    return false;
  }

  /// Returns true if any field was updated from [userDisplayNames].
  bool _mergeParentCacheIntoFields() {
    var changed = false;
    final cb = widget.task.createdBy.trim();
    if (cb.isNotEmpty &&
        (_assignedByName == null || _assignedByName!.trim().isEmpty)) {
      final v = _lookupCachedName(cb);
      if (v != null) {
        _assignedByName = v;
        changed = true;
      }
    }
    final ids = widget.task.assignedTo
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return changed;
    if (_assignedToNames.length != ids.length) {
      return changed;
    }
    for (var i = 0; i < ids.length; i++) {
      if (_assignedToNames[i].trim().isNotEmpty) continue;
      final v = _lookupCachedName(ids[i]);
      if (v != null) {
        _assignedToNames[i] = v;
        changed = true;
      }
    }
    return changed;
  }

  static bool _isReliableDisplayName(String? v) {
    if (v == null || v.trim().isEmpty) return false;
    if (v == 'Loading...' || v == '...') return false;
    return true;
  }

  /// Cache keys may not match task ids exactly (casing, spacing, email vs uid).
  String? _lookupCachedName(String rawId) {
    final id = rawId.trim();
    if (id.isEmpty) return null;
    final c = widget.userDisplayNames;
    for (final key in [id, id.toLowerCase()]) {
      final v = c[key];
      if (_isReliableDisplayName(v)) return v;
    }
    final idLower = id.toLowerCase();
    for (final e in c.entries) {
      if (e.key.trim().toLowerCase() == idLower &&
          _isReliableDisplayName(e.value)) {
        return e.value;
      }
    }
    return null;
  }

  /// Pre-fill from [userDisplayNames] so the modal matches the list without waiting.
  void _seedFromParentNameCache() {
    final cb = widget.task.createdBy.trim();
    if (cb.isNotEmpty) {
      final v = _lookupCachedName(cb);
      if (v != null) {
        _assignedByName = v;
      }
    }
    final ids = widget.task.assignedTo
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      _assignedToNames = [];
      return;
    }
    _assignedToNames = ids
        .map((id) {
          final v = _lookupCachedName(id);
          return v ?? '';
        })
        .toList();
  }

  /// Resolves a user reference (UID, email, or legacy doc id) to a display string.
  /// Matches [QuickTasksScreen._fetchUserNameIfMissing] fallbacks so task rows and
  /// this modal stay consistent when `users` docs are not keyed by Firebase UID.
  Future<String> _fetchUserDisplayName(
    String userRef,
    String unknownLabel,
  ) async {
    if (userRef.isEmpty) return unknownLabel;
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;

      final direct =
          await FirebaseFirestore.instance.collection('users').doc(userRef).get();
      if (direct.exists) {
        doc = direct;
      } else {
        final byUidField = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: userRef)
            .limit(1)
            .get();
        if (byUidField.docs.isNotEmpty) {
          doc = byUidField.docs.first;
        }
      }

      final emailLower = userRef.trim().toLowerCase();
      if (doc == null && userRef.contains('@')) {
        final byEmailId =
            await FirebaseFirestore.instance.collection('users').doc(emailLower).get();
        if (byEmailId.exists) {
          doc = byEmailId;
        }
      }
      if (doc == null && userRef.contains('@')) {
        final byEmailField = await FirebaseFirestore.instance
            .collection('users')
            .where('e-mail', isEqualTo: emailLower)
            .limit(1)
            .get();
        if (byEmailField.docs.isNotEmpty) {
          doc = byEmailField.docs.first;
        }
      }

      if (doc == null || !doc.exists) {
        return unknownLabel;
      }

      final d = doc.data()!;
      final fullName =
          '${(d['first_name'] ?? '').toString().trim()} ${(d['last_name'] ?? '').toString().trim()}'
              .trim();
      if (fullName.isNotEmpty) return fullName;

      final email = (d['e-mail'] ?? d['email'] ?? '').toString();
      if (email.isNotEmpty) {
        if (email.contains('@')) {
          final emailParts = email.split('@')[0].split('.');
          return emailParts
              .map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}')
              .join(' ');
        }
        return email;
      }

      final dn = (d['displayName'] ?? d['name'] ?? '').toString().trim();
      if (dn.isNotEmpty) return dn;

      return userRef.length > 12 ? '${userRef.substring(0, 12)}…' : userRef;
    } catch (_) {
      return unknownLabel;
    }
  }

  Future<void> _resolveUserNames() async {
    if (!mounted) return;
    final unknown = AppLocalizations.of(context)!.commonUnknownUser;

    // Do not use a single Future.wait without catchError — one failing future would
    // cancel waiting and could leave names stuck on "Loading…".
    Future<void> safe(Future<void> f) =>
        f.catchError((Object _, StackTrace __) {});

    await Future.wait<void>([
      safe(_resolveCreatedByDisplay(unknown)),
      safe(_resolveAssignedToDisplay(unknown)),
    ]);
  }

  Future<void> _resolveCreatedByDisplay(String unknownLabel) async {
    final id = widget.task.createdBy.trim();
    if (id.isEmpty) return;
    if (_assignedByName != null && _assignedByName!.trim().isNotEmpty) {
      return;
    }
    final cached = _lookupCachedName(id);
    if (cached != null) {
      if (mounted) setState(() => _assignedByName = cached);
      return;
    }
    final name = await _fetchUserDisplayName(id, unknownLabel).timeout(
      const Duration(seconds: 12),
      onTimeout: () => unknownLabel,
    );
    if (mounted) setState(() => _assignedByName = name);
  }

  Future<void> _resolveAssignedToDisplay(String unknownLabel) async {
    final ids = widget.task.assignedTo
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      if (mounted) setState(() => _assignedToNames = []);
      return;
    }
    var names = List<String>.from(_assignedToNames);
    if (names.length != ids.length) {
      names = List.generate(
        ids.length,
        (i) => i < names.length ? names[i] : '',
      );
    }
    // Re-apply cache in case the parent map was filled after seed (same reference).
    for (var i = 0; i < ids.length; i++) {
      if (names[i].trim().isNotEmpty) continue;
      final hit = _lookupCachedName(ids[i]);
      if (hit != null) names[i] = hit;
    }

    final pending = <int>[];
    for (var i = 0; i < ids.length; i++) {
      if (names[i].trim().isEmpty) pending.add(i);
    }
    if (pending.isNotEmpty) {
      await Future.wait(pending.map((i) async {
        names[i] = await _fetchUserDisplayName(ids[i], unknownLabel).timeout(
          const Duration(seconds: 12),
          onTimeout: () => unknownLabel,
        );
      }));
    }
    for (var i = 0; i < ids.length; i++) {
      if (names[i].trim().isEmpty) {
        final hit = _lookupCachedName(ids[i]);
        if (hit != null) names[i] = hit;
      }
      if (names[i].trim().isEmpty) {
        names[i] = unknownLabel;
      }
    }
    if (mounted) setState(() => _assignedToNames = names);
  }

  String _formatAssigneesLine() {
    final l10n = AppLocalizations.of(context)!;
    final ids = widget.task.assignedTo
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return l10n.taskUnassigned;
    if (_assignedToNames.length != ids.length) {
      return l10n.commonLoading;
    }
    final parts = <String>[];
    for (var i = 0; i < ids.length; i++) {
      var n = _assignedToNames[i].trim();
      if (n.isEmpty) {
        n = _lookupCachedName(ids[i])?.trim() ?? '';
      }
      parts.add(
        n.isNotEmpty ? n : l10n.commonLoading,
      );
    }
    return parts.join(', ');
  }

  String _creatorDisplayLine() {
    final l10n = AppLocalizations.of(context)!;
    final id = widget.task.createdBy.trim();
    if (id.isEmpty) return l10n.commonUnknown;
    final resolved = _assignedByName?.trim();
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    final cached = _lookupCachedName(id);
    if (cached != null) return cached;
    return l10n.commonLoading;
  }

  Widget _buildCreatorAssigneeOpenSection() {
    final l10n = AppLocalizations.of(context)!;
    final df = DateFormat.yMMMd().add_jm();
    final map = _currentTask.assigneeFirstOpenedAt;
    final ids = _currentTask.assignedTo
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xffECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 18, color: Color(0xff047857)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.taskAssigneeOpenTrackingTitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff065F46),
                  ),
                ),
              ),
            ],
          ),
          if (_currentTask.firstViewedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.taskDetailFirstViewedAt(
                df.format(_currentTask.firstViewedAt!.toDate()),
              ),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff047857),
              ),
            ),
          ],
          if (ids.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...ids.map((id) {
              final name = _lookupCachedName(id) ?? id;
              final ts = _firstTimestampForAssigneeSlot(map, id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        ts != null
                            ? l10n.taskAssigneeOpenedAt(df.format(ts.toDate()))
                            : l10n.taskAssigneeNotOpenedYet,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: ts != null
                              ? const Color(0xff047857)
                              : const Color(0xff94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _taskDocSub?.cancel();
    _parentCachePollTimer?.cancel();
    _animationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        Flexible(child: _buildBody()),
        _buildActions(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(_currentStatus),
            _getStatusColor(_currentStatus).withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  _getStatusIcon(_currentStatus),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.task.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: Colors.white,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (context) => AddEditTaskDialog(
                      task: widget.task,
                    ),
                  ).then((_) {
                    widget.onTaskUpdated();
                  });
                },
                icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                tooltip: widget.task.isDraft ? 'Edit & Publish Draft' : 'Edit Task',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildStatusChip(_currentStatus),
              _buildPriorityChip(widget.task.priority),
              if (widget.task.isRecurring &&
                  widget.task.enhancedRecurrence.type != EnhancedRecurrenceType.none)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.recurring,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(),
            if (_isCurrentUserTaskCreator(_currentTask)) ...[
              const SizedBox(height: 14),
              _buildCreatorAssigneeOpenSection(),
            ],
            const SizedBox(height: 14),
            _buildDescriptionSection(),
            const SizedBox(height: 14),
            _buildAttachmentsSection(),
            const SizedBox(height: 14),
            _buildStatusUpdateSection(),
            if (_currentStatus != TaskStatus.todo) ...[
              const SizedBox(height: 14),
              _buildNotesSection(),
            ],
            const SizedBox(height: 20),
            TaskCommentsSection(task: _currentTask),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.calendar_today,
            'Due Date',
            DateFormat('MMM dd, yyyy • h:mm a').format(widget.task.dueDate),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.person,
            'Assigned To',
            _formatAssigneesLine(),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.person_outline,
            'Assigned By',
            _creatorDisplayLine(),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.access_time,
            'Created',
            DateFormat('MMM dd, yyyy').format(widget.task.createdAt.toDate()),
          ),
          if (widget.task.isRecurring &&
              widget.task.enhancedRecurrence.type != EnhancedRecurrenceType.none) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xffE2E8F0)),
            const SizedBox(height: 10),
            _buildRecurrenceSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    final recurrence = widget.task.enhancedRecurrence;
    final nextOccurrences = _getNextOccurrences(recurrence, widget.task.dueDate);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recurrence Pattern
        _buildInfoRow(
          Icons.repeat,
          'Recurrence',
          recurrence.localizedDescription(AppLocalizations.of(context)!),
        ),
        const SizedBox(height: 16),
        // Next Occurrence
        if (nextOccurrences.isNotEmpty) ...[
          _buildInfoRow(
            Icons.calendar_today,
            'Next Due',
            _formatNextOccurrence(nextOccurrences.first),
          ),
          const SizedBox(height: 16),
        ] else ...[
          _buildInfoRow(
            Icons.event_busy,
            'Next Due',
            'No more occurrences',
          ),
          const SizedBox(height: 16),
        ],
        // End Date (if set)
        if (recurrence.endDate != null) ...[
          _buildInfoRow(
            Icons.event_busy,
            'Ends On',
            DateFormat('MMM dd, yyyy').format(recurrence.endDate!),
          ),
          const SizedBox(height: 16),
        ],
        // Upcoming Occurrences Preview (next 3)
        if (nextOccurrences.length > 1) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ConnecteamStyle.primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ConnecteamStyle.primaryBlue.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: ConnecteamStyle.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.upcomingOccurrences,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ConnecteamStyle.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...nextOccurrences.skip(1).take(3).map((date) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${_formatNextOccurrence(date)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: ConnecteamStyle.textGrey,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<DateTime> _getNextOccurrences(EnhancedRecurrence recurrence, DateTime startDate) {
    if (recurrence.type == EnhancedRecurrenceType.none) {
      return [];
    }

    // Get next 5 occurrences starting from today
    final now = DateTime.now();
    final startFrom = now.isAfter(startDate) ? now : startDate;
    
    // Generate occurrences (up to 5)
    final occurrences = recurrence.generateOccurrences(
      startFrom,
      5,
      timezoneId: null, // Use system timezone
    );

    // Filter out past dates and respect end date
    final validOccurrences = occurrences.where((date) {
      if (date.isBefore(now)) return false;
      if (recurrence.endDate != null && date.isAfter(recurrence.endDate!)) return false;
      return true;
    }).toList();

    return validOccurrences;
  }

  String _formatNextOccurrence(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final daysDiff = taskDate.difference(today).inDays;

    if (daysDiff == 0) {
      return 'Today ${DateFormat('h:mm a').format(date)}';
    } else if (daysDiff == 1) {
      return 'Tomorrow ${DateFormat('h:mm a').format(date)}';
    } else if (daysDiff < 7) {
      return DateFormat('EEEE, MMM d • h:mm a').format(date);
    } else {
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return _buildAttributeRow(
      icon: icon,
      label: label,
      child: Text(
        value,
        style: ConnecteamStyle.cellText.copyWith(fontSize: 13, height: 1.35),
      ),
    );
  }

  Widget _buildAttributeRow({required IconData icon, required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[600], size: 18),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.description,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Text(
            widget.task.description.isNotEmpty
                ? widget.task.description
                : 'No description provided',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: widget.task.description.isNotEmpty
                  ? const Color(0xff475569)
                  : const Color(0xff94A3B8),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context)!.attachments,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xff1E293B),
              ),
            ),
            const Spacer(),
            if (_currentStatus != TaskStatus.done)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isUploadingFile
                      ? null
                      : () {
                          AppLogger.debug('Add Files button clicked');
                          _pickAndUploadFiles();
                        },
                  icon: _isUploadingFile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.attach_file, size: 18),
                  label: Text(
                    _isUploadingFile ? 'Uploading...' : 'Add Files',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_currentTask.attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.attach_file,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.noAttachmentsYet,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xff94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.addFilesToShareResourcesOr,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff94A3B8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...List.generate(_currentTask.attachments.length, (index) {
            final attachment = _currentTask.attachments[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAttachmentItem(attachment),
            );
          }),
      ],
    );
  }

  Widget _buildAttachmentItem(TaskAttachment attachment) {
    final fileIcon = _fileService.getFileIcon(attachment.fileType);
    final fileSize = _fileService.formatFileSize(attachment.fileSize);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                fileIcon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.originalName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$fileSize • ${DateFormat('MMM dd, yyyy').format(attachment.uploadedAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _downloadFile(attachment),
                icon: const Icon(Icons.download),
                tooltip: AppLocalizations.of(context)!.download,
                iconSize: 20,
                color: const Color(0xff0386FF),
              ),
              if (_currentStatus != TaskStatus.done)
                IconButton(
                  onPressed: () => _removeAttachment(attachment),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: AppLocalizations.of(context)!.remove,
                  iconSize: 20,
                  color: Colors.red.shade400,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUpdateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.updateStatus,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: TaskStatus.values.map((status) {
            final isSelected = _currentStatus == status;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _currentStatus = status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getStatusColor(status)
                          : const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _getStatusColor(status)
                            : const Color(0xffE2E8F0),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: isSelected
                              ? Colors.white
                              : _getStatusColor(status),
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusLabel(status),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : _getStatusColor(status),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.progressNotes,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xff1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: _currentStatus == TaskStatus.done
                  ? 'Add completion notes or summary...'
                  : 'Add progress notes or comments...',
              hintStyle: GoogleFonts.inter(
                color: const Color(0xff94A3B8),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xff475569),
            ),
          ),
        ),
      ],
    );
  }

  /// True when this task is an application-form update that describes "unable to"
  /// match (no specific time, no duration, no per-day times). In that case we must
  /// not allow Update Status / accept until the underlying application has a match.
  bool get _isNoMatchApplicationTask {
    final title = (widget.task.title).toLowerCase();
    final desc = widget.task.description.toLowerCase();
    final isApplicationFormTask = title.contains('application form') ||
        title.contains('update application');
    final indicatesNoMatch = desc.contains('unable to');
    return isApplicationFormTask && indicatesNoMatch;
  }

  Widget _buildActions() {
    final hasChanges = _currentStatus != widget.task.status;
    final allowUpdate = hasChanges &&
        !_isUpdating &&
        !_isNoMatchApplicationTask;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: Color(0xffF8FAFC),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xffE2E8F0)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.commonCancel,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff64748B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Tooltip(
              message: _isNoMatchApplicationTask
                  ? 'Resolve the "unable to" items above before updating status.'
                  : '',
              child: ElevatedButton(
                onPressed: allowUpdate ? _updateTask : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: allowUpdate
                    ? _getStatusColor(_currentStatus)
                    : const Color(0xffE2E8F0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: allowUpdate ? 4 : 0,
              ),
              child: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentStatus == TaskStatus.done
                              ? Icons.check_circle
                              : Icons.update,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentStatus == TaskStatus.done
                              ? 'Submit Task'
                              : 'Update Status',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(TaskStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _getStatusLabel(status),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(TaskPriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.flag,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            _getPriorityLabel(priority),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTask() async {
    setState(() => _isUpdating = true);

    try {
      // Determine completion fields
      Timestamp? completedAt = widget.task.completedAt;
      int? overdueFrozen = widget.task.overdueDaysAtCompletion;

      final wasDone = widget.task.status == TaskStatus.done;
      final willBeDone = _currentStatus == TaskStatus.done;

      if (!wasDone && willBeDone) {
        final now = DateTime.now();
        final overdue = now.isAfter(widget.task.dueDate)
            ? now.difference(widget.task.dueDate).inDays
            : 0;
        completedAt = Timestamp.fromDate(now);
        overdueFrozen = overdue;
      }

      final updatedTask = Task(
        id: widget.task.id,
        title: widget.task.title,
        description: widget.task.description,
        createdBy: widget.task.createdBy,
        assignedTo: widget.task.assignedTo,
        dueDate: widget.task.dueDate,
        priority: widget.task.priority,
        status: _currentStatus,
        isRecurring: widget.task.isRecurring,
        recurrenceType: widget.task.recurrenceType,
        enhancedRecurrence: widget.task.enhancedRecurrence,
        createdAt: widget.task.createdAt,
        attachments: _currentTask.attachments,
        completedAt: completedAt,
        overdueDaysAtCompletion: overdueFrozen,
        isArchived: widget.task.isArchived,
        archivedAt: widget.task.archivedAt,
        startDate: widget.task.startDate,
        isDraft: widget.task.isDraft,
        publishedAt: widget.task.publishedAt,
        location: widget.task.location,
        startTime: widget.task.startTime,
        endTime: widget.task.endTime,
        labels: widget.task.labels,
        subTaskIds: widget.task.subTaskIds,
        firstOpenedAt: _currentTask.firstOpenedAt,
        firstViewedAt: _currentTask.firstViewedAt,
        assigneeFirstOpenedAt: _currentTask.assigneeFirstOpenedAt,
      );

      await _taskService.updateTask(widget.task.id, updatedTask);

      if (mounted) {
        widget.onTaskUpdated();
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _currentStatus == TaskStatus.done
                      ? Icons.check_circle
                      : Icons.update,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _currentStatus == TaskStatus.done
                      ? 'Task submitted successfully!'
                      : 'Task status updated!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: _getStatusColor(_currentStatus),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.failedToUpdateTaskPleaseTry,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _pickAndUploadFiles() async {
    AppLogger.debug('_pickAndUploadFiles called');

    try {
      if (mounted) {
        setState(() => _isUploadingFile = true);
      }

      AppLogger.debug('Calling file service to pick files...');
      final files = await _fileService.pickFiles();

      if (files == null || files.isEmpty) {
        AppLogger.debug('No files selected or user cancelled');
        if (mounted) {
          setState(() => _isUploadingFile = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.noFilesSelected,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      AppLogger.debug('${files.length} files selected, starting upload...');
      int successfulUploads = 0;

      for (final file in files) {
        try {
          AppLogger.debug('Uploading file: ${file.name}');
          final attachment =
              await _fileService.uploadFile(file, widget.task.id);
          await _taskService.addAttachmentToTask(widget.task.id, attachment);

          if (mounted) {
            setState(() {
              _currentTask = _currentTask.copyWith(
                attachments: [..._currentTask.attachments, attachment],
              );
            });
          }

          successfulUploads++;
          AppLogger.error('Successfully uploaded: ${file.name}');
        } catch (e) {
          AppLogger.error('Failed to upload ${file.name}: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to upload ${file.name}: ${e.toString()}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      }

      if (mounted && successfulUploads > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.successfuluploadsFileSUploadedSuccessfully,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error in _pickAndUploadFiles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to upload files: ${e.toString()}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingFile = false);
      }
    }
  }

  Future<void> _downloadFile(TaskAttachment attachment) async {
    try {
      await _fileService.downloadFile(attachment);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .taskDownloadFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeAttachment(TaskAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.removeAttachment),
        content: Text(
            'Are you sure you want to remove "${attachment.originalName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.remove),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _taskService.removeAttachmentFromTask(
            widget.task.id, attachment.id);

        setState(() {
          _currentTask = _currentTask.copyWith(
            attachments: _currentTask.attachments
                .where((a) => a.id != attachment.id)
                .toList(),
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.attachmentRemovedSuccessfully,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .taskRemoveAttachmentFailed(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return const Color(0xff3B82F6);
      case TaskStatus.inProgress:
        return const Color(0xff8B5CF6);
      case TaskStatus.done:
        return const Color(0xff10B981);
    }
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.hourglass_empty;
      case TaskStatus.done:
        return Icons.check_circle;
    }
  }

  String _getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Completed';
    }
  }

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }
}
