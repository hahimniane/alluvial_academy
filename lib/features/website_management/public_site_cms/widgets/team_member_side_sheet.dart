import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/core/models/public_site_cms_models.dart';
import 'package:alluwalacademyadmin/core/services/public_site_cms_service.dart';
import 'package:alluwalacademyadmin/core/utils/platform_image_bytes.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/widgets/directory_user_picker_dialog.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/widgets/image_upload_zone.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TeamMemberSideSheet extends StatefulWidget {
  const TeamMemberSideSheet({super.key, this.existing});

  final PublicSiteTeamMember? existing;

  @override
  State<TeamMemberSideSheet> createState() => _TeamMemberSideSheetState();
}

class _TeamMemberSideSheetState extends State<TeamMemberSideSheet> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _city;
  late final TextEditingController _education;
  late final TextEditingController _bio;
  late final TextEditingController _why;
  late final TextEditingController _langs;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sort;
  String _category = 'teacher';
  bool _saving = false;
  bool _uploading = false;
  late final String _docId;
  String? _linkedUid;
  String _linkedSummary = '';
  bool _resolvingLinkedSummary = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _docId = e?.id ?? FirebaseFirestore.instance.collection(PublicSiteCmsService.teamCollection).doc().id;
    _name = TextEditingController(text: e?.name ?? '');
    _role = TextEditingController(text: e?.role ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _education = TextEditingController(text: e?.education ?? '');
    _bio = TextEditingController(text: e?.bio ?? '');
    _why = TextEditingController(text: e?.whyAlluwal ?? '');
    _langs = TextEditingController(text: e?.languages.join(', ') ?? '');
    _imageUrl = TextEditingController(text: e?.imageUrl ?? '');
    _sort = TextEditingController(text: e != null ? '${e.sortOrder}' : '0');
    if (e != null) {
      _category = e.category == 'leadership' ? 'leadership' : 'teacher';
    }
    final lu = e?.linkedUserUid?.trim();
    _linkedUid = (lu != null && lu.isNotEmpty) ? lu : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveLinkedSummary());
  }

  Future<void> _resolveLinkedSummary() async {
    final uid = _linkedUid;
    if (uid == null || uid.isEmpty) return;
    setState(() => _resolvingLinkedSummary = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      if (snap.exists) {
        final d = snap.data() ?? {};
        final em = (d['e-mail'] ?? d['email'] ?? '').toString();
        final fn = (d['first_name'] ?? d['first-name'] ?? '').toString();
        final ln = (d['last_name'] ?? d['last-name'] ?? '').toString();
        final dn = '$fn $ln'.trim();
        setState(() {
          _linkedSummary = dn.isNotEmpty ? '$dn · $em' : (em.isNotEmpty ? em : uid);
        });
      } else {
        setState(() => _linkedSummary = uid);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _linkedSummary = uid);
      }
    } finally {
      if (mounted) {
        setState(() => _resolvingLinkedSummary = false);
      }
    }
  }

  Future<void> _pickLinkedUser() async {
    final picked = await showDirectoryUserPickerDialog(context);
    if (!mounted || picked == null) return;
    setState(() {
      _linkedUid = picked.uid;
      _linkedSummary = '${picked.displayName} · ${picked.email}';
    });
  }

  void _clearLinkedUser() {
    setState(() {
      _linkedUid = null;
      _linkedSummary = '';
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _city.dispose();
    _education.dispose();
    _bio.dispose();
    _why.dispose();
    _langs.dispose();
    _imageUrl.dispose();
    _sort.dispose();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.publicSiteCmsUploadNoBytes)),
          );
        }
        return;
      }
      setState(() => _uploading = true);
      final url = await PublicSiteCmsService.uploadTeamPhoto(
        memberId: _docId,
        bytes: bytes,
        fileName: f.name,
      );
      _imageUrl.text = url;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.publicSiteCmsUploadDone)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  void _dismiss() {
    Scaffold.maybeOf(context)?.closeEndDrawer();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final langs = _langs.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final link = _linkedUid?.trim();
      if (link == null || link.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.publicSiteCmsLinkedUserRequired)),
          );
        }
        return;
      }
      if (_city.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.publicSiteCmsCityRequired)),
          );
        }
        return;
      }

      final member = PublicSiteTeamMember(
        id: _docId,
        name: _name.text.trim(),
        role: _role.text.trim(),
        city: _city.text.trim(),
        education: _education.text.trim(),
        bio: _bio.text.trim(),
        languages: langs,
        whyAlluwal: _why.text.trim(),
        imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
        photoAsset: widget.existing?.photoAsset,
        linkedUserUid: link,
        category: _category,
        sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
        active: true,
      );
      if (member.name.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.publicSiteCmsNameRequired)),
          );
        }
        return;
      }
      await PublicSiteCmsService.saveTeamMember(member);
      if (mounted) {
        _dismiss();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.publicSiteCmsTeamSaved)),
        );
      }
    } on PublicSiteCmsValidationException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'duplicate_linked_user' => l.publicSiteCmsDuplicateLinkedUser,
        'linked_user_required' => l.publicSiteCmsLinkedUserRequired,
        'city_required' => l.publicSiteCmsCityRequired,
        _ => e.code,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mq = MediaQuery.sizeOf(context);
    final maxH = math.min(900.0, mq.height - 40);

    InputDecoration d(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: PublicSiteCmsTheme.textSecondary, fontSize: 14),
        filled: true,
        fillColor: PublicSiteCmsTheme.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
          borderSide: const BorderSide(color: PublicSiteCmsTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
          borderSide: const BorderSide(color: PublicSiteCmsTheme.accentNavy, width: 1.5),
        ),
      );
    }

    return Material(
      color: PublicSiteCmsTheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? l.publicSiteCmsTeamAddProfile : l.commonEdit,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: PublicSiteCmsTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : _dismiss,
                    icon: const Icon(Icons.close),
                    tooltip: l.commonCancel,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: d(l.publicSiteCmsName),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _role,
                      decoration: d(l.publicSiteCmsRoleTitle),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use — controlled [setState] selection (not Form-managed)
                      value: _category,
                      decoration: d(l.publicSiteCmsCategory),
                      items: [
                        DropdownMenuItem(
                          value: 'leadership',
                          child: Text(l.publicSiteCmsCategoryLeadership),
                        ),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text(l.publicSiteCmsCategoryTeacher),
                        ),
                      ],
                      onChanged: (v) => setState(() => _category = v ?? 'teacher'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _city,
                      decoration: d(l.publicSiteCmsCity),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _education,
                      decoration: d(l.publicSiteCmsEducation),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bio,
                      maxLines: 3,
                      decoration: d(l.publicSiteCmsBio),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _why,
                      maxLines: 2,
                      decoration: d(l.publicSiteCmsWhyAlluwal),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _langs,
                      decoration: d(l.publicSiteCmsLanguagesComma),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sort,
                      keyboardType: TextInputType.number,
                      decoration: d(l.publicSiteCmsSortOrder),
                    ),
                    const SizedBox(height: 12),
                    ImageUploadZone(
                      title: l.publicSiteCmsImageUrl,
                      urlController: _imageUrl,
                      busy: _uploading,
                      onPick: _uploading ? () {} : _pickAndUpload,
                      actionLabel: l.publicSiteCmsUploadPhoto,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.publicSiteCmsLinkedUserSectionTitle,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: PublicSiteCmsTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_resolvingLinkedSummary)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else if (_linkedUid != null && _linkedUid!.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _linkedSummary.isNotEmpty ? _linkedSummary : _linkedUid!,
                        ),
                        subtitle: Text(
                          _linkedUid!,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l.publicSiteCmsClearLinkedUser,
                          onPressed: _clearLinkedUser,
                        ),
                      )
                    else
                      Text(
                        l.publicSiteCmsLinkedUserMissingHint,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: PublicSiteCmsTheme.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickLinkedUser,
                      icon: const Icon(Icons.person_search),
                      label: Text(l.publicSiteCmsPickLinkedUserButton),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: PublicSiteCmsTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : _dismiss,
                    child: Text(l.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: PublicSiteCmsTheme.accentNavy,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l.commonSave),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
