import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../services/class_contacts_service.dart';

enum ClassContactsVariant { teacher, parent, student }

/// Tap-to-call numbers for the people the signed-in user has classes with.
///
/// A teacher sees each student with their parents, a parent sees each child
/// with their teachers, a student sees their own teachers. Takes no space when
/// there is no one to show.
class ClassContactsCard extends StatefulWidget {
  const ClassContactsCard({
    super.key,
    required this.variant,
    this.margin = EdgeInsets.zero,
  });

  final ClassContactsVariant variant;
  final EdgeInsetsGeometry margin;

  @override
  State<ClassContactsCard> createState() => _ClassContactsCardState();
}

class _ClassContactsCardState extends State<ClassContactsCard> {
  bool _loading = true;
  ClassContacts? _contacts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final contacts = await ClassContactsService.load();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final contacts = _contacts;

    final String title;
    final String helper;
    switch (widget.variant) {
      case ClassContactsVariant.teacher:
        title = l10n.classContactsTeacherTitle;
        helper = l10n.classContactsTeacherHelper;
      case ClassContactsVariant.parent:
        title = l10n.classContactsParentTitle;
        helper = l10n.classContactsParentHelper;
      case ClassContactsVariant.student:
        title = l10n.classContactsStudentTitle;
        helper = l10n.classContactsStudentHelper;
    }

    Widget body;
    if (contacts == null) {
      body = _ErrorRow(onRetry: _load);
    } else {
      switch (widget.variant) {
        case ClassContactsVariant.teacher:
        case ClassContactsVariant.parent:
          final groups = widget.variant == ClassContactsVariant.teacher
              ? contacts.students
              : contacts.children;
          if (groups.isEmpty) return const SizedBox.shrink();
          body = ClassContactGroupList(groups: groups);
        case ClassContactsVariant.student:
          if (contacts.teachers.isEmpty) return const SizedBox.shrink();
          body = Column(
            children: [
              for (final contact in contacts.teachers)
                ClassContactRow(contact: contact),
            ],
          );
      }
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
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_rounded,
                    size: 18, color: Color(0xFF059669)),
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
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      helper,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
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

/// Students (or children), each with the people to call about them.
class ClassContactGroupList extends StatelessWidget {
  const ClassContactGroupList({super.key, required this.groups});

  final List<ClassContactGroup> groups;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        for (final group in groups)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.studentName.isEmpty
                      ? l10n.classContactsRelationStudent
                      : group.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (group.contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      l10n.classContactsNoPhone,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  )
                else
                  for (final contact in group.contacts)
                    ClassContactRow(contact: contact),
              ],
            ),
          ),
      ],
    );
  }
}

class ClassContactRow extends StatelessWidget {
  const ClassContactRow({super.key, required this.contact});

  final ClassContact contact;

  String _relationLabel(AppLocalizations l10n) =>
      switch (contact.relationship) {
        ClassContactRelationship.parent => l10n.classContactsRelationParent,
        ClassContactRelationship.student => l10n.classContactsRelationStudent,
        ClassContactRelationship.teacher => l10n.classContactsRelationTeacher,
      };

  Future<void> _call() async {
    await launchUrl(contact.telUri);
  }

  Future<void> _copy(BuildContext context) async {
    final message = AppLocalizations.of(context)!.classContactsCopied;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: contact.phone));
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final relation = _relationLabel(l10n);
    final name = contact.name.isEmpty ? relation : contact.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _call,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name · $relation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    Text(
                      contact.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0386FF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.classContactsCall(name),
            onPressed: _call,
            icon: const Icon(Icons.call_rounded),
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              minimumSize: const Size(40, 40),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: l10n.classContactsCopy,
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.classContactsLoadError,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF92400E),
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
      ],
    );
  }
}
