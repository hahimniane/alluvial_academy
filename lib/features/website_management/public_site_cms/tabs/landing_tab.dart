import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/core/models/public_site_cms_models.dart';
import 'package:alluwalacademyadmin/core/services/public_site_cms_service.dart';
import 'package:alluwalacademyadmin/core/utils/platform_image_bytes.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/widgets/image_upload_zone.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class PublicSiteLandingTab extends StatefulWidget {
  const PublicSiteLandingTab({super.key});

  @override
  State<PublicSiteLandingTab> createState() => _PublicSiteLandingTabState();
}

class _PublicSiteLandingTabState extends State<PublicSiteLandingTab> {
  bool _loading = true;
  bool _saving = false;
  String? _uploadingSlot;
  late final TextEditingController _bgHex;
  late final TextEditingController _mainUrl;
  late final TextEditingController _leftUrl;
  late final TextEditingController _rightUrl;

  @override
  void initState() {
    super.initState();
    _bgHex = TextEditingController();
    _mainUrl = TextEditingController();
    _leftUrl = TextEditingController();
    _rightUrl = TextEditingController();
    PublicSiteCmsService.syncAdminClaimForPublicSiteStorage();
    _load();
  }

  @override
  void dispose() {
    _bgHex.dispose();
    _mainUrl.dispose();
    _leftUrl.dispose();
    _rightUrl.dispose();
    super.dispose();
  }

  Color _previewBgColor() {
    return Color(PublicSiteLandingDoc.parseHeroBackgroundArgb(_bgHex.text));
  }

  String _colorToHex6(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _openColorPicker() {
    final l = AppLocalizations.of(context)!;
    var working = _previewBgColor();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInDialog) {
            return AlertDialog(
              title: Text(l.publicSiteCmsHeroColorPickerTitle),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: working,
                  onColorChanged: (c) {
                    setInDialog(() {
                      working = c;
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    _bgHex.text = _colorToHex6(working);
                    setState(() {});
                    Navigator.pop(ctx);
                  },
                  child: Text(l.commonSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await PublicSiteCmsService.getLandingDoc();
      if (!mounted) return;
      setState(() {
        _bgHex.text = d.heroBackgroundColorHex;
        _mainUrl.text = d.heroMainImageUrl;
        _leftUrl.text = d.heroLeftImageUrl;
        _rightUrl.text = d.heroRightImageUrl;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.commonError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await PublicSiteCmsService.saveLandingDoc(
        PublicSiteLandingDoc(
          heroBackgroundColorHex: _bgHex.text,
          heroMainImageUrl: _mainUrl.text,
          heroLeftImageUrl: _leftUrl.text,
          heroRightImageUrl: _rightUrl.text,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.publicSiteCmsLandingSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.commonError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickUpload(String slotId) async {
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
      setState(() => _uploadingSlot = slotId);
      final url = await PublicSiteCmsService.uploadLandingHeroImage(
        slotId: slotId,
        bytes: bytes,
        fileName: f.name,
      );
      switch (slotId) {
        case 'main':
          _mainUrl.text = url;
          break;
        case 'left':
          _leftUrl.text = url;
          break;
        case 'right':
          _rightUrl.text = url;
          break;
      }
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
        setState(() => _uploadingSlot = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 960;
        final heroBlock = Material(
          color: PublicSiteCmsTheme.surface,
          borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusLg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: PublicSiteCmsTheme.border),
              borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusLg),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.publicSiteCmsLandingHeroBg,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: PublicSiteCmsTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: l.publicSiteCmsHeroColorPickerTitle,
                        child: InkWell(
                          onTap: _openColorPicker,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _previewBgColor(),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: PublicSiteCmsTheme.border),
                            ),
                            child: const Icon(Icons.color_lens_outlined, size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: _bgHex,
                          builder: (context, _) {
                            return TextField(
                              controller: _bgHex,
                              onChanged: (_) => setState(() {}),
                              style: GoogleFonts.inter(),
                              decoration: InputDecoration(
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
                                  borderSide: const BorderSide(
                                    color: PublicSiteCmsTheme.accentNavy,
                                    width: 1.5,
                                  ),
                                ),
                                hintText: l.publicSiteCmsLandingHeroBgHint,
                                hintStyle: GoogleFonts.inter(
                                  color: PublicSiteCmsTheme.textTertiary,
                                  fontSize: 13,
                                ),
                              ),
                              autocorrect: false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                children: [
                  Text(
                    l.publicSiteCmsLandingIntro,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: PublicSiteCmsTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  heroBlock,
                  const SizedBox(height: 12),
                  if (wide) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ImageUploadZone(
                            title: l.publicSiteCmsLandingMainImage,
                            urlController: _mainUrl,
                            busy: _uploadingSlot == 'main',
                            onPick: _uploadingSlot != null ? () {} : () => _pickUpload('main'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ImageUploadZone(
                            title: l.publicSiteCmsLandingLeftImage,
                            urlController: _leftUrl,
                            busy: _uploadingSlot == 'left',
                            onPick: _uploadingSlot != null ? () {} : () => _pickUpload('left'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ImageUploadZone(
                            title: l.publicSiteCmsLandingRightImage,
                            urlController: _rightUrl,
                            busy: _uploadingSlot == 'right',
                            onPick: _uploadingSlot != null ? () {} : () => _pickUpload('right'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ImageUploadZone(
                        title: l.publicSiteCmsLandingMainImage,
                        urlController: _mainUrl,
                        busy: _uploadingSlot == 'main',
                        onPick: _uploadingSlot != null ? () {} : () => _pickUpload('main'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ImageUploadZone(
                        title: l.publicSiteCmsLandingLeftImage,
                        urlController: _leftUrl,
                        busy: _uploadingSlot == 'left',
                        onPick: _uploadingSlot != null ? () {} : () => _pickUpload('left'),
                      ),
                    ),
                    ImageUploadZone(
                      title: l.publicSiteCmsLandingRightImage,
                      urlController: _rightUrl,
                      busy: _uploadingSlot == 'right',
                      onPick: _uploadingSlot != null ? () {} : () => _pickUpload('right'),
                    ),
                  ],
                ],
              ),
            ),
            Material(
              color: PublicSiteCmsTheme.surface,
              elevation: 6,
              shadowColor: Colors.black26,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(height: 1, thickness: 1, color: PublicSiteCmsTheme.borderStrong),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: PublicSiteCmsTheme.accentNavy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusMd),
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 20),
                        label: Text(
                          l.publicSiteCmsSaveLanding,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                    ),
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
