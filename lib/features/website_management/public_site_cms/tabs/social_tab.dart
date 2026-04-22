import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/core/models/public_site_cms_models.dart';
import 'package:alluwalacademyadmin/core/services/public_site_cms_service.dart';
import 'package:alluwalacademyadmin/features/website_management/public_site_cms/theme/public_site_cms_tokens.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class PublicSiteSocialTab extends StatefulWidget {
  const PublicSiteSocialTab({super.key});

  @override
  State<PublicSiteSocialTab> createState() => _PublicSiteSocialTabState();
}

class _PublicSiteSocialTabState extends State<PublicSiteSocialTab> {
  bool _loading = true;
  bool _saving = false;
  bool _instagramOn = false;
  bool _facebookOn = false;
  bool _tiktokOn = false;
  late final TextEditingController _instagramUrl;
  late final TextEditingController _facebookUrl;
  late final TextEditingController _tiktokUrl;

  @override
  void initState() {
    super.initState();
    _instagramUrl = TextEditingController();
    _facebookUrl = TextEditingController();
    _tiktokUrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _instagramUrl.dispose();
    _facebookUrl.dispose();
    _tiktokUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await PublicSiteCmsService.getSocialDoc();
      if (!mounted) return;
      setState(() {
        _instagramOn = d.instagram.enabled;
        _facebookOn = d.facebook.enabled;
        _tiktokOn = d.tiktok.enabled;
        _instagramUrl.text = d.instagram.url;
        _facebookUrl.text = d.facebook.url;
        _tiktokUrl.text = d.tiktok.url;
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
      await PublicSiteCmsService.saveSocialDoc(
        PublicSiteSocialDoc(
          instagram: PublicSiteSocialNetwork(
            enabled: _instagramOn,
            url: _instagramUrl.text,
          ),
          facebook: PublicSiteSocialNetwork(
            enabled: _facebookOn,
            url: _facebookUrl.text,
          ),
          tiktok: PublicSiteSocialNetwork(
            enabled: _tiktokOn,
            url: _tiktokUrl.text,
          ),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.publicSiteCmsSocialSaved)),
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

  Widget _networkCard({
    required String title,
    required IconData faIcon,
    required bool enabled,
    required ValueChanged<bool> onEnabled,
    required TextEditingController urlCtrl,
  }) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: PublicSiteCmsTheme.surface,
        borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusLg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: PublicSiteCmsTheme.border),
            borderRadius: BorderRadius.circular(PublicSiteCmsTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      FaIcon(faIcon, size: 18, color: PublicSiteCmsTheme.accentNavy),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: PublicSiteCmsTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    l.publicSiteCmsSocialShowIcon,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: PublicSiteCmsTheme.textSecondary,
                    ),
                  ),
                  value: enabled,
                  onChanged: onEnabled,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlCtrl,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: l.publicSiteCmsSocialUrl,
                    hintText: 'https://…',
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
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            children: [
              Text(
                l.publicSiteCmsSocialIntro,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: PublicSiteCmsTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _networkCard(
                title: l.publicSiteCmsSocialInstagram,
                faIcon: FontAwesomeIcons.instagram,
                enabled: _instagramOn,
                onEnabled: (v) => setState(() => _instagramOn = v),
                urlCtrl: _instagramUrl,
              ),
              _networkCard(
                title: l.publicSiteCmsSocialFacebook,
                faIcon: FontAwesomeIcons.facebookF,
                enabled: _facebookOn,
                onEnabled: (v) => setState(() => _facebookOn = v),
                urlCtrl: _facebookUrl,
              ),
              _networkCard(
                title: l.publicSiteCmsSocialTiktok,
                faIcon: FontAwesomeIcons.tiktok,
                enabled: _tiktokOn,
                onEnabled: (v) => setState(() => _tiktokOn = v),
                urlCtrl: _tiktokUrl,
              ),
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
                      l.publicSiteCmsSaveSocial,
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
  }
}
