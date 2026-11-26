import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/models/announcement.dart';
import 'package:alluwalacademyadmin/core/services/announcement_service.dart';
import 'package:alluwalacademyadmin/core/widgets/announcements_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'admin_action_cards.dart';

const _accent = Color(0xFF0386FF);

/// Admin home: the published announcements (newest first), "New announcement"
/// and removing one.
class AnnouncementsAdminCard extends StatefulWidget {
  const AnnouncementsAdminCard({super.key});

  @override
  State<AnnouncementsAdminCard> createState() => _AnnouncementsAdminCardState();
}

class _AnnouncementsAdminCardState extends State<AnnouncementsAdminCard> {
  late Future<List<Announcement>> _future;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _future = AnnouncementService.fetchAllPublished();
  }

  void _reload() {
    setState(() => _future = AnnouncementService.fetchAllPublished());
  }

  Future<void> _compose() async {
    final posted = await showDialog<bool>(
      context: context,
      builder: (_) => const NewAnnouncementDialog(),
    );
    if (posted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.announcementsPosted)),
      );
      _reload();
    }
  }

  Future<void> _remove(Announcement item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.announcementsRemoveConfirmTitle),
        content: Text(l10n.announcementsRemoveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AnnouncementService.archive(item.id);
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.announcementsRemoved)));
      _reload();
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.announcementsRemoveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AdminActionCardShell(
      title: l10n.announcementsTitle,
      icon: Icons.campaign_rounded,
      accentColor: _accent,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: _compose,
              style: FilledButton.styleFrom(backgroundColor: _accent),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.announcementsNew),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Announcement>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              if (snapshot.hasError) {
                return Row(
                  children: [
                    Expanded(child: _note(l10n.announcementsLoadError)),
                    TextButton(onPressed: _reload, child: Text(l10n.tryAgain)),
                  ],
                );
              }
              final items = snapshot.data ?? const <Announcement>[];
              if (items.isEmpty) return _note(l10n.announcementsEmpty);
              final now = DateTime.now();
              return Column(
                children: [
                  for (final item in items)
                    AnnouncementTile(
                      item: item,
                      expanded: _expanded.contains(item.id),
                      onToggle: () => setState(() {
                        if (!_expanded.remove(item.id)) _expanded.add(item.id);
                      }),
                      trailing: IconButton(
                        tooltip: l10n.remove,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _remove(item),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Color(0xFF94A3B8)),
                      ),
                      footer: _Facts(item: item, now: now),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
      );
}

String audienceLabel(AppLocalizations l10n, String role) {
  switch (role) {
    case 'teacher':
      return l10n.announcementsAudienceTeachers;
    case 'student':
      return l10n.announcementsAudienceStudents;
    case 'parent':
      return l10n.announcementsAudienceParents;
    default:
      return l10n.announcementsAudienceAdmins;
  }
}

/// Who an announcement goes to and until when.
class _Facts extends StatelessWidget {
  const _Facts({required this.item, required this.now});

  final Announcement item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final everyone = Announcement.roles.every(item.audience.contains);
    final labels = <String>[
      everyone
          ? l10n.announcementsAudienceEveryone
          : item.audience.map((role) => audienceLabel(l10n, role)).join(', '),
      if (item.pinned) l10n.announcementsPinned,
      if (item.expiresAt != null)
        item.isActive(now)
            ? l10n.announcementsShownUntil(
                announcementDate(context, item.expiresAt))
            : l10n
                .announcementsEnded(announcementDate(context, item.expiresAt)),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final label in labels)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Title, message, audience, pin, end date and the phone-notification switch.
/// Pops true once the announcement is posted.
class NewAnnouncementDialog extends StatefulWidget {
  const NewAnnouncementDialog({super.key});

  @override
  State<NewAnnouncementDialog> createState() => _NewAnnouncementDialogState();
}

class _NewAnnouncementDialogState extends State<NewAnnouncementDialog> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  final Set<String> _audience = Announcement.roles.toSet();
  bool _pinned = false;
  bool _sendPush = false;
  DateTime? _showUntil;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _problemText(
      AppLocalizations l10n, AnnouncementDraftProblem? problem) {
    switch (problem) {
      case null:
        return null;
      case AnnouncementDraftProblem.titleMissing:
        return l10n.announcementsTitleMissing;
      case AnnouncementDraftProblem.titleTooLong:
        return l10n.announcementsTitleTooLong(Announcement.titleMax);
      case AnnouncementDraftProblem.bodyMissing:
        return l10n.announcementsMessageMissing;
      case AnnouncementDraftProblem.bodyTooLong:
        return l10n.announcementsMessageTooLong(Announcement.bodyMax);
      case AnnouncementDraftProblem.noAudience:
        return l10n.announcementsNoAudience;
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _showUntil ?? today.add(const Duration(days: 7)),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 366)),
    );
    if (picked != null) setState(() => _showUntil = picked);
  }

  Future<void> _post() async {
    final l10n = AppLocalizations.of(context)!;
    final problem = announcementDraftProblem(
      title: _title.text,
      body: _message.text,
      audience: _audience,
    );
    if (problem != null) {
      setState(() => _error = _problemText(l10n, problem));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final until = _showUntil;
    try {
      await AnnouncementService.create(
        title: _title.text,
        body: _message.text,
        audience: _audience.toList(),
        pinned: _pinned,
        // Shown through the whole chosen day.
        expiresAt: until == null
            ? null
            : DateTime(until.year, until.month, until.day, 23, 59, 59),
        sendPush: _sendPush,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.announcementsPostFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labelStyle = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF334155),
    );
    return AlertDialog(
      title: Text(l10n.announcementsNew),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                maxLength: Announcement.titleMax,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.announcementsFieldTitle,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _message,
                maxLength: Announcement.bodyMax,
                minLines: 4,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.announcementsFieldMessage,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.announcementsAudience, style: labelStyle),
              Wrap(
                spacing: 4,
                children: [
                  for (final role in Announcement.roles)
                    SizedBox(
                      width: 160,
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _audience.contains(role),
                        title: Text(audienceLabel(l10n, role)),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _audience.add(role);
                          } else {
                            _audience.remove(role);
                          }
                        }),
                      ),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pinned,
                onChanged: (value) => setState(() => _pinned = value),
                title: Text(l10n.announcementsPin, style: labelStyle),
                subtitle: Text(l10n.announcementsPinHelper),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(l10n.announcementsShowUntil, style: labelStyle),
                subtitle: Text(_showUntil == null
                    ? l10n.announcementsNoEndDate
                    : announcementDate(context, _showUntil)),
                onTap: _pickDate,
                trailing: _showUntil == null
                    ? null
                    : IconButton(
                        tooltip: l10n.announcementsClearEndDate,
                        onPressed: () => setState(() => _showUntil = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _sendPush,
                onChanged: (value) => setState(() => _sendPush = value),
                title: Text(l10n.announcementsSendPush, style: labelStyle),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _post,
          style: FilledButton.styleFrom(backgroundColor: _accent),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.announcementsPost),
        ),
      ],
    );
  }
}
