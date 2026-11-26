import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';

const _accent = Color(0xFF0386FF);
const _longBody = 220;

String announcementDate(BuildContext context, DateTime? date) {
  if (date == null) return '';
  return DateFormat.yMMMd(Localizations.localeOf(context).toString())
      .format(date);
}

String announcementByline(BuildContext context, Announcement item) {
  return [item.createdByName, announcementDate(context, item.createdAt)]
      .where((part) => part.isNotEmpty)
      .join(' · ');
}

/// School announcements addressed to [role] ('teacher', 'student' or
/// 'parent'): pinned first, then newest, expired ones hidden. An unseen pinned
/// announcement opens once as a pop-up; closing it records it as seen.
class AnnouncementsCard extends StatefulWidget {
  const AnnouncementsCard({
    super.key,
    required this.role,
    this.margin = EdgeInsets.zero,
  });

  final String role;
  final EdgeInsetsGeometry margin;

  @override
  State<AnnouncementsCard> createState() => _AnnouncementsCardState();
}

class _AnnouncementsCardState extends State<AnnouncementsCard> {
  bool _loading = true;
  bool _failed = false;
  List<Announcement> _items = const [];
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final all = await AnnouncementService.fetchForRole(widget.role);
      final active = activeAnnouncements(all, widget.role, DateTime.now());
      if (!mounted) return;
      setState(() {
        _items = active;
        _loading = false;
      });
      await _popUnseenPinned(active);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _popUnseenPinned(List<Announcement> active) async {
    final pinnedIds = active.where((item) => item.pinned).map((e) => e.id);
    if (pinnedIds.isEmpty) return;
    final seen = await AnnouncementService.seenIds(pinnedIds);
    while (true) {
      final next = nextUnseenPinned(active, seen);
      if (next == null || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AnnouncementPopup(item: next),
      );
      seen.add(next.id);
      AnnouncementService.markSeen(next.id).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    Widget body;
    if (_failed) {
      body = Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.announcementsLoadError,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
            TextButton(onPressed: _load, child: Text(l10n.tryAgain)),
          ],
        ),
      );
    } else if (_items.isEmpty) {
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.announcementsEmpty,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          for (final item in _items)
            AnnouncementTile(
              item: item,
              expanded: _expanded.contains(item.id),
              onToggle: () => setState(() {
                if (!_expanded.remove(item.id)) _expanded.add(item.id);
              }),
            ),
        ],
      );
    }

    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded,
                    size: 18, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.announcementsTitle,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

/// One announcement in a list: title, byline, the message (folded when long).
class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggle,
    this.footer,
    this.trailing,
  });

  final Announcement item;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final long =
        item.body.length > _longBody || '\n'.allMatches(item.body).length >= 4;
    final byline = announcementByline(context, item);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: item.pinned ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              item.pinned ? const Color(0xFFBFDBFE) : const Color(0x0D000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.pinned)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Icon(Icons.push_pin_rounded,
                      size: 14,
                      color: _accent,
                      semanticLabel: l10n.announcementsPinned),
                ),
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (byline.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                byline,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          if (item.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item.body,
                maxLines: long && !expanded ? 4 : null,
                overflow: long && !expanded
                    ? TextOverflow.ellipsis
                    : TextOverflow.clip,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
          if (long)
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  expanded
                      ? l10n.announcementsShowLess
                      : l10n.announcementsShowMore,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
              ),
            ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// A pinned announcement opened as a pop-up.
class AnnouncementPopup extends StatelessWidget {
  const AnnouncementPopup({super.key, required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final byline = announcementByline(context, item);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.campaign_rounded, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.announcementsLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: _accent,
                  ),
                ),
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                if (byline.isNotEmpty)
                  Text(
                    byline,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      content: item.body.isEmpty
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Text(
                  item.body,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(backgroundColor: _accent),
          child: Text(l10n.announcementsGotIt),
        ),
      ],
    );
  }
}
