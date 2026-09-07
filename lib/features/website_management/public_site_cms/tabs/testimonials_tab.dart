import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/core/utils/platform_image_bytes.dart';
import 'package:alluwalacademyadmin/core/models/public_site_cms_models.dart';
import 'package:alluwalacademyadmin/core/services/public_site_cms_service.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/widgets/hover_list_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Quotes from parents, students and teachers shown on the public home page.
/// Mirrors the "Testimonials" tab of the web CMS: same collection, same fields.
class PublicSiteTestimonialsTab extends StatefulWidget {
  const PublicSiteTestimonialsTab({super.key});

  @override
  State<PublicSiteTestimonialsTab> createState() => _PublicSiteTestimonialsTabState();
}

class _PublicSiteTestimonialsTabState extends State<PublicSiteTestimonialsTab> {
  bool _importing = false;

  String _categoryLabel(AppLocalizations l, String category) {
    switch (category) {
      case 'parent':
        return l.publicSiteCmsTestimonialCategoryParent;
      case 'student':
        return l.publicSiteCmsTestimonialCategoryStudent;
      case 'teacher':
        return l.publicSiteCmsTestimonialCategoryTeacher;
      default:
        return l.publicSiteCmsTestimonialCategoryOther;
    }
  }

  Future<void> _importDefaults() async {
    if (_importing) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = AppLocalizations.of(context)!;
    setState(() => _importing = true);
    try {
      final r = await PublicSiteCmsService.importDefaultTestimonials();
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text(l.publicSiteCmsTestimonialImportDone(r.imported, r.skipped))),
      );
    } catch (e) {
      if (mounted) {
        messenger?.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _confirmDelete(PublicSiteTestimonial t) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.publicSiteCmsTestimonialDeleteTitle),
        content: Text('${t.name}: “${t.quote}”'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.commonDelete)),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await PublicSiteCmsService.deleteTestimonial(t.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _openEditor({PublicSiteTestimonial? existing, required int nextSortOrder}) async {
    final saved = await showDialog<PublicSiteTestimonial>(
      context: context,
      builder: (_) => _TestimonialEditorDialog(existing: existing, nextSortOrder: nextSortOrder),
    );
    if (saved == null || !mounted) return;
    final l = AppLocalizations.of(context)!;
    try {
      await PublicSiteCmsService.saveTestimonial(saved);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saved.active ? l.publicSiteCmsTestimonialPublished : l.publicSiteCmsTestimonialDraftSaved)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return StreamBuilder<List<PublicSiteTestimonial>>(
      stream: PublicSiteCmsService.testimonialsAdminCmsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('${l.commonError}: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!;
        final nextSortOrder = docs.fold<int>(0, (m, t) => t.sortOrder > m ? t.sortOrder : m) + 1;

        return Stack(
          children: [
            if (docs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l.publicSiteCmsTestimonialsEmpty,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: const Color(0xff64748B)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l.publicSiteCmsTestimonialsIntro,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, height: 1.35, color: const Color(0xff94A3B8)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final t = docs[i];
                  return HoverListCard(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE6EEF8),
                        foregroundColor: PublicSiteCmsTheme.accentNavy,
                        backgroundImage: (t.imageUrl ?? '').isNotEmpty ? NetworkImage(t.imageUrl!) : null,
                        child: (t.imageUrl ?? '').isNotEmpty
                            ? null
                            : Text(publicSiteInitials(t.name),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      title: Text(
                        t.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: PublicSiteCmsTheme.textPrimary),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_categoryLabel(l, t.category)}${t.role.isNotEmpty ? ' · ${t.role}' : ''} · #${t.sortOrder}'
                            '${t.active ? '' : ' · ${l.publicSiteCmsTestimonialDraftBadge}'}',
                            style: GoogleFonts.inter(fontSize: 13, color: PublicSiteCmsTheme.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '“${t.quote}”',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 13, height: 1.35, color: const Color(0xFF334155)),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openEditor(existing: t, nextSortOrder: nextSortOrder),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(t),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: _importing ? null : _importDefaults,
                      icon: _importing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_download_outlined),
                      label: Text(l.publicSiteCmsTestimonialImportDefaults),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openEditor(nextSortOrder: nextSortOrder),
                    icon: const Icon(Icons.format_quote_rounded),
                    label: Text(l.publicSiteCmsTestimonialAdd),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TestimonialEditorDialog extends StatefulWidget {
  const _TestimonialEditorDialog({this.existing, required this.nextSortOrder});

  final PublicSiteTestimonial? existing;
  final int nextSortOrder;

  @override
  State<_TestimonialEditorDialog> createState() => _TestimonialEditorDialogState();
}

class _TestimonialEditorDialogState extends State<_TestimonialEditorDialog> {
  late final TextEditingController _quote = TextEditingController(text: widget.existing?.quote ?? '');
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _role = TextEditingController(text: widget.existing?.role ?? '');
  late final String _id = widget.existing?.id ?? PublicSiteCmsService.newTestimonialId();
  String? _imageUrl;
  bool _uploading = false;
  late final TextEditingController _sortOrder =
      TextEditingController(text: '${widget.existing?.sortOrder ?? widget.nextSortOrder}');
  late String _category = widget.existing?.category ?? 'parent';
  late bool _active = widget.existing?.active ?? true;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.existing?.imageUrl;
  }

  @override
  void dispose() {
    _quote.dispose();
    _name.dispose();
    _role.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final l = AppLocalizations.of(context)!;
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: !kIsWeb,
        withReadStream: kIsWeb,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.first;
      final bytes = await readPlatformImageBytes(f);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.publicSiteCmsUploadNoBytes)));
        }
        return;
      }
      setState(() => _uploading = true);
      final url = await PublicSiteCmsService.uploadTestimonialPhoto(
        testimonialId: _id,
        bytes: bytes,
        fileName: f.name,
      );
      if (!mounted) return;
      setState(() => _imageUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.publicSiteCmsUploadDone)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _submit() {
    final l = AppLocalizations.of(context)!;
    final quote = _quote.text.trim();
    final name = _name.text.trim();
    if (quote.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.publicSiteCmsTestimonialNeedsQuoteAndName), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.of(context).pop(PublicSiteTestimonial(
      id: _id,
      quote: quote,
      name: name,
      role: _role.text.trim(),
      category: _category,
      imageUrl: _imageUrl,
      sortOrder: int.tryParse(_sortOrder.text.trim()) ?? widget.nextSortOrder,
      active: _active,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    InputDecoration deco(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder());
    return AlertDialog(
      title: Text(
        widget.existing == null ? l.publicSiteCmsTestimonialAdd : l.publicSiteCmsTestimonialEdit,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _quote, maxLines: 4, decoration: deco(l.publicSiteCmsTestimonialQuote)),
              const SizedBox(height: 12),
              TextField(controller: _name, decoration: deco(l.publicSiteCmsTestimonialName)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: deco(l.publicSiteCmsTestimonialCategory),
                items: [
                  DropdownMenuItem(value: 'parent', child: Text(l.publicSiteCmsTestimonialCategoryParent)),
                  DropdownMenuItem(value: 'student', child: Text(l.publicSiteCmsTestimonialCategoryStudent)),
                  DropdownMenuItem(value: 'teacher', child: Text(l.publicSiteCmsTestimonialCategoryTeacher)),
                  DropdownMenuItem(value: 'other', child: Text(l.publicSiteCmsTestimonialCategoryOther)),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'parent'),
              ),
              const SizedBox(height: 12),
              TextField(controller: _role, decoration: deco(l.publicSiteCmsTestimonialRole)),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFE6EEF8),
                    foregroundColor: PublicSiteCmsTheme.accentNavy,
                    backgroundImage: (_imageUrl ?? '').isNotEmpty ? NetworkImage(_imageUrl!) : null,
                    child: (_imageUrl ?? '').isNotEmpty
                        ? null
                        : Text(publicSiteInitials(_name.text).isEmpty ? '?' : publicSiteInitials(_name.text),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickAndUpload,
                          icon: _uploading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_outlined, size: 18),
                          label: Text((_imageUrl ?? '').isNotEmpty
                              ? l.publicSiteCmsTestimonialReplacePhoto
                              : l.publicSiteCmsUploadPhoto),
                        ),
                        if ((_imageUrl ?? '').isNotEmpty)
                          TextButton(
                            onPressed: _uploading ? null : () => setState(() => _imageUrl = null),
                            child: Text(l.publicSiteCmsTestimonialRemovePhoto),
                          )
                        else
                          Text(
                            l.publicSiteCmsTestimonialPhotoHint,
                            style: GoogleFonts.inter(fontSize: 12, color: PublicSiteCmsTheme.textTertiary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sortOrder,
                keyboardType: TextInputType.number,
                decoration: deco(l.publicSiteCmsTestimonialSortOrder),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(l.publicSiteCmsTestimonialPublishedToggle, style: GoogleFonts.inter(fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.commonCancel)),
        FilledButton(
          onPressed: _uploading ? null : _submit,
          child: Text(_active ? l.publicSiteCmsTestimonialPublish : l.publicSiteCmsTestimonialSaveDraft),
        ),
      ],
    );
  }
}
