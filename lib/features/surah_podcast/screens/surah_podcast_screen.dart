import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/constants/surah_data.dart';
import 'package:alluwalacademyadmin/features/surah_podcast/services/surah_podcast_service.dart';
import 'package:alluwalacademyadmin/core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

import 'surah_detail_screen.dart';
import '../widgets/upload_podcast_dialog.dart';

class SurahPodcastScreen extends StatefulWidget {
  const SurahPodcastScreen({super.key});

  @override
  State<SurahPodcastScreen> createState() => _SurahPodcastScreenState();
}

class _SurahPodcastScreenState extends State<SurahPodcastScreen>
    with SingleTickerProviderStateMixin {
  String? _role;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  List<SurahPodcastItem> _allItems = [];
  List<PodcastAssignment> _assignments = [];

  /// When set, shows the detail view for this surah inline.
  int? _selectedSurahNumber;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final role = await UserRoleService.getCurrentUserRole();
      final roleLower = role?.toLowerCase() ?? '';
      final uid = FirebaseAuth.instance.currentUser?.uid;

      AppLogger.info(
          'SurahPodcast._loadData: role="$role" roleLower="$roleLower" uid=$uid');

      if (roleLower == 'student' || roleLower == 'parent') {
        // Students only see assigned content
        final assigned = uid != null
            ? await SurahPodcastService.getAssignedPodcasts(uid)
            : <SurahPodcastItem>[];
        AppLogger.info(
            'SurahPodcast: student/parent loaded ${assigned.length} assigned items');
        if (mounted) {
          setState(() {
            _role = roleLower;
            _allItems = assigned;
            _isLoading = false;
          });
        }
      } else {
        // Admin, teacher, and any other role see ALL content
        final items = await SurahPodcastService.listPodcasts();
        AppLogger.info(
            'SurahPodcast: loaded ${items.length} items for role="$roleLower"');

        final isTeacher = roleLower == 'teacher';
        if (isTeacher) {
          _tabController ??= TabController(length: 2, vsync: this);
        }

        final assignments =
            (isTeacher && uid != null)
                ? await SurahPodcastService.getTeacherAssignments(uid)
                : <PodcastAssignment>[];

        if (mounted) {
          setState(() {
            _role = roleLower.isEmpty ? (role ?? 'teacher') : roleLower;
            _allItems =
                items.where((i) => i.status == 'active').toList();
            if (_allItems.isEmpty && items.isNotEmpty) {
              // If no items are 'active', show all (status might differ)
              _allItems = items;
            }
            _assignments = assignments;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.error('SurahPodcast._loadData error', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load content';
        });
      }
    }
  }

  /// Group items by surah number.
  Map<int, List<SurahPodcastItem>> get _groupedBySurah {
    final map = <int, List<SurahPodcastItem>>{};
    for (final item in _allItems) {
      map.putIfAbsent(item.surahNumber, () => []).add(item);
    }
    return map;
  }

  /// Filtered surah numbers based on search.
  List<int> get _filteredSurahNumbers {
    final grouped = _groupedBySurah;
    var numbers = grouped.keys.toList()..sort();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      numbers = numbers.where((n) {
        final surah = getSurahByNumber(n);
        if (surah == null) return false;
        return surah.nameEn.toLowerCase().contains(q) ||
            surah.nameAr.contains(q) ||
            n.toString().contains(q);
      }).toList();
    }
    return numbers;
  }

  bool get _isAdmin {
    final r = _role?.toLowerCase();
    return r == 'admin' || r == 'super_admin';
  }
  bool get _isTeacher => _role?.toLowerCase() == 'teacher';

  void _openSurahDetail(int surahNumber) {
    setState(() => _selectedSurahNumber = surahNumber);
  }

  void _closeSurahDetail() {
    setState(() => _selectedSurahNumber = null);
  }

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
        body: SafeArea(
          child: Center(
            child: _buildErrorCard(),
          ),
        ),
      );
    }

    // Show detail view inline when a surah is selected
    if (_selectedSurahNumber != null) {
      final surah = getSurahByNumber(_selectedSurahNumber!);
      if (surah != null) {
        final items = _groupedBySurah[_selectedSurahNumber!] ?? [];
        return Material(
          color: const Color(0xFFF8FAFC),
          child: SafeArea(
            child: SurahDetailScreen(
              key: ValueKey(_selectedSurahNumber),
              surah: surah,
              items: items,
              role: _role ?? 'student',
              onBack: _closeSurahDetail,
              onContentChanged: () {
                _loadData();
              },
            ),
          ),
        );
      }
    }

    if (_isAdmin) return _buildAdminView();
    if (_isTeacher) return _buildTeacherView();
    return _buildStudentView();
  }

  // ───────────────────── ADMIN VIEW ─────────────────────

  Widget _buildAdminView() {
    final numbers = _filteredSurahNumbers;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF0E72ED),
          child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildPageHeader(
                'Surah Library',
                subtitle: '${_allItems.length} items across ${_groupedBySurah.length} surahs',
                icon: Icons.library_music_rounded,
              ),
            ),
            SliverToBoxAdapter(child: _buildSearchBar()),
            if (numbers.isEmpty && _allItems.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(
                Icons.cloud_upload_rounded,
                'No content uploaded yet',
                'Upload audio, video, or text content for any surah.',
              ))
            else if (numbers.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(
                Icons.search_off_rounded,
                'No results found',
                'Try a different search term.',
              ))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: _isWide(context) ? 280 : 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: _isWide(context) ? 1.1 : 0.95,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildSurahFolder(numbers[i]),
                    childCount: numbers.length,
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await UploadPodcastDialog.show(context);
          if (added == true) {
            _loadData();
          }
        },
        backgroundColor: const Color(0xFF0E72ED),
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Content',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ───────────────────── TEACHER VIEW ─────────────────────

  Widget _buildTeacherView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(
              'Surah Content',
              icon: Icons.podcasts_rounded,
            ),
            Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0E72ED),
              unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: const Color(0xFF0E72ED),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              labelStyle: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: 'Library (${_groupedBySurah.length})'),
                Tab(text: 'Shared (${_assignments.length})'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTeacherLibraryTab(),
                _buildTeacherAssignmentsTab(),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTeacherLibraryTab() {
    final numbers = _filteredSurahNumbers;
    if (_allItems.isEmpty) {
      return _buildEmptyState(
        Icons.library_music_outlined,
        'No content available',
        'The admin has not uploaded any surah content yet.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF0E72ED),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSearchBar()),
          if (numbers.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(
                Icons.search_off_rounded,
                'No results found',
                'Try a different search term.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: _isWide(context) ? 280 : 200,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: _isWide(context) ? 1.1 : 0.95,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildSurahFolder(numbers[i]),
                  childCount: numbers.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeacherAssignmentsTab() {
    if (_assignments.isEmpty) {
      return _buildEmptyState(
        Icons.share_rounded,
        'Nothing shared yet',
        'Open a surah and share content with your students.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF0E72ED),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: _assignments.length,
        itemBuilder: (context, index) =>
            _buildAssignmentCard(_assignments[index]),
      ),
    );
  }

  Widget _buildAssignmentCard(PodcastAssignment a) {
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
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0E72ED).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.podcasts_rounded,
              color: Color(0xFF0E72ED), size: 22),
        ),
        title: Text(a.podcastTitle,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.people_outline_rounded,
                  size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                '${a.studentIds.length} student${a.studentIds.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF6B7280)),
              ),
              if (a.assignedAt != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.schedule_rounded,
                    size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  DateFormat.yMMMd().format(a.assignedAt!),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF6B7280)),
                ),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded,
              color: Color(0xFFEF4444), size: 22),
          tooltip: 'Remove',
          onPressed: () async {
            await SurahPodcastService.unassignPodcast(a.assignmentId);
            _loadData();
          },
        ),
      ),
    );
  }

  // ───────────────────── STUDENT VIEW ─────────────────────

  Widget _buildStudentView() {
    final numbers = _filteredSurahNumbers;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF1E3A5F),
          child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildStudentHeader()),
            if (_allItems.isNotEmpty)
              SliverToBoxAdapter(child: _buildSearchBar()),
            if (_allItems.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(
                  Icons.headphones_rounded,
                  'No content assigned yet',
                  'Your teacher will assign surah content for you to explore.',
                ),
              )
            else if (numbers.isEmpty)
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
                    maxCrossAxisExtent: _isWide(context) ? 280 : 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: _isWide(context) ? 1.1 : 0.95,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildSurahFolder(numbers[i]),
                    childCount: numbers.length,
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A5F), Color(0xFF2E5A8F)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Surah Content',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  '${_groupedBySurah.length} surah${_groupedBySurah.length == 1 ? '' : 's'} · ${_allItems.length} item${_allItems.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  // ───────────────────── SURAH FOLDER CARD ─────────────────────

  Widget _buildSurahFolder(int surahNumber) {
    final surah = getSurahByNumber(surahNumber);
    if (surah == null) return const SizedBox.shrink();

    final items = _groupedBySurah[surahNumber] ?? [];
    final audioCount = items.where((i) => i.isAudio).length;
    final videoCount = items.where((i) => i.isVideo).length;
    final pdfCount = items.where((i) => i.isPdf).length;
    final textCount = items.where((i) => i.isText).length;

    return GestureDetector(
      onTap: () => _openSurahDetail(surahNumber),
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
              // Surah number badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2E5A8F)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$surahNumber',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Surah name
              Text(
                surah.nameEn,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                surah.nameAr,
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF6B7280)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Content indicators
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (audioCount > 0)
                    _contentBadge(Icons.headphones_rounded, '$audioCount',
                        const Color(0xFF0E72ED)),
                  if (videoCount > 0)
                    _contentBadge(Icons.videocam_rounded, '$videoCount',
                        const Color(0xFF7C3AED)),
                  if (pdfCount > 0)
                    _contentBadge(Icons.picture_as_pdf_rounded, '$pdfCount',
                        const Color(0xFFEF4444)),
                  if (textCount > 0)
                    _contentBadge(Icons.article_rounded, '$textCount',
                        const Color(0xFF10B981)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contentBadge(IconData icon, String count, Color color) {
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
          Text(count,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // ───────────────────── SHARED WIDGETS ─────────────────────

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
            onPressed: _loadData,
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
          hintText: 'Search by surah name or number...',
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
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('Try Again', style: GoogleFonts.inter()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E72ED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  bool _isWide(BuildContext context) =>
      MediaQuery.of(context).size.width > 600;
}
