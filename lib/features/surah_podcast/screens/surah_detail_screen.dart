import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alluwalacademyadmin/core/constants/surah_data.dart';
import 'package:alluwalacademyadmin/core/services/surah_podcast_service.dart';

import '../widgets/podcast_player_widget.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/upload_podcast_dialog.dart';
import '../widgets/assign_podcast_dialog.dart';

class SurahDetailScreen extends StatefulWidget {
  final SurahInfo surah;
  final List<SurahPodcastItem> items;
  final String role;
  final VoidCallback? onContentChanged;
  final VoidCallback? onBack;

  const SurahDetailScreen({
    super.key,
    required this.surah,
    required this.items,
    required this.role,
    this.onContentChanged,
    this.onBack,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  String? _currentlyPlayingId;
  late List<SurahPodcastItem> _items;

  List<SurahPodcastItem> get _audioItems =>
      _items.where((i) => i.isAudio).toList();
  List<SurahPodcastItem> get _videoItems =>
      _items.where((i) => i.isVideo).toList();
  List<SurahPodcastItem> get _textItems =>
      _items.where((i) => i.isText).toList();
  List<SurahPodcastItem> get _pdfItems =>
      _items.where((i) => i.isPdf).toList();

  bool get _isAdmin =>
      widget.role == 'admin' || widget.role == 'super_admin';
  bool get _isTeacher => widget.role == 'teacher';

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _onPlayStarted(String id) {
    setState(() => _currentlyPlayingId = id);
  }

  Future<void> _deleteItem(SurahPodcastItem item) async {
    final typeLabel = item.isVideo
        ? 'video'
        : item.isPdf
            ? 'PDF'
            : item.isText
                ? 'text'
                : 'audio';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $typeLabel',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete "${item.title}"?',
          style: GoogleFonts.inter(color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Delete', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await SurahPodcastService.deletePodcast(item.podcastId);
        setState(() => _items.removeWhere((i) => i.podcastId == item.podcastId));
        widget.onContentChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted successfully'),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to delete'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Inline header bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF1E293B)),
                onPressed: _goBack,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.surah.number}. ${widget.surah.nameEn}',
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B)),
                    ),
                    Text(
                      '${widget.surah.nameAr} · ${widget.surah.ayahCount} Ayahs',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.add_rounded,
                      color: Color(0xFF0E72ED)),
                  tooltip: 'Add content',
                  onPressed: () async {
                    final added = await UploadPodcastDialog.show(context,
                        surah: widget.surah);
                    if (added == true) {
                      widget.onContentChanged?.call();
                      final fresh = await SurahPodcastService.listPodcasts(
                          surahNumber: widget.surah.number);
                      if (mounted) setState(() => _items = fresh);
                    }
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        // Body
        Expanded(
          child: _items.isEmpty
              ? _buildEmpty()
              : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (_audioItems.isNotEmpty) ...[
                  _sectionHeader(
                      Icons.headphones_rounded, 'Audio', _audioItems.length),
                  const SizedBox(height: 8),
                  ..._audioItems.map(_buildAudioCard),
                  const SizedBox(height: 20),
                ],
                if (_videoItems.isNotEmpty) ...[
                  _sectionHeader(
                      Icons.videocam_rounded, 'Video', _videoItems.length),
                  const SizedBox(height: 8),
                  ..._videoItems.map(_buildVideoCard),
                  const SizedBox(height: 20),
                ],
                if (_pdfItems.isNotEmpty) ...[
                  _sectionHeader(
                      Icons.picture_as_pdf_rounded, 'PDF', _pdfItems.length),
                  const SizedBox(height: 8),
                  ..._pdfItems.map(_buildPdfCard),
                  const SizedBox(height: 20),
                ],
                if (_textItems.isNotEmpty) ...[
                  _sectionHeader(
                      Icons.article_rounded, 'Text', _textItems.length),
                  const SizedBox(height: 8),
                  ..._textItems.map(_buildTextCard),
                ],
              ],
            ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
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
              child: Icon(Icons.folder_open_rounded,
                  size: 32,
                  color: const Color(0xFF0E72ED).withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text('No content yet',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151))),
            const SizedBox(height: 6),
            Text(
              _isAdmin
                  ? 'Add audio, video, PDF, or text content for this surah.'
                  : 'Content for this surah has not been added yet.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: const Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final added = await UploadPodcastDialog.show(context,
                      surah: widget.surah);
                  if (added == true) {
                    widget.onContentChanged?.call();
                    final fresh = await SurahPodcastService.listPodcasts(
                        surahNumber: widget.surah.number);
                    if (mounted) setState(() => _items = fresh);
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Add Content',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E72ED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, int count) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1E3A5F), size: 18),
        ),
        const SizedBox(width: 10),
        Text('$title ($count)',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A5F))),
      ],
    );
  }

  Widget _buildAudioCard(SurahPodcastItem item) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827))),
              ),
              _languageBadge(item.language),
              if (_isAdmin || _isTeacher) ...[
                const SizedBox(width: 4),
                _actionMenu(item),
              ],
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.description,
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF6B7280)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          _metaRow(item),
          const SizedBox(height: 10),
          PodcastPlayerWidget(
            podcastId: item.podcastId,
            audioUrl: item.downloadUrl,
            durationSeconds: item.durationSeconds,
            onPlayStarted: _onPlayStarted,
            shouldPause: _currentlyPlayingId != null &&
                _currentlyPlayingId != item.podcastId,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(SurahPodcastItem item) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(item.title,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827))),
                ),
                _languageBadge(item.language),
                if (_isAdmin || _isTeacher) ...[
                  const SizedBox(width: 4),
                  _actionMenu(item),
                ],
              ],
            ),
          ),
          if (item.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Text(item.description,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF6B7280)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: _metaRow(item),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: VideoPlayerWidget(
              videoUrl: item.downloadUrl,
              title: item.title,
              videoId: item.podcastId,
              onPlayStarted: _onPlayStarted,
              shouldPause: _currentlyPlayingId != null &&
                  _currentlyPlayingId != item.podcastId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCard(SurahPodcastItem item) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.article_rounded,
                    size: 18, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.title,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827))),
              ),
              _languageBadge(item.language),
              if (_isAdmin || _isTeacher) ...[
                const SizedBox(width: 4),
                _actionMenu(item),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              item.textContent,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.6,
                  color: const Color(0xFF374151)),
            ),
          ),
          if (item.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Added ${DateFormat.yMMMd().format(item.createdAt!)}',
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfCard(SurahPodcastItem item) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    size: 18, color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827))),
                    if (item.description.isNotEmpty)
                      Text(item.description,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: const Color(0xFF6B7280)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _languageBadge(item.language),
              if (_isAdmin || _isTeacher) ...[
                const SizedBox(width: 4),
                _actionMenu(item),
              ],
            ],
          ),
          _metaRow(item),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openPdf(item),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Open PDF',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdf(SurahPodcastItem item) async {
    final uri = Uri.tryParse(item.downloadUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open PDF'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _metaRow(SurahPodcastItem item) {
    if (item.durationSeconds == 0 && item.fileSizeBytes == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (item.durationSeconds > 0) ...[
            const Icon(Icons.access_time_rounded,
                size: 13, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(item.formattedDuration,
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF94A3B8))),
            const SizedBox(width: 12),
          ],
          if (item.fileSizeBytes > 0) ...[
            const Icon(Icons.sd_storage_outlined,
                size: 13, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(item.formattedFileSize,
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF94A3B8))),
          ],
          if (item.createdAt != null) ...[
            const SizedBox(width: 12),
            const Icon(Icons.calendar_today_rounded,
                size: 13, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(DateFormat.yMMMd().format(item.createdAt!),
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF94A3B8))),
          ],
        ],
      ),
    );
  }

  Widget _actionMenu(SurahPodcastItem item) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded,
          color: Color(0xFF94A3B8), size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      padding: EdgeInsets.zero,
      onSelected: (action) {
        if (action == 'delete') _deleteItem(item);
        if (action == 'share') _assignItem(item);
      },
      itemBuilder: (_) => [
        if (_isTeacher || _isAdmin)
          PopupMenuItem(
            value: 'share',
            child: Row(
              children: [
                const Icon(Icons.share_rounded,
                    size: 18, color: Color(0xFF0E72ED)),
                const SizedBox(width: 10),
                Text('Share with Students',
                    style: GoogleFonts.inter(fontSize: 14)),
              ],
            ),
          ),
        if (_isAdmin)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Color(0xFFEF4444)),
                const SizedBox(width: 10),
                Text('Delete',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: const Color(0xFFEF4444))),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _assignItem(SurahPodcastItem item) async {
    final assigned = await AssignPodcastDialog.show(context, item);
    if (assigned == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Shared with students successfully'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _languageBadge(String lang) {
    final label = lang == 'en'
        ? 'EN'
        : lang == 'fr'
            ? 'FR'
            : lang == 'ar'
                ? 'AR'
                : lang.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF10B981))),
    );
  }
}
